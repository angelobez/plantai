import type { INestApplication, LoggerService } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { eq, sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
import { careGuides, listings, species } from '../src/database/schema';
import { cellCenter, type LatLng } from '../src/profile/donation-grid';
import { createTestApp } from './support/app';
import { type AuthTokensBody, databaseOf, newAccount } from './support/auth';
import { signUpWithDonationProfile } from './support/donation';
import { testEnv } from './support/env';
import {
  careGuideContent,
  FakeCareGuideWriter,
} from './support/fake-care-guide-writer';
import { FakeOutbox } from './support/fake-outbox';
import { FakePhotoStorage } from './support/fake-photo-storage';
import {
  createListing,
  expireListingIn,
  type MyListingBody,
  type PhotoBody,
  publishListing,
  uploadPhoto,
} from './support/listings';
import { startPostgis } from './support/postgis';

/** One item of `GET /v1/listings/nearby`. */
interface NearbyItemBody {
  id: string;
  commonName: string;
  scientificName: string | null;
  photo: PhotoBody;
  quantity: number;
  distanceKm: number;
  neighborhood: string;
}

/** Keeps every log line so the test can read what would reach CloudWatch. */
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

const UNKNOWN_ID = '01890000-0000-7000-8000-000000000000';

/** Vila Mariana, São Paulo: where the donors live unless a test moves them. */
const VILA_MARIANA: LatLng = { lat: -23.5874, lng: -46.6345 };

/**
 * About how many km one degree of latitude spans around São Paulo on the
 * WGS 84 spheroid, which `ST_Distance` and `ST_DWithin` use.
 */
const KM_PER_LAT_DEGREE = 110.75;

/** [km] north of [point], along its meridian. */
function north(point: LatLng, km: number): LatLng {
  return { lat: point.lat + km / KM_PER_LAT_DEGREE, lng: point.lng };
}

function header({ lat, lng }: LatLng): string {
  return `${String(lat)},${String(lng)}`;
}

describe('listings near the searcher (Mudas por perto) and the detail', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const photoStorage = new FakePhotoStorage();
  const careGuideWriter = new FakeCareGuideWriter();
  const logger = new CapturingLogger();
  let gbifKeys = 11000;

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      photoStorage,
      careGuideWriter,
      logger,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  // Every test starts with no listings, so the searcher sees only its own.
  beforeEach(async () => {
    await databaseOf(app).execute(sql`TRUNCATE ${listings} CASCADE`);
  });

  function donorAt(
    point: LatLng = VILA_MARIANA,
    fields: { name?: string; neighborhood?: string } = {},
  ): Promise<AuthTokensBody> {
    return signUpWithDonationProfile(
      app,
      outbox,
      { ...point, neighborhood: fields.neighborhood ?? 'Vila Mariana' },
      newAccount(fields.name ? { name: fields.name } : {}),
    );
  }

  function nearby(
    session: AuthTokensBody,
    from: LatLng | string | null,
    page?: number | string,
  ): request.Test {
    const test = request(app.getHttpServer())
      .get('/v1/listings/nearby')
      .query(page === undefined ? {} : { page })
      .set('Authorization', `Bearer ${session.accessToken}`);
    if (from === null) return test;
    return test.set(
      'X-Search-Location',
      typeof from === 'string' ? from : header(from),
    );
  }

  async function nearbyItems(
    session: AuthTokensBody,
    from: LatLng,
    page?: number,
  ): Promise<NearbyItemBody[]> {
    const response = await nearby(session, from, page).expect(200);
    return response.body as NearbyItemBody[];
  }

  function detail(
    session: AuthTokensBody,
    id: string,
    from: LatLng | string | null = VILA_MARIANA,
  ): request.Test {
    const test = request(app.getHttpServer())
      .get(`/v1/listings/${id}`)
      .set('Authorization', `Bearer ${session.accessToken}`);
    if (from === null) return test;
    return test.set(
      'X-Search-Location',
      typeof from === 'string' ? from : header(from),
    );
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

  async function scientificNameOf(speciesId: string): Promise<string> {
    const [row] = await databaseOf(app)
      .select({ name: species.scientificName })
      .from(species)
      .where(eq(species.id, speciesId));
    if (!row) throw new Error('no species');
    return row.name;
  }

  async function guideFor(
    speciesId: string,
    status: 'ready' | 'generating' | 'failed',
  ): Promise<void> {
    await databaseOf(app)
      .insert(careGuides)
      .values({
        speciesId,
        status,
        content: status === 'ready' ? careGuideContent() : null,
        model: 'claude-sonnet-5-5',
        promptVersion: 1,
        startedAt: sql`now()`,
        generatedAt: status === 'ready' ? sql`now()` : null,
      });
  }

  /** Publishes a listing of [speciesId], expecting the `201`. */
  async function publishWithSpecies(
    donor: AuthTokensBody,
    speciesId: string,
    fields: { commonName?: string; quantity?: number; note?: string } = {},
  ): Promise<MyListingBody> {
    const photo = await uploadPhoto(app, donor);
    const response = await createListing(app, donor, {
      photoId: photo.id,
      commonName: 'Costela-de-adão',
      quantity: 3,
      speciesId,
      ...fields,
    }).expect(201);
    return response.body as MyListingBody;
  }

  /** Stores a status the donor's actions would set (they come in #66). */
  async function setStoredStatus(
    id: string,
    status: 'donated' | 'closed',
  ): Promise<void> {
    await databaseOf(app)
      .update(listings)
      .set({ status, ...(status === 'donated' ? { quantity: 0 } : {}) })
      .where(eq(listings.id, id));
  }

  describe('GET /listings/nearby', () => {
    it('lists the active listings of other Users, nearest first', async () => {
      const searcher = await donorAt();
      const far = await donorAt(north(VILA_MARIANA, 20), {
        neighborhood: 'Santana',
      });
      const near = await donorAt(north(VILA_MARIANA, 3), {
        neighborhood: 'Liberdade',
      });
      const middle = await donorAt(north(VILA_MARIANA, 10), {
        neighborhood: 'Freguesia do Ó',
      });
      const farListing = await publishListing(app, far);
      const nearListing = await publishListing(app, near, {
        commonName: 'Jiboia',
        quantity: 1,
      });
      const middleListing = await publishListing(app, middle);
      await publishListing(app, searcher, { commonName: 'Minha própria' });

      const items = await nearbyItems(searcher, VILA_MARIANA);

      expect(items.map((item) => item.id)).toEqual([
        nearListing.id,
        middleListing.id,
        farListing.id,
      ]);
      expect(items[0]).toEqual({
        id: nearListing.id,
        commonName: 'Jiboia',
        scientificName: null,
        photo: {
          id: nearListing.photo.id,
          url: expect.any(String) as unknown,
          expiresAt: expect.any(String) as unknown,
        },
        quantity: 1,
        distanceKm: 3,
        neighborhood: 'Liberdade',
      });
      expect(items.map((item) => item.distanceKm)).toEqual([3, 10, 20]);
    });

    it('shows the scientific name of the species', async () => {
      const searcher = await donorAt();
      const donor = await donorAt(north(VILA_MARIANA, 2));
      const speciesId = await addSpecies('Monstera deliciosa');
      await publishWithSpecies(donor, speciesId);

      const [item] = await nearbyItems(searcher, VILA_MARIANA);

      expect(item?.scientificName).toBe(await scientificNameOf(speciesId));
    });

    it('cuts at 30 km from the center of the listing’s cell', async () => {
      const searcher = await donorAt();
      const donor = await donorAt(north(VILA_MARIANA, 5));
      const listing = await publishListing(app, donor);
      const center = cellCenter(north(VILA_MARIANA, 5));

      const inside = await nearbyItems(searcher, north(center, -29.3));
      const outside = await nearbyItems(searcher, north(center, -30.7));

      expect(inside.map((item) => [item.id, item.distanceKm])).toEqual([
        [listing.id, 29],
      ]);
      expect(outside).toEqual([]);
    });

    it('rounds the distance to the center of the cell, 0 in the same cell', async () => {
      const searcher = await donorAt();
      const donor = await donorAt();
      await publishListing(app, donor);
      const center = cellCenter(VILA_MARIANA);

      const [sameCell] = await nearbyItems(searcher, north(center, 0.3));
      const [closeBy] = await nearbyItems(searcher, north(center, -1.7));
      const [further] = await nearbyItems(searcher, north(center, 7.4));

      expect(sameCell?.distanceKm).toBe(0);
      expect(closeBy?.distanceKm).toBe(2);
      expect(further?.distanceKm).toBe(7);
    });

    it('gives the same distance to two donors in the same cell', async () => {
      const searcher = await donorAt();
      const center = cellCenter(VILA_MARIANA);
      // Two different points, both well inside the same ~1 km cell.
      const first = await donorAt(north(center, 0.2));
      const second = await donorAt(north(center, -0.2));
      await publishListing(app, first);
      await publishListing(app, second);

      const items = await nearbyItems(searcher, north(center, 12.4));

      expect(items).toHaveLength(2);
      expect(items[0]?.distanceKm).toBe(12);
      expect(items[1]?.distanceKm).toBe(12);
      const body = JSON.stringify(items);
      expect(body).not.toContain(String(north(center, 0.2).lat));
      expect(body).not.toContain(String(center.lat));
    });

    it('breaks a tie in distance with the newest first', async () => {
      const searcher = await donorAt();
      const donor = await donorAt(north(VILA_MARIANA, 4));
      const older = await publishListing(app, donor, { commonName: 'Velha' });
      const newer = await publishListing(app, donor, { commonName: 'Nova' });

      const items = await nearbyItems(searcher, VILA_MARIANA);

      expect(items.map((item) => item.id)).toEqual([newer.id, older.id]);
    });

    it('leaves out donated, closed and expired listings', async () => {
      const searcher = await donorAt();
      const donor = await donorAt(north(VILA_MARIANA, 2));
      const active = await publishListing(app, donor, { commonName: 'Ativa' });
      const donated = await publishListing(app, donor);
      const closed = await publishListing(app, donor);
      const expired = await publishListing(app, donor);
      const expiringSoon = await publishListing(app, donor);
      await setStoredStatus(donated.id, 'donated');
      await setStoredStatus(closed.id, 'closed');
      await expireListingIn(app, expired.id, '-1 day');
      await expireListingIn(app, expiringSoon.id, '1 day');

      const items = await nearbyItems(searcher, VILA_MARIANA);

      expect(items.map((item) => item.id).sort()).toEqual(
        [active.id, expiringSoon.id].sort(),
      );
    });

    it('pages 30 at a time', async () => {
      const searcher = await donorAt();
      const donor = await donorAt(north(VILA_MARIANA, 2));
      const published: string[] = [];
      for (let i = 0; i < 31; i += 1) {
        published.push((await publishListing(app, donor)).id);
      }

      const first = await nearbyItems(searcher, VILA_MARIANA);
      const second = await nearbyItems(searcher, VILA_MARIANA, 2);
      const third = await nearbyItems(searcher, VILA_MARIANA, 3);

      expect(first).toHaveLength(30);
      expect(second).toHaveLength(1);
      expect(third).toEqual([]);
      // Same distance for all: the newest first, so the oldest is last.
      expect(second[0]?.id).toBe(published[0]);
      expect(new Set([...first, ...second].map((item) => item.id)).size).toBe(
        31,
      );
    });

    it.each(['0', '-1', '1.5', 'dois'])(
      'answers VALIDATION_FAILED for page=%s',
      async (page) => {
        const searcher = await donorAt();

        const response = await nearby(searcher, VILA_MARIANA, page).expect(400);

        expect(response.body).toMatchObject({
          code: 'VALIDATION_FAILED',
          errors: [{ path: 'page' }],
        });
      },
    );

    it('answers LOCATION_REQUIRED without X-Search-Location', async () => {
      const searcher = await donorAt();

      const response = await nearby(searcher, null).expect(400);

      expect(response.body).toMatchObject({ code: 'LOCATION_REQUIRED' });
    });

    it.each([
      '',
      'abc',
      '-23.5',
      '-23.5,-46.6,1',
      '-23.5;-46.6',
      '91,0',
      '-90.1,0',
      '0,180.5',
      '0,-181',
      'NaN,NaN',
      '1e2,3',
    ])(
      'answers VALIDATION_FAILED for X-Search-Location "%s"',
      async (value) => {
        const searcher = await donorAt();

        const response = await nearby(searcher, value).expect(400);

        expect(response.body).toMatchObject({
          code: 'VALIDATION_FAILED',
          errors: [{ path: 'X-Search-Location' }],
        });
      },
    );

    it('accepts the limits and spaces around the comma', async () => {
      const searcher = await donorAt();

      await nearby(searcher, '90,180').expect(200);
      await nearby(searcher, '-90,-180').expect(200);
      await nearby(searcher, '-23.5874, -46.6345').expect(200);
    });

    it('keeps the searcher’s coordinates out of the log', async () => {
      const searcher = await donorAt();
      const donor = await donorAt(north(VILA_MARIANA, 2));
      await publishListing(app, donor);

      await nearby(searcher, '-23.51234,-46.65678').expect(200);

      const line = logger.lines.find((l) =>
        l.includes('GET /v1/listings/nearby 200'),
      );
      expect(line).toBeDefined();
      const everything = logger.lines.join('\n');
      expect(everything).not.toContain('23.51234');
      expect(everything).not.toContain('46.65678');
    });
  });

  describe('GET /listings/:id', () => {
    it('shows the listing with the note, the donor’s first name and no phone', async () => {
      const donor = await donorAt(north(VILA_MARIANA, 6), {
        name: 'Marina Souza Lima',
        neighborhood: 'Aclimação',
      });
      const searcher = await donorAt();
      const listing = await publishListing(app, donor, {
        commonName: 'Espada-de-são-jorge',
        quantity: 5,
        note: 'Pegar à tarde',
      });

      const response = await detail(searcher, listing.id).expect(200);

      expect(response.body).toEqual({
        id: listing.id,
        commonName: 'Espada-de-são-jorge',
        scientificName: null,
        photo: {
          id: listing.photo.id,
          url: expect.any(String) as unknown,
          expiresAt: expect.any(String) as unknown,
        },
        quantity: 5,
        distanceKm: 6,
        neighborhood: 'Aclimação',
        status: 'active',
        note: 'Pegar à tarde',
        donorFirstName: 'Marina',
        createdAt: expect.any(String) as unknown,
        careGuide: null,
      });
      const createdAt = Date.parse(
        (response.body as { createdAt: string }).createdAt,
      );
      expect(Math.abs(Date.now() - createdAt)).toBeLessThan(60_000);
      const body = JSON.stringify(response.body);
      expect(body).not.toContain('987654321');
      expect(body).not.toMatch(/phone/i);
    });

    it('shows the ready care guide of the species, without asking Claude', async () => {
      const donor = await donorAt();
      const searcher = await donorAt();
      const ready = await addSpecies('Monstera deliciosa');
      await guideFor(ready, 'ready');
      const generating = await addSpecies('Dracaena trifasciata');
      await guideFor(generating, 'generating');
      const failed = await addSpecies('Epipremnum aureum');
      await guideFor(failed, 'failed');
      const noGuide = await addSpecies('Zamioculcas zamiifolia');
      const withGuide = await publishWithSpecies(donor, ready);
      const others = await Promise.all(
        [generating, failed, noGuide].map((id) =>
          publishWithSpecies(donor, id),
        ),
      );
      const requestsBefore = careGuideWriter.requests.length;

      const shown = await detail(searcher, withGuide.id).expect(200);
      const hidden = await Promise.all(
        others.map((listing) => detail(searcher, listing.id).expect(200)),
      );

      expect(shown.body).toMatchObject({
        scientificName: await scientificNameOf(ready),
        careGuide: careGuideContent(),
      });
      for (const response of hidden) {
        expect(response.body).toMatchObject({ careGuide: null });
      }
      expect(careGuideWriter.requests).toHaveLength(requestsBefore);
    });

    it('shows a listing that is no longer active with its effective status', async () => {
      const donor = await donorAt();
      const searcher = await donorAt();
      const donated = await publishListing(app, donor);
      const closed = await publishListing(app, donor);
      const expired = await publishListing(app, donor);
      await setStoredStatus(donated.id, 'donated');
      await setStoredStatus(closed.id, 'closed');
      await expireListingIn(app, expired.id, '-1 day');

      const statuses = await Promise.all(
        [donated, closed, expired].map(async (listing) => {
          const response = await detail(searcher, listing.id).expect(200);
          return (response.body as { status: string }).status;
        }),
      );

      expect(statuses).toEqual(['donated', 'closed', 'closed']);
    });

    it('shows an empty note as null', async () => {
      const donor = await donorAt();
      const searcher = await donorAt();
      const listing = await publishListing(app, donor);

      const response = await detail(searcher, listing.id).expect(200);

      expect(response.body).toMatchObject({ note: null });
    });

    it('answers NOT_FOUND for a listing that does not exist', async () => {
      const searcher = await donorAt();

      const response = await detail(searcher, UNKNOWN_ID).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
    });

    it('answers VALIDATION_FAILED for an id that is not a UUID', async () => {
      const searcher = await donorAt();

      const response = await detail(searcher, 'not-a-uuid').expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [{ path: 'id' }],
      });
    });

    it('answers LOCATION_REQUIRED without X-Search-Location', async () => {
      const donor = await donorAt();
      const searcher = await donorAt();
      const listing = await publishListing(app, donor);

      const response = await detail(searcher, listing.id, null).expect(400);

      expect(response.body).toMatchObject({ code: 'LOCATION_REQUIRED' });
    });

    it('answers VALIDATION_FAILED for a bad X-Search-Location', async () => {
      const donor = await donorAt();
      const searcher = await donorAt();
      const listing = await publishListing(app, donor);

      const response = await detail(searcher, listing.id, '-23.5').expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [{ path: 'X-Search-Location' }],
      });
    });
  });
});
