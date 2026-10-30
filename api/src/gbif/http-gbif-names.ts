import { messageOf } from '../errors/message-of';
import { gbifMatchUrl, resolveGbifMatch } from './gbif-match';
import {
  GbifNames,
  type GbifResolution,
  GbifUnavailableError,
} from './gbif-names';

/** GETs a URL and parses the JSON body; fails on a non-2xx answer. */
export type FetchJson = (url: string) => Promise<unknown>;

const TIMEOUT_MS = 10_000;

/** A plain {@link FetchJson} with a timeout, for the API. */
export const fetchJsonWithTimeout: FetchJson = async (url) => {
  const response = await fetch(url, {
    headers: { Accept: 'application/json' },
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`HTTP ${String(response.status)} for ${url}`);
  }
  return response.json();
};

/**
 * {@link GbifNames} over GBIF's public API (no key). The seed script passes
 * its own [fetchJson], which caches on disk.
 */
export class HttpGbifNames extends GbifNames {
  constructor(private readonly fetchJson: FetchJson = fetchJsonWithTimeout) {
    super();
  }

  async resolve(scientificName: string): Promise<GbifResolution> {
    try {
      return resolveGbifMatch(
        scientificName,
        await this.fetchJson(gbifMatchUrl(scientificName)),
      );
    } catch (error) {
      throw new GbifUnavailableError(messageOf(error), { cause: error });
    }
  }
}
