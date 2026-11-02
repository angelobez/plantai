import type { INestApplication, LoggerService } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import { testEnv } from './support/env';
import { startPostgis } from './support/postgis';

const SECRET = 'cloudfront-origin-secret-of-at-least-32-chars';

/** Keeps every log line so the test can read what would reach CloudWatch. */
class CapturingLogger implements LoggerService {
  readonly lines: string[] = [];

  log(message: unknown): void {
    this.lines.push(JSON.stringify(message));
  }
  error(message: unknown): void {
    this.lines.push(JSON.stringify(message));
  }
  warn(message: unknown): void {
    this.lines.push(JSON.stringify(message));
  }
}

describe('CloudFront origin secret', () => {
  let container: StartedPostgreSqlContainer;

  beforeAll(async () => {
    container = await startPostgis();
  });

  afterAll(async () => {
    await container.stop();
  });

  describe('when configured', () => {
    let app: INestApplication<App>;
    const logger = new CapturingLogger();

    beforeAll(async () => {
      app = await createTestApp(
        testEnv(container.getConnectionUri(), {
          CLOUDFRONT_ORIGIN_SECRET: SECRET,
        }),
        { logger },
      );
    });

    afterAll(async () => {
      await app.close();
    });

    it.each([
      ['without the header', undefined],
      ['with a wrong value', 'not-the-secret'],
      ['with a longer value', `${SECRET}x`],
    ])(
      'answers 403 DIRECT_ACCESS_FORBIDDEN as problem+json %s',
      async (_case, value) => {
        let call = request(app.getHttpServer()).get('/v1/health');
        if (value !== undefined) call = call.set('X-Origin-Verify', value);
        const response = await call
          .expect(403)
          .expect('Content-Type', /^application\/problem\+json/);

        expect(response.body).toEqual({
          type: 'about:blank',
          title: 'Forbidden',
          status: 403,
          code: 'DIRECT_ACCESS_FORBIDDEN',
        });
      },
    );

    it('refuses also what sits outside /v1 (docs, unknown paths)', async () => {
      const server = app.getHttpServer();
      await request(server).get('/docs/openapi.json').expect(403);
      await request(server).post('/nothing-here').expect(403);
    });

    it('answers normally with the right value, and never logs it', async () => {
      await request(app.getHttpServer())
        .get('/v1/health')
        .set('X-Origin-Verify', SECRET)
        .expect(200);

      const line = logger.lines.find((l) => l.includes('GET /v1/health 200'));
      expect(line).toContain('x-origin-verify');
      expect(logger.lines.join('\n')).not.toContain(SECRET);
    });
  });

  describe('when not configured', () => {
    let app: INestApplication<App>;

    beforeAll(async () => {
      app = await createTestApp(testEnv(container.getConnectionUri()));
    });

    afterAll(async () => {
      await app.close();
    });

    it('answers as usual, with or without the header', async () => {
      const server = app.getHttpServer();
      await request(server).get('/v1/health').expect(200);
      await request(server)
        .get('/v1/health')
        .set('X-Origin-Verify', 'anything')
        .expect(200);
    });
  });
});
