import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { eq, sql } from 'drizzle-orm';
import sharp from 'sharp';
import request from 'supertest';
import type { App } from 'supertest/types';
import {
  identifications,
  photos,
  species,
  speciesNames,
} from '../src/database/schema';
import { createTestApp } from './support/app';
import {
  type AuthTokensBody,
  databaseOf,
  signUpAndVerify,
} from './support/auth';
import { testEnv } from './support/env';
import { FakeGbifNames } from './support/fake-gbif-names';
import { FakeOutbox } from './support/fake-outbox';
import {
  FAKE_PHOTO_STORAGE_URL,
  FakePhotoStorage,
} from './support/fake-photo-storage';
import {
  candidateImage,
  FakePlantIdentifier,
  rawCandidate,
} from './support/fake-plant-identifier';
import { startPostgis } from './support/postgis';

interface PhotoBody {
  id: string;
  url: string;
}

interface ReferencePhotoBody {
  url: string;
  author: string;
  license: string;
  sourceUrl: string;
}

interface CandidateBody {
  scientificName: string;
  commonName: string | null;
  score: number;
  images: ReferencePhotoBody[];
}

interface IdentificationBody {
  id: string;
  result: 'recognized' | 'not_recognized';
  candidates: CandidateBody[];
  remainingToday: number;
}

interface SpeciesItemBody {
  id: string;
  commonName: string;
  scientificName: string;
  referencePhoto: ReferencePhotoBody;
  matchedAlternativeName: string | null;
}

describe('identifications (Identificação)', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const photoStorage = new FakePhotoStorage();
  const gbifNames = new FakeGbifNames();
  const plantIdentifier = new FakePlantIdentifier();
  let gbifKeys = 5000;

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      photoStorage,
      gbifNames,
      plantIdentifier,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  // Every test starts from an empty Catalog and a Pl@ntNet that works.
  beforeEach(async () => {
    await databaseOf(app).execute(sql`TRUNCATE ${species} CASCADE`);
    plantIdentifier.answers(rawCandidate());
    plantIdentifier.failing = false;
    gbifNames.failing = false;
  });

  /** A new User, so each test has its own daily limit. */
  function newSession(): Promise<AuthTokensBody> {
    return signUpAndVerify(app, outbox);
  }

  /** Uploads a JPEG for [session] the way the app does, before identifying. */
  async function uploadPhoto(session: AuthTokensBody): Promise<PhotoBody> {
    const jpeg = await sharp({
      create: { width: 30, height: 20, channels: 3, background: '#3F6B4A' },
    })
      .jpeg()
      .toBuffer();
    const response = await request(app.getHttpServer())
      .post('/v1/photos')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .attach('file', jpeg, 'planta.jpg')
      .expect(201);
    return response.body as PhotoBody;
  }

  function identify(session: AuthTokensBody, body: object): request.Test {
    return request(app.getHttpServer())
      .post('/v1/identifications')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send(body);
  }

  /** Uploads a photo and identifies it, expecting the `201`. */
  async function identifyNewPhoto(
    session: AuthTokensBody,
  ): Promise<IdentificationBody> {
    const photo = await uploadPhoto(session);
    const response = await identify(session, { photoId: photo.id }).expect(201);
    return response.body as IdentificationBody;
  }

  function choose(
    session: AuthTokensBody,
    identificationId: string,
    body: object,
  ): request.Test {
    return request(app.getHttpServer())
      .post(`/v1/identifications/${identificationId}/choice`)
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send(body);
  }

  /** The storage key behind a photo the API answered with. */
  function keyOf(photo: PhotoBody): string {
    return new URL(photo.url).pathname.slice(1);
  }

  /** Adds identification rows for [session]'s User, created at [createdAt]. */
  async function seedIdentifications(
    session: AuthTokensBody,
    count: number,
    createdAt = sql`now()`,
  ): Promise<void> {
    await databaseOf(app).execute(sql`
      INSERT INTO identifications (id, user_id, result, candidates, created_at)
      SELECT gen_random_uuid(), ${session.user.id}, 'not_recognized', '[]', ${createdAt}
      FROM generate_series(1, ${count})
    `);
  }

  /** A seed species in the Catalog, with our own photo copy. */
  async function addSeedSpecies({
    scientificName,
    gbifKey,
    primary,
  }: {
    scientificName: string;
    gbifKey: number;
    primary?: string;
  }): Promise<string> {
    const db = databaseOf(app);
    const [row] = await db
      .insert(species)
      .values({
        gbifKey,
        scientificName,
        referencePhotoS3Key: `species/${String(gbifKey)}.jpg`,
        referencePhotoAuthor: 'Wikimedia author',
        referencePhotoLicense: 'CC BY-SA 4.0',
        referencePhotoSourceUrl:
          'https://commons.wikimedia.org/wiki/File:x.jpg',
        origin: 'seed',
      })
      .returning();
    if (!row) throw new Error('no species');
    if (primary) {
      await db
        .insert(speciesNames)
        .values({ speciesId: row.id, name: primary, isPrimary: true });
    }
    return row.id;
  }

  describe('POST /identifications', () => {
    it('answers the candidates and attaches the photo', async () => {
      const session = await newSession();
      const photo = await uploadPhoto(session);
      const image = candidateImage({ author: 'Ana Ribeiro' });
      plantIdentifier.answers(
        rawCandidate({
          scientificName: 'Epipremnum aureum',
          commonNames: ['Jibóia'],
          score: 0.81,
          gbifKey: 2868323,
          images: [image],
        }),
        rawCandidate({
          scientificName: 'Epipremnum pinnatum',
          commonNames: ['Jiboia'],
          score: 0.13,
          gbifKey: 2868325,
        }),
      );
      const sentBefore = plantIdentifier.photos.length;

      const response = await identify(session, { photoId: photo.id }).expect(
        201,
      );

      const body = response.body as IdentificationBody;
      expect(body).toEqual({
        id: expect.any(String) as string,
        result: 'recognized',
        candidates: [
          {
            scientificName: 'Epipremnum aureum',
            commonName: 'Jibóia',
            score: 0.81,
            images: [image],
          },
          expect.objectContaining({ scientificName: 'Epipremnum pinnatum' }),
        ],
        remainingToday: 9,
      });
      // Pl@ntNet got the stored photo, and the photo is now kept.
      expect(plantIdentifier.photos.slice(sentBefore)).toEqual([
        photoStorage.get(keyOf(photo))?.bytes,
      ]);
      expect(photoStorage.get(keyOf(photo))?.tags).toEqual({});
      const [row] = await databaseOf(app)
        .select({ attachedAt: photos.attachedAt })
        .from(photos)
        .where(eq(photos.id, photo.id));
      expect(row?.attachedAt).toBeInstanceOf(Date);
    });

    it('counts down what is left of the day', async () => {
      const session = await newSession();

      expect((await identifyNewPhoto(session)).remainingToday).toBe(9);
      expect((await identifyNewPhoto(session)).remainingToday).toBe(8);
    });

    it.each([
      ['the top candidate scores below 0.2', [rawCandidate({ score: 0.19 })]],
      ['Pl@ntNet finds no species', []],
    ])(
      'is not recognized when %s, and still counts',
      async (_case, candidates) => {
        const session = await newSession();
        plantIdentifier.answers(...candidates);

        const body = await identifyNewPhoto(session);

        expect(body).toMatchObject({
          result: 'not_recognized',
          candidates: [],
          remainingToday: 9,
        });
        const [row] = await databaseOf(app)
          .select()
          .from(identifications)
          .where(eq(identifications.id, body.id));
        expect(row?.result).toBe('not_recognized');
        expect(row?.candidates).toEqual(candidates);
      },
    );

    it('keeps a candidate of exactly 0.2 recognized', async () => {
      const session = await newSession();
      plantIdentifier.answers(rawCandidate({ score: 0.2 }));

      expect((await identifyNewPhoto(session)).result).toBe('recognized');
    });

    it('answers unavailable when Pl@ntNet fails, without counting', async () => {
      const session = await newSession();
      const photo = await uploadPhoto(session);
      plantIdentifier.failing = true;

      const response = await identify(session, { photoId: photo.id }).expect(
        503,
      );

      expect(response.body).toMatchObject({
        code: 'IDENTIFICATION_SERVICE_UNAVAILABLE',
      });
      const rows = await databaseOf(app)
        .select()
        .from(identifications)
        .where(eq(identifications.userId, session.user.id));
      expect(rows).toEqual([]);
      expect(photoStorage.get(keyOf(photo))?.tags).toEqual({
        unattached: 'true',
      });
      plantIdentifier.failing = false;
      expect((await identifyNewPhoto(session)).remainingToday).toBe(9);
    });

    it('refuses the 11th of the day without asking Pl@ntNet', async () => {
      const session = await newSession();
      await seedIdentifications(session, 9);
      expect((await identifyNewPhoto(session)).remainingToday).toBe(0);
      const photo = await uploadPhoto(session);
      const sentBefore = plantIdentifier.photos.length;

      const response = await identify(session, { photoId: photo.id }).expect(
        429,
      );

      expect(response.body).toMatchObject({
        code: 'IDENTIFICATION_DAILY_LIMIT',
      });
      expect(plantIdentifier.photos).toHaveLength(sentBefore);
    });

    it("does not count yesterday's identifications", async () => {
      const session = await newSession();
      await seedIdentifications(
        session,
        10,
        sql`now() - interval '1 day' - interval '1 hour'`,
      );

      expect((await identifyNewPhoto(session)).remainingToday).toBe(9);
    });

    it("does not count another User's identifications", async () => {
      const someoneElse = await newSession();
      await seedIdentifications(someoneElse, 10);
      const session = await newSession();

      expect((await identifyNewPhoto(session)).remainingToday).toBe(9);
    });

    describe('a candidate without a gbifKey', () => {
      it('is resolved through GBIF', async () => {
        const session = await newSession();
        gbifNames.knows(
          'Sansevieria trifasciata',
          11041822,
          'Dracaena trifasciata',
        );
        plantIdentifier.answers(
          rawCandidate({
            scientificName: 'Sansevieria trifasciata',
            gbifKey: null,
          }),
        );

        const body = await identifyNewPhoto(session);

        expect(gbifNames.asked).toContain('Sansevieria trifasciata');
        expect(body.candidates.map((c) => c.scientificName)).toEqual([
          'Dracaena trifasciata',
        ]);
      });

      it('is dropped when GBIF has no match', async () => {
        const session = await newSession();
        plantIdentifier.answers(
          rawCandidate({ scientificName: 'Monstera', gbifKey: null }),
          rawCandidate({ scientificName: 'Monstera deliciosa', score: 0.1 }),
        );

        const body = await identifyNewPhoto(session);

        expect(body.result).toBe('recognized');
        expect(body.candidates.map((c) => c.scientificName)).toEqual([
          'Monstera deliciosa',
        ]);
      });

      it('is dropped when GBIF is down', async () => {
        const session = await newSession();
        gbifNames.failing = true;
        plantIdentifier.answers(
          rawCandidate({ scientificName: 'Unknown plant', gbifKey: null }),
          rawCandidate({ scientificName: 'Epipremnum aureum' }),
        );

        const body = await identifyNewPhoto(session);

        expect(body.candidates.map((c) => c.scientificName)).toEqual([
          'Epipremnum aureum',
        ]);
      });

      it('makes the photo not recognized when no candidate is left', async () => {
        const session = await newSession();
        plantIdentifier.answers(
          rawCandidate({ scientificName: 'Monstera', gbifKey: null }),
        );

        const body = await identifyNewPhoto(session);

        expect(body).toMatchObject({
          result: 'not_recognized',
          candidates: [],
        });
      });
    });

    it('drops a candidate with no image that is not in the Catalog', async () => {
      const session = await newSession();
      await addSeedSpecies({
        scientificName: 'Monstera deliciosa',
        gbifKey: 2868241,
        primary: 'Costela-de-adão',
      });
      plantIdentifier.answers(
        rawCandidate({ scientificName: 'Epipremnum aureum', images: [] }),
        rawCandidate({
          scientificName: 'Monstera deliciosa',
          gbifKey: 2868241,
          score: 0.1,
          images: [],
        }),
      );

      const body = await identifyNewPhoto(session);

      expect(body.candidates).toEqual([
        expect.objectContaining({
          scientificName: 'Monstera deliciosa',
          images: [],
        }),
      ]);
    });

    describe('the commonName of a candidate', () => {
      it('is the primary name of the Catalog species with its gbifKey', async () => {
        const session = await newSession();
        await addSeedSpecies({
          scientificName: 'Monstera deliciosa',
          gbifKey: 2868241,
          primary: 'Costela-de-adão',
        });
        plantIdentifier.answers(
          rawCandidate({
            scientificName: 'Monstera deliciosa',
            commonNames: ['Banana de-macaco'],
            gbifKey: 2868241,
          }),
        );

        const body = await identifyNewPhoto(session);

        expect(body.candidates[0]?.commonName).toBe('Costela-de-adão');
      });

      it("is otherwise Pl@ntNet's first name that looks like one", async () => {
        const session = await newSession();
        plantIdentifier.answers(
          rawCandidate({
            commonNames: ['Fica maiorzinha, trocar de vazo', 'Costela de-adão'],
          }),
        );

        const body = await identifyNewPhoto(session);

        expect(body.candidates[0]?.commonName).toBe('Costela-de-adão');
      });

      it('skips a Catalog species with no name yet', async () => {
        const session = await newSession();
        await addSeedSpecies({
          scientificName: 'Epipremnum aureum',
          gbifKey: 2868323,
        });
        plantIdentifier.answers(rawCandidate({ commonNames: ['Jiboia'] }));

        const body = await identifyNewPhoto(session);

        expect(body.candidates[0]?.commonName).toBe('Jiboia');
      });

      it('is null when no name passes', async () => {
        const session = await newSession();
        plantIdentifier.answers(rawCandidate({ commonNames: ['Dourados 1'] }));

        const body = await identifyNewPhoto(session);

        expect(body.candidates[0]?.commonName).toBeNull();
      });
    });

    it("answers NOT_FOUND for another User's photo", async () => {
      const owner = await newSession();
      const photo = await uploadPhoto(owner);
      const session = await newSession();

      const response = await identify(session, { photoId: photo.id }).expect(
        404,
      );

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
      expect(photoStorage.get(keyOf(photo))?.tags).toEqual({
        unattached: 'true',
      });
    });

    it('answers NOT_FOUND for a photo that does not exist', async () => {
      const session = await newSession();

      const response = await identify(session, {
        photoId: '01890000-0000-7000-8000-000000000000',
      }).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
    });

    it.each([
      ['no photoId', {}],
      ['a photoId that is not a UUID', { photoId: 'abc' }],
    ])('answers VALIDATION_FAILED for %s', async (_case, body) => {
      const session = await newSession();

      const response = await identify(session, body).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path: 'photoId' })],
      });
    });

    it('answers 401 without a session', async () => {
      await request(app.getHttpServer())
        .post('/v1/identifications')
        .send({ photoId: '01890000-0000-7000-8000-000000000000' })
        .expect(401);
    });
  });

  describe('POST /identifications/:id/choice', () => {
    it('adds a new species to the Catalog, with the external photo and no name', async () => {
      const session = await newSession();
      gbifKeys += 1;
      const first = candidateImage({ author: 'Pedro Alves' });
      plantIdentifier.answers(
        rawCandidate({ score: 0.6 }),
        rawCandidate({
          scientificName: 'Epipremnum pinnatum',
          commonNames: ['Jiboia'],
          score: 0.3,
          gbifKey: gbifKeys,
          images: [first, candidateImage()],
        }),
      );
      const identification = await identifyNewPhoto(session);

      const response = await choose(session, identification.id, {
        candidateIndex: 1,
      }).expect(200);

      const chosen = (response.body as { species: SpeciesItemBody }).species;
      expect(chosen).toEqual({
        id: expect.any(String) as string,
        commonName: 'Epipremnum pinnatum',
        scientificName: 'Epipremnum pinnatum',
        referencePhoto: first,
        matchedAlternativeName: null,
      });
      const [row] = await databaseOf(app)
        .select()
        .from(species)
        .where(eq(species.id, chosen.id));
      expect(row).toMatchObject({
        gbifKey: gbifKeys,
        origin: 'identification',
        referencePhotoUrl: first.url,
        referencePhotoS3Key: null,
      });
      const names = await databaseOf(app)
        .select()
        .from(speciesNames)
        .where(eq(speciesNames.speciesId, chosen.id));
      expect(names).toEqual([]);
      // It is now in the Catalog for everyone.
      const search = await request(app.getHttpServer())
        .get('/v1/species')
        .query({ q: 'pinnatum' })
        .set('Authorization', `Bearer ${session.accessToken}`)
        .expect(200);
      expect(search.body).toEqual([chosen]);
    });

    it('reuses the seed species with the same gbifKey', async () => {
      const session = await newSession();
      const seedId = await addSeedSpecies({
        scientificName: 'Monstera deliciosa',
        gbifKey: 2868241,
        primary: 'Costela-de-adão',
      });
      plantIdentifier.answers(
        rawCandidate({
          scientificName: 'Monstera deliciosa',
          gbifKey: 2868241,
        }),
      );
      const identification = await identifyNewPhoto(session);

      const response = await choose(session, identification.id, {
        candidateIndex: 0,
      }).expect(200);

      expect(response.body).toEqual({
        species: {
          id: seedId,
          commonName: 'Costela-de-adão',
          scientificName: 'Monstera deliciosa',
          referencePhoto: {
            url: `${FAKE_PHOTO_STORAGE_URL}/species/2868241.jpg`,
            author: 'Wikimedia author',
            license: 'CC BY-SA 4.0',
            sourceUrl: 'https://commons.wikimedia.org/wiki/File:x.jpg',
          },
          matchedAlternativeName: null,
        },
      });
      const rows = await databaseOf(app)
        .select()
        .from(species)
        .where(eq(species.gbifKey, 2868241));
      expect(rows).toHaveLength(1);
    });

    it('reuses the species a previous choice added', async () => {
      const session = await newSession();
      const first = await identifyNewPhoto(session);
      const second = await identifyNewPhoto(session);

      const a = await choose(session, first.id, { candidateIndex: 0 }).expect(
        200,
      );
      const b = await choose(session, second.id, { candidateIndex: 0 }).expect(
        200,
      );

      expect((b.body as { species: SpeciesItemBody }).species.id).toBe(
        (a.body as { species: SpeciesItemBody }).species.id,
      );
    });

    it('answers 204 for "nenhuma destas"', async () => {
      const session = await newSession();
      const identification = await identifyNewPhoto(session);

      await choose(session, identification.id, { none: true }).expect(204);

      const [row] = await databaseOf(app)
        .select()
        .from(identifications)
        .where(eq(identifications.id, identification.id));
      expect(row).toMatchObject({ chosenNone: true, chosenSpeciesId: null });
      expect(row?.chosenAt).toBeInstanceOf(Date);
    });

    it.each([
      ['a candidate', { candidateIndex: 0 }],
      ['"nenhuma destas"', { none: true }],
    ])(
      'answers IDENTIFICATION_ALREADY_CHOSEN after %s',
      async (_case, firstChoice) => {
        const session = await newSession();
        const identification = await identifyNewPhoto(session);
        await choose(session, identification.id, firstChoice).expect((res) => {
          expect([200, 204]).toContain(res.status);
        });

        const response = await choose(session, identification.id, {
          candidateIndex: 0,
        }).expect(409);

        expect(response.body).toMatchObject({
          code: 'IDENTIFICATION_ALREADY_CHOSEN',
        });
      },
    );

    it.each([
      ['an index past the candidates', { candidateIndex: 1 }],
      ['a negative index', { candidateIndex: -1 }],
      ['a fractional index', { candidateIndex: 0.5 }],
      ['neither field', {}],
      ['both fields', { candidateIndex: 0, none: true }],
      ['none: false', { none: false }],
    ])('answers VALIDATION_FAILED for %s', async (_case, body) => {
      const session = await newSession();
      const identification = await identifyNewPhoto(session);

      const response = await choose(session, identification.id, body).expect(
        400,
      );

      expect(response.body).toMatchObject({ code: 'VALIDATION_FAILED' });
      const [row] = await databaseOf(app)
        .select()
        .from(identifications)
        .where(eq(identifications.id, identification.id));
      expect(row?.chosenAt).toBeNull();
    });

    it('answers VALIDATION_FAILED for a photo that was not recognized', async () => {
      const session = await newSession();
      plantIdentifier.answers();
      const identification = await identifyNewPhoto(session);

      const response = await choose(session, identification.id, {
        candidateIndex: 0,
      }).expect(400);

      expect(response.body).toMatchObject({ code: 'VALIDATION_FAILED' });
    });

    it("answers NOT_FOUND for another User's identification", async () => {
      const owner = await newSession();
      const identification = await identifyNewPhoto(owner);
      const session = await newSession();

      const response = await choose(session, identification.id, {
        candidateIndex: 0,
      }).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
    });

    it('answers NOT_FOUND for an identification that does not exist', async () => {
      const session = await newSession();

      await choose(session, '01890000-0000-7000-8000-000000000000', {
        none: true,
      }).expect(404);
    });

    it('answers VALIDATION_FAILED for an id that is not a UUID', async () => {
      const session = await newSession();

      const response = await choose(session, 'abc', { none: true }).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path: 'id' })],
      });
    });
  });
});
