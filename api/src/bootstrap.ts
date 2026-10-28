import type { INestApplication } from '@nestjs/common';
import { ProblemDetailsFilter } from './errors/problem-details.filter';

/**
 * Cross-cutting setup shared by every entry point (local HTTP server, Lambda
 * handler) and by the tests, so they all serve the same API.
 */
export function configureApp(app: INestApplication): void {
  app.setGlobalPrefix('v1');
  app.useGlobalFilters(new ProblemDetailsFilter());
  app.enableShutdownHooks();
}
