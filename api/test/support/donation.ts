import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import type { App } from 'supertest/types';
import {
  type AuthTokensBody,
  newAccount,
  type NewAccount,
  signUpAndVerify,
} from './auth';
import type { FakeOutbox } from './fake-outbox';

/** The body of `PUT /v1/me/donation-profile`. */
export interface DonationProfileBody {
  phone: string;
  lat: number;
  lng: number;
  neighborhood: string;
}

/** A valid donation profile in Vila Mariana, São Paulo. */
export function donationProfile(
  overrides: Partial<DonationProfileBody> = {},
): DonationProfileBody {
  return {
    phone: '11987654321',
    lat: -23.5874,
    lng: -46.6345,
    neighborhood: 'Vila Mariana',
    ...overrides,
  };
}

/** `PUT /v1/me/donation-profile` as [session], without checking the answer. */
export function putDonationProfile(
  app: INestApplication<App>,
  session: AuthTokensBody,
  body: object,
): request.Test {
  return request(app.getHttpServer())
    .put('/v1/me/donation-profile')
    .set('Authorization', `Bearer ${session.accessToken}`)
    .send(body);
}

/**
 * A signed-in User whose donation profile is set at the given point (Vila
 * Mariana by default), ready to publish listings. `user` is the profile the
 * `PUT` answered.
 */
export async function signUpWithDonationProfile(
  app: INestApplication<App>,
  outbox: FakeOutbox,
  profile: Partial<DonationProfileBody> = {},
  account: NewAccount = newAccount(),
): Promise<AuthTokensBody> {
  const session = await signUpAndVerify(app, outbox, account);
  const response = await putDonationProfile(
    app,
    session,
    donationProfile(profile),
  ).expect(200);
  return { ...session, user: response.body as AuthTokensBody['user'] };
}
