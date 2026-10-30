import type { INestApplication, LoggerService } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { eq, sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
import { users } from '../src/database/schema';
import { cellCenter } from '../src/profile/donation-grid';
import { createTestApp } from './support/app';
import {
  type AuthTokensBody,
  databaseOf,
  signUpAndVerify,
} from './support/auth';
import {
  donationProfile,
  putDonationProfile,
  signUpWithDonationProfile,
} from './support/donation';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import { startPostgis } from './support/postgis';

/** Keeps every log line so the test can check what would reach CloudWatch. */
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

describe('PUT /me/donation-profile', () => {
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

  function getMe(session: AuthTokensBody): request.Test {
    return request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${session.accessToken}`);
  }

  /** The point the database keeps for [session]'s User. */
  async function storedPoint(
    session: AuthTokensBody,
  ): Promise<{ lat: number; lng: number }> {
    const [row] = await databaseOf(app)
      .select({
        lat: sql<number>`ST_Y(${users.donationLocation}::geometry)`,
        lng: sql<number>`ST_X(${users.donationLocation}::geometry)`,
      })
      .from(users)
      .where(eq(users.id, session.user.id));
    if (!row) throw new Error('no such user');
    return row;
  }

  it('saves the profile and answers the body of GET /me', async () => {
    const session = await signUpAndVerify(app, outbox);

    const put = await putDonationProfile(
      app,
      session,
      donationProfile(),
    ).expect(200);

    expect(put.body).toEqual({
      ...session.user,
      phone: '+5511987654321',
      donationLocation: { neighborhood: 'Vila Mariana' },
    });
    const me = await getMe(session).expect(200);
    expect(me.body).toEqual(put.body);
  });

  it.each([
    ['only the area code and number', '11987654321'],
    ['the country code', '+5511987654321'],
    ['the country code and a mask', '+55 (11) 98765-4321'],
    ['a mask', '(11) 98765-4321'],
    ['spaces', '11 98765 4321'],
    ['the country code without +', '55 11 98765-4321'],
  ])('stores a phone with %s in E.164', async (_case, phone) => {
    const session = await signUpAndVerify(app, outbox);

    await putDonationProfile(app, session, donationProfile({ phone })).expect(
      200,
    );

    const me = await getMe(session).expect(200);
    expect(me.body).toMatchObject({ phone: '+5511987654321' });
  });

  it.each([
    ['a landline', '(11) 3333-4444'],
    ['a landline with the country code', '+55 11 3333-4444'],
    ['a mobile from another country', '+1 202 555 0123'],
    ['a number without the area code', '98765-4321'],
    ['letters', 'meu celular'],
    ['too few digits', '123'],
    ['an empty phone', ''],
  ])(
    'rejects %s with INVALID_PHONE and saves nothing',
    async (_case, phone) => {
      const session = await signUpAndVerify(app, outbox);

      const response = await putDonationProfile(
        app,
        session,
        donationProfile({ phone }),
      ).expect(400);

      expect(response.body).toMatchObject({ code: 'INVALID_PHONE' });
      const me = await getMe(session).expect(200);
      expect(me.body).toEqual(session.user);
    },
  );

  it('trims the neighborhood', async () => {
    const session = await signUpAndVerify(app, outbox);

    const put = await putDonationProfile(
      app,
      session,
      donationProfile({ neighborhood: '  Saúde  ' }),
    ).expect(200);

    expect(put.body).toMatchObject({
      donationLocation: { neighborhood: 'Saúde' },
    });
  });

  it('accepts a neighborhood of exactly 60 characters', async () => {
    const session = await signUpAndVerify(app, outbox);

    await putDonationProfile(
      app,
      session,
      donationProfile({ neighborhood: 'a'.repeat(60) }),
    ).expect(200);
  });

  it.each([
    ['an empty neighborhood', { neighborhood: '' }, 'neighborhood'],
    ['a neighborhood of only spaces', { neighborhood: '   ' }, 'neighborhood'],
    [
      'a neighborhood over 60',
      { neighborhood: 'a'.repeat(61) },
      'neighborhood',
    ],
    ['a latitude above 90', { lat: 90.0001 }, 'lat'],
    ['a latitude below -90', { lat: -91 }, 'lat'],
    ['a longitude above 180', { lng: 180.5 }, 'lng'],
    ['a longitude below -180', { lng: -181 }, 'lng'],
    ['a latitude that is text', { lat: '-23.5' }, 'lat'],
    ['a phone that is not text', { phone: 11987654321 }, 'phone'],
  ])('rejects %s with VALIDATION_FAILED', async (_case, overrides, path) => {
    const session = await signUpAndVerify(app, outbox);

    const response = await putDonationProfile(app, session, {
      ...donationProfile(),
      ...overrides,
    }).expect(400);

    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path }],
    });
    const me = await getMe(session).expect(200);
    expect(me.body).toEqual(session.user);
  });

  it.each(['phone', 'lat', 'lng', 'neighborhood'])(
    'requires the %s',
    async (field) => {
      const session = await signUpAndVerify(app, outbox);
      const body = Object.fromEntries(
        Object.entries(donationProfile()).filter(([key]) => key !== field),
      );

      const response = await putDonationProfile(app, session, body).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [{ path: field }],
      });
    },
  );

  it('stores the center of the ~1 km cell, never the exact point', async () => {
    const exact = { lat: -23.587412, lng: -46.634567 };
    const session = await signUpWithDonationProfile(app, outbox, exact);

    const stored = await storedPoint(session);

    const center = cellCenter(exact);
    expect(stored.lat).toBeCloseTo(center.lat, 9);
    expect(stored.lng).toBeCloseTo(center.lng, 9);
    expect(stored.lat).not.toBeCloseTo(exact.lat, 6);
  });

  it('stores the same point for two points in the same cell', async () => {
    const center = cellCenter({ lat: -23.5874, lng: -46.6345 });
    const marina = await signUpWithDonationProfile(app, outbox, {
      lat: center.lat + 0.002,
      lng: center.lng - 0.002,
    });
    const joao = await signUpWithDonationProfile(app, outbox, {
      lat: center.lat - 0.002,
      lng: center.lng + 0.002,
    });

    expect(await storedPoint(marina)).toEqual(await storedPoint(joao));
  });

  it('never answers or logs the coordinates', async () => {
    const session = await signUpAndVerify(app, outbox);
    const exact = { lat: -23.581234, lng: -46.639876 };

    const put = await putDonationProfile(
      app,
      session,
      donationProfile(exact),
    ).expect(200);
    const me = await getMe(session).expect(200);

    for (const body of [put.body, me.body]) {
      expect(JSON.stringify(body)).not.toMatch(/-?23\.5|-?46\.6/);
    }
    const everything = logger.lines.join('\n');
    expect(everything).not.toContain('23.581234');
    expect(everything).not.toContain('46.639876');
  });

  it('replaces a previous profile', async () => {
    const session = await signUpWithDonationProfile(app, outbox);
    const before = await storedPoint(session);

    const put = await putDonationProfile(
      app,
      session,
      donationProfile({
        phone: '21 99876-5432',
        lat: -22.9711,
        lng: -43.1822,
        neighborhood: 'Copacabana',
      }),
    ).expect(200);

    expect(put.body).toMatchObject({
      phone: '+5521998765432',
      donationLocation: { neighborhood: 'Copacabana' },
    });
    expect(await storedPoint(session)).not.toEqual(before);
  });

  it('only changes the signed-in User', async () => {
    const marina = await signUpAndVerify(app, outbox);
    const joao = await signUpAndVerify(app, outbox);

    await putDonationProfile(app, marina, donationProfile()).expect(200);

    const me = await getMe(joao).expect(200);
    expect(me.body).toEqual(joao.user);
  });

  it('without a token answers 401 UNAUTHENTICATED', async () => {
    const response = await request(app.getHttpServer())
      .put('/v1/me/donation-profile')
      .send(donationProfile())
      .expect(401);
    expect(response.body).toMatchObject({ code: 'UNAUTHENTICATED' });
  });
});
