import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { eq, sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
import { Sessions } from '../src/auth/sessions';
import { users } from '../src/database/schema';
import { Users } from '../src/users/users';
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

describe('resetting the password with an e-mail code', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const NEW_PASSWORD = 'senha-nova-456';

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

  function requestCode(email: unknown): request.Test {
    return request(app.getHttpServer())
      .post('/v1/auth/password-reset/request')
      .send({ email });
  }

  function confirm(body: Record<string, unknown>): request.Test {
    return request(app.getHttpServer())
      .post('/v1/auth/password-reset/confirm')
      .send({ newPassword: NEW_PASSWORD, ...body });
  }

  function logIn(email: string, password: string): request.Test {
    return request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email, password });
  }

  function refresh(refreshToken: string): request.Test {
    return request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken });
  }

  async function expectInvalidCode(response: request.Test): Promise<void> {
    const answer = await response
      .expect(400)
      .expect('Content-Type', /^application\/problem\+json/);
    expect(answer.body).toMatchObject({ code: 'INVALID_CODE' });
  }

  /** Asks for a code for [email] and returns the one e-mailed. */
  async function resetCodeFor(email: string): Promise<string> {
    await requestCode(email).expect(204);
    return outbox.lastCodeTo(email, 'password-reset-code');
  }

  function wrongCodeFor(code: string): string {
    return code === '000000' ? '111111' : '000000';
  }

  describe('POST /auth/password-reset/request', () => {
    it('answers 204 with no body and e-mails a password_reset code to an account', async () => {
      const account = newAccount();
      await signUpAndVerify(app, outbox, account);
      outbox.clear();

      const response = await requestCode(account.email).expect(204);

      expect(response.text).toBe('');
      expect(outbox.sentTo(account.email)).toHaveLength(1);
      expect(outbox.lastTo(account.email).template).toBe('password-reset-code');
    });

    it('answers the same 204 for an e-mail without an account, and sends nothing', async () => {
      const email = newAccount().email;

      const response = await requestCode(email).expect(204);

      expect(response.text).toBe('');
      expect(outbox.sentTo(email)).toHaveLength(0);
    });

    it('treats the e-mail case-insensitively', async () => {
      const account = newAccount();
      await signUpAndVerify(app, outbox, account);
      outbox.clear();

      await requestCode(account.email.toUpperCase()).expect(204);

      expect(outbox.sentTo(account.email)).toHaveLength(1);
    });

    it('rejects an invalid e-mail with VALIDATION_FAILED', async () => {
      const response = await requestCode('marina').expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [{ path: 'email' }],
      });
    });
  });

  describe('POST /auth/password-reset/confirm', () => {
    it('sets the new password and answers with tokens that read /me', async () => {
      const account = newAccount({ name: 'Marina Souza' });
      const signedUp = await signUpAndVerify(app, outbox, account);
      const code = await resetCodeFor(account.email);

      const response = await confirm({ email: account.email, code }).expect(
        200,
      );
      const body = response.body as AuthTokensBody;
      expect(body).toEqual({
        accessToken: expect.any(String) as unknown,
        refreshToken: expect.any(String) as unknown,
        user: signedUp.user,
      });
      await request(app.getHttpServer())
        .get('/v1/me')
        .set('Authorization', `Bearer ${body.accessToken}`)
        .expect(200);

      await logIn(account.email, NEW_PASSWORD).expect(200);
      await logIn(account.email, account.password).expect(401);
    });

    it("revokes every refresh token family of the User, but not the new one nor other Users'", async () => {
      const account = newAccount();
      const first = await signUpAndVerify(app, outbox, account);
      const user = await app.get(Users).findByEmail(account.email);
      if (!user) throw new Error('user not created');
      const second = await app.get(Sessions).start(user);
      const other = await signUpAndVerify(app, outbox);
      const code = await resetCodeFor(account.email);

      const reset = (await confirm({ email: account.email, code }).expect(200))
        .body as AuthTokensBody;

      await refresh(first.refreshToken).expect(401);
      await refresh(second.refreshToken).expect(401);
      await refresh(reset.refreshToken).expect(200);
      await refresh(other.refreshToken).expect(200);
    });

    it('confirms the e-mail of an unconfirmed account (the code proves it)', async () => {
      const account = newAccount();
      await signUp(app, account);
      const code = await resetCodeFor(account.email);

      await confirm({ email: account.email, code }).expect(200);

      const user = await app.get(Users).findByEmail(account.email);
      expect(user?.emailVerifiedAt).toBeInstanceOf(Date);
      await logIn(account.email, NEW_PASSWORD).expect(200);
    });

    it('keeps the date an e-mail was already confirmed', async () => {
      const account = newAccount();
      await signUpAndVerify(app, outbox, account);
      const before = await app.get(Users).findByEmail(account.email);
      const code = await resetCodeFor(account.email);

      await confirm({ email: account.email, code }).expect(200);

      const after = await app.get(Users).findByEmail(account.email);
      expect(after?.emailVerifiedAt).toEqual(before?.emailVerifiedAt);
    });

    it('gives a password to an account without one (Google only), which then logs in', async () => {
      const email = newAccount().email;
      await databaseOf(app)
        .insert(users)
        .values({
          name: 'Marina',
          email,
          emailVerifiedAt: new Date(),
          googleSub: `google-${email}`,
        });
      await logIn(email, NEW_PASSWORD).expect(401);
      const code = await resetCodeFor(email);

      await confirm({ email, code }).expect(200);

      await logIn(email, NEW_PASSWORD).expect(200);
      const [row] = await databaseOf(app)
        .select({ googleSub: users.googleSub })
        .from(users)
        .where(eq(users.email, email));
      expect(row?.googleSub).toBe(`google-${email}`);
    });

    it('a wrong code answers INVALID_CODE and keeps the old password', async () => {
      const account = newAccount();
      await signUpAndVerify(app, outbox, account);
      const code = await resetCodeFor(account.email);

      await expectInvalidCode(
        confirm({ email: account.email, code: wrongCodeFor(code) }),
      );
      await logIn(account.email, account.password).expect(200);
    });

    it('an expired code answers INVALID_CODE', async () => {
      const account = newAccount();
      await signUpAndVerify(app, outbox, account);
      const code = await resetCodeFor(account.email);
      await databaseOf(app).execute(
        sql`UPDATE email_codes SET expires_at = now() - interval '1 second'
            WHERE user_id = (SELECT id FROM users WHERE email = ${account.email})
              AND purpose = 'password_reset'`,
      );

      await expectInvalidCode(confirm({ email: account.email, code }));
    });

    it('a code out of attempts answers INVALID_CODE, even when right', async () => {
      const account = newAccount();
      await signUpAndVerify(app, outbox, account);
      const code = await resetCodeFor(account.email);
      for (let attempt = 0; attempt < 5; attempt += 1) {
        await expectInvalidCode(
          confirm({ email: account.email, code: wrongCodeFor(code) }),
        );
      }

      await expectInvalidCode(confirm({ email: account.email, code }));
    });

    it('a used code answers INVALID_CODE the second time', async () => {
      const account = newAccount();
      await signUpAndVerify(app, outbox, account);
      const code = await resetCodeFor(account.email);
      await confirm({ email: account.email, code }).expect(200);

      await expectInvalidCode(confirm({ email: account.email, code }));
    });

    it('asking for a new code invalidates the previous one', async () => {
      const account = newAccount();
      await signUpAndVerify(app, outbox, account);
      const first = await resetCodeFor(account.email);
      const second = await resetCodeFor(account.email);
      if (first === second) return; // 1 in a million: nothing to tell apart

      await expectInvalidCode(confirm({ email: account.email, code: first }));
      await confirm({ email: account.email, code: second }).expect(200);
    });

    it('the signup code does not reset the password', async () => {
      const account = newAccount();
      await signUp(app, account);
      const signupCode = outbox.lastCodeTo(account.email, 'signup-code');
      await resetCodeFor(account.email);

      await expectInvalidCode(
        confirm({ email: account.email, code: signupCode }),
      );
    });

    it('an e-mail without an account answers INVALID_CODE', async () => {
      await expectInvalidCode(
        confirm({ email: newAccount().email, code: '123456' }),
      );
    });

    it.each([
      ['an invalid e-mail', { email: 'marina' }, 'email'],
      ['a code that is not 6 digits', { code: '12345' }, 'code'],
      [
        'a password under 8 characters',
        { newPassword: 'a'.repeat(7) },
        'newPassword',
      ],
      [
        'a password over 128 characters',
        { newPassword: 'a'.repeat(129) },
        'newPassword',
      ],
    ])('rejects %s with VALIDATION_FAILED', async (_case, change, path) => {
      const response = await confirm({
        email: 'marina@email.com',
        code: '123456',
        ...change,
      }).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [{ path }],
      });
    });
  });
});
