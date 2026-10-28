import { existsSync } from 'node:fs';
import { z } from 'zod';

const envSchema = z.object({
  DATABASE_URL: z.url(),
  PORT: z.coerce.number().int().positive().default(3000),
  MIN_APP_VERSION: z
    .string()
    .regex(/^\d+\.\d+\.\d+$/, 'must be a version like 1.2.3'),
  PLANTNET_API_KEY: z.string().min(1).optional(),
});

export type Env = z.infer<typeof envSchema>;

export class InvalidEnvError extends Error {
  override readonly name = 'InvalidEnvError';
}

/**
 * Validates the process environment once, at startup. Everything else reads
 * the returned typed config, never `process.env`.
 */
export function parseEnv(source: Record<string, string | undefined>): Env {
  const result = envSchema.safeParse(source);
  if (result.success) return result.data;

  const problems = result.error.issues.map(
    (issue) => `${issue.path.join('.')}: ${issue.message}`,
  );
  throw new InvalidEnvError(
    `Invalid environment variables:\n  ${problems.join('\n  ')}`,
  );
}

/**
 * Reads `.env` from the working directory when there is one (local runs and
 * drizzle-kit), then validates the whole process environment.
 */
export function loadEnv(): Env {
  if (existsSync('.env')) process.loadEnvFile('.env');
  return parseEnv(process.env);
}
