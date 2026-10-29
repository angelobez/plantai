import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { eq, sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
import { refreshTokens } from '../src/database/schema';
import { hashOpaqueToken } from '../src/auth/secrets';
import { Sessions } from '../src/auth/sessions';
import { Users } from '../src/users/users';
import { createTestApp } from './support/app';
import {
  type AuthTokensBody,
  databaseOf,
  signUpAndVerify,
} from './support/auth';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import { startPostgis } from './support/postgis';

describe('renewing the session with a refresh token', () => {
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

  function refresh(refreshToken: unknown): request.Test {
    return request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken });
  }

  async function expectUnauthenticated(response: request.Test): Promise<void> {
    const answer = await response
      .expect(401)
      .expect('Content-Type', /^application\/problem\+json/);
    expect(answer.body).toMatchObject({ code: 'UNAUTHENTICATED' });
  }

  async function familyOf(refreshToken: string): Promise<string> {
    const [row] = await databaseOf(app)
      .select({ familyId: refreshTokens.familyId })
      .from(refreshTokens)
      .where(eq(refreshTokens.tokenHash, hashOpaqueToken(refreshToken)));
    if (!row) throw new Error('refresh token not stored');
    return row.familyId;
  }

  it('answers a new pair of the same family, and the new access token reads /me', async () => {
    const session = await signUpAndVerify(app, outbox);

    const renewed = await refresh(session.refreshToken).expect(200);
    const body = renewed.body as AuthTokensBody;

    expect(body.user).toEqual(session.user);
    expect(body.refreshToken).not.toBe(session.refreshToken);
    expect(await familyOf(body.refreshToken)).toBe(
      await familyOf(session.refreshToken),
    );
    await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${body.accessToken}`)
      .expect(200);
  });

  it('chains: the renewed token renews again', async () => {
    const session = await signUpAndVerify(app, outbox);

    const first = (await refresh(session.refreshToken).expect(200))
      .body as AuthTokensBody;
    await refresh(first.refreshToken).expect(200);
  });

  it('a reused token revokes the whole family, the new token included', async () => {
    const session = await signUpAndVerify(app, outbox);
    const renewed = (await refresh(session.refreshToken).expect(200))
      .body as AuthTokensBody;

    await expectUnauthenticated(refresh(session.refreshToken));
    await expectUnauthenticated(refresh(renewed.refreshToken));
  });

  it('a reuse does not touch the other sessions of the same User', async () => {
    const session = await signUpAndVerify(app, outbox);
    const renewed = (await refresh(session.refreshToken).expect(200))
      .body as AuthTokensBody;
    const user = await app.get(Users).findById(session.user.id);
    if (!user) throw new Error('user not found');
    const other = await app.get(Sessions).start(user);

    await expectUnauthenticated(refresh(session.refreshToken));

    await expectUnauthenticated(refresh(renewed.refreshToken));
    await refresh(other.refreshToken).expect(200);
  });

  it('an expired token answers UNAUTHENTICATED', async () => {
    const session = await signUpAndVerify(app, outbox);
    await databaseOf(app)
      .update(refreshTokens)
      .set({ expiresAt: sql`now() - interval '1 second'` })
      .where(
        eq(refreshTokens.tokenHash, hashOpaqueToken(session.refreshToken)),
      );

    await expectUnauthenticated(refresh(session.refreshToken));
  });

  it('a new token lasts 30 days', async () => {
    const session = await signUpAndVerify(app, outbox);
    const renewed = (await refresh(session.refreshToken).expect(200))
      .body as AuthTokensBody;

    const [row] = await databaseOf(app)
      .select({
        days: sql<number>`round(extract(epoch from ${refreshTokens.expiresAt} - now()) / 86400)::int`,
      })
      .from(refreshTokens)
      .where(
        eq(refreshTokens.tokenHash, hashOpaqueToken(renewed.refreshToken)),
      );
    expect(row?.days).toBe(30);
  });

  it('an unknown token answers UNAUTHENTICATED', async () => {
    await expectUnauthenticated(refresh('not-a-token-we-issued'));
  });

  it('a missing token answers VALIDATION_FAILED', async () => {
    const answer = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({})
      .expect(400);
    expect(answer.body).toMatchObject({ code: 'VALIDATION_FAILED' });
  });

  it('two refreshes racing with the same token renew only once', async () => {
    const session = await signUpAndVerify(app, outbox);

    const answers = await Promise.all([
      refresh(session.refreshToken),
      refresh(session.refreshToken),
    ]);

    expect(answers.map((answer) => answer.status).sort()).toEqual([200, 401]);
  });
});
