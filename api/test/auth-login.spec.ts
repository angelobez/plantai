import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import { users } from '../src/database/schema';
import { createTestApp } from './support/app';
import {
  type AuthTokensBody,
  databaseOf,
  newAccount,
  signUp,
  signUpAndVerify,
} from './support/auth';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import { startPostgis } from './support/postgis';

describe('log in with e-mail and password', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  function logIn(email: string, password: string): request.Test {
    return request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email, password });
  }

  async function expectInvalidCredentials(
    response: request.Test,
  ): Promise<void> {
    const answer = await response
      .expect(401)
      .expect('Content-Type', /^application\/problem\+json/);
    expect(answer.body).toMatchObject({ code: 'INVALID_CREDENTIALS' });
  }

  it('answers with tokens for the right password, and the token reads /me', async () => {
    const account = newAccount({ name: 'Marina Souza' });
    const signedUp = await signUpAndVerify(app, outbox, account);

    const response = await logIn(account.email, account.password).expect(200);
    const body = response.body as AuthTokensBody;
    expect(body).toEqual({
      accessToken: expect.any(String) as unknown,
      refreshToken: expect.any(String) as unknown,
      user: signedUp.user,
    });
    expect(body.refreshToken).not.toBe(signedUp.refreshToken);

    const me = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${body.accessToken}`)
      .expect(200);
    expect(me.body).toEqual(signedUp.user);
  });

  it('treats the e-mail case-insensitively', async () => {
    const account = newAccount();
    await signUpAndVerify(app, outbox, account);

    await logIn(account.email.toUpperCase(), account.password).expect(200);
  });

  it('a wrong password answers INVALID_CREDENTIALS', async () => {
    const account = newAccount();
    await signUpAndVerify(app, outbox, account);

    await expectInvalidCredentials(logIn(account.email, 'senha-errada-1'));
  });

  it('an e-mail without an account answers the same INVALID_CREDENTIALS', async () => {
    await expectInvalidCredentials(logIn('ninguem@email.com', 'senha-boa-123'));
  });

  it('an account without a password (Google only) answers the same INVALID_CREDENTIALS', async () => {
    const email = newAccount().email;
    await databaseOf(app)
      .insert(users)
      .values({
        name: 'Marina',
        email,
        emailVerifiedAt: new Date(),
        googleSub: `google-${email}`,
      });

    await expectInvalidCredentials(logIn(email, 'senha-boa-123'));
  });

  it('a wrong password on an unconfirmed account answers INVALID_CREDENTIALS and sends no code', async () => {
    const account = newAccount();
    await signUp(app, account);
    outbox.clear();

    await expectInvalidCredentials(logIn(account.email, 'senha-errada-1'));
    expect(outbox.sentTo(account.email)).toHaveLength(0);
  });

  it('the right password on an unconfirmed account answers EMAIL_NOT_VERIFIED and sends a new signup code', async () => {
    const account = newAccount();
    await signUp(app, account);
    outbox.clear();

    const response = await logIn(account.email, account.password)
      .expect(403)
      .expect('Content-Type', /^application\/problem\+json/);
    expect(response.body).toMatchObject({ code: 'EMAIL_NOT_VERIFIED' });

    expect(outbox.sentTo(account.email)).toHaveLength(1);
    const code = outbox.lastCodeTo(account.email, 'signup-code');
    const verified = await request(app.getHttpServer())
      .post('/v1/auth/verify-email')
      .send({ email: account.email, code })
      .expect(200);
    expect((verified.body as AuthTokensBody).user.email).toBe(account.email);
  });

  it.each([
    ['an invalid e-mail', { email: 'marina' }, 'email'],
    ['an empty password', { password: '' }, 'password'],
    [
      'a password over 128 characters',
      { password: 'a'.repeat(129) },
      'password',
    ],
  ])('rejects %s with VALIDATION_FAILED', async (_case, change, path) => {
    const response = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email: 'marina@email.com', password: 'senha-boa-123', ...change })
      .expect(400);

    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path }],
    });
  });
});
