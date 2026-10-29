import { Controller, Get, type INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import jwt from 'jsonwebtoken';
import request from 'supertest';
import type { App } from 'supertest/types';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../src/auth/current-user.decorator';
import { Public } from '../src/auth/public.decorator';
import { createTestApp } from './support/app';
import { type AuthTokensBody, signUpAndVerify } from './support/auth';
import { TEST_JWT_SECRET, testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import { startPostgis } from './support/postgis';

/** Registered only in the test module, to show the guard on a new route. */
@Controller('test-protected')
class ProtectedProbeController {
  @Get()
  whoAmI(@CurrentUser() user: AuthenticatedUser): AuthenticatedUser {
    return user;
  }

  @Public()
  @Get('open')
  open(): { ok: true } {
    return { ok: true };
  }
}

describe('protected routes', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  let session: AuthTokensBody;

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      controllers: [ProtectedProbeController],
    });
    session = await signUpAndVerify(app, outbox);
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  async function expectUnauthenticated(response: request.Test): Promise<void> {
    const answer = await response
      .expect(401)
      .expect('Content-Type', /^application\/problem\+json/);
    expect(answer.body).toEqual({
      type: 'about:blank',
      title: 'Unauthorized',
      status: 401,
      code: 'UNAUTHENTICATED',
    });
  }

  describe.each(['/v1/me', '/v1/test-protected'])('%s', (path) => {
    it('without a token answers 401 UNAUTHENTICATED', async () => {
      await expectUnauthenticated(request(app.getHttpServer()).get(path));
    });

    it('with a malformed token answers 401 UNAUTHENTICATED', async () => {
      await expectUnauthenticated(
        request(app.getHttpServer())
          .get(path)
          .set('Authorization', 'Bearer not-a-jwt'),
      );
    });

    it('with another scheme answers 401 UNAUTHENTICATED', async () => {
      await expectUnauthenticated(
        request(app.getHttpServer())
          .get(path)
          .set('Authorization', `Basic ${session.accessToken}`),
      );
    });

    it('with a token signed by another secret answers 401 UNAUTHENTICATED', async () => {
      const forged = jwt.sign({}, 'another-secret-that-is-32-characters-long', {
        algorithm: 'HS256',
        subject: session.user.id,
        expiresIn: '15m',
      });
      await expectUnauthenticated(
        request(app.getHttpServer())
          .get(path)
          .set('Authorization', `Bearer ${forged}`),
      );
    });

    it('with an expired token answers 401 UNAUTHENTICATED', async () => {
      const issuedAt = Math.floor(Date.now() / 1000) - 16 * 60;
      const expired = jwt.sign({ iat: issuedAt }, TEST_JWT_SECRET, {
        algorithm: 'HS256',
        subject: session.user.id,
        expiresIn: '15m',
      });
      await expectUnauthenticated(
        request(app.getHttpServer())
          .get(path)
          .set('Authorization', `Bearer ${expired}`),
      );
    });
  });

  it('an unsigned token ("alg": "none") is refused', async () => {
    const unsigned = jwt.sign({ sub: session.user.id }, '', {
      algorithm: 'none',
    });
    await expectUnauthenticated(
      request(app.getHttpServer())
        .get('/v1/me')
        .set('Authorization', `Bearer ${unsigned}`),
    );
  });

  it('hands the authenticated User to the controller', async () => {
    await request(app.getHttpServer())
      .get('/v1/test-protected')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(200, { id: session.user.id });
  });

  it('the access token lasts 15 minutes', () => {
    const payload = jwt.decode(session.accessToken) as jwt.JwtPayload;
    expect(payload.sub).toBe(session.user.id);
    expect((payload.exp ?? 0) - (payload.iat ?? 0)).toBe(15 * 60);
  });

  it('a route marked @Public() needs no token', async () => {
    await request(app.getHttpServer())
      .get('/v1/test-protected/open')
      .expect(200, { ok: true });
  });

  it('/health stays public', async () => {
    await request(app.getHttpServer()).get('/v1/health').expect(200);
  });

  it('/docs stays public', async () => {
    await request(app.getHttpServer()).get('/docs/openapi.json').expect(200);
  });

  it('an unknown route still answers 404 NOT_FOUND, not 401', async () => {
    const answer = await request(app.getHttpServer())
      .get('/v1/does-not-exist')
      .expect(404);
    expect(answer.body).toMatchObject({ code: 'NOT_FOUND' });
  });
});
