import type { INestApplication } from '@nestjs/common';
import { eq, sql } from 'drizzle-orm';
import sharp from 'sharp';
import request from 'supertest';
import type { App } from 'supertest/types';
import { listings } from '../../src/database/schema';
import { type AuthTokensBody, databaseOf } from './auth';

export interface PhotoBody {
  id: string;
  url: string;
  expiresAt: string;
}

/** One listing of `GET /v1/me/listings`, and the answer of `POST`. */
export interface MyListingBody {
  id: string;
  commonName: string;
  photo: PhotoBody;
  status: 'active' | 'donated' | 'closed';
  quantity: number;
  note: string | null;
  interestCount: number;
  expiresAt: string;
  canRenew: boolean;
}

/** `POST /v1/photos` with a small generated JPEG, expecting the `201`. */
export async function uploadPhoto(
  app: INestApplication<App>,
  session: AuthTokensBody,
): Promise<PhotoBody> {
  const jpeg = await sharp({
    create: { width: 30, height: 20, channels: 3, background: '#3F6B4A' },
  })
    .jpeg()
    .toBuffer();
  const response = await request(app.getHttpServer())
    .post('/v1/photos')
    .set('Authorization', `Bearer ${session.accessToken}`)
    .attach('file', jpeg, 'muda.jpg')
    .expect(201);
  return response.body as PhotoBody;
}

/** The storage key behind a photo the API answered with. */
export function keyOf(photo: PhotoBody): string {
  return new URL(photo.url).pathname.slice(1);
}

/** `POST /v1/listings` as [session], without checking the answer. */
export function createListing(
  app: INestApplication<App>,
  session: AuthTokensBody,
  body: object,
): request.Test {
  return request(app.getHttpServer())
    .post('/v1/listings')
    .set('Authorization', `Bearer ${session.accessToken}`)
    .send(body);
}

/**
 * Uploads a photo and publishes a listing with it, expecting the `201`.
 * [session] must already have a donation profile
 * (`signUpWithDonationProfile`).
 */
export async function publishListing(
  app: INestApplication<App>,
  session: AuthTokensBody,
  fields: { commonName?: string; quantity?: number; note?: string } = {},
): Promise<MyListingBody> {
  const photo = await uploadPhoto(app, session);
  const response = await createListing(app, session, {
    photoId: photo.id,
    commonName: 'Costela-de-adão',
    quantity: 3,
    ...fields,
  }).expect(201);
  return response.body as MyListingBody;
}

/** `GET /v1/me/listings` as [session], without checking the answer. */
export function myListings(
  app: INestApplication<App>,
  session: AuthTokensBody,
): request.Test {
  return request(app.getHttpServer())
    .get('/v1/me/listings')
    .set('Authorization', `Bearer ${session.accessToken}`);
}

/** `PATCH /v1/listings/:id` as [session], without checking the answer. */
export function editListing(
  app: INestApplication<App>,
  session: AuthTokensBody,
  listingId: string,
  body: object,
): request.Test {
  return request(app.getHttpServer())
    .patch(`/v1/listings/${listingId}`)
    .set('Authorization', `Bearer ${session.accessToken}`)
    .send(body);
}

/** `POST /v1/listings/:id/close` as [session], without checking the answer. */
export function closeListing(
  app: INestApplication<App>,
  session: AuthTokensBody,
  listingId: string,
): request.Test {
  return request(app.getHttpServer())
    .post(`/v1/listings/${listingId}/close`)
    .set('Authorization', `Bearer ${session.accessToken}`);
}

/**
 * Moves [listingId]'s expiry to now + [interval] (`'3 days'`, `'-1 day'`):
 * deadlines are tested by changing the date in the database, with no fake
 * clock.
 */
export async function expireListingIn(
  app: INestApplication<App>,
  listingId: string,
  interval: string,
): Promise<void> {
  await databaseOf(app)
    .update(listings)
    .set({ expiresAt: sql`now() + ${interval}::interval` })
    .where(eq(listings.id, listingId));
}
