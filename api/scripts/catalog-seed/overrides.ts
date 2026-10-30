import { readFile } from 'node:fs/promises';
import { z } from 'zod';

/**
 * A hand correction of one species of the seed, for when Flora, GBIF or
 * Wikidata give the wrong name or no usable photo.
 */
const seedOverrideSchema = z.strictObject({
  /** Replaces the main common name the sources gave. */
  commonName: z.string().trim().min(1),
  /** Replaces the other names the sources gave. */
  otherNames: z.array(z.string().trim().min(1)),
  /** A Commons file (without `File:`) to use instead of Wikidata's photo. */
  photoFile: z.string().trim().min(1).optional(),
});

export type SeedOverride = z.infer<typeof seedOverrideSchema>;

/** The overrides by accepted scientific name, as GBIF resolves it. */
export type SeedOverrides = Record<string, SeedOverride>;

const seedOverridesSchema = z.record(z.string(), seedOverrideSchema);

/** `catalog/seed-overrides.json`, checked in next to the seed. */
export async function readSeedOverrides(path: string): Promise<SeedOverrides> {
  return seedOverridesSchema.parse(JSON.parse(await readFile(path, 'utf8')));
}
