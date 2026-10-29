/**
 * Builds catalog/catalog-seed.json: Claude proposes the species, GBIF
 * validates the names, Flora (with GBIF as fallback) gives the common names
 * and Wikidata/Commons give a free reference photo.
 *
 *   npm run catalog:build                      # names from Claude
 *   npm run catalog:build -- --names list.txt  # names from a file instead
 *   npm run catalog:build -- --refresh-proposal
 *
 * Every response is cached in catalog/.cache (git-ignored), Claude's
 * proposal included, so a new run only calls what is missing.
 */
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { parseArgs } from 'node:util';
import { cachedFetchJson } from './catalog-seed/http-cache';
import { buildSeed } from './catalog-seed/pipeline';
import { proposeSpecies } from './catalog-seed/propose';
import { formatDiscardReport, serializeSeed } from './catalog-seed/seed';

const CATALOG_DIR = join(__dirname, '..', 'catalog');
const CACHE_DIR = join(CATALOG_DIR, '.cache');
const PROPOSAL_FILE = join(CACHE_DIR, 'claude-proposal.json');
const OUTPUT_FILE = join(CATALOG_DIR, 'catalog-seed.json');
const MINIMUM = 30;

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
  console.log('Pedindo a lista de espécies ao Claude...');
  const names = await proposeSpecies();
  await mkdir(CACHE_DIR, { recursive: true });
  await writeFile(PROPOSAL_FILE, JSON.stringify(names, null, 2));
  return names;
}

async function main(): Promise<void> {
  const { values } = parseArgs({
    options: {
      names: { type: 'string' },
      'refresh-proposal': { type: 'boolean', default: false },
    },
  });

  const names = await candidateNames(values.names, values['refresh-proposal']);
  console.log(`${String(names.length)} nomes candidatos.`);

  const { species, discards } = await buildSeed(
    names,
    cachedFetchJson(CACHE_DIR),
    (name, index) => {
      process.stdout.write(
        `\r[${String(index + 1)}/${String(names.length)}] ${name.padEnd(40)}`,
      );
    },
  );
  process.stdout.write('\n');

  await writeFile(OUTPUT_FILE, await serializeSeed(species, OUTPUT_FILE));
  console.log(`${String(species.length)} espécies em ${OUTPUT_FILE}`);
  console.log(formatDiscardReport(discards));

  if (species.length < MINIMUM) {
    console.error(
      `Menos de ${String(MINIMUM)} espécies: a semente ainda não está pronta.`,
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
      'Sem credencial do Claude: defina ANTHROPIC_API_KEY ou use --names <arquivo>.',
    );
  }
  process.exitCode = 1;
});
