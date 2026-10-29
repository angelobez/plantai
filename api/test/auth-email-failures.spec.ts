import type { INestApplication, LoggerService } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import { newAccount, signUp, signUpAndVerify } from './support/auth';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import { startPostgis } from './support/postgis';

/** Keeps every log line so the test can read what the API logged. */
class CapturingLogger implements LoggerService {
  readonly lines: string[] = [];

  log(message: unknown): void {
    this.lines.push(JSON.stringify(message));
  }
  error(message: unknown): void {
    this.lines.push(JSON.stringify(message));
  }
  warn(message: unknown): void {
    this.lines.push(JSON.stringify(message));
  }
}

/**
 * When the e-mail provider fails, the /auth routes answer exactly as when it
 * works: a 500 only for e-mails with an account would tell who uses PlantAí.
 * The failure goes to the log, without the address.
 */
describe('e-mail that fails to send', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const logger = new CapturingLogger();

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      logger,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  beforeEach(() => {
    logger.lines.length = 0;
  });

  afterEach(() => {
    outbox.failing = false;
  });

  function expectLoggedWithout(template: string, email: string): void {
    const everything = logger.lines.join('\n');
    expect(everything).toContain(template);
    expect(everything).not.toContain(email);
  }

  it('POST /auth/signup still answers 202 for a new e-mail', async () => {
    const account = newAccount();
    outbox.failing = true;

    await request(app.getHttpServer())
      .post('/v1/auth/signup')
      .send(account)
      .expect(202);

    expectLoggedWithout('signup-code', account.email);
  });

  it('POST /auth/signup still answers 202 for a confirmed account', async () => {
    const account = newAccount();
    await signUpAndVerify(app, outbox, account);
    outbox.failing = true;

    await request(app.getHttpServer())
      .post('/v1/auth/signup')
      .send(account)
      .expect(202);

    expectLoggedWithout('account-exists', account.email);
  });

  it('POST /auth/login still answers EMAIL_NOT_VERIFIED for an unconfirmed account', async () => {
    const account = newAccount();
    await signUp(app, account);
    outbox.failing = true;

    const response = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email: account.email, password: account.password })
      .expect(403);

    expect(response.body).toMatchObject({ code: 'EMAIL_NOT_VERIFIED' });
    expectLoggedWithout('signup-code', account.email);
  });

  it('POST /auth/password-reset/request still answers 204 for an account', async () => {
    const account = newAccount();
    await signUpAndVerify(app, outbox, account);
    outbox.failing = true;

    await request(app.getHttpServer())
      .post('/v1/auth/password-reset/request')
      .send({ email: account.email })
      .expect(204);

    expectLoggedWithout('password-reset-code', account.email);
  });
});
