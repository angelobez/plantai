import type { Env } from '../../src/config/env';

/** Signs the access tokens in tests; a test can sign its own JWTs with it. */
export const TEST_JWT_SECRET = 'test-secret-that-is-at-least-32-characters';

/**
 * A valid {@link Env} for the test app, pointing at [databaseUrl]. Pass
 * [overrides] for what a test cares about (`MIN_APP_VERSION`, for instance).
 */
export function testEnv(
  databaseUrl: string,
  overrides: Partial<Env> = {},
): Env {
  return {
    DATABASE_URL: databaseUrl,
    PORT: 0,
    MIN_APP_VERSION: '0.0.0',
    JWT_SECRET: TEST_JWT_SECRET,
    GOOGLE_WEB_CLIENT_ID: 'test-web-client.apps.googleusercontent.com',
    EMAIL_FROM: 'PlantAí <test@plantai.test>',
    // The photo storage is a fake in the test app; these only satisfy the type.
    S3_BUCKET: 'plantai-photos-test',
    S3_REGION: 'us-east-1',
    // The plant identifier is a fake in the test app too.
    PLANTNET_API_KEY: 'test-plantnet-key',
    ...overrides,
  };
}

/** For tests that never touch the database (the postgres client is lazy). */
export const UNUSED_DATABASE_URL =
  'postgres://unused:unused@localhost:1/unused';
