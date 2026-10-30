import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import type request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import type { AuthTokensBody } from './support/auth';
import { signUpWithDonationProfile } from './support/donation';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import {
  closeListing,
  donateFromListing,
  editListing,
  expireListingIn,
  type MyListingBody,
  myListings,
  nearbyIds,
  publishListing,
  renewListing,
} from './support/listings';
import { startPostgis } from './support/postgis';

const UNKNOWN_ID = '01890000-0000-7000-8000-000000000000';

describe("the donor's actions on a listing", () => {
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

  function newDonor(): Promise<AuthTokensBody> {
    return signUpWithDonationProfile(app, outbox);
  }

  /**
   * [listing] with [changes], as a later answer shows it: the photo's
   * presigned URL is signed again, so its expiry moves.
   */
  function asLater(
    listing: MyListingBody | undefined,
    changes: Partial<MyListingBody> = {},
  ): object {
    if (!listing) throw new Error('The listing is missing');
    return {
      ...listing,
      photo: { ...listing.photo, expiresAt: expect.any(String) as unknown },
      ...changes,
    };
  }

  async function mineById(
    session: AuthTokensBody,
    id: string,
  ): Promise<MyListingBody | undefined> {
    const response = await myListings(app, session).expect(200);
    return (response.body as MyListingBody[]).find((item) => item.id === id);
  }

  /** Every donor route, so the common rules are checked on all of them. */
  const donorRoutes: [
    string,
    (session: AuthTokensBody, id: string) => request.Test,
  ][] = [
    ['PATCH', (session, id) => editListing(app, session, id, { quantity: 2 })],
    ['close', (session, id) => closeListing(app, session, id)],
    ['donations', (session, id) => donateFromListing(app, session, id, 1)],
    ['renew', (session, id) => renewListing(app, session, id)],
  ];

  /** Seconds between [later] and [earlier], two ISO dates. */
  function secondsBetween(later: string, earlier: string): number {
    return (Date.parse(later) - Date.parse(earlier)) / 1000;
  }

  const THIRTY_DAYS_IN_SECONDS = 30 * 24 * 60 * 60;

  describe('PATCH /listings/:id', () => {
    it('changes the quantity and answers the listing as Meus anúncios shows it', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor, { note: 'à tarde' });

      const response = await editListing(app, donor, listing.id, {
        quantity: 7,
      }).expect(200);

      expect(response.body).toEqual(
        asLater(listing, { quantity: 7, note: 'à tarde' }),
      );
      expect(await mineById(donor, listing.id)).toEqual(
        asLater(listing, { quantity: 7 }),
      );
    });

    it.each([
      ['null', null],
      ['empty', ''],
      ['blank', '   '],
    ])('clears the note when it is %s', async (_, note) => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor, { note: 'à tarde' });

      const response = await editListing(app, donor, listing.id, {
        note,
      }).expect(200);

      expect(response.body).toEqual(asLater(listing, { note: null }));
      expect(await mineById(donor, listing.id)).toMatchObject({ note: null });
    });

    it('changes the note, trimmed, keeping the quantity', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor, { quantity: 4 });

      const response = await editListing(app, donor, listing.id, {
        note: '  pegar de manhã  ',
      }).expect(200);

      expect(response.body).toEqual(
        asLater(listing, { quantity: 4, note: 'pegar de manhã' }),
      );
    });

    it.each([
      ['no field', {}],
      ['a quantity of 0', { quantity: 0 }],
      ['a quantity of 100', { quantity: 100 }],
      ['a fractional quantity', { quantity: 1.5 }],
      ['a note over 200 characters', { note: 'a'.repeat(201) }],
    ])('answers VALIDATION_FAILED for %s', async (_, body) => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);

      const response = await editListing(app, donor, listing.id, body).expect(
        400,
      );

      expect(response.body).toMatchObject({ code: 'VALIDATION_FAILED' });
    });
  });

  describe('POST /listings/:id/close', () => {
    it('closes the listing, which stays in Meus anúncios as closed and leaves the nearby of other Users', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);
      const neighbor = await newDonor();
      expect(await nearbyIds(app, neighbor)).toContain(listing.id);

      const response = await closeListing(app, donor, listing.id).expect(200);

      expect(response.body).toEqual(
        asLater(listing, { status: 'closed', canRenew: false }),
      );
      expect(await mineById(donor, listing.id)).toMatchObject({
        status: 'closed',
      });
      expect(await nearbyIds(app, neighbor)).not.toContain(listing.id);
    });
  });

  describe('POST /listings/:id/donations', () => {
    it('takes the donated seedlings off the quantity, keeping the listing active', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor, { quantity: 5 });

      const response = await donateFromListing(
        app,
        donor,
        listing.id,
        2,
      ).expect(200);

      expect(response.body).toEqual(asLater(listing, { quantity: 3 }));
      expect(await mineById(donor, listing.id)).toEqual(
        asLater(listing, { quantity: 3 }),
      );
    });

    it('marks the listing donated when the quantity reaches zero, and it leaves the nearby of other Users', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor, { quantity: 3 });
      const neighbor = await newDonor();
      await donateFromListing(app, donor, listing.id, 1).expect(200);
      expect(await nearbyIds(app, neighbor)).toContain(listing.id);

      const response = await donateFromListing(
        app,
        donor,
        listing.id,
        2,
      ).expect(200);

      expect(response.body).toEqual(
        asLater(listing, { quantity: 0, status: 'donated' }),
      );
      expect(await mineById(donor, listing.id)).toMatchObject({
        quantity: 0,
        status: 'donated',
        canRenew: false,
      });
      expect(await nearbyIds(app, neighbor)).not.toContain(listing.id);
    });

    it('takes two concurrent donations one after the other, never below zero', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor, { quantity: 3 });

      const responses = await Promise.all([
        donateFromListing(app, donor, listing.id, 2),
        donateFromListing(app, donor, listing.id, 2),
      ]);

      expect(responses.map((r) => r.status).sort()).toEqual([200, 400]);
      expect(await mineById(donor, listing.id)).toMatchObject({
        quantity: 1,
        status: 'active',
      });
    });

    it('answers INVALID_DONATION_COUNT above the quantity, and leaves the listing as it is', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor, { quantity: 3 });

      const response = await donateFromListing(
        app,
        donor,
        listing.id,
        4,
      ).expect(400);

      expect(response.body).toMatchObject({ code: 'INVALID_DONATION_COUNT' });
      expect(await mineById(donor, listing.id)).toEqual(asLater(listing));
    });

    it.each([
      ['no count', undefined],
      ['a count of 0', 0],
      ['a negative count', -1],
      ['a fractional count', 1.5],
      ['a text count', '1'],
    ])('answers VALIDATION_FAILED for %s', async (_, count) => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);

      const response = await donateFromListing(
        app,
        donor,
        listing.id,
        count,
      ).expect(400);

      expect(response.body).toMatchObject({ code: 'VALIDATION_FAILED' });
    });

    it('answers LISTING_NOT_ACTIVE once donated', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor, { quantity: 1 });
      await donateFromListing(app, donor, listing.id, 1).expect(200);

      const response = await donateFromListing(
        app,
        donor,
        listing.id,
        1,
      ).expect(409);

      expect(response.body).toMatchObject({ code: 'LISTING_NOT_ACTIVE' });
    });
  });

  describe('POST /listings/:id/renew', () => {
    it('renews a listing in its last 7 days for 30 days from now', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);
      await expireListingIn(app, listing.id, '3 days');
      expect(await mineById(donor, listing.id)).toMatchObject({
        canRenew: true,
      });
      const before = new Date().toISOString();

      const response = await renewListing(app, donor, listing.id).expect(200);

      const body = response.body as MyListingBody;
      expect(body).toEqual(
        asLater(listing, {
          expiresAt: expect.any(String) as unknown as string,
          canRenew: false,
        }),
      );
      expect(secondsBetween(body.expiresAt, before)).toBeGreaterThanOrEqual(
        THIRTY_DAYS_IN_SECONDS - 5,
      );
      expect(secondsBetween(body.expiresAt, before)).toBeLessThanOrEqual(
        THIRTY_DAYS_IN_SECONDS + 5,
      );
      expect(await mineById(donor, listing.id)).toMatchObject({
        expiresAt: body.expiresAt,
        canRenew: false,
      });
    });

    it('answers RENEWAL_NOT_ALLOWED before the last 7 days, and leaves the listing as it is', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);
      await expireListingIn(app, listing.id, '8 days');
      const before = await mineById(donor, listing.id);
      expect(before).toMatchObject({ canRenew: false });

      const response = await renewListing(app, donor, listing.id).expect(409);

      expect(response.body).toMatchObject({ code: 'RENEWAL_NOT_ALLOWED' });
      expect(await mineById(donor, listing.id)).toEqual(asLater(before));
    });

    it('answers RENEWAL_NOT_ALLOWED for a listing just published', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);

      const response = await renewListing(app, donor, listing.id).expect(409);

      expect(response.body).toMatchObject({ code: 'RENEWAL_NOT_ALLOWED' });
    });
  });

  describe('common rules of the donor routes', () => {
    it.each(donorRoutes)(
      "%s answers NOT_FOUND for another User's listing, and leaves it as it is",
      async (_, call) => {
        const donor = await newDonor();
        const listing = await publishListing(app, donor);
        const other = await newDonor();

        const response = await call(other, listing.id).expect(404);

        expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
        expect(await mineById(donor, listing.id)).toEqual(asLater(listing));
      },
    );

    it.each(donorRoutes)(
      '%s answers NOT_FOUND for a listing that does not exist',
      async (_, call) => {
        const donor = await newDonor();

        const response = await call(donor, UNKNOWN_ID).expect(404);

        expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
      },
    );

    it.each(donorRoutes)(
      '%s answers LISTING_NOT_ACTIVE for a closed listing',
      async (_, call) => {
        const donor = await newDonor();
        const listing = await publishListing(app, donor);
        await closeListing(app, donor, listing.id).expect(200);

        const response = await call(donor, listing.id).expect(409);

        expect(response.body).toMatchObject({ code: 'LISTING_NOT_ACTIVE' });
      },
    );

    it.each(donorRoutes)(
      '%s answers LISTING_NOT_ACTIVE for an expired listing, and leaves it as it is',
      async (_, call) => {
        const donor = await newDonor();
        const listing = await publishListing(app, donor);
        await expireListingIn(app, listing.id, '-1 day');
        const before = await mineById(donor, listing.id);

        const response = await call(donor, listing.id).expect(409);

        expect(response.body).toMatchObject({ code: 'LISTING_NOT_ACTIVE' });
        expect(await mineById(donor, listing.id)).toEqual(asLater(before));
      },
    );
  });
});
