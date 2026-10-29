import type { INestApplication, LoggerService, Type } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { App } from 'supertest/types';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap';
import type { Env } from '../../src/config/env';
import { GoogleTokenVerifier } from '../../src/auth/google/google-token-verifier';
import { EmailSender } from '../../src/email/email-sender';
import { FakeGoogleVerifier } from './fake-google-verifier';
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
  /**
   * Verifies the Google ID tokens instead of Google. Pass one to hand out
   * tokens; without it, a throwaway one rejects every token.
   */
  googleVerifier?: FakeGoogleVerifier;
}

/**
 * The whole Nest app, configured exactly like the real entry points. Only the
 * ports to external services (e-mail, Google) are swapped for fakes.
 */
export async function createTestApp(
  env: Env,
  {
    controllers = [],
    logger,
    outbox = new FakeOutbox(),
    googleVerifier = new FakeGoogleVerifier(),
  }: TestAppOptions = {},
): Promise<INestApplication<App>> {
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule.forRoot(env)],
    controllers,
  })
    .overrideProvider(EmailSender)
    .useValue(outbox)
    .overrideProvider(GoogleTokenVerifier)
    .useValue(googleVerifier)
    .compile();

  const app = moduleRef.createNestApplication<INestApplication<App>>({
    logger: logger ?? false,
  });
  await configureApp(app);
  return app;
}
