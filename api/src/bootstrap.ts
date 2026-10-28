import type { INestApplication } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import type { Request, Response } from 'express';
import { AppModule } from './app.module';
import type { Env } from './config/env';
import { DomainError } from './errors/domain-error';
import {
  ProblemDetailsFilter,
  sendProblem,
} from './errors/problem-details.filter';
import { ZodValidationPipe } from './errors/validation';

/**
 * Cross-cutting setup shared by every entry point (local HTTP server, Lambda
 * handler) and by the tests, so they all serve the same API. It also
 * initializes the app, because the last fallback must come after the routes.
 */
export async function configureApp(app: INestApplication): Promise<void> {
  app.setGlobalPrefix('v1');
  app.useGlobalFilters(new ProblemDetailsFilter());
  app.useGlobalPipes(new ZodValidationPipe());
  await app.init();

  // Nest's own not-found handler only covers /v1; this answers everything else.
  app.use((_request: Request, response: Response) => {
    sendProblem(response, new DomainError('NOT_FOUND'));
  });
}

/** Creates the configured app; used by the local server and the Lambda handler. */
export async function createApp(env: Env): Promise<NestExpressApplication> {
  const app = await NestFactory.create<NestExpressApplication>(
    AppModule.forRoot(env),
  );
  await configureApp(app);
  return app;
}
