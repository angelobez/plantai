import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import type { GoogleIdentity } from '../src/auth/google/google-token-verifier';
import { createTestApp } from './support/app';
import {
  type AuthTokensBody,
  newAccount,
  signUp,
  signUpAndVerify,
} from './support/auth';
import { testEnv } from './support/env';
import {
  FakeGoogleVerifier,
  googleIdentity,
} from './support/fake-google-verifier';
import { FakeOutbox } from './support/fake-outbox';
import { startPostgis } from './support/postgis';

describe('sign in with Google', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const google = new FakeGoogleVerifier();

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      googleVerifier: google,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  function signInWithToken(idToken: string): request.Test {
    return request(app.getHttpServer())
      .post('/v1/auth/google')
      .send({ idToken });
  }

  function signInWithGoogle(identity: GoogleIdentity): request.Test {
    return signInWithToken(google.tokenFor(identity));
  }

  async function signedIn(identity: GoogleIdentity): Promise<AuthTokensBody> {
    const response = await signInWithGoogle(identity).expect(200);
    return response.body as AuthTokensBody;
  }

  async function expectProblem(
    response: request.Test,
    status: number,
    code: string,
  ): Promise<void> {
    const answer = await response
      .expect(status)
      .expect('Content-Type', /^application\/problem\+json/);
    expect(answer.body).toMatchObject({ code });
  }

  async function me(accessToken: string): Promise<AuthTokensBody['user']> {
    const response = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    return response.body as AuthTokensBody['user'];
  }

  it('creates a confirmed account with the name from Google and reads /me', async () => {
    const identity = googleIdentity({ name: 'Joana Lima' });

    const body = await signedIn(identity);

    expect(body).toEqual({
      accessToken: expect.any(String) as unknown,
      refreshToken: expect.any(String) as unknown,
      user: {
        id: expect.stringMatching(/^[0-9a-f-]{36}$/) as unknown,
        name: 'Joana Lima',
        email: identity.email,
        phone: null,
        donationLocation: null,
      },
    });
    expect(await me(body.accessToken)).toEqual(body.user);

    // Confirmed: signing up with the e-mail now gets "you already have an account".
    await signUp(app, newAccount({ email: identity.email }));
    expect(outbox.lastTo(identity.email).template).toBe('account-exists');
  });

  it('names the account after the e-mail when Google sends no name', async () => {
    const identity = googleIdentity({
      name: undefined,
      email: `joana.lima${String(Date.now())}@gmail.com`,
    });

    const body = await signedIn(identity);

    expect(body.user.name).toBe(identity.email.split('@')[0]);
  });

  it('signing in again with the same sub enters the same account', async () => {
    const identity = googleIdentity();
    const first = await signedIn(identity);

    const again = await signedIn(identity);

    expect(again.user.id).toBe(first.user.id);
    expect(again.refreshToken).not.toBe(first.refreshToken);
  });

  it('finds the account by sub even after the e-mail changes at Google', async () => {
    const identity = googleIdentity();
    const first = await signedIn(identity);

    const again = await signedIn({
      ...identity,
      email: `outro${String(Date.now())}@gmail.com`,
    });

    expect(again.user).toEqual(first.user);
  });

  it('joins a confirmed @gmail.com account made with a password', async () => {
    const account = newAccount({
      name: 'Marina Souza',
      email: `marina${String(Date.now())}@gmail.com`,
    });
    const withPassword = await signUpAndVerify(app, outbox, account);

    const body = await signedIn(
      googleIdentity({ email: account.email, name: 'Marina S.' }),
    );

    expect(body.user).toEqual(withPassword.user);
    // The account keeps its password, so both ways in work.
    await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email: account.email, password: account.password })
      .expect(200);
  });

  it('joins a confirmed account when the token has hd (Google Workspace)', async () => {
    const account = newAccount({
      email: `marina${String(Date.now())}@empresa.com.br`,
    });
    const withPassword = await signUpAndVerify(app, outbox, account);

    const body = await signedIn(
      googleIdentity({ email: account.email, hd: 'empresa.com.br' }),
    );

    expect(body.user.id).toBe(withPassword.user.id);
  });

  it('after joining, signs in by sub', async () => {
    const account = newAccount({
      email: `marina${String(Date.now())}@gmail.com`,
    });
    const withPassword = await signUpAndVerify(app, outbox, account);
    const identity = googleIdentity({ email: account.email });
    await signedIn(identity);

    const again = await signedIn({ ...identity, email: 'mudou@gmail.com' });

    expect(again.user.id).toBe(withPassword.user.id);
  });

  it('refuses to join an account without the guarantee (not @gmail.com, no hd)', async () => {
    const account = newAccount({
      email: `marina${String(Date.now())}@email.com`,
    });
    await signUpAndVerify(app, outbox, account);

    await expectProblem(
      signInWithGoogle(googleIdentity({ email: account.email })),
      409,
      'GOOGLE_ACCOUNT_LINK_REFUSED',
    );
  });

  it('refuses to join an account already joined to another Google account', async () => {
    const identity = googleIdentity();
    await signedIn(identity);

    await expectProblem(
      signInWithGoogle(googleIdentity({ email: identity.email })),
      409,
      'GOOGLE_ACCOUNT_LINK_REFUSED',
    );
  });

  it('takes over an account never confirmed, dropping the pending password', async () => {
    const intruder = newAccount({
      name: 'Intruso',
      email: `vitima${String(Date.now())}@gmail.com`,
      password: 'senha-do-intruso',
    });
    await signUp(app, intruder);
    const pendingCode = outbox.lastCodeTo(intruder.email, 'signup-code');

    const body = await signedIn(
      googleIdentity({ email: intruder.email, name: 'Vítima Dona' }),
    );

    expect(body.user).toMatchObject({
      name: 'Vítima Dona',
      email: intruder.email,
    });
    // The old password stops working: there is none any more.
    await expectProblem(
      request(app.getHttpServer())
        .post('/v1/auth/login')
        .send({ email: intruder.email, password: intruder.password }),
      401,
      'INVALID_CREDENTIALS',
    );
    // The pending sign-up code no longer opens the account either.
    const verify = await request(app.getHttpServer())
      .post('/v1/auth/verify-email')
      .send({ email: intruder.email, code: pendingCode })
      .expect(400);
    expect(verify.body).toMatchObject({ code: 'INVALID_CODE' });
    // And the account is now confirmed.
    await signUp(app, intruder);
    expect(outbox.lastTo(intruder.email).template).toBe('account-exists');
  });

  it('refuses a token whose e-mail Google has not verified', async () => {
    await expectProblem(
      signInWithGoogle(googleIdentity({ emailVerified: false })),
      409,
      'GOOGLE_ACCOUNT_LINK_REFUSED',
    );
  });

  it('answers INVALID_CREDENTIALS to an invalid token', async () => {
    await expectProblem(
      signInWithToken('not-a-google-token'),
      401,
      'INVALID_CREDENTIALS',
    );
  });

  it('rejects a missing idToken with VALIDATION_FAILED', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/auth/google')
      .send({})
      .expect(400);
    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path: 'idToken' }],
    });
  });
});
