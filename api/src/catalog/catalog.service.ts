import { Inject, Injectable } from '@nestjs/common';
import { asc, eq, sql } from 'drizzle-orm';
import type { CareGuideFieldsResponse } from '../care-guides/care-guide.dto';
import { DATABASE, type Database } from '../database/database.module';
import { normalized, species, speciesNames } from '../database/schema';
import { DomainError } from '../errors/domain-error';
import { PhotoStorage } from '../photo-storage/photo-storage';
import {
  type ReferencePhotoResponse,
  SEARCH_LIMIT,
  type SpeciesItemResponse,
  type SpeciesResponse,
} from './species.dto';

/** The reference photo columns of a `species` row. */
export type ReferencePhotoColumns = Pick<
  typeof species.$inferSelect,
  | 'referencePhotoS3Key'
  | 'referencePhotoUrl'
  | 'referencePhotoAuthor'
  | 'referencePhotoLicense'
  | 'referencePhotoSourceUrl'
>;

interface SearchRow extends Record<string, unknown> {
  id: string;
  scientific_name: string;
  primary_name: string | null;
  matched_alternative_name: string | null;
  reference_photo_s3_key: string | null;
  reference_photo_url: string | null;
  reference_photo_author: string;
  reference_photo_license: string;
  reference_photo_source_url: string;
}

/**
 * [term] with the wildcards of `LIKE` (`%`, `_`) and its escape character
 * (`\`) escaped, so they match only themselves.
 */
function escapeLike(term: string): string {
  return term.replace(/[\\%_]/g, (character) => `\\${character}`);
}

/**
 * The Catalog as the app reads it: the search by name and one species. Other
 * features (identification, garden) show a species' reference photo through
 * {@link CatalogService.presentReferencePhoto}.
 */
@Injectable()
export class CatalogService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    @Inject(PhotoStorage) private readonly storage: PhotoStorage,
  ) {}

  /**
   * Species whose common or scientific name contains [term], accents and
   * capitals aside: one row per species, at most {@link SEARCH_LIMIT}. Those
   * with a name that starts with the term come first, then the rest, each
   * group by the primary name (the scientific one when there is none).
   *
   * Both sides go through `normalized()`, the same expression the trigram
   * indexes of `species_names.name_normalized` and `species.scientific_name`
   * are built on.
   */
  async search(term: string): Promise<SpeciesItemResponse[]> {
    const normalizedTerm = normalized(escapeLike(term));
    const contains = sql`'%' || ${normalizedTerm} || '%'`;
    const startsWith = sql`${normalizedTerm} || '%'`;
    const scientific = normalized(sql`s.scientific_name`);

    const rows = await this.db.execute<SearchRow>(sql`
      WITH matching AS (
        SELECT species_id FROM species_names
        WHERE name_normalized ILIKE ${contains}
        UNION
        SELECT id FROM species s WHERE ${scientific} ILIKE ${contains}
      )
      SELECT
        s.id,
        s.scientific_name,
        p.name AS primary_name,
        CASE
          WHEN coalesce(p.name_normalized ILIKE ${contains}, false)
            OR ${scientific} ILIKE ${contains} THEN NULL
          ELSE alternative.name
        END AS matched_alternative_name,
        s.reference_photo_s3_key,
        s.reference_photo_url,
        s.reference_photo_author,
        s.reference_photo_license,
        s.reference_photo_source_url
      FROM matching
      JOIN species s ON s.id = matching.species_id
      LEFT JOIN species_names p ON p.species_id = s.id AND p.is_primary
      LEFT JOIN LATERAL (
        SELECT n.name FROM species_names n
        WHERE n.species_id = s.id
          AND NOT n.is_primary
          AND n.name_normalized ILIKE ${contains}
        ORDER BY n.name_normalized ILIKE ${startsWith} DESC, n.name_normalized
        LIMIT 1
      ) alternative ON true
      ORDER BY
        (
          ${scientific} ILIKE ${startsWith}
          OR EXISTS (
            SELECT 1 FROM species_names n
            WHERE n.species_id = s.id AND n.name_normalized ILIKE ${startsWith}
          )
        ) DESC,
        ${normalized(sql`coalesce(p.name, s.scientific_name)`)},
        s.id
      LIMIT ${SEARCH_LIMIT}
    `);

    return Promise.all(
      rows.map(async (row) => ({
        id: row.id,
        commonName: row.primary_name ?? row.scientific_name,
        scientificName: row.scientific_name,
        referencePhoto: await this.presentReferencePhoto({
          referencePhotoS3Key: row.reference_photo_s3_key,
          referencePhotoUrl: row.reference_photo_url,
          referencePhotoAuthor: row.reference_photo_author,
          referencePhotoLicense: row.reference_photo_license,
          referencePhotoSourceUrl: row.reference_photo_source_url,
        }),
        matchedAlternativeName: row.matched_alternative_name,
      })),
    );
  }

  /**
   * One species with all its names, without the care guide (the controller
   * adds it); `NOT_FOUND` when there is none.
   */
  async get(
    id: string,
  ): Promise<Omit<SpeciesResponse, keyof CareGuideFieldsResponse>> {
    const [row] = await this.db
      .select()
      .from(species)
      .where(eq(species.id, id));
    if (!row) throw new DomainError('NOT_FOUND');

    const names = await this.db
      .select({ name: speciesNames.name, isPrimary: speciesNames.isPrimary })
      .from(speciesNames)
      .where(eq(speciesNames.speciesId, id))
      .orderBy(asc(speciesNames.nameNormalized), asc(speciesNames.name));
    const primary = names.find((name) => name.isPrimary);

    return {
      id: row.id,
      commonName: primary?.name ?? row.scientificName,
      scientificName: row.scientificName,
      referencePhoto: await this.presentReferencePhoto(row),
      otherNames: names
        .filter((name) => !name.isPrimary)
        .map((name) => name.name),
    };
  }

  /**
   * A species' reference photo as responses show it: presigned now when it
   * is our own copy in the storage, the external URL otherwise.
   */
  async presentReferencePhoto(
    row: ReferencePhotoColumns,
  ): Promise<ReferencePhotoResponse> {
    const url = row.referencePhotoS3Key
      ? (await this.storage.presignedGetUrl(row.referencePhotoS3Key)).url
      : row.referencePhotoUrl;
    if (!url) throw new Error('A species has no reference photo');
    return {
      url,
      author: row.referencePhotoAuthor,
      license: row.referencePhotoLicense,
      sourceUrl: row.referencePhotoSourceUrl,
    };
  }
}
