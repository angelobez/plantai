import type { INestApplication } from '@nestjs/common';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import { testEnv, UNUSED_DATABASE_URL } from './support/env';

/** The versioned contract. Refresh it with `npm run openapi:update`. */
const SNAPSHOT_PATH = join(__dirname, '..', 'openapi.json');
const UPDATE = process.env.UPDATE_OPENAPI_SNAPSHOT === '1';

interface OpenApiDocument {
  paths: Record<string, Record<string, OpenApiOperation>>;
  components: { schemas: Record<string, unknown> };
}

interface OpenApiOperation {
  responses: Record<string, { content?: Record<string, unknown> }>;
}

// Building the document never queries the database, and the postgres client
// connects lazily, so these tests need no PostGIS container.
describe('OpenAPI at /docs', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    app = await createTestApp(
      testEnv(UNUSED_DATABASE_URL, { MIN_APP_VERSION: '1.0.0' }),
    );
  });

  afterAll(async () => {
    await app.close();
  });

  async function fetchDocument(): Promise<{ body: OpenApiDocument }> {
    return request(app.getHttpServer())
      .get('/docs/openapi.json')
      .expect(200)
      .expect('Content-Type', /^application\/json/);
  }

  it('serves the Swagger UI without a Bearer token or X-App-Version', async () => {
    const response = await request(app.getHttpServer())
      .get('/docs')
      .redirects(1)
      .expect(200)
      .expect('Content-Type', /^text\/html/);

    expect(response.text).toMatch(/swagger-ui/i);
  });

  it('serves the document even to an app older than MIN_APP_VERSION', async () => {
    await request(app.getHttpServer())
      .get('/docs/openapi.json')
      .set('X-App-Version', '0.0.1')
      .expect(200);
  });

  it('describes GET /v1/health with its response and problem+json errors', async () => {
    const { body } = await fetchDocument();
    const health = body.paths['/v1/health']?.get;

    expect(health?.responses['200']?.content).toEqual({
      'application/json': {
        schema: { $ref: '#/components/schemas/HealthResponse_Output' },
      },
    });
    expect(body.components.schemas['HealthResponse_Output']).toMatchObject({
      required: ['status', 'apiVersion', 'postgisVersion'],
    });

    expect(health?.responses['503']?.content).toEqual({
      'application/problem+json': {
        schema: {
          allOf: [
            { $ref: '#/components/schemas/ProblemDetails' },
            {
              type: 'object',
              properties: {
                code: { type: 'string', enum: ['HEALTH_CHECK_FAILED'] },
              },
            },
          ],
        },
      },
    });
    expect(body.components.schemas['ProblemDetails']).toMatchObject({
      required: ['type', 'title', 'status', 'code'],
    });
  });

  it('matches the versioned snapshot (update with `npm run openapi:update`)', async () => {
    const { body } = await fetchDocument();
    const generated = `${JSON.stringify(body, null, 2)}\n`;

    if (UPDATE) writeFileSync(SNAPSHOT_PATH, generated);

    const snapshot = readFileSync(SNAPSHOT_PATH, 'utf8');
    expect(generated).toBe(snapshot);
  });
});
