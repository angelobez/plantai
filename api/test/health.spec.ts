import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import { startPostgis } from './support/postgis';

describe('GET /v1/health with the database up', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp({
      DATABASE_URL: container.getConnectionUri(),
      PORT: 0,
      MIN_APP_VERSION: '0.0.0',
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  it('reports the API and PostGIS versions read from the database', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/health')
      .expect(200);

    expect(response.body).toEqual({
      status: 'ok',
      apiVersion: '0.0.0',
      postgisVersion: expect.stringMatching(/^3\.5\.\d+/) as unknown,
    });
  });
});

describe('GET /v1/health with the database down', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    const container = await startPostgis();
    app = await createTestApp({
      DATABASE_URL: container.getConnectionUri(),
      PORT: 0,
      MIN_APP_VERSION: '0.0.0',
    });
    await container.stop();
  });

  afterAll(async () => {
    await app.close();
  });

  it('answers 503 HEALTH_CHECK_FAILED as problem+json', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/health')
      .expect(503)
      .expect('Content-Type', /^application\/problem\+json/);

    expect(response.body).toEqual({
      type: 'about:blank',
      title: 'Service Unavailable',
      status: 503,
      code: 'HEALTH_CHECK_FAILED',
    });
  });
});
