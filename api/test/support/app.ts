import type { INestApplication, LoggerService, Type } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { App } from 'supertest/types';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap';
import type { Env } from '../../src/config/env';

export interface TestAppOptions {
  /** Extra controllers that exist only in the test module. */
  controllers?: Type[];
  /** Receives the app's logs; by default they are discarded. */
  logger?: LoggerService;
}

/** The whole Nest app, configured exactly like the real entry points. */
export async function createTestApp(
  env: Env,
  { controllers = [], logger }: TestAppOptions = {},
): Promise<INestApplication<App>> {
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule.forRoot(env)],
    controllers,
  }).compile();

  const app = moduleRef.createNestApplication<INestApplication<App>>({
    logger: logger ?? false,
  });
  await configureApp(app);
  return app;
}
