import type { GbifResolution } from './gbif-match';

export type { GbifResolution } from './gbif-match';

/** GBIF could not be reached, or answered something unexpected. */
export class GbifUnavailableError extends Error {
  override readonly name = 'GbifUnavailableError';
}

/**
 * The port for resolving a scientific name in GBIF (`species/match`) to the
 * `gbifKey` of its accepted species, the Catalog's identity. The real adapter
 * is {@link HttpGbifNames}, shared with the seed script; tests swap in a fake.
 *
 * An abstract class rather than an interface, so it doubles as the Nest
 * injection token.
 */
export abstract class GbifNames {
  /**
   * The accepted species for [scientificName], or `ok: false` with the
   * reason it was discarded. Fails with {@link GbifUnavailableError}.
   */
  abstract resolve(scientificName: string): Promise<GbifResolution>;
}
