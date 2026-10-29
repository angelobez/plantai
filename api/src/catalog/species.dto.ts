import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

/** The shortest and longest search term, after the trim. */
export const SEARCH_TERM_LENGTH = { min: 2, max: 50 } as const;

/** How many species one search answers at most. */
export const SEARCH_LIMIT = 20;

export class SearchSpeciesQuery extends createZodDto(
  z.object({
    q: z
      .string()
      .trim()
      .min(SEARCH_TERM_LENGTH.min)
      .max(SEARCH_TERM_LENGTH.max)
      .describe(
        'Part of a common or scientific name; accents and capitals do not matter',
      ),
  }),
) {}

/**
 * A Catalog photo as every response shows it, with the credit. The `url` is
 * presigned (1 h) when the photo is our own copy in the storage, and the
 * external URL otherwise (Pl@ntNet's, for instance). Candidates of an
 * identification use the same shape.
 */
export const referencePhotoSchema = z.object({
  url: z.url(),
  author: z.string(),
  license: z.string().describe('Such as CC BY-SA 4.0'),
  sourceUrl: z.url().describe('The page of the photo, for the credit link'),
});

export type ReferencePhotoResponse = z.infer<typeof referencePhotoSchema>;

const speciesFields = {
  id: z.uuid(),
  commonName: z
    .string()
    .describe(
      'The primary common name; the scientific name while the species has none',
    ),
  scientificName: z.string().describe('Without author'),
  referencePhoto: referencePhotoSchema,
};

/** One search result; the choice of a candidate answers the same shape. */
export const speciesItemSchema = z.object({
  ...speciesFields,
  matchedAlternativeName: z
    .string()
    .meta({ example: 'banana-de-macaco' })
    .nullable()
    .describe(
      'The alternative name the term matched, when it matched neither the primary nor the scientific name',
    ),
});

export type SpeciesItemResponse = z.infer<typeof speciesItemSchema>;

export class SpeciesItem extends createZodDto(speciesItemSchema) {}

/** `GET /species/:id`. */
export const speciesSchema = z.object({
  ...speciesFields,
  otherNames: z
    .array(z.string())
    .describe('The alternative common names, in alphabetical order'),
});

export type SpeciesResponse = z.infer<typeof speciesSchema>;

export class Species extends createZodDto(speciesSchema) {}
