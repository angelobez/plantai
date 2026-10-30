/**
 * Builds catalog/catalog-seed.json: Claude proposes the species, GBIF
 * validates the names, Flora (with GBIF as fallback) gives the common names
 * and Wikidata/Commons give a free reference photo.
 *
 *   npm run catalog:build                      # names from Claude
 *   npm run catalog:build -- --names list.txt  # names from a file instead
 *   npm run catalog:build -- --refresh-proposal
 *
 * catalog/seed-overrides.json corrects species by hand, keyed by the accepted
 * scientific name: its `commonName` and `otherNames` replace the ones the
 * sources gave, and an optional `photoFile` (a Commons file name) replaces the
 * Wikidata photo, still checked for a free license and an author.
 *
 * Every response is cached in catalog/.cache (git-ignored), Claude's
 * proposal included, so a new run only calls what is missing. The Claude key
 * (ANTHROPIC_API_KEY) comes from api/.env, the same file the API reads.
 */
import { existsSync } from 'node:fs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { parseArgs } from 'node:util';
import { cachedFetchJson } from './catalog-seed/http-cache';
import { readSeedOverrides } from './catalog-seed/overrides';
import { buildSeed } from './catalog-seed/pipeline';
import { proposeSpecies } from './catalog-seed/propose';
import { formatDiscardReport, serializeSeed } from './catalog-seed/seed';

const CATALOG_DIR = join(__dirname, '..', 'catalog');
const CACHE_DIR = join(CATALOG_DIR, '.cache');
const PROPOSAL_FILE = join(CACHE_DIR, 'claude-proposal.json');
const OUTPUT_FILE = join(CATALOG_DIR, 'catalog-seed.json');
const OVERRIDES_FILE = join(CATALOG_DIR, 'seed-overrides.json');
const MINIMUM = 30;
const ENV_FILE = join(__dirname, '..', '.env');

/** One name per line; blank lines and `#` comments are ignored. */
function parseNameList(text: string): string[] {
  return text
    .split('\n')
    .map((line) => line.replace(/#.*/, '').trim())
    .filter((line) => line !== '');
}

async function candidateNames(
  namesFile: string | undefined,
  refresh: boolean,
): Promise<string[]> {
  if (namesFile !== undefined) {
    return parseNameList(await readFile(namesFile, 'utf8'));
  }
  if (!refresh) {
    try {
      return JSON.parse(await readFile(PROPOSAL_FILE, 'utf8')) as string[];
    } catch {
      // No proposal cached yet.
    }
  }
  console.log('Asking Claude for the species list...');
  const names = await proposeSpecies();
  await mkdir(CACHE_DIR, { recursive: true });
  await writeFile(PROPOSAL_FILE, JSON.stringify(names, null, 2));
  return names;
}

async function main(): Promise<void> {
  // Only the variables: the script does not need the API's whole config.
  if (existsSync(ENV_FILE)) process.loadEnvFile(ENV_FILE);
  const { values } = parseArgs({
    options: {
      names: { type: 'string' },
      'refresh-proposal': { type: 'boolean', default: false },
    },
  });

  const names = await candidateNames(values.names, values['refresh-proposal']);
  console.log(`${String(names.length)} candidate names.`);

  const overrides = await readSeedOverrides(OVERRIDES_FILE);
  const { species, discards } = await buildSeed(
    names,
    cachedFetchJson(CACHE_DIR),
    {
      overrides,
      onProgress: (name, index) => {
        process.stdout.write(
          `\r[${String(index + 1)}/${String(names.length)}] ${name.padEnd(40)}`,
        );
      },
    },
  );
  process.stdout.write('\n');

  const built = new Set(species.map((item) => item.scientificName));
  for (const name of Object.keys(overrides)) {
    if (!built.has(name)) {
      console.warn(`The override of ${name} matched no species in the seed.`);
    }
  }

  await writeFile(OUTPUT_FILE, await serializeSeed(species, OUTPUT_FILE));
  console.log(`${String(species.length)} species in ${OUTPUT_FILE}`);
  console.log(formatDiscardReport(discards));

  if (species.length < MINIMUM) {
    console.error(
      `Fewer than ${String(MINIMUM)} species: the seed is not ready yet.`,
    );
    process.exitCode = 1;
  }
}

main().catch((error: unknown) => {
  console.error(error);
  if (
    error instanceof Error &&
    error.message.includes('authentication method')
  ) {
    console.error(
      'No Claude credentials: set ANTHROPIC_API_KEY in api/.env or use --names <file>.',
    );
  }
  process.exitCode = 1;
});
