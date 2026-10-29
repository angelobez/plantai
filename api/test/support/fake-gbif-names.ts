import {
  type GbifNames,
  type GbifResolution,
  GbifUnavailableError,
} from '../../src/gbif/gbif-names';

/**
 * Stands in for GBIF: a test teaches it which names resolve to which accepted
 * species; any other name has no match. Keeps every name it was asked about.
 */
export class FakeGbifNames implements GbifNames {
  private readonly accepted = new Map<
    string,
    { gbifKey: number; scientificName: string }
  >();

  /** Every name passed to {@link resolve}, oldest first. */
  readonly asked: string[] = [];

  /** While true, every call fails as if GBIF were down. */
  failing = false;

  /**
   * Makes [name] resolve to [gbifKey]; to [scientificName] too, when [name]
   * is a synonym.
   */
  knows(name: string, gbifKey: number, scientificName: string = name): this {
    this.accepted.set(name, { gbifKey, scientificName });
    return this;
  }

  resolve(scientificName: string): Promise<GbifResolution> {
    this.asked.push(scientificName);
    if (this.failing) {
      return Promise.reject(new GbifUnavailableError('The fake GBIF is down'));
    }
    const match = this.accepted.get(scientificName);
    return Promise.resolve(
      match
        ? { ok: true, ...match }
        : { ok: false, reason: 'GBIF: sem match exato (NONE)' },
    );
  }
}
