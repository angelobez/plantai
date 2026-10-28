import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import { startPostgis } from './support/postgis';

describe('X-App-Version check (MIN_APP_VERSION=1.2.0)', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp({
      DATABASE_URL: container.getConnectionUri(),
      PORT: 0,
      MIN_APP_VERSION: '1.2.0',
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  it.each(['1.1.9', '0.9.0', '1.2.0-beta.1'])(
    'answers %s with 426 APP_UPDATE_REQUIRED',
    async (version) => {
      const response = await request(app.getHttpServer())
        .get('/v1/health')
        .set('X-App-Version', version)
        .expect(426)
        .expect('Content-Type', /^application\/problem\+json/);

      expect(response.body).toEqual({
        type: 'about:blank',
        title: 'Upgrade Required',
        status: 426,
        code: 'APP_UPDATE_REQUIRED',
      });
    },
  );

  it.each(['1.2.0', '1.2.1', '2.0.0', '1.2.0+7'])(
    'lets %s through',
    async (version) => {
      await request(app.getHttpServer())
        .get('/v1/health')
        .set('X-App-Version', version)
        .expect(200);
    },
  );

  it('lets a request without the header through', async () => {
    await request(app.getHttpServer()).get('/v1/health').expect(200);
  });

  it.each(['latest', '1.2', 'v1.2.0', ''])(
    'answers %p with 400 VALIDATION_FAILED',
    async (version) => {
      const response = await request(app.getHttpServer())
        .get('/v1/health')
        .set('X-App-Version', version)
        .expect(400)
        .expect('Content-Type', /^application\/problem\+json/);

      expect(response.body).toEqual({
        type: 'about:blank',
        title: 'Bad Request',
        status: 400,
        code: 'VALIDATION_FAILED',
        errors: [
          { path: 'X-App-Version', message: expect.any(String) as unknown },
        ],
      });
    },
  );
});
