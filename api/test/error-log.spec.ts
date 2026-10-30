import type { INestApplication, LoggerService } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import { databaseOf, signUpAndVerify } from './support/auth';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import { startPostgis } from './support/postgis';

/** Keeps every argument of every error line, the stack included. */
class CapturingLogger implements LoggerService {
  readonly errors: string[] = [];

  log(): void {}
  warn(): void {}
  error(...messages: unknown[]): void {
    this.errors.push(messages.map((m) => String(m)).join('\n'));
  }
}

describe('error log of a failed query', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const logger = new CapturingLogger();

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      logger,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  // The v0.3 close-out (#68) hit this with a dev database that had not run the
  // listings migration: Drizzle's message carried the searcher's coordinates.
  it('logs the SQL and the Postgres cause but no parameter value', async () => {
    const session = await signUpAndVerify(app, outbox);
    await databaseOf(app).execute(
      sql`ALTER TABLE listings RENAME TO listings_gone`,
    );

    await request(app.getHttpServer())
      .get('/v1/listings/nearby')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .set('X-Search-Location', '-23.123457,-46.765432')
      .expect(500);

    const everything = logger.errors.join('\n');
    expect(everything).toContain('Failed query: select');
    expect(everything).toContain('relation "listings" does not exist');
    expect(everything).toContain('42P01');
    expect(everything).toMatch(/\n\s+at /);
    expect(everything).not.toContain('params');
    expect(everything).not.toContain('23.123457');
    expect(everything).not.toContain('46.765432');
  });
});
