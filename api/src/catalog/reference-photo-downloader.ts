import { setTimeout as sleep } from 'node:timers/promises';

/**
 * Wikimedia asks every client for a User-Agent that names the tool and a way
 * to reach its author (https://meta.wikimedia.org/wiki/User-Agent_policy).
 */
export const PLANTAI_USER_AGENT =
  'PlantAi/0.2 (https://github.com/angelobez/plantai; catalog load)';

const TIMEOUT_MS = 30_000;
const RETRIES = 3;
/** Between downloads, to stay polite with upload.wikimedia.org. */
const PAUSE_MS = 250;

/**
 * The port for downloading a Catalog reference photo (from Wikimedia
 * Commons). The real adapter is {@link HttpReferencePhotoDownloader}; tests
 * swap in a fake.
 *
 * An abstract class rather than an interface, so it doubles as the Nest
 * injection token.
 */
export abstract class ReferencePhotoDownloader {
  /** The file's bytes; fails on any non-2xx answer. */
  abstract download(url: string): Promise<Buffer>;
}

/** Downloads with fetch, retrying 429 and 5xx with backoff. */
export class HttpReferencePhotoDownloader extends ReferencePhotoDownloader {
  async download(url: string): Promise<Buffer> {
    for (let attempt = 0; ; attempt++) {
      await sleep(PAUSE_MS);
      const response = await fetch(url, {
        headers: { 'User-Agent': PLANTAI_USER_AGENT },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      const retryable = response.status === 429 || response.status >= 500;
      if (retryable && attempt < RETRIES) {
        await sleep(1000 * 2 ** attempt);
        continue;
      }
      if (!response.ok) {
        throw new Error(`HTTP ${String(response.status)} for ${url}`);
      }
      return Buffer.from(await response.arrayBuffer());
    }
  }
}
