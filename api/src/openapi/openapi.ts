import type { INestApplication } from '@nestjs/common';
import {
  DocumentBuilder,
  type OpenAPIObject,
  SwaggerModule,
} from '@nestjs/swagger';
import { cleanupOpenApiDoc } from 'nestjs-zod';
import { API_VERSION } from '../app-version';

/** Where the Swagger UI lives; outside `/v1`, public and unversioned. */
export const DOCS_PATH = 'docs';
export const DOCS_JSON_PATH = `${DOCS_PATH}/openapi.json`;

/** The OpenAPI document, generated from the routes' Zod schemas. */
export function createOpenApiDocument(app: INestApplication): OpenAPIObject {
  const config = new DocumentBuilder()
    .setTitle('PlantAí API')
    .setVersion(API_VERSION)
    .addBearerAuth()
    .build();
  return cleanupOpenApiDoc(SwaggerModule.createDocument(app, config));
}

/**
 * Serves the UI at `/docs` and the JSON at `/docs/openapi.json`. These routes
 * sit on the HTTP adapter, outside Nest's router, so no guard or middleware of
 * the API (Bearer, `X-App-Version`) applies to them.
 */
export function setupOpenApi(app: INestApplication): void {
  SwaggerModule.setup(DOCS_PATH, app, () => createOpenApiDocument(app), {
    jsonDocumentUrl: DOCS_JSON_PATH,
    raw: ['json'],
    customSiteTitle: 'PlantAí API',
  });
}
