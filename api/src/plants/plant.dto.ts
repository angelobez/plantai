import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import { photoSchema } from '../photos/photo.dto';
import { speciesSchema } from '../catalog/species.dto';

/** The shortest and longest plant name, after the trim. */
export const PLANT_NAME_LENGTH = { min: 1, max: 80 } as const;

/**
 * A plant's name: a free nickname ("Jiboia da sala"). Spaces at the ends
 * are trimmed before the length is checked. `PATCH /plants/:id` takes the
 * same field.
 */
export const plantCommonNameSchema = z
  .string()
  .trim()
  .min(PLANT_NAME_LENGTH.min)
  .max(PLANT_NAME_LENGTH.max)
  .describe('A free nickname, 1 to 80 characters after the trim');

export class CreatePlantRequest extends createZodDto(
  z.object({
    photoId: z
      .uuid()
      .describe('A photo the User sent with POST /photos, not yet any plant’s'),
    commonName: plantCommonNameSchema,
    speciesId: z
      .uuid()
      .optional()
      .describe('A Catalog species; without it, the plant has only the name'),
  }),
) {}

/**
 * `PATCH /plants/:id`: a new name, the species of a plant saved without one,
 * or both. At least one of them. The species is set once: a plant that has
 * one answers `SPECIES_ALREADY_SET`.
 */
export const updatePlantRequestSchema = z
  .object({
    commonName: plantCommonNameSchema.optional(),
    speciesId: z
      .uuid()
      .optional()
      .describe(
        'A Catalog species, only for a plant that has none yet (SPECIES_ALREADY_SET)',
      ),
  })
  .refine(
    (body) => body.commonName !== undefined || body.speciesId !== undefined,
    { message: 'send commonName, speciesId or both' },
  );

export class UpdatePlantRequest extends createZodDto(
  updatePlantRequestSchema,
) {}

/**
 * One plant of `GET /plants`, and the answer of `POST /plants` and
 * `PATCH /plants/:id`.
 */
export const plantItemSchema = z.object({
  id: z.uuid(),
  commonName: z.string(),
  photo: photoSchema,
  species: z
    .object({
      id: z.uuid(),
      commonName: z
        .string()
        .describe(
          'The primary common name; the scientific name while the species has none',
        ),
      scientificName: z.string(),
      wateringSummary: z
        .string()
        .meta({ example: '1x por semana' })
        .nullable()
        .describe(
          'The watering summary of the care guide; null until the guide is written',
        ),
    })
    .nullable()
    .describe('Null for a plant saved with only a name'),
});

export type PlantItemResponse = z.infer<typeof plantItemSchema>;

export class PlantItem extends createZodDto(plantItemSchema) {}

/** `GET /plants/:id`: the plant with its species as `GET /species/:id`. */
export const plantSchema = z.object({
  id: z.uuid(),
  commonName: z.string(),
  photo: photoSchema,
  species: speciesSchema
    .nullable()
    .describe(
      'The species with its care guide, as GET /species/:id; null for a plant saved with only a name',
    ),
});

export type PlantResponse = z.infer<typeof plantSchema>;

export class Plant extends createZodDto(plantSchema) {}
