import { Inject, Injectable, Logger } from '@nestjs/common';
import { and, count, eq, gte, inArray } from 'drizzle-orm';
import { z } from 'zod';
import { CatalogService } from '../catalog/catalog.service';
import type { SpeciesItemResponse } from '../catalog/species.dto';
import { DATABASE, type Database } from '../database/database.module';
import { identifications, species, speciesNames } from '../database/schema';
import { startOfToday } from '../database/today';
import { DomainError } from '../errors/domain-error';
import { GbifNames } from '../gbif/gbif-names';
import { PhotosService } from '../photos/photos.service';
import { plausibleCommonName } from './candidate-common-name';
import type {
  CandidateResponse,
  ChoiceRequestBody,
  IdentificationResponse,
} from './identification.dto';
import {
  IdentificationServiceUnavailableError,
  PlantIdentifier,
  type RawCandidate,
} from './plant-identifier';

/** How many identifications a User may make per day. */
export const IDENTIFICATION_DAILY_LIMIT = 10;

/**
 * Below this top score the photo is "not recognized": it only stops useless
 * photos (not a plant, blurred); docs/research/teste-plantnet.md.
 */
export const RECOGNITION_THRESHOLD = 0.2;

/**
 * A candidate as the `identifications.candidates` column keeps it: what
 * Pl@ntNet answered, with the `gbifKey` GBIF resolved when Pl@ntNet had none.
 * For a recognized photo the column holds the shown candidates, in order, so
 * `candidateIndex` points into it; otherwise Pl@ntNet's raw list.
 */
const storedCandidateSchema = z.object({
  scientificName: z.string(),
  commonNames: z.array(z.string()),
  score: z.number(),
  gbifKey: z.int(),
  images: z.array(
    z.object({
      url: z.string(),
      author: z.string(),
      license: z.string(),
      sourceUrl: z.string(),
    }),
  ),
});

type StoredCandidate = z.infer<typeof storedCandidateSchema>;

/** A candidate that can be shown and chosen, with its name for the app. */
interface UsableCandidate extends StoredCandidate {
  commonName: string | null;
}

/**
 * Identification by photo: asks Pl@ntNet, within the daily limit, and turns
 * the chosen candidate into a Catalog species.
 */
@Injectable()
export class IdentificationsService {
  private readonly logger = new Logger(IdentificationsService.name);

  constructor(
    @Inject(DATABASE) private readonly db: Database,
    @Inject(PlantIdentifier) private readonly identifier: PlantIdentifier,
    @Inject(GbifNames) private readonly gbif: GbifNames,
    @Inject(PhotosService) private readonly photos: PhotosService,
    @Inject(CatalogService) private readonly catalog: CatalogService,
  ) {}

  /**
   * Identifies [userId]'s photo [photoId]. The daily limit is checked before
   * Pl@ntNet is called; a Pl@ntNet failure leaves no row, so it does not
   * count. Any answer, recognized or not, counts and attaches the photo.
   */
  async identify(
    userId: string,
    photoId: string,
  ): Promise<IdentificationResponse> {
    const usedToday = await this.countToday(userId);
    if (usedToday >= IDENTIFICATION_DAILY_LIMIT) {
      throw new DomainError('IDENTIFICATION_DAILY_LIMIT');
    }
    const photo = await this.photos.findOwned(userId, photoId);
    const raw = await this.askIdentifier(await this.photos.read(photo));

    const usable = await this.usableCandidates(raw);
    const recognized =
      usable.length > 0 && (raw[0]?.score ?? 0) >= RECOGNITION_THRESHOLD;

    await this.photos.attach(photo);
    const [row] = await this.db
      .insert(identifications)
      .values({
        userId,
        photoId: photo.id,
        result: recognized ? 'recognized' : 'not_recognized',
        candidates: recognized ? usable.map(toStored) : raw,
      })
      .returning();
    if (!row) throw new Error('The identification insert returned no row');

    return {
      id: row.id,
      result: row.result,
      candidates: recognized ? usable.map(toResponse) : [],
      remainingToday: IDENTIFICATION_DAILY_LIMIT - usedToday - 1,
    };
  }

  /**
   * Records [userId]'s choice on identification [id]: the chosen species
   * (added to the Catalog when new), or null for "nenhuma destas". One choice
   * per identification.
   */
  async choose(
    userId: string,
    id: string,
    choice: ChoiceRequestBody,
  ): Promise<SpeciesItemResponse | null> {
    const speciesId = await this.db.transaction(async (tx) => {
      const [row] = await tx
        .select()
        .from(identifications)
        .where(
          and(eq(identifications.id, id), eq(identifications.userId, userId)),
        )
        .for('update');
      if (!row) throw new DomainError('NOT_FOUND');
      if (row.chosenAt) throw new DomainError('IDENTIFICATION_ALREADY_CHOSEN');
      if (row.result === 'not_recognized') {
        throw new DomainError('VALIDATION_FAILED', {
          errors: [{ path: '', message: 'the photo was not recognized' }],
        });
      }

      let chosenSpeciesId: string | null = null;
      if (choice.candidateIndex !== undefined) {
        const candidates = z.array(storedCandidateSchema).parse(row.candidates);
        const candidate = candidates[choice.candidateIndex];
        if (!candidate) {
          throw new DomainError('VALIDATION_FAILED', {
            errors: [
              {
                path: 'candidateIndex',
                message: `there are ${String(candidates.length)} candidates`,
              },
            ],
          });
        }
        chosenSpeciesId = await this.upsertSpecies(tx, candidate);
      }

      await tx
        .update(identifications)
        .set({
          chosenSpeciesId,
          chosenNone: chosenSpeciesId === null,
          chosenAt: new Date(),
        })
        .where(eq(identifications.id, id));
      return chosenSpeciesId;
    });

    return speciesId === null ? null : this.speciesItem(speciesId);
  }

  private async countToday(userId: string): Promise<number> {
    const [today] = await this.db
      .select({ identifications: count() })
      .from(identifications)
      .where(
        and(
          eq(identifications.userId, userId),
          gte(identifications.createdAt, startOfToday()),
        ),
      );
    return today?.identifications ?? 0;
  }

  private async askIdentifier(photo: Buffer): Promise<RawCandidate[]> {
    try {
      return await this.identifier.identify(photo);
    } catch (error) {
      if (!(error instanceof IdentificationServiceUnavailableError)) {
        throw error;
      }
      this.logger.warn(`Pl@ntNet is unavailable: ${error.message}`);
      throw new DomainError('IDENTIFICATION_SERVICE_UNAVAILABLE', {
        cause: error,
      });
    }
  }

  /**
   * The candidates the app can show, in Pl@ntNet's order:
   * - one without a `gbifKey` is resolved in GBIF, or dropped (no match, or
   *   GBIF down);
   * - one with no image is dropped unless its species is in the Catalog,
   *   since a new species needs a reference photo.
   *
   * A candidate whose species is in the Catalog takes its Catalog name;
   * otherwise Pl@ntNet's first plausible name, or null.
   */
  private async usableCandidates(
    raw: RawCandidate[],
  ): Promise<UsableCandidate[]> {
    const linked = (
      await Promise.all(raw.map((candidate) => this.withGbifKey(candidate)))
    ).filter((candidate) => candidate !== null);

    const inCatalog = await this.catalogNamesByGbifKey(
      linked.map((candidate) => candidate.gbifKey),
    );
    return linked
      .filter(
        (candidate) =>
          candidate.images.length > 0 || inCatalog.has(candidate.gbifKey),
      )
      .map((candidate) => ({
        ...candidate,
        commonName:
          inCatalog.get(candidate.gbifKey) ??
          plausibleCommonName(candidate.commonNames),
      }));
  }

  private async withGbifKey(
    candidate: RawCandidate,
  ): Promise<StoredCandidate | null> {
    if (candidate.gbifKey !== null) {
      return { ...candidate, gbifKey: candidate.gbifKey };
    }
    try {
      const resolution = await this.gbif.resolve(candidate.scientificName);
      if (!resolution.ok) return null;
      return {
        ...candidate,
        gbifKey: resolution.gbifKey,
        scientificName: resolution.scientificName,
      };
    } catch (error) {
      this.logger.warn(
        `Dropped the candidate ${candidate.scientificName}: ${error instanceof Error ? error.message : String(error)}`,
      );
      return null;
    }
  }

  /**
   * The Catalog species among [gbifKeys], each with the name its responses
   * use: the primary name, or the scientific name while it has none.
   */
  private async catalogNamesByGbifKey(
    gbifKeys: number[],
  ): Promise<Map<number, string>> {
    if (gbifKeys.length === 0) return new Map();
    const rows = await this.db
      .select({
        gbifKey: species.gbifKey,
        primaryName: speciesNames.name,
        scientificName: species.scientificName,
      })
      .from(species)
      .leftJoin(
        speciesNames,
        and(
          eq(speciesNames.speciesId, species.id),
          eq(speciesNames.isPrimary, true),
        ),
      )
      .where(inArray(species.gbifKey, gbifKeys));
    return new Map(
      rows.map((row) => [row.gbifKey, row.primaryName ?? row.scientificName]),
    );
  }

  /**
   * The species with [candidate]'s `gbifKey`, added when new: origin
   * `identification`, no name until its care guide gives one, and the
   * candidate's first image as the external reference photo.
   */
  private async upsertSpecies(
    tx: Parameters<Parameters<Database['transaction']>[0]>[0],
    candidate: StoredCandidate,
  ): Promise<string> {
    const image = candidate.images[0];
    if (image) {
      // Any unique conflict (gbif_key or scientific_name) means it is there.
      const [inserted] = await tx
        .insert(species)
        .values({
          gbifKey: candidate.gbifKey,
          scientificName: candidate.scientificName,
          referencePhotoUrl: image.url,
          referencePhotoAuthor: image.author,
          referencePhotoLicense: image.license,
          referencePhotoSourceUrl: image.sourceUrl,
          origin: 'identification',
        })
        .onConflictDoNothing()
        .returning({ id: species.id });
      if (inserted) return inserted.id;
    }

    const [existing] = await tx
      .select({ id: species.id })
      .from(species)
      .where(eq(species.gbifKey, candidate.gbifKey));
    if (existing) return existing.id;
    const [sameName] = await tx
      .select({ id: species.id })
      .from(species)
      .where(eq(species.scientificName, candidate.scientificName));
    if (sameName) return sameName.id;
    throw new Error(
      `The candidate ${candidate.scientificName} has no image and no species`,
    );
  }

  /** The species as a search result shows it. */
  private async speciesItem(id: string): Promise<SpeciesItemResponse> {
    const [row] = await this.db
      .select({ species, primaryName: speciesNames.name })
      .from(species)
      .leftJoin(
        speciesNames,
        and(
          eq(speciesNames.speciesId, species.id),
          eq(speciesNames.isPrimary, true),
        ),
      )
      .where(eq(species.id, id));
    if (!row) throw new Error(`The species ${id} is gone`);
    return {
      id: row.species.id,
      commonName: row.primaryName ?? row.species.scientificName,
      scientificName: row.species.scientificName,
      referencePhoto: await this.catalog.presentReferencePhoto(row.species),
      matchedAlternativeName: null,
    };
  }
}

function toStored({
  scientificName,
  commonNames,
  score,
  gbifKey,
  images,
}: UsableCandidate): StoredCandidate {
  return { scientificName, commonNames, score, gbifKey, images };
}

function toResponse({
  scientificName,
  commonName,
  score,
  images,
}: UsableCandidate): CandidateResponse {
  return { scientificName, commonName, score, images };
}
