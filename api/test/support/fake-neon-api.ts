import {
  CU_SECONDS_PER_CU_HOUR,
  type NeonApi,
  NeonApiError,
  type NeonProjectUsage,
} from '../../src/maintenance/neon-api';

/** The start of a Neon billing cycle, as `GET /projects/{id}` sends it. */
export const NOVEMBER = '2026-11-01T00:00:00Z';
export const DECEMBER = '2026-12-01T00:00:00Z';

/**
 * Stands in for the Neon API: answers whatever a test put in {@link next},
 * an idle project at the start of November by default. Counts the calls.
 */
export class FakeNeonApi implements NeonApi {
  next: NeonProjectUsage = {
    computeTimeSeconds: 0,
    consumptionPeriodStart: NOVEMBER,
  };

  /** While true, every call fails as if the Neon API were down. */
  failing = false;

  calls = 0;

  /** Makes the next calls answer [cuHours] used since [periodStart]. */
  uses(cuHours: number, periodStart = NOVEMBER): this {
    this.next = {
      computeTimeSeconds: cuHours * CU_SECONDS_PER_CU_HOUR,
      consumptionPeriodStart: periodStart,
    };
    return this;
  }

  projectUsage(): Promise<NeonProjectUsage> {
    this.calls += 1;
    if (this.failing) {
      return Promise.reject(
        new NeonApiError('The fake Neon API answered 503 Service Unavailable'),
      );
    }
    return Promise.resolve({ ...this.next });
  }
}
