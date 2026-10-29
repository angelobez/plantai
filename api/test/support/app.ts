import type { INestApplication, LoggerService, Type } from '@nestjs/common';
import { Test, type TestingModuleBuilder } from '@nestjs/testing';
import { ThrottlerStorage } from '@nestjs/throttler';
import type { App } from 'supertest/types';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap';
import type { Env } from '../../src/config/env';
import { GoogleTokenVerifier } from '../../src/auth/google/google-token-verifier';
import { EmailSender } from '../../src/email/email-sender';
import { GbifNames } from '../../src/gbif/gbif-names';
import { PlantIdentifier } from '../../src/identifications/plant-identifier';
import { PhotoStorage } from '../../src/photo-storage/photo-storage';
import { FakeGbifNames } from './fake-gbif-names';
import { FakeGoogleVerifier } from './fake-google-verifier';
import { FakeOutbox } from './fake-outbox';
import { FakePhotoStorage } from './fake-photo-storage';
import { FakePlantIdentifier } from './fake-plant-identifier';

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
  /**
   * Keeps the photos in memory instead of S3. Pass one to look at what the
   * API stored (bytes, tags) or to make it fail; without it, a throwaway one.
   */
  photoStorage?: FakePhotoStorage;
  /**
   * Resolves scientific names instead of GBIF. Pass one taught with
   * `knows()`; without it, a throwaway one matches no name.
   */
  gbifNames?: FakeGbifNames;
  /**
   * Identifies the photos instead of Pl@ntNet. Pass one to set its answer
   * (`answers()`) or make it fail; without it, a throwaway one recognizes
   * nothing.
   */
  plantIdentifier?: FakePlantIdentifier;
  /**
   * Keeps the real `/auth` rate limits. Without it no request is ever limited,
   * so a test may call `/auth` as often as it needs.
   */
  realRateLimits?: boolean;
}

/** Counts nothing and never blocks. */
const unlimitedStorage: ThrottlerStorage = {
  increment: () =>
    Promise.resolve({
      totalHits: 0,
      timeToExpire: 0,
      isBlocked: false,
      timeToBlockExpire: 0,
    }),
};

/**
 * The whole Nest app, configured exactly like the real entry points. Only the
 * ports to external services (e-mail, Google, photo storage, GBIF, Pl@ntNet)
 * are swapped for fakes, and the rate limits are off unless a test asks for
 * them.
 */
export async function createTestApp(
  env: Env,
  {
    controllers = [],
    logger,
    outbox = new FakeOutbox(),
    googleVerifier = new FakeGoogleVerifier(),
    photoStorage = new FakePhotoStorage(),
    gbifNames = new FakeGbifNames(),
    plantIdentifier = new FakePlantIdentifier(),
    realRateLimits = false,
  }: TestAppOptions = {},
): Promise<INestApplication<App>> {
  let builder: TestingModuleBuilder = Test.createTestingModule({
    imports: [AppModule.forRoot(env)],
    controllers,
  })
    .overrideProvider(EmailSender)
    .useValue(outbox)
    .overrideProvider(GoogleTokenVerifier)
    .useValue(googleVerifier)
    .overrideProvider(PhotoStorage)
    .useValue(photoStorage)
    .overrideProvider(GbifNames)
    .useValue(gbifNames)
    .overrideProvider(PlantIdentifier)
    .useValue(plantIdentifier);
  if (!realRateLimits) {
    builder = builder
      .overrideProvider(ThrottlerStorage)
      .useValue(unlimitedStorage);
  }
  const moduleRef = await builder.compile();

  const app = moduleRef.createNestApplication<INestApplication<App>>({
    logger: logger ?? false,
  });
  await configureApp(app);
  return app;
}
