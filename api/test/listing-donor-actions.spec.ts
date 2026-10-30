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
  editListing,
  expireListingIn,
  type MyListingBody,
  myListings,
  publishListing,
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

  /**
   * Every donor route, so the common rules are checked on all of them. #67
   * adds `donations` and `renew` here.
   */
  const donorRoutes: [
    string,
    (session: AuthTokensBody, id: string) => request.Test,
  ][] = [
    ['PATCH', (session, id) => editListing(app, session, id, { quantity: 2 })],
    ['close', (session, id) => closeListing(app, session, id)],
  ];

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
    it('closes the listing, which stays in Meus anúncios as closed', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);

      const response = await closeListing(app, donor, listing.id).expect(200);

      expect(response.body).toEqual(
        asLater(listing, { status: 'closed', canRenew: false }),
      );
      expect(await mineById(donor, listing.id)).toMatchObject({
        status: 'closed',
      });
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
