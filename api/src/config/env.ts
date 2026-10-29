import { existsSync } from 'node:fs';
import { z } from 'zod';
import { isSemanticVersion } from '../semantic-version';

/** An empty value (`KEY=` in `.env`) counts as unset. */
const optional = <T extends z.ZodType>(schema: T) =>
  z.preprocess(
    (value) => (value === '' ? undefined : value),
    schema.optional(),
  );

const envSchema = z
  .object({
    DATABASE_URL: z.url(),
    PORT: z.coerce.number().int().positive().default(3000),
    MIN_APP_VERSION: z
      .string()
      .refine(isSemanticVersion, 'must be a semantic version like 1.2.3'),
    /** Identifies the plants in the photos (https://my.plantnet.org/). */
    PLANTNET_API_KEY: z.string().min(1),
    /** Signs the access tokens (HS256). */
    JWT_SECRET: z.string().min(32),
    /** The Google Cloud OAuth Web client: the audience of the Google ID tokens. */
    GOOGLE_WEB_CLIENT_ID: z.string().min(1),
    /** Without it, e-mails are written to the API log instead of sent. */
    RESEND_API_KEY: optional(z.string().min(1)),
    /** Sender of every e-mail, such as `PlantAí <onboarding@resend.dev>`. */
    EMAIL_FROM: z.string().min(1),
    /** The private bucket of the photo storage (S3, or the local emulator). */
    S3_BUCKET: z.string().min(1),
    S3_REGION: z.string().min(1),
    /** Only for the local emulator; unset, the SDK talks to AWS itself. */
    S3_ENDPOINT: optional(z.url()),
    /** Only for the emulator; on Lambda the credentials come from its role. */
    S3_ACCESS_KEY_ID: optional(z.string().min(1)),
    S3_SECRET_ACCESS_KEY: optional(z.string().min(1)),
  })
  .superRefine((env, context) => {
    const keys = ['S3_ACCESS_KEY_ID', 'S3_SECRET_ACCESS_KEY'] as const;
    const missing = keys.filter((key) => env[key] === undefined);
    if (missing.length === 1) {
      context.addIssue({
        code: 'custom',
        path: missing,
        message: `required when ${keys.find((key) => !missing.includes(key)) ?? ''} is set`,
      });
    }
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
