import { Inject, Injectable } from '@nestjs/common';
import { and, eq, ne, sql } from 'drizzle-orm';
import sharp from 'sharp';
import { DATABASE, type Database } from '../database/database.module';
import { species, speciesNames } from '../database/schema';
import { PhotoStorage } from '../photo-storage/photo-storage';
import type { CatalogSeedSpecies } from './catalog-seed';
import { ReferencePhotoDownloader } from './reference-photo-downloader';

/** The longest side of a Catalog reference photo, in pixels. */
export const REFERENCE_PHOTO_MAX_SIZE = 1200;

/** Which part of loading one species failed. */
export type CatalogLoadStep = 'species' | 'photo';

export interface CatalogLoadFailure {
  scientificName: string;
  step: CatalogLoadStep;
  reason: string;
}

export interface CatalogLoadSummary {
  /** Species of the seed now in the Catalog. */
  species: number;
  /** Of those, the ones this run created. */
  newSpecies: number;
  /** Reference photos this run copied to the storage. */
  photosCopied: number;
  failures: CatalogLoadFailure[];
}

/** The storage key of a species' own reference photo. */
export function referencePhotoKey(speciesId: string): string {
  return `species/${speciesId}.jpg`;
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/**
 * Loads the seed into the Catalog (`npm run catalog:load`). For each species
 * it upserts the row by `gbif_key`, syncs the names and, if the photo is not
 * in the storage yet, copies it there. Running it again duplicates nothing
 * and only completes what failed; a failure in one species never stops the
 * others.
 *
 * Constructor parameters use explicit `@Inject`, because the script runs on
 * tsx, which emits no decorator metadata.
 */
@Injectable()
export class CatalogLoader {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    @Inject(PhotoStorage) private readonly storage: PhotoStorage,
    @Inject(ReferencePhotoDownloader)
    private readonly downloader: ReferencePhotoDownloader,
  ) {}

  async load(
    seed: CatalogSeedSpecies[],
    onProgress: (item: CatalogSeedSpecies, index: number) => void = () =>
      undefined,
  ): Promise<CatalogLoadSummary> {
    const summary: CatalogLoadSummary = {
      species: 0,
      newSpecies: 0,
      photosCopied: 0,
      failures: [],
    };
    const fail = (
      item: CatalogSeedSpecies,
      step: CatalogLoadStep,
      error: unknown,
    ) => {
      summary.failures.push({
        scientificName: item.scientificName,
        step,
        reason: messageOf(error),
      });
    };

    for (const [index, item] of seed.entries()) {
      onProgress(item, index);
      let row: { id: string; isNew: boolean; hasOwnPhoto: boolean };
      try {
        row = await this.upsertSpecies(item);
      } catch (error) {
        fail(item, 'species', error);
        continue;
      }
      summary.species += 1;
      if (row.isNew) summary.newSpecies += 1;

      if (!row.hasOwnPhoto) {
        try {
          await this.copyReferencePhoto(row.id, item);
          summary.photosCopied += 1;
        } catch (error) {
          fail(item, 'photo', error);
        }
      }
    }
    return summary;
  }

  /**
   * Upserts the species and syncs its names in one transaction. Until its
   * photo is copied, the species shows the original by its URL, which keeps
   * the one-photo-field `CHECK` true.
   */
  private upsertSpecies(item: CatalogSeedSpecies) {
    const photo = item.referencePhoto;
    // Only while the species has no photo of its own is the credit replaced.
    const unlessOwnPhoto = (column: string) =>
      sql.raw(
        `CASE WHEN species.reference_photo_s3_key IS NULL THEN excluded.${column} ELSE species.${column} END`,
      );

    return this.db.transaction(async (tx) => {
      const [row] = await tx
        .insert(species)
        .values({
          gbifKey: item.gbifKey,
          scientificName: item.scientificName,
          referencePhotoUrl: photo.imageUrl,
          referencePhotoAuthor: photo.author,
          referencePhotoLicense: photo.license,
          referencePhotoSourceUrl: photo.sourceUrl,
          origin: 'seed',
        })
        .onConflictDoUpdate({
          target: species.gbifKey,
          set: {
            scientificName: sql.raw('excluded.scientific_name'),
            origin: sql.raw('excluded.origin'),
            referencePhotoUrl: unlessOwnPhoto('reference_photo_url'),
            referencePhotoAuthor: unlessOwnPhoto('reference_photo_author'),
            referencePhotoLicense: unlessOwnPhoto('reference_photo_license'),
            referencePhotoSourceUrl: unlessOwnPhoto(
              'reference_photo_source_url',
            ),
          },
        })
        .returning({
          id: species.id,
          // xmax is 0 only on a row this statement inserted.
          isNew: sql<boolean>`(xmax = 0)`,
          hasOwnPhoto: sql<boolean>`(${species.referencePhotoS3Key} IS NOT NULL)`,
        });
      if (!row) throw new Error('The species upsert returned no row');

      // In the seed, the primary name is Flora e Funga do Brasil's: one that
      // Claude made primary goes back to being an alternative name.
      await tx
        .update(speciesNames)
        .set({ isPrimary: false })
        .where(
          and(
            eq(speciesNames.speciesId, row.id),
            eq(speciesNames.isPrimary, true),
            ne(speciesNames.name, item.commonName),
          ),
        );
      await tx
        .insert(speciesNames)
        .values({ speciesId: row.id, name: item.commonName, isPrimary: true })
        .onConflictDoUpdate({
          target: [speciesNames.speciesId, speciesNames.name],
          set: { isPrimary: true },
        });
      const otherNames = item.otherNames.filter(
        (name) => name !== item.commonName,
      );
      if (otherNames.length > 0) {
        // Names only grow: Claude's alternative names stay.
        await tx
          .insert(speciesNames)
          .values(otherNames.map((name) => ({ speciesId: row.id, name })))
          .onConflictDoNothing();
      }
      return row;
    });
  }

  /**
   * Downloads the photo, shrinks it to {@link REFERENCE_PHOTO_MAX_SIZE} and
   * stores it as JPEG without the `unattached` tag: it belongs to the
   * Catalog, so the lifecycle rule must never delete it.
   */
  private async copyReferencePhoto(
    speciesId: string,
    item: CatalogSeedSpecies,
  ): Promise<void> {
    const original = await this.downloader.download(
      item.referencePhoto.imageUrl,
    );
    const jpeg = await sharp(original)
      .rotate()
      .resize({
        width: REFERENCE_PHOTO_MAX_SIZE,
        height: REFERENCE_PHOTO_MAX_SIZE,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .jpeg({ quality: 85, mozjpeg: true })
      .toBuffer();
    const key = referencePhotoKey(speciesId);
    await this.storage.put(key, jpeg, { unattached: false });
    await this.db
      .update(species)
      .set({
        referencePhotoS3Key: key,
        referencePhotoUrl: null,
        referencePhotoAuthor: item.referencePhoto.author,
        referencePhotoLicense: item.referencePhoto.license,
        referencePhotoSourceUrl: item.referencePhoto.sourceUrl,
      })
      .where(eq(species.id, speciesId));
  }
}

/** The summary printed at the end of the load (script output: English). */
export function formatCatalogLoadSummary(summary: CatalogLoadSummary): string {
  const lines = [
    `Species in the Catalog: ${String(summary.species)} (${String(summary.newSpecies)} new)`,
    `Reference photos copied: ${String(summary.photosCopied)}`,
  ];
  if (summary.failures.length === 0) {
    lines.push('Failures: none');
  } else {
    lines.push(`Failures (${String(summary.failures.length)}):`);
    for (const failure of summary.failures) {
      lines.push(
        `  - ${failure.scientificName} (${failure.step}): ${failure.reason}`,
      );
    }
    lines.push('Run it again to retry what failed.');
  }
  return lines.join('\n');
}
