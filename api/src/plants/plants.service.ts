import { Inject, Injectable } from '@nestjs/common';
import { and, asc, desc, eq, isNull, type SQL, sql } from 'drizzle-orm';
import { CareGuideService } from '../care-guides/care-guide.service';
import { CatalogService } from '../catalog/catalog.service';
import { DATABASE, type Database } from '../database/database.module';
import {
  careGuides,
  photos,
  plants,
  species,
  speciesNames,
} from '../database/schema';
import { DomainError } from '../errors/domain-error';
import { PhotosService } from '../photos/photos.service';
import type { PlantItemResponse, PlantResponse } from './plant.dto';

/** What `POST /plants` takes, already validated. */
export interface NewPlant {
  photoId: string;
  commonName: string;
  speciesId?: string | undefined;
}

/** A User's plant row with its photo, as {@link PlantsService} finds it. */
export interface OwnedPlant {
  plant: typeof plants.$inferSelect;
  photo: { id: string; s3Key: string };
}

function invalid(path: string, message: string): DomainError {
  return new DomainError('VALIDATION_FAILED', {
    errors: [{ path, message }],
  });
}

/**
 * Meu jardim: a User's plants. Each plant has the photo it was saved with
 * (`photos.plant_id`) and, when the User chose one, its species, set once.
 *
 * Another User's plant does not exist for anyone else: every read goes
 * through {@link findOwned}, which answers `NOT_FOUND`.
 */
@Injectable()
export class PlantsService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    @Inject(PhotosService) private readonly photosService: PhotosService,
    @Inject(CatalogService) private readonly catalogService: CatalogService,
    @Inject(CareGuideService)
    private readonly careGuideService: CareGuideService,
  ) {}

  /**
   * Saves a plant for [userId] with one of their photos, which becomes the
   * plant's (attached, so the lifecycle rule keeps it). The photo must not
   * be another plant's, and [NewPlant.speciesId], when given, must exist:
   * `VALIDATION_FAILED` otherwise. The care guide is not generated here; the
   * first `GET /plants/:id` does it.
   */
  async create(userId: string, input: NewPlant): Promise<PlantItemResponse> {
    const photo = await this.photosService.findOwned(userId, input.photoId);
    if (photo.plantId) {
      throw invalid('photoId', 'the photo already belongs to a plant');
    }
    if (input.speciesId && !(await this.speciesExists(input.speciesId))) {
      throw invalid('speciesId', 'no such species');
    }

    await this.photosService.attach(photo);
    const plantId = await this.db.transaction(async (tx) => {
      const [plant] = await tx
        .insert(plants)
        .values({
          userId,
          commonName: input.commonName,
          speciesId: input.speciesId ?? null,
        })
        .returning({ id: plants.id });
      if (!plant) throw new Error('The plant insert returned no row');
      // Only a photo no plant has yet: two saves of the same photo at once
      // leave one plant.
      const linked = await tx
        .update(photos)
        .set({ plantId: plant.id })
        .where(and(eq(photos.id, photo.id), isNull(photos.plantId)))
        .returning({ id: photos.id });
      if (linked.length === 0) {
        throw invalid('photoId', 'the photo already belongs to a plant');
      }
      return plant.id;
    });

    const [item] = await this.items(userId, eq(plants.id, plantId));
    if (!item) throw new Error('The new plant was not found');
    return item;
  }

  /**
   * [userId]'s plants, newest first, each with the watering summary of its
   * species' care guide when the guide is `ready`. Reading the list never
   * has Claude write a guide.
   */
  list(userId: string): Promise<PlantItemResponse[]> {
    return this.items(userId);
  }

  /**
   * One of [userId]'s plants, with its species and care guide as
   * `GET /species/:id` answers them: the first reading of a species has
   * Claude write the guide, and while another request writes it, this
   * throws `CARE_GUIDE_GENERATING`. `NOT_FOUND` for another User's plant.
   */
  async get(userId: string, plantId: string): Promise<PlantResponse> {
    const { plant, photo } = await this.findOwned(userId, plantId);
    let plantSpecies: PlantResponse['species'] = null;
    if (plant.speciesId) {
      // The guide first: a new species gets its primary name from Claude.
      const careGuide = await this.careGuideService.forResponse(
        plant.speciesId,
        userId,
      );
      plantSpecies = {
        ...(await this.catalogService.get(plant.speciesId)),
        ...careGuide,
      };
    }
    return {
      id: plant.id,
      commonName: plant.commonName,
      photo: await this.photosService.present(photo),
      species: plantSpecies,
    };
  }

  /**
   * [userId]'s plant [plantId] with its photo; `NOT_FOUND` when there is
   * none, or when it is someone else's, so its existence is not revealed.
   * Every route on one plant starts here.
   */
  async findOwned(userId: string, plantId: string): Promise<OwnedPlant> {
    const [row] = await this.db
      .select({
        plant: plants,
        photo: { id: photos.id, s3Key: photos.s3Key },
      })
      .from(plants)
      .innerJoin(photos, eq(photos.plantId, plants.id))
      .where(and(eq(plants.id, plantId), eq(plants.userId, userId)))
      .orderBy(asc(photos.createdAt))
      .limit(1);
    if (!row) throw new DomainError('NOT_FOUND');
    return row;
  }

  /**
   * [userId]'s plants matching [filter], newest first, as list items. A
   * plant shows its first photo (today it has only one).
   */
  private async items(
    userId: string,
    filter?: SQL,
  ): Promise<PlantItemResponse[]> {
    const rows = await this.db
      .selectDistinctOn([plants.createdAt, plants.id], {
        id: plants.id,
        commonName: plants.commonName,
        photoId: photos.id,
        photoS3Key: photos.s3Key,
        speciesId: species.id,
        scientificName: species.scientificName,
        primaryName: speciesNames.name,
        wateringSummary: sql<
          string | null
        >`${careGuides.content} -> 'watering' ->> 'summary'`,
      })
      .from(plants)
      .innerJoin(photos, eq(photos.plantId, plants.id))
      .leftJoin(species, eq(species.id, plants.speciesId))
      .leftJoin(
        speciesNames,
        and(
          eq(speciesNames.speciesId, species.id),
          eq(speciesNames.isPrimary, true),
        ),
      )
      .leftJoin(
        careGuides,
        and(
          eq(careGuides.speciesId, species.id),
          eq(careGuides.status, 'ready'),
        ),
      )
      .where(and(eq(plants.userId, userId), filter))
      .orderBy(desc(plants.createdAt), desc(plants.id), asc(photos.createdAt));

    return Promise.all(
      rows.map(async (row) => ({
        id: row.id,
        commonName: row.commonName,
        photo: await this.photosService.present({
          id: row.photoId,
          s3Key: row.photoS3Key,
        }),
        species:
          row.speciesId && row.scientificName
            ? {
                id: row.speciesId,
                commonName: row.primaryName ?? row.scientificName,
                scientificName: row.scientificName,
                wateringSummary: row.wateringSummary,
              }
            : null,
      })),
    );
  }

  private async speciesExists(speciesId: string): Promise<boolean> {
    const [row] = await this.db
      .select({ id: species.id })
      .from(species)
      .where(eq(species.id, speciesId));
    return row !== undefined;
  }
}
