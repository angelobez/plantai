import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
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

describe('sign-up with an e-mail code', () => {
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

  function verify(email: string, code: string): request.Test {
    return request(app.getHttpServer())
      .post('/v1/auth/verify-email')
      .send({ email, code });
  }

  /** Any code but [code]: the next one, wrapping at 999999. */
  function wrong(code: string): string {
    return String((Number(code) + 1) % 1_000_000).padStart(6, '0');
  }

  async function expectInvalidCode(response: request.Test): Promise<void> {
    const answer = await response
      .expect(400)
      .expect('Content-Type', /^application\/problem\+json/);
    expect(answer.body).toMatchObject({ code: 'INVALID_CODE' });
  }

  it('signs up, confirms the code from the e-mail and reads /me with the token', async () => {
    const account = newAccount({ name: 'Marina Souza' });

    const signup = await request(app.getHttpServer())
      .post('/v1/auth/signup')
      .send(account)
      .expect(202);
    expect(signup.text).toBe('');

    const email = outbox.lastTo(account.email);
    expect(email.template).toBe('signup-code');
    expect(email.subject).toMatch(/código/i);
    const code = outbox.lastCodeTo(account.email);
    expect(code).toMatch(/^\d{6}$/);

    const verified = await verify(account.email, code).expect(200);
    const body = verified.body as AuthTokensBody;
    expect(body).toEqual({
      accessToken: expect.any(String) as unknown,
      refreshToken: expect.any(String) as unknown,
      user: {
        id: expect.stringMatching(/^[0-9a-f-]{36}$/) as unknown,
        name: 'Marina Souza',
        email: account.email,
        phone: null,
        donationLocation: null,
      },
    });

    const me = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${body.accessToken}`)
      .expect(200);
    expect(me.body).toEqual(body.user);
  });

  it('a code works only once', async () => {
    const account = newAccount();
    await signUp(app, account);
    const code = outbox.lastCodeTo(account.email);
    await verify(account.email, code).expect(200);

    await expectInvalidCode(verify(account.email, code));
  });

  it('answers the same 202 for a new, an unconfirmed and a confirmed e-mail', async () => {
    const fresh = newAccount();
    const confirmed = newAccount();
    await signUpAndVerify(app, outbox, confirmed);
    const unconfirmed = newAccount();
    await signUp(app, unconfirmed);

    for (const account of [fresh, unconfirmed, confirmed]) {
      const response = await request(app.getHttpServer())
        .post('/v1/auth/signup')
        .send(account)
        .expect(202);
      expect(response.text).toBe('');
    }
  });

  it('signing up again before confirming takes the new name and password and sends a new code', async () => {
    const first = newAccount({ name: 'Marina', password: 'primeira-senha' });
    await signUp(app, first);

    await signUp(app, {
      ...first,
      name: 'Marina Souza',
      password: 'nova-senha-1',
    });
    const newCode = outbox.lastCodeTo(first.email);
    expect(outbox.sentTo(first.email)).toHaveLength(2);

    const answer = await verify(first.email, newCode).expect(200);
    expect((answer.body as AuthTokensBody).user.name).toBe('Marina Souza');

    const [row] = await databaseOf(app).execute<{ ok: boolean }>(
      sql`SELECT password_hash IS NOT NULL AS ok FROM users WHERE email = ${first.email}`,
    );
    expect(row?.ok).toBe(true);
  });

  it('a confirmed e-mail gets the "you already have an account" e-mail and keeps its password', async () => {
    const account = newAccount();
    await signUpAndVerify(app, outbox, account);
    const [before] = await databaseOf(app).execute<{
      hash: string;
      name: string;
    }>(
      sql`SELECT password_hash AS hash, name FROM users WHERE email = ${account.email}`,
    );

    await signUp(app, {
      ...account,
      name: 'Outra Pessoa',
      password: 'senha-do-intruso',
    });

    const email = outbox.lastTo(account.email);
    expect(email.template).toBe('account-exists');
    expect(email.text).toMatch(/Esqueci a senha/);
    expect(email.text).not.toMatch(/\b\d{6}\b/);
    const [after] = await databaseOf(app).execute<{
      hash: string;
      name: string;
    }>(
      sql`SELECT password_hash AS hash, name FROM users WHERE email = ${account.email}`,
    );
    expect(after).toEqual(before);
  });

  it('treats the e-mail case-insensitively', async () => {
    const account = newAccount();
    await signUpAndVerify(app, outbox, account);

    await signUp(app, { ...account, email: account.email.toUpperCase() });

    expect(outbox.lastTo(account.email.toUpperCase()).template).toBe(
      'account-exists',
    );
  });

  it('a wrong code counts an attempt; on the sixth, even the right code fails', async () => {
    const account = newAccount();
    await signUp(app, account);
    const code = outbox.lastCodeTo(account.email);

    for (let attempt = 1; attempt <= 5; attempt += 1) {
      await expectInvalidCode(verify(account.email, wrong(code)));
    }
    await expectInvalidCode(verify(account.email, code));
  });

  it('the right code still works after four wrong ones', async () => {
    const account = newAccount();
    await signUp(app, account);
    const code = outbox.lastCodeTo(account.email);

    for (let attempt = 1; attempt <= 4; attempt += 1) {
      await expectInvalidCode(verify(account.email, wrong(code)));
    }
    await verify(account.email, code).expect(200);
  });

  it('an expired code fails', async () => {
    const account = newAccount();
    await signUp(app, account);
    const code = outbox.lastCodeTo(account.email);
    await databaseOf(app).execute(
      sql`UPDATE email_codes SET expires_at = now() - interval '1 second'
          WHERE user_id = (SELECT id FROM users WHERE email = ${account.email})`,
    );

    await expectInvalidCode(verify(account.email, code));
  });

  it('a code expires 15 minutes after it is sent', async () => {
    const account = newAccount();
    await signUp(app, account);

    const [row] = await databaseOf(app).execute<{ minutes: number }>(
      sql`SELECT round(extract(epoch FROM expires_at - created_at) / 60)::int AS minutes
          FROM email_codes
          WHERE user_id = (SELECT id FROM users WHERE email = ${account.email})`,
    );
    expect(row?.minutes).toBe(15);
  });

  it('asking for a new code (signing up again) invalidates the previous one', async () => {
    const account = newAccount();
    await signUp(app, account);
    const first = outbox.lastCodeTo(account.email);
    // Keep asking until the new code differs, so the test cannot pass by luck.
    let second = first;
    while (second === first) {
      await signUp(app, account);
      second = outbox.lastCodeTo(account.email);
    }

    await expectInvalidCode(verify(account.email, first));
    await verify(account.email, second).expect(200);
  });

  it('a code for an e-mail without an account fails the same way', async () => {
    await expectInvalidCode(verify('ninguem@email.com', '123456'));
  });

  it.each([
    ['a short password', { password: '1234567' }, 'password'],
    [
      'a password over 128 characters',
      { password: 'a'.repeat(129) },
      'password',
    ],
    ['an invalid e-mail', { email: 'marina' }, 'email'],
    ['an empty name', { name: '   ' }, 'name'],
    ['a name over 80 characters', { name: 'a'.repeat(81) }, 'name'],
  ])('rejects %s with VALIDATION_FAILED', async (_case, change, path) => {
    const response = await request(app.getHttpServer())
      .post('/v1/auth/signup')
      .send({ ...newAccount(), ...change })
      .expect(400);

    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path }],
    });
  });

  it('accepts a password of exactly 8 characters, with no composition rule', async () => {
    await request(app.getHttpServer())
      .post('/v1/auth/signup')
      .send(newAccount({ password: 'abcdefgh' }))
      .expect(202);
  });

  it('rejects a code that is not 6 digits with VALIDATION_FAILED', async () => {
    const response = await verify('marina@email.com', '12345').expect(400);
    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path: 'code' }],
    });
  });
});
