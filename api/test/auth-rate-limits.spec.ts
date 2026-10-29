import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import { newAccount } from './support/auth';
import { testEnv } from './support/env';
import { startPostgis } from './support/postgis';

describe('auth rate limits', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;

  beforeAll(async () => {
    container = await startPostgis();
  });

  // A new app per test: each one starts with empty buckets.
  beforeEach(async () => {
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      realRateLimits: true,
    });
  });

  afterEach(async () => {
    await app.close();
  });

  afterAll(async () => {
    await container.stop();
  });

  function post(path: string, body: object): request.Test {
    return request(app.getHttpServer()).post(`/v1/auth/${path}`).send(body);
  }

  async function expectTooManyRequests(response: request.Test): Promise<void> {
    const answer = await response
      .expect(429)
      .expect('Content-Type', /^application\/problem\+json/);
    expect(answer.body).toMatchObject({
      status: 429,
      code: 'TOO_MANY_REQUESTS',
    });
  }

  const logIn = (email: string): request.Test =>
    post('login', { email, password: 'senha-errada-1' });

  it('the sixth login for the same e-mail answers TOO_MANY_REQUESTS', async () => {
    const { email } = newAccount();
    for (let attempt = 1; attempt <= 5; attempt++) {
      await logIn(email).expect(401);
    }

    await expectTooManyRequests(logIn(email));
  });

  it('counts the e-mail whatever its case', async () => {
    const { email } = newAccount();
    for (let attempt = 1; attempt <= 5; attempt++) {
      await logIn(email).expect(401);
    }

    await expectTooManyRequests(logIn(email.toUpperCase()));
  });

  it('the limit of one e-mail does not block another e-mail', async () => {
    const blocked = newAccount().email;
    for (let attempt = 1; attempt <= 6; attempt++) {
      await logIn(blocked);
    }

    await logIn(newAccount().email).expect(401);
  });

  it('verify-email and password-reset/confirm allow 5 per e-mail', async () => {
    const { email } = newAccount();
    const attempts = [
      ['verify-email', { email, code: '000000' }],
      [
        'password-reset/confirm',
        { email, code: '000000', newPassword: 'senha-nova-123' },
      ],
    ] as const;
    for (const [path, body] of attempts) {
      for (let attempt = 1; attempt <= 5; attempt++) {
        await post(path, body).expect(400);
      }
      await expectTooManyRequests(post(path, body));
    }
  });

  it('signup and password-reset/request allow 3 per e-mail', async () => {
    const account = newAccount();
    const attempts = [
      ['signup', account, 202],
      ['password-reset/request', { email: account.email }, 204],
    ] as const;
    for (const [path, body, status] of attempts) {
      for (let attempt = 1; attempt <= 3; attempt++) {
        await post(path, body).expect(status);
      }
      await expectTooManyRequests(post(path, body));
    }
  });

  it('allows 20 requests per minute from one IP across /auth', async () => {
    const requests = [
      () => logIn(newAccount().email),
      () => post('refresh', { refreshToken: 'not-a-token' }),
      () => post('logout', { refreshToken: 'not-a-token' }),
      () => post('google', { idToken: 'not-a-token' }),
    ];
    for (let attempt = 0; attempt < 20; attempt++) {
      const send = requests[attempt % requests.length];
      if (send === undefined) throw new Error('unreachable');
      const response = await send();
      expect(response.status).not.toBe(429);
    }

    await expectTooManyRequests(post('refresh', { refreshToken: 'x' }));
  });

  it('does not limit routes outside /auth', async () => {
    for (let attempt = 0; attempt < 25; attempt++) {
      await request(app.getHttpServer()).get('/v1/health').expect(200);
    }
  });
});
