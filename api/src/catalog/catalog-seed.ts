import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { z } from 'zod';

/** `catalog/catalog-seed.json`, written by `npm run catalog:build`. */
export const CATALOG_SEED_PATH = join(
  __dirname,
  '..',
  '..',
  'catalog',
  'catalog-seed.json',
);

const catalogSeedSpeciesSchema = z.object({
  gbifKey: z.number().int().positive(),
  scientificName: z.string().min(1),
  /** The primary name, from Flora e Funga do Brasil. */
  commonName: z.string().min(1),
  otherNames: z.array(z.string().min(1)),
  referencePhoto: z.object({
    /** The file's page on Wikimedia Commons, for the credit. */
    sourceUrl: z.url(),
    /** The image itself, downloaded by the load. */
    imageUrl: z.url(),
    author: z.string().min(1),
    license: z.string().min(1),
  }),
});

export type CatalogSeedSpecies = z.infer<typeof catalogSeedSpeciesSchema>;

const catalogSeedSchema = z.array(catalogSeedSpeciesSchema);

/** Reads and validates the seed JSON. */
export async function readCatalogSeed(
  path: string = CATALOG_SEED_PATH,
): Promise<CatalogSeedSpecies[]> {
  return catalogSeedSchema.parse(JSON.parse(await readFile(path, 'utf8')));
}
