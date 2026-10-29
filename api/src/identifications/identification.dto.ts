import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import {
  referencePhotoSchema,
  speciesItemSchema,
} from '../catalog/species.dto';
import { identificationResult } from '../database/schema';

export class IdentifyRequest extends createZodDto(
  z.object({
    photoId: z.uuid().describe('A photo the User sent with POST /photos'),
  }),
) {}

/** One species Pl@ntNet proposes for the photo. */
export const candidateSchema = z.object({
  scientificName: z.string().describe('Without author'),
  commonName: z
    .string()
    .meta({ example: 'Jiboia' })
    .nullable()
    .describe(
      "The Catalog's primary name when the species is there (its scientific name while it has none); otherwise the first Pl@ntNet name that looks like one; null when none does (the app shows the scientific name)",
    ),
  score: z.number().min(0).max(1).describe("Pl@ntNet's confidence"),
  images: z
    .array(referencePhotoSchema)
    .describe('Pl@ntNet photos of the species, with their credit'),
});

export type CandidateResponse = z.infer<typeof candidateSchema>;

export const identificationSchema = z.object({
  id: z.uuid(),
  result: z.enum(identificationResult.enumValues),
  candidates: z
    .array(candidateSchema)
    .describe('Up to 3, best first; empty when not_recognized'),
  remainingToday: z
    .int()
    .min(0)
    .describe('Identifications the User still has today'),
});

export type IdentificationResponse = z.infer<typeof identificationSchema>;

export class Identification extends createZodDto(identificationSchema) {}

/**
 * Either a candidate (its index in `candidates`) or "nenhuma destas", never
 * both. One object with a refinement rather than a union, since a DTO class
 * needs an object schema.
 */
export const choiceRequestSchema = z
  .strictObject({
    candidateIndex: z.int().min(0).optional().describe('Index in `candidates`'),
    none: z.literal(true).optional().describe('"Nenhuma destas"'),
  })
  .refine(
    (choice) =>
      (choice.candidateIndex === undefined) !== (choice.none === undefined),
    { message: 'send either candidateIndex or none: true' },
  );

export type ChoiceRequestBody = z.infer<typeof choiceRequestSchema>;

export class ChoiceRequest extends createZodDto(choiceRequestSchema) {}

export const choiceResponseSchema = z.object({
  species: speciesItemSchema.describe('The chosen species, now in the Catalog'),
});

export type ChoiceResponseBody = z.infer<typeof choiceResponseSchema>;

export class ChoiceResponse extends createZodDto(choiceResponseSchema) {}
