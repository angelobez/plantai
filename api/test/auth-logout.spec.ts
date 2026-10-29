import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
import { hashOpaqueToken } from '../src/auth/secrets';
import { createTestApp } from './support/app';
import { databaseOf, signUpAndVerify } from './support/auth';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import { startPostgis } from './support/postgis';

describe('POST /auth/logout', () => {
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

  function logout(body: object): request.Test {
    return request(app.getHttpServer()).post('/v1/auth/logout').send(body);
  }

  // Until `POST /auth/refresh` exists (#40), the revocation is read from the
  // database; once it does, "refresh with it answers UNAUTHENTICATED" is the
  // front-door check.
  async function revokedAt(token: string): Promise<string | null | undefined> {
    const [row] = await databaseOf(app).execute<{ at: string | null }>(
      sql`SELECT revoked_at::text AS at FROM refresh_tokens
          WHERE token_hash = ${hashOpaqueToken(token)}`,
    );
    return row?.at;
  }

  it('revokes the refresh token and answers 204 without a body, with no access token', async () => {
    const session = await signUpAndVerify(app, outbox);
    expect(await revokedAt(session.refreshToken)).toBeNull();

    const response = await logout({
      refreshToken: session.refreshToken,
    }).expect(204);

    expect(response.text).toBe('');
    expect(await revokedAt(session.refreshToken)).toEqual(expect.any(String));
  });

  it('only revokes the given token, not the other sessions', async () => {
    const session = await signUpAndVerify(app, outbox);
    const other = await signUpAndVerify(app, outbox);

    await logout({ refreshToken: session.refreshToken }).expect(204);

    expect(await revokedAt(other.refreshToken)).toBeNull();
  });

  it('answers 204 again for a token already revoked, keeping the first revocation', async () => {
    const session = await signUpAndVerify(app, outbox);
    await logout({ refreshToken: session.refreshToken }).expect(204);
    const first = await revokedAt(session.refreshToken);

    await logout({ refreshToken: session.refreshToken }).expect(204);

    expect(await revokedAt(session.refreshToken)).toBe(first);
  });

  it('answers 204 for an expired token', async () => {
    const session = await signUpAndVerify(app, outbox);
    await databaseOf(app).execute(
      sql`UPDATE refresh_tokens SET expires_at = now() - interval '1 second'
          WHERE token_hash = ${hashOpaqueToken(session.refreshToken)}`,
    );

    await logout({ refreshToken: session.refreshToken }).expect(204);
  });

  it('answers 204 for a token it never issued', async () => {
    await logout({ refreshToken: 'nunca-emitido' }).expect(204);
  });

  it('the access token is not a refresh token: logging out with it revokes nothing', async () => {
    const session = await signUpAndVerify(app, outbox);

    await logout({ refreshToken: session.accessToken }).expect(204);

    expect(await revokedAt(session.refreshToken)).toBeNull();
  });

  it.each([
    ['no refresh token', {}],
    ['an empty refresh token', { refreshToken: '' }],
    ['a refresh token that is not text', { refreshToken: 42 }],
  ])('rejects %s with VALIDATION_FAILED', async (_case, body) => {
    const response = await logout(body).expect(400);
    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path: 'refreshToken' }],
    });
  });
});
