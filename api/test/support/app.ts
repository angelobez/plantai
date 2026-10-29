import type { INestApplication, LoggerService, Type } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { App } from 'supertest/types';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap';
import type { Env } from '../../src/config/env';
import { EmailSender } from '../../src/email/email-sender';
import { FakeOutbox } from './fake-outbox';

export interface TestAppOptions {
  /** Extra controllers that exist only in the test module. */
  controllers?: Type[];
  /** Receives the app's logs; by default they are discarded. */
  logger?: LoggerService;
  /**
   * Gets every e-mail the API sends, instead of the log or Resend. Pass one to
   * read the codes; without it, the e-mails are kept by a throwaway outbox.
   */
  outbox?: FakeOutbox;
}

/**
 * The whole Nest app, configured exactly like the real entry points. Only the
 * ports to external services (e-mail) are swapped for fakes.
 */
export async function createTestApp(
  env: Env,
  { controllers = [], logger, outbox = new FakeOutbox() }: TestAppOptions = {},
): Promise<INestApplication<App>> {
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule.forRoot(env)],
    controllers,
  })
    .overrideProvider(EmailSender)
    .useValue(outbox)
    .compile();

  const app = moduleRef.createNestApplication<INestApplication<App>>({
    logger: logger ?? false,
  });
  await configureApp(app);
  return app;
}
