import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { eq, sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
import { interests, listings, photos, species } from '../src/database/schema';
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
import { FakePhotoStorage } from './support/fake-photo-storage';
import {
  createListing,
  expireListingIn,
  keyOf,
  type MyListingBody,
  myListings,
  type PhotoBody,
  publishListing,
  uploadPhoto,
} from './support/listings';
import { startPostgis } from './support/postgis';

interface PlantItemBody {
  id: string;
  commonName: string;
  photo: PhotoBody;
  species: { id: string } | null;
}

const UNKNOWN_ID = '01890000-0000-7000-8000-000000000000';

const DAY_MS = 24 * 60 * 60 * 1000;

describe('listings (Anúncios)', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const photoStorage = new FakePhotoStorage();
  let gbifKeys = 9000;

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      photoStorage,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  /** A new User with a donation profile, so each test has its own listings. */
  function newDonor(): Promise<AuthTokensBody> {
    return signUpWithDonationProfile(app, outbox);
  }

  async function addSpecies(scientificName: string): Promise<string> {
    gbifKeys += 1;
    const [row] = await databaseOf(app)
      .insert(species)
      .values({
        gbifKey: gbifKeys,
        scientificName: `${scientificName} ${String(gbifKeys)}`,
        referencePhotoUrl: `https://upload.example.org/${String(gbifKeys)}.jpg`,
        referencePhotoAuthor: 'Ana Autora',
        referencePhotoLicense: 'CC BY-SA 4.0',
        referencePhotoSourceUrl: `https://commons.example.org/File:${String(gbifKeys)}`,
        origin: 'seed',
      })
      .returning();
    if (!row) throw new Error('no species');
    return row.id;
  }

  async function savePlant(
    session: AuthTokensBody,
    fields: { commonName: string; speciesId?: string },
  ): Promise<PlantItemBody> {
    const photo = await uploadPhoto(app, session);
    const response = await request(app.getHttpServer())
      .post('/v1/plants')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({ photoId: photo.id, ...fields })
      .expect(201);
    return response.body as PlantItemBody;
  }

  function deletePlant(session: AuthTokensBody, id: string): request.Test {
    return request(app.getHttpServer())
      .delete(`/v1/plants/${id}`)
      .set('Authorization', `Bearer ${session.accessToken}`);
  }

  /** The listing columns the API never answers, to check what it stored. */
  async function storedListing(id: string) {
    const [row] = await databaseOf(app)
      .select({
        note: listings.note,
        neighborhood: listings.neighborhood,
        location: sql<string>`ST_AsText(${listings.location})`,
        plantId: listings.plantId,
      })
      .from(listings)
      .where(eq(listings.id, id));
    if (!row) throw new Error('no such listing');
    return row;
  }

  /** [list] without the photo URLs' expiry, which every response presigns anew. */
  function withoutUrlExpiry(list: unknown): unknown {
    return (list as MyListingBody[]).map(({ photo, ...listing }) => ({
      ...listing,
      photo: { id: photo.id, url: photo.url },
    }));
  }

  function expectAbout30DaysAhead(expiresAt: string): void {
    const days = (Date.parse(expiresAt) - Date.now()) / DAY_MS;
    expect(days).toBeGreaterThan(29.99);
    expect(days).toBeLessThanOrEqual(30);
  }

  describe('POST /listings', () => {
    it("publishes from a plant, with the plant's photo, active for 30 days", async () => {
      const donor = await newDonor();
      const speciesId = await addSpecies('Monstera deliciosa');
      const plant = await savePlant(donor, {
        commonName: 'Costela-de-adão',
        speciesId,
      });

      const response = await createListing(app, donor, {
        photoId: plant.photo.id,
        commonName: '  Costela-de-adão  ',
        speciesId,
        plantId: plant.id,
        quantity: 3,
        note: 'Pegar à tarde',
      }).expect(201);

      const body = response.body as MyListingBody;
      expect(body).toEqual({
        id: expect.any(String) as unknown,
        commonName: 'Costela-de-adão',
        photo: {
          id: plant.photo.id,
          url: expect.any(String) as unknown,
          expiresAt: expect.any(String) as unknown,
        },
        status: 'active',
        quantity: 3,
        interestCount: 0,
        expiresAt: expect.any(String) as unknown,
        canRenew: false,
      });
      expectAbout30DaysAhead(body.expiresAt);
      const list = await myListings(app, donor).expect(200);
      expect(withoutUrlExpiry(list.body)).toEqual(withoutUrlExpiry([body]));
      // The plant keeps its photo.
      const plants = await request(app.getHttpServer())
        .get('/v1/plants')
        .set('Authorization', `Bearer ${donor.accessToken}`)
        .expect(200);
      expect(plants.body).toMatchObject([{ photo: { id: plant.photo.id } }]);
    });

    it('publishes with a new photo of the seedling and attaches it', async () => {
      const donor = await newDonor();
      const photo = await uploadPhoto(app, donor);
      expect(photoStorage.get(keyOf(photo))?.tags).not.toEqual({});

      const response = await createListing(app, donor, {
        photoId: photo.id,
        commonName: 'Espada-de-são-jorge',
        quantity: 5,
      }).expect(201);

      expect(response.body).toMatchObject({
        commonName: 'Espada-de-são-jorge',
        photo: { id: photo.id },
        status: 'active',
        quantity: 5,
      });
      expect(photoStorage.get(keyOf(photo))?.tags).toEqual({});
      const [row] = await databaseOf(app)
        .select({ attachedAt: photos.attachedAt, plantId: photos.plantId })
        .from(photos)
        .where(eq(photos.id, photo.id));
      expect(row?.attachedAt).not.toBeNull();
      expect(row?.plantId).toBeNull();
    });

    it('copies the location and the neighborhood of the profile, and a later change of the profile leaves the listing as it is', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);
      const before = await storedListing(listing.id);
      expect(before.neighborhood).toBe('Vila Mariana');

      await putDonationProfile(
        app,
        donor,
        donationProfile({ lat: -22.9, lng: -43.2, neighborhood: 'Tijuca' }),
      ).expect(200);

      expect(await storedListing(listing.id)).toEqual(before);
    });

    it('answers DONATION_PROFILE_REQUIRED without a donation profile, before any other rule', async () => {
      const owner = await newDonor();
      const othersPhoto = await uploadPhoto(app, owner);
      const session = await signUpAndVerify(app, outbox);

      const response = await createListing(app, session, {
        photoId: othersPhoto.id,
        commonName: 'Jiboia',
        plantId: UNKNOWN_ID,
        speciesId: UNKNOWN_ID,
        quantity: 2,
      }).expect(409);

      expect(response.body).toMatchObject({
        code: 'DONATION_PROFILE_REQUIRED',
      });
      const list = await myListings(app, session).expect(200);
      expect(list.body).toEqual([]);
    });

    it("answers NOT_FOUND for another User's photo, or one that does not exist", async () => {
      const owner = await newDonor();
      const othersPhoto = await uploadPhoto(app, owner);
      const donor = await newDonor();

      for (const photoId of [othersPhoto.id, UNKNOWN_ID]) {
        const response = await createListing(app, donor, {
          photoId,
          commonName: 'Jiboia',
          quantity: 2,
        }).expect(404);
        expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
      }
      expect(photoStorage.get(keyOf(othersPhoto))?.tags).not.toEqual({});
    });

    it("answers VALIDATION_FAILED for another User's plant, or one that does not exist", async () => {
      const owner = await newDonor();
      const othersPlant = await savePlant(owner, { commonName: 'Jiboia' });
      const donor = await newDonor();
      const photo = await uploadPhoto(app, donor);

      for (const plantId of [othersPlant.id, UNKNOWN_ID]) {
        const response = await createListing(app, donor, {
          photoId: photo.id,
          commonName: 'Jiboia',
          plantId,
          quantity: 2,
        }).expect(400);
        expect(response.body).toMatchObject({
          code: 'VALIDATION_FAILED',
          errors: [{ path: 'plantId' }],
        });
      }
      const list = await myListings(app, donor).expect(200);
      expect(list.body).toEqual([]);
    });

    it('answers VALIDATION_FAILED for a species that does not exist', async () => {
      const donor = await newDonor();
      const photo = await uploadPhoto(app, donor);

      const response = await createListing(app, donor, {
        photoId: photo.id,
        commonName: 'Jiboia',
        speciesId: UNKNOWN_ID,
        quantity: 2,
      }).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [{ path: 'speciesId' }],
      });
    });

    it.each([
      ['an empty name', { commonName: '   ' }, 'commonName'],
      [
        'a name over 80 characters',
        { commonName: 'a'.repeat(81) },
        'commonName',
      ],
      ['no seedlings', { quantity: 0 }, 'quantity'],
      ['100 seedlings', { quantity: 100 }, 'quantity'],
      ['half a seedling', { quantity: 1.5 }, 'quantity'],
      ['a note over 200 characters', { note: 'a'.repeat(201) }, 'note'],
    ])('answers VALIDATION_FAILED for %s', async (_case, fields, path) => {
      const donor = await newDonor();
      const photo = await uploadPhoto(app, donor);

      const response = await createListing(app, donor, {
        photoId: photo.id,
        commonName: 'Jiboia',
        quantity: 2,
        ...fields,
      }).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [{ path }],
      });
    });

    it.each([
      ['1 seedling', { quantity: 1 }],
      ['99 seedlings', { quantity: 99 }],
      ['an 80-character name', { commonName: 'a'.repeat(80) }],
    ])('accepts %s', async (_case, fields) => {
      const donor = await newDonor();

      const listing = await publishListing(app, donor, fields);

      expect(listing).toMatchObject(fields);
    });

    it('keeps a note of 200 characters after the trim', async () => {
      const donor = await newDonor();
      const note = 'b'.repeat(200);

      const listing = await publishListing(app, donor, { note: `  ${note} ` });

      expect((await storedListing(listing.id)).note).toBe(note);
    });

    it.each([
      ['an empty note', ''],
      ['a note of only spaces', '   '],
    ])('stores %s as no note', async (_case, note) => {
      const donor = await newDonor();

      const listing = await publishListing(app, donor, { note });

      expect((await storedListing(listing.id)).note).toBeNull();
    });
  });

  describe('GET /me/listings', () => {
    it("answers only the User's listings, newest first", async () => {
      const donor = await newDonor();
      const first = await publishListing(app, donor, { commonName: 'Jiboia' });
      const second = await publishListing(app, donor, {
        commonName: 'Pimenta',
      });
      await publishListing(app, await newDonor());

      const response = await myListings(app, donor).expect(200);

      expect(withoutUrlExpiry(response.body)).toEqual(
        withoutUrlExpiry([second, first]),
      );
    });

    it('answers an empty list for a User without listings', async () => {
      const session = await signUpAndVerify(app, outbox);

      const response = await myListings(app, session).expect(200);

      expect(response.body).toEqual([]);
    });

    it('counts each User who had interest once', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);
      const [ana, bia] = await Promise.all([
        signUpAndVerify(app, outbox),
        signUpAndVerify(app, outbox),
      ]);
      // The interest route comes in a later ticket; the rows stand for it.
      await databaseOf(app)
        .insert(interests)
        .values([
          { listingId: listing.id, userId: ana.user.id },
          { listingId: listing.id, userId: bia.user.id },
        ]);

      const response = await myListings(app, donor).expect(200);

      expect(response.body).toMatchObject([{ interestCount: 2 }]);
    });

    it('allows renewing only within the last 7 days', async () => {
      const donor = await newDonor();
      const later = await publishListing(app, donor);
      const soon = await publishListing(app, donor);
      await expireListingIn(app, later.id, '8 days');
      await expireListingIn(app, soon.id, '3 days');

      const response = await myListings(app, donor).expect(200);

      expect(response.body).toMatchObject([
        { id: soon.id, status: 'active', canRenew: true },
        { id: later.id, status: 'active', canRenew: false },
      ]);
    });

    it('shows an expired listing as closed, which cannot be renewed', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);
      await expireListingIn(app, listing.id, '-1 day');

      const response = await myListings(app, donor).expect(200);

      expect(response.body).toMatchObject([
        { id: listing.id, status: 'closed', canRenew: false },
      ]);
    });

    it('shows a donated listing as donated, even past its expiry', async () => {
      const donor = await newDonor();
      const listing = await publishListing(app, donor);
      await databaseOf(app)
        .update(listings)
        .set({ status: 'donated', quantity: 0 })
        .where(eq(listings.id, listing.id));
      await expireListingIn(app, listing.id, '-1 day');

      const response = await myListings(app, donor).expect(200);

      expect(response.body).toMatchObject([
        { id: listing.id, status: 'donated', quantity: 0, canRenew: false },
      ]);
    });
  });

  describe('DELETE /plants/:id', () => {
    it("keeps the plant's photo a listing uses, and the listing", async () => {
      const donor = await newDonor();
      const plant = await savePlant(donor, { commonName: 'Jiboia' });
      const created = await createListing(app, donor, {
        photoId: plant.photo.id,
        commonName: 'Jiboia',
        plantId: plant.id,
        quantity: 2,
      }).expect(201);
      const listing = created.body as MyListingBody;

      await deletePlant(donor, plant.id).expect(204);

      expect(photoStorage.has(keyOf(plant.photo))).toBe(true);
      const list = await myListings(app, donor).expect(200);
      expect(list.body).toMatchObject([
        { id: listing.id, status: 'active', photo: { id: plant.photo.id } },
      ]);
      const [photo] = await databaseOf(app)
        .select({ plantId: photos.plantId })
        .from(photos)
        .where(eq(photos.id, plant.photo.id));
      expect(photo).toEqual({ plantId: null });
      expect((await storedListing(listing.id)).plantId).toBeNull();
    });

    it('still deletes the photo of a plant whose listing has a photo of its own', async () => {
      const donor = await newDonor();
      const plant = await savePlant(donor, { commonName: 'Jiboia' });
      const seedling = await uploadPhoto(app, donor);
      await createListing(app, donor, {
        photoId: seedling.id,
        commonName: 'Jiboia',
        plantId: plant.id,
        quantity: 2,
      }).expect(201);

      await deletePlant(donor, plant.id).expect(204);

      expect(photoStorage.has(keyOf(plant.photo))).toBe(false);
      expect(photoStorage.has(keyOf(seedling))).toBe(true);
      const list = await myListings(app, donor).expect(200);
      expect(list.body).toMatchObject([{ photo: { id: seedling.id } }]);
    });
  });
});
