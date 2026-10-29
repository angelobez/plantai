import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import type { FetchJson } from './pipeline';

// Wikimedia asks for a User-Agent that identifies the tool and a contact.
const USER_AGENT =
  'PlantAiCatalogSeed/0.1 (https://github.com/angelobez/plantai) node-fetch';

const RETRIES = 4;
const PAUSE_MS = 150;

/**
 * GETs JSON and keeps each successful answer in `cacheDir`, one file per URL,
 * so running the script again does not repeat the calls. Failures are not
 * cached, and 429/5xx are retried with backoff.
 */
export function cachedFetchJson(cacheDir: string): FetchJson {
  return async (url) => {
    const file = join(
      cacheDir,
      `${createHash('sha256').update(url).digest('hex')}.json`,
    );
    try {
      const cached = JSON.parse(await readFile(file, 'utf8')) as {
        body: unknown;
      };
      return cached.body;
    } catch {
      // Not cached yet.
    }

    for (let attempt = 0; ; attempt++) {
      await sleep(PAUSE_MS);
      const response = await fetch(url, {
        headers: {
          'User-Agent': USER_AGENT,
          Accept: url.includes('query.wikidata.org/sparql')
            ? 'application/sparql-results+json'
            : 'application/json',
        },
      });
      const retryable = response.status === 429 || response.status >= 500;
      if (retryable && attempt < RETRIES) {
        await sleep(1000 * 2 ** attempt);
        continue;
      }
      if (!response.ok) {
        throw new Error(`HTTP ${String(response.status)} em ${url}`);
      }
      const body: unknown = await response.json();
      await mkdir(cacheDir, { recursive: true });
      await writeFile(file, JSON.stringify({ url, body }));
      return body;
    }
  };
}
