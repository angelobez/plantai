import { z } from 'zod';

/** The Neon API (https://neon.com/docs/reference/api-reference). */
export const NEON_API_URL = 'https://console.neon.tech/api/v2';

/** A CU-hour in the CU-seconds of {@link NeonProjectUsage.computeTimeSeconds}. */
export const CU_SECONDS_PER_CU_HOUR = 3600;

/** What the project has used in the current billing cycle. */
export interface NeonProjectUsage {
  /**
   * Compute time of the cycle, in CU-seconds: weighted by the compute size,
   * so dividing by {@link CU_SECONDS_PER_CU_HOUR} gives the CU-hours the Free plan caps at 100
   * (https://neon.com/docs/introduction/usage-calculations).
   */
  computeTimeSeconds: number;
  /** When the billing cycle started, as Neon sends it (ISO 8601). */
  consumptionPeriodStart: string;
}

/** The part of the Neon API the maintenance routine uses. */
export interface NeonApi {
  projectUsage(): Promise<NeonProjectUsage>;
}

/** Neon answered with an error or with something unexpected. */
export class NeonApiError extends Error {
  override readonly name = 'NeonApiError';
}

const projectSchema = z.object({
  project: z.object({
    compute_time_seconds: z.number().nonnegative(),
    consumption_period_start: z.string().min(1),
  }),
});

export interface NeonApiOptions {
  /** A key restricted to the project (Neon's "project-scoped" API key). */
  apiKey: string;
  projectId: string;
  fetch?: typeof globalThis.fetch;
}

/**
 * The real client. Reads the usage snapshot of `GET /projects/{project_id}`,
 * which Neon keeps on every plan (the consumption history API is only for
 * the paid ones) and calls approximate, meant for monitoring: enough to warn
 * before the 100 CU-hours of the Free plan.
 */
export function neonApiClient({
  apiKey,
  projectId,
  fetch = globalThis.fetch,
}: NeonApiOptions): NeonApi {
  const url = `${NEON_API_URL}/projects/${encodeURIComponent(projectId)}`;
  return {
    async projectUsage() {
      const response = await fetch(url, {
        headers: {
          Accept: 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        signal: AbortSignal.timeout(10_000),
      });
      if (!response.ok) {
        throw new NeonApiError(
          `GET /projects/{project_id} answered ${String(response.status)} ${response.statusText}`.trim(),
        );
      }
      const parsed = projectSchema.safeParse(await response.json());
      if (!parsed.success) {
        throw new NeonApiError(
          `GET /projects/{project_id} answered an unexpected body: ${z.prettifyError(parsed.error)}`,
        );
      }
      return {
        computeTimeSeconds: parsed.data.project.compute_time_seconds,
        consumptionPeriodStart: parsed.data.project.consumption_period_start,
      };
    },
  };
}
