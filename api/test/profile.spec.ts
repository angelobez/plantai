import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import { type AuthTokensBody, signUpAndVerify } from './support/auth';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import { startPostgis } from './support/postgis';

describe('PATCH /me', () => {
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

  function patchMe(session: AuthTokensBody, body: object): request.Test {
    return request(app.getHttpServer())
      .patch('/v1/me')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send(body);
  }

  function getMe(session: AuthTokensBody): request.Test {
    return request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${session.accessToken}`);
  }

  it('changes the name, answers the profile and GET /me shows it', async () => {
    const session = await signUpAndVerify(app, outbox);

    const patched = await patchMe(session, { name: 'Marina S.' }).expect(200);
    expect(patched.body).toEqual({ ...session.user, name: 'Marina S.' });

    const me = await getMe(session).expect(200);
    expect(me.body).toEqual(patched.body);
  });

  it('trims the spaces around the name', async () => {
    const session = await signUpAndVerify(app, outbox);

    const patched = await patchMe(session, { name: '  Marina  ' }).expect(200);
    expect((patched.body as AuthTokensBody['user']).name).toBe('Marina');
  });

  it('accepts a name of exactly 80 characters', async () => {
    const session = await signUpAndVerify(app, outbox);

    await patchMe(session, { name: 'a'.repeat(80) }).expect(200);
  });

  it.each([
    ['an empty name', { name: '' }],
    ['a name of only spaces', { name: '   ' }],
    ['a name over 80 characters', { name: 'a'.repeat(81) }],
    ['no name', {}],
    ['a name that is not text', { name: 42 }],
  ])('rejects %s with VALIDATION_FAILED', async (_case, body) => {
    const session = await signUpAndVerify(app, outbox);

    const response = await patchMe(session, body).expect(400);
    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path: 'name' }],
    });
    const me = await getMe(session).expect(200);
    expect(me.body).toEqual(session.user);
  });

  it('only changes the signed-in User', async () => {
    const marina = await signUpAndVerify(app, outbox);
    const joao = await signUpAndVerify(app, outbox);

    await patchMe(marina, { name: 'Marina S.' }).expect(200);

    const me = await getMe(joao).expect(200);
    expect(me.body).toEqual(joao.user);
  });

  it('without a token answers 401 UNAUTHENTICATED', async () => {
    const response = await request(app.getHttpServer())
      .patch('/v1/me')
      .send({ name: 'Marina' })
      .expect(401);
    expect(response.body).toMatchObject({ code: 'UNAUTHENTICATED' });
  });
});
