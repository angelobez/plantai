/**
 * Loads catalog/catalog-seed.json into the Catalog: species and names in the
 * database, reference photos copied from Wikimedia to the photo storage, and
 * the care guides Claude writes (only the missing or failed ones; it needs
 * ANTHROPIC_API_KEY).
 *
 *   npm run db:up && npm run db:migrate   # PostGIS and the S3 emulator
 *   npm run catalog:load
 *   npm run catalog:load -- --seed other-seed.json   # a different seed file
 *
 * Idempotent: running it again duplicates nothing and only completes what
 * failed. Reads api/.env like the API.
 */
import 'reflect-metadata';
import { parseArgs } from 'node:util';
import { NestFactory } from '@nestjs/core';
import { CatalogLoadModule } from '../src/catalog/catalog-load.module';
import {
  CatalogLoader,
  formatCatalogLoadSummary,
} from '../src/catalog/catalog-loader';
import { readCatalogSeed } from '../src/catalog/catalog-seed';
import { loadEnv } from '../src/config/env';

async function main(): Promise<void> {
  const { values } = parseArgs({ options: { seed: { type: 'string' } } });
  const seed = await readCatalogSeed(values.seed);
  const context = await NestFactory.createApplicationContext(
    CatalogLoadModule.forRoot(loadEnv()),
    { logger: ['error', 'warn'] },
  );
  try {
    console.log(`Loading ${String(seed.length)} species from the seed...`);
    const summary = await context.get(CatalogLoader).load(
      seed,
      (item, index) => {
        process.stdout.write(
          `\r[${String(index + 1)}/${String(seed.length)}] ${item.scientificName.padEnd(40)}`,
        );
      },
      (done, total) => {
        process.stdout.write(
          `\rCare guides: ${String(done)}/${String(total)}`.padEnd(48),
        );
      },
    );
    process.stdout.write('\n');
    console.log(formatCatalogLoadSummary(summary));
    if (summary.failures.length > 0) process.exitCode = 1;
  } finally {
    await context.close();
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
