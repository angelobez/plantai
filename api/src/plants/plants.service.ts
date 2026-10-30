import { Inject, Injectable, Logger } from '@nestjs/common';
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
import { invalidField } from '../errors/validation';
import { messageOf } from '../errors/message-of';
import { PhotoStorage } from '../photo-storage/photo-storage';
import { PhotosService } from '../photos/photos.service';
import type { PlantItemResponse, PlantResponse } from './plant.dto';

/** What `POST /plants` takes, already validated. */
export interface NewPlant {
  photoId: string;
  commonName: string;
  speciesId?: string | undefined;
}

/** What `PATCH /plants/:id` takes, already validated: at least one field. */
export interface PlantChanges {
  commonName?: string | undefined;
  speciesId?: string | undefined;
}

/** A User's plant row with its photo, as {@link PlantsService} finds it. */
export interface OwnedPlant {
  plant: typeof plants.$inferSelect;
  photo: { id: string; s3Key: string };
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
  private readonly logger = new Logger(PlantsService.name);

  constructor(
    @Inject(DATABASE) private readonly db: Database,
    @Inject(PhotosService) private readonly photosService: PhotosService,
    @Inject(CatalogService) private readonly catalogService: CatalogService,
    @Inject(CareGuideService)
    private readonly careGuideService: CareGuideService,
    @Inject(PhotoStorage) private readonly storage: PhotoStorage,
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
      throw invalidField('photoId', 'the photo already belongs to a plant');
    }
    if (input.speciesId && !(await this.speciesExists(input.speciesId))) {
      throw invalidField('speciesId', 'no such species');
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
        throw invalidField('photoId', 'the photo already belongs to a plant');
      }
      return plant.id;
    });

    return this.item(userId, plantId);
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
   * Changes [userId]'s plant [plantId] and answers it as a list item.
   * `NOT_FOUND` for another User's plant. The species is set once: a plant
   * that has one, even the same, answers `SPECIES_ALREADY_SET` (to fix a
   * wrong species, the User removes the plant and saves it again). A species
   * that does not exist is `VALIDATION_FAILED`. The species goes first, so a
   * body with both changes nothing when it fails. Setting it never has Claude
   * write the guide; the next `GET /plants/:id` does it.
   */
  async update(
    userId: string,
    plantId: string,
    changes: PlantChanges,
  ): Promise<PlantItemResponse> {
    const { plant } = await this.findOwned(userId, plantId);
    if (changes.speciesId !== undefined) {
      await this.setSpecies(plant, changes.speciesId);
    }
    if (changes.commonName !== undefined) {
      await this.db
        .update(plants)
        .set({ commonName: changes.commonName })
        .where(eq(plants.id, plant.id));
    }
    return this.item(userId, plant.id);
  }

  /**
   * Removes [userId]'s plant [plantId] with its photos: the rows first, in
   * one transaction, then the objects in the storage. An object that fails
   * to go is logged and left for later; the plant is gone anyway.
   * `NOT_FOUND` for another User's plant.
   */
  async remove(userId: string, plantId: string): Promise<void> {
    const { plant } = await this.findOwned(userId, plantId);
    const removed = await this.db.transaction(async (tx) => {
      // `photos.plant_id` is SET NULL, so the photos go before the plant.
      const plantPhotos = await tx
        .delete(photos)
        .where(eq(photos.plantId, plant.id))
        .returning({ s3Key: photos.s3Key });
      await tx.delete(plants).where(eq(plants.id, plant.id));
      return plantPhotos;
    });

    await Promise.all(
      removed.map(async ({ s3Key }) => {
        try {
          await this.storage.delete(s3Key);
        } catch (error) {
          const reason = messageOf(error);
          this.logger.warn(
            `Photo ${s3Key} of removed plant ${plant.id} not deleted from the storage: ${reason}`,
          );
        }
      }),
    );
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

  /** One of [userId]'s plants as a list item, right after a change. */
  private async item(
    userId: string,
    plantId: string,
  ): Promise<PlantItemResponse> {
    const [item] = await this.items(userId, eq(plants.id, plantId));
    if (!item) throw new Error(`The plant ${plantId} was not found`);
    return item;
  }

  private async setSpecies(
    plant: OwnedPlant['plant'],
    speciesId: string,
  ): Promise<void> {
    if (plant.speciesId) throw new DomainError('SPECIES_ALREADY_SET');
    if (!(await this.speciesExists(speciesId))) {
      throw invalidField('speciesId', 'no such species');
    }
    // Only a plant with no species yet: of two requests at once, one wins.
    const updated = await this.db
      .update(plants)
      .set({ speciesId })
      .where(and(eq(plants.id, plant.id), isNull(plants.speciesId)))
      .returning({ id: plants.id });
    if (updated.length === 0) throw new DomainError('SPECIES_ALREADY_SET');
  }

  private async speciesExists(speciesId: string): Promise<boolean> {
    const [row] = await this.db
      .select({ id: species.id })
      .from(species)
      .where(eq(species.id, speciesId));
    return row !== undefined;
  }
}
