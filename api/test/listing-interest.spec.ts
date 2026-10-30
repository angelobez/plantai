import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import {
  type AuthTokensBody,
  newAccount,
  signUpAndVerify,
} from './support/auth';
import { signUpWithDonationProfile } from './support/donation';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import {
  closeListing,
  expireListingIn,
  type MyListingBody,
  myListings,
  publishListing,
} from './support/listings';
import { startPostgis } from './support/postgis';

const UNKNOWN_ID = '01890000-0000-7000-8000-000000000000';

describe('Tenho interesse (POST /listings/:id/interest)', () => {
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

  /** `POST /v1/listings/:id/interest` as [session], without checking the answer. */
  function showInterest(session: AuthTokensBody, id: string): request.Test {
    return request(app.getHttpServer())
      .post(`/v1/listings/${id}/interest`)
      .set('Authorization', `Bearer ${session.accessToken}`);
  }

  async function interestCountOf(
    donor: AuthTokensBody,
    listing: MyListingBody,
  ): Promise<number | undefined> {
    const response = await myListings(app, donor).expect(200);
    return (response.body as MyListingBody[]).find(
      (item) => item.id === listing.id,
    )?.interestCount;
  }

  function newSearcher(): Promise<AuthTokensBody> {
    return signUpAndVerify(app, outbox);
  }

  it("answers the wa.me link to the donor's phone with the message ready", async () => {
    const donor = await signUpWithDonationProfile(
      app,
      outbox,
      { phone: '+55 (11) 98765-4321' },
      newAccount({ name: 'Marina Souza' }),
    );
    const listing = await publishListing(app, donor, {
      commonName: 'Costela-de-adão',
    });

    const response = await showInterest(await newSearcher(), listing.id).expect(
      200,
    );

    const message =
      'Oi, Marina! Vi no PlantAí seu anúncio de Costela-de-adão e tenho interesse.';
    expect(response.body).toEqual({
      whatsappUrl: `https://wa.me/5511987654321?text=${encodeURIComponent(message)}`,
    });
    const url = new URL((response.body as { whatsappUrl: string }).whatsappUrl);
    expect(url.searchParams.get('text')).toBe(message);
  });

  it('counts each User once: tapping again reopens without counting, another User counts', async () => {
    const donor = await signUpWithDonationProfile(app, outbox);
    const listing = await publishListing(app, donor);
    const searcher = await newSearcher();

    await showInterest(searcher, listing.id).expect(200);
    expect(await interestCountOf(donor, listing)).toBe(1);

    const again = await showInterest(searcher, listing.id).expect(200);
    expect(again.body).toEqual({ whatsappUrl: expect.any(String) as unknown });
    expect(await interestCountOf(donor, listing)).toBe(1);

    await showInterest(await newSearcher(), listing.id).expect(200);
    expect(await interestCountOf(donor, listing)).toBe(2);
  });

  it("answers OWN_LISTING on the User's own listing, without counting it", async () => {
    const donor = await signUpWithDonationProfile(app, outbox);
    const listing = await publishListing(app, donor);

    const response = await showInterest(donor, listing.id).expect(409);

    expect(response.body).toMatchObject({ code: 'OWN_LISTING' });
    expect(await interestCountOf(donor, listing)).toBe(0);
  });

  it.each([
    [
      'closed',
      (donor: AuthTokensBody, listing: MyListingBody) =>
        closeListing(app, donor, listing.id).expect(200),
    ],
    [
      'expired',
      (_: AuthTokensBody, listing: MyListingBody) =>
        expireListingIn(app, listing.id, '-1 day'),
    ],
  ])(
    'answers LISTING_NOT_ACTIVE on a %s listing, without counting it',
    async (_, endListing) => {
      const donor = await signUpWithDonationProfile(app, outbox);
      const listing = await publishListing(app, donor);
      await endListing(donor, listing);

      const response = await showInterest(
        await newSearcher(),
        listing.id,
      ).expect(409);

      expect(response.body).toMatchObject({ code: 'LISTING_NOT_ACTIVE' });
      expect(await interestCountOf(donor, listing)).toBe(0);
    },
  );

  it('answers NOT_FOUND for a listing that does not exist', async () => {
    const response = await showInterest(await newSearcher(), UNKNOWN_ID).expect(
      404,
    );

    expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
  });

  it('answers VALIDATION_FAILED for an id that is not a UUID', async () => {
    const response = await showInterest(await newSearcher(), 'abc').expect(400);

    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path: 'id' }],
    });
  });
});
