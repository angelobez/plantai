import type { INestApplication, LoggerService } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { eq, sql } from 'drizzle-orm';
import sharp from 'sharp';
import request from 'supertest';
import type { App } from 'supertest/types';
import {
  careGuides,
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
import {
  careGuideContent,
  FakeCareGuideWriter,
} from './support/fake-care-guide-writer';
import { FakeOutbox } from './support/fake-outbox';
import { FakePhotoStorage } from './support/fake-photo-storage';
import { startPostgis } from './support/postgis';

interface PhotoBody {
  id: string;
  url: string;
  expiresAt: string;
}

interface PlantItemBody {
  id: string;
  commonName: string;
  photo: PhotoBody;
  species: {
    id: string;
    commonName: string;
    scientificName: string;
    wateringSummary: string | null;
  } | null;
}

interface PlantBody {
  id: string;
  commonName: string;
  photo: PhotoBody;
  species: {
    id: string;
    commonName: string;
    scientificName: string;
    referencePhoto: { url: string; author: string };
    otherNames: string[];
    careGuide: { watering: { summary: string } } | null;
    careGuideStatus: string;
  } | null;
}

const UNKNOWN_ID = '01890000-0000-7000-8000-000000000000';

/** Keeps every log line so a test can read what the API logged. */
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

describe('plants (Meu jardim)', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const photoStorage = new FakePhotoStorage();
  const careGuideWriter = new FakeCareGuideWriter();
  const logger = new CapturingLogger();
  let gbifKeys = 7000;

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

  // Every test starts from an empty Catalog, so species names never clash.
  beforeEach(async () => {
    await databaseOf(app).execute(sql`TRUNCATE ${species} CASCADE`);
    careGuideWriter.failing = false;
    careGuideWriter.gate = undefined;
    careGuideWriter.requests.length = 0;
    photoStorage.failing = false;
    logger.lines.length = 0;
  });

  /** A new User, so each test has its own garden. */
  function newSession(): Promise<AuthTokensBody> {
    return signUpAndVerify(app, outbox);
  }

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

  /** The storage key behind a photo the API answered with. */
  function keyOf(photo: PhotoBody): string {
    return new URL(photo.url).pathname.slice(1);
  }

  /** A seed species with its primary name and an external photo. */
  async function addSpecies(
    scientificName: string,
    primary?: string,
  ): Promise<string> {
    const db = databaseOf(app);
    gbifKeys += 1;
    const [row] = await db
      .insert(species)
      .values({
        gbifKey: gbifKeys,
        scientificName,
        referencePhotoUrl: `https://upload.example.org/${String(gbifKeys)}.jpg`,
        referencePhotoAuthor: 'Ana Autora',
        referencePhotoLicense: 'CC BY-SA 4.0',
        referencePhotoSourceUrl: `https://commons.example.org/File:${String(gbifKeys)}`,
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

  function createPlant(session: AuthTokensBody, body: object): request.Test {
    return request(app.getHttpServer())
      .post('/v1/plants')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send(body);
  }

  /** Uploads a photo and saves a plant with it, expecting the `201`. */
  async function savePlant(
    session: AuthTokensBody,
    fields: { commonName: string; speciesId?: string },
  ): Promise<PlantItemBody> {
    const photo = await uploadPhoto(session);
    const response = await createPlant(session, {
      photoId: photo.id,
      ...fields,
    }).expect(201);
    return response.body as PlantItemBody;
  }

  function listPlants(session: AuthTokensBody): request.Test {
    return request(app.getHttpServer())
      .get('/v1/plants')
      .set('Authorization', `Bearer ${session.accessToken}`);
  }

  function getPlant(session: AuthTokensBody, id: string): request.Test {
    return request(app.getHttpServer())
      .get(`/v1/plants/${id}`)
      .set('Authorization', `Bearer ${session.accessToken}`);
  }

  function patchPlant(
    session: AuthTokensBody,
    id: string,
    body: object,
  ): request.Test {
    return request(app.getHttpServer())
      .patch(`/v1/plants/${id}`)
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send(body);
  }

  function deletePlant(session: AuthTokensBody, id: string): request.Test {
    return request(app.getHttpServer())
      .delete(`/v1/plants/${id}`)
      .set('Authorization', `Bearer ${session.accessToken}`);
  }

  /** A care guide row of [speciesId] in [status], as if already generated. */
  async function guideFor(
    speciesId: string,
    status: 'ready' | 'generating' | 'failed',
    wateringSummary = '1x por semana',
  ): Promise<void> {
    await databaseOf(app)
      .insert(careGuides)
      .values({
        speciesId,
        status,
        content:
          status === 'ready'
            ? careGuideContent({
                watering: { summary: wateringSummary, details: 'Regue.' },
              })
            : null,
        model: 'claude-sonnet-5-5',
        promptVersion: 1,
        startedAt: sql`now()`,
        generatedAt: status === 'ready' ? sql`now()` : null,
      });
  }

  describe('POST /plants', () => {
    it('saves the plant with its species and attaches the photo', async () => {
      const session = await newSession();
      const speciesId = await addSpecies('Epipremnum aureum', 'Jiboia');
      const photo = await uploadPhoto(session);

      const response = await createPlant(session, {
        photoId: photo.id,
        commonName: 'Jiboia',
        speciesId,
      }).expect(201);

      expect(response.body).toEqual({
        id: expect.any(String) as unknown,
        commonName: 'Jiboia',
        photo: {
          id: photo.id,
          url: FakePhotoStorage.urlOf(keyOf(photo)),
          expiresAt: expect.any(String) as unknown,
        },
        species: {
          id: speciesId,
          commonName: 'Jiboia',
          scientificName: 'Epipremnum aureum',
          wateringSummary: null,
        },
      });
      // The photo is the plant's now, and the lifecycle rule keeps it.
      expect(photoStorage.get(keyOf(photo))?.tags).toEqual({});
      const [row] = await databaseOf(app)
        .select({ plantId: photos.plantId, attachedAt: photos.attachedAt })
        .from(photos)
        .where(eq(photos.id, photo.id));
      expect(row?.plantId).toBe((response.body as PlantItemBody).id);
      expect(row?.attachedAt).toBeInstanceOf(Date);
    });

    it('saves a plant with only a name, trimmed', async () => {
      const session = await newSession();
      const photo = await uploadPhoto(session);

      const response = await createPlant(session, {
        photoId: photo.id,
        commonName: '  Pimenta da vó  ',
      }).expect(201);

      expect(response.body).toMatchObject({
        commonName: 'Pimenta da vó',
        species: null,
      });
    });

    it('does not have Claude write the care guide', async () => {
      const session = await newSession();
      const speciesId = await addSpecies('Dracaena trifasciata', 'Espada');

      await savePlant(session, { commonName: 'Espada', speciesId });

      expect(careGuideWriter.requests).toEqual([]);
    });

    it('answers VALIDATION_FAILED for a species that does not exist', async () => {
      const session = await newSession();
      const photo = await uploadPhoto(session);

      const response = await createPlant(session, {
        photoId: photo.id,
        commonName: 'Jiboia',
        speciesId: UNKNOWN_ID,
      }).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path: 'speciesId' })],
      });
      // Nothing was saved, and the photo is still unattached.
      expect((await listPlants(session).expect(200)).body).toEqual([]);
      expect(photoStorage.get(keyOf(photo))?.tags).toEqual({
        unattached: 'true',
      });
    });

    it.each([
      ['no commonName', {}, 'commonName'],
      ['an empty commonName', { commonName: '' }, 'commonName'],
      ['a blank commonName', { commonName: '   ' }, 'commonName'],
      ['a commonName over 80', { commonName: 'a'.repeat(81) }, 'commonName'],
      [
        'a speciesId that is not a UUID',
        { commonName: 'Jiboia', speciesId: 'abc' },
        'speciesId',
      ],
    ])('answers VALIDATION_FAILED for %s', async (_, fields, path) => {
      const session = await newSession();
      const photo = await uploadPhoto(session);

      const response = await createPlant(session, {
        photoId: photo.id,
        ...fields,
      }).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path })],
      });
    });

    it('accepts a commonName of 80 characters', async () => {
      const session = await newSession();

      const plant = await savePlant(session, { commonName: 'a'.repeat(80) });

      expect(plant.commonName).toHaveLength(80);
    });

    it.each([
      ['no photoId', {}],
      ['a photoId that is not a UUID', { photoId: 'abc' }],
    ])('answers VALIDATION_FAILED for %s', async (_, body) => {
      const session = await newSession();

      const response = await createPlant(session, {
        commonName: 'Jiboia',
        ...body,
      }).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path: 'photoId' })],
      });
    });

    it("answers NOT_FOUND for another User's photo", async () => {
      const owner = await newSession();
      const photo = await uploadPhoto(owner);
      const session = await newSession();

      const response = await createPlant(session, {
        photoId: photo.id,
        commonName: 'Jiboia',
      }).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
      expect(photoStorage.get(keyOf(photo))?.tags).toEqual({
        unattached: 'true',
      });
    });

    it('answers NOT_FOUND for a photo that does not exist', async () => {
      const session = await newSession();

      const response = await createPlant(session, {
        photoId: UNKNOWN_ID,
        commonName: 'Jiboia',
      }).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
    });

    it('answers VALIDATION_FAILED for a photo another plant already has', async () => {
      const session = await newSession();
      const photo = await uploadPhoto(session);
      await createPlant(session, {
        photoId: photo.id,
        commonName: 'Jiboia',
      }).expect(201);

      const response = await createPlant(session, {
        photoId: photo.id,
        commonName: 'Outra',
      }).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path: 'photoId' })],
      });
      expect((await listPlants(session).expect(200)).body).toHaveLength(1);
    });

    it('answers UNAUTHENTICATED without a session', async () => {
      await request(app.getHttpServer())
        .post('/v1/plants')
        .send({ photoId: UNKNOWN_ID, commonName: 'Jiboia' })
        .expect(401);
    });
  });

  describe('GET /plants', () => {
    it('answers an empty garden', async () => {
      const session = await newSession();

      const response = await listPlants(session).expect(200);

      expect(response.body).toEqual([]);
    });

    it('answers the plants newest first, with the watering summary', async () => {
      const session = await newSession();
      const jiboia = await addSpecies('Epipremnum aureum', 'Jiboia');
      await guideFor(jiboia, 'ready', 'A cada 3 dias');
      const espada = await addSpecies('Dracaena trifasciata', 'Espada');
      await guideFor(espada, 'failed');
      const novaSemNome = await addSpecies('Planta nova');
      await guideFor(novaSemNome, 'generating');

      const first = await savePlant(session, {
        commonName: 'Jiboia da sala',
        speciesId: jiboia,
      });
      await savePlant(session, { commonName: 'Espada', speciesId: espada });
      await savePlant(session, {
        commonName: 'Nova',
        speciesId: novaSemNome,
      });
      await savePlant(session, { commonName: 'Pimenta da vó' });

      const response = await listPlants(session).expect(200);
      const body = response.body as PlantItemBody[];

      expect(body.map((plant) => [plant.commonName, plant.species])).toEqual([
        ['Pimenta da vó', null],
        [
          'Nova',
          {
            id: novaSemNome,
            commonName: 'Planta nova',
            scientificName: 'Planta nova',
            wateringSummary: null,
          },
        ],
        [
          'Espada',
          {
            id: espada,
            commonName: 'Espada',
            scientificName: 'Dracaena trifasciata',
            wateringSummary: null,
          },
        ],
        [
          'Jiboia da sala',
          {
            id: jiboia,
            commonName: 'Jiboia',
            scientificName: 'Epipremnum aureum',
            wateringSummary: 'A cada 3 dias',
          },
        ],
      ]);
      // POST answers the same item, the summary included.
      expect({ ...body[3], photo: body[3]?.photo.id }).toEqual({
        ...first,
        photo: first.photo.id,
      });
      // The list never has Claude write a guide.
      expect(careGuideWriter.requests).toEqual([]);
    });

    it("does not show another User's plants", async () => {
      const owner = await newSession();
      await savePlant(owner, { commonName: 'Jiboia' });
      const session = await newSession();

      const response = await listPlants(session).expect(200);

      expect(response.body).toEqual([]);
    });

    it('answers UNAUTHENTICATED without a session', async () => {
      await request(app.getHttpServer()).get('/v1/plants').expect(401);
    });
  });

  describe('GET /plants/:id', () => {
    it('answers the plant with its species and the care guide Claude wrote', async () => {
      const session = await newSession();
      const speciesId = await addSpecies('Epipremnum aureum', 'Jiboia');
      const content = careGuideContent({ commonName: 'jiboia' });
      careGuideWriter.writes('Epipremnum aureum', content);
      const saved = await savePlant(session, {
        commonName: 'Jiboia da sala',
        speciesId,
      });

      const response = await getPlant(session, saved.id).expect(200);

      expect(response.body).toEqual({
        id: saved.id,
        commonName: 'Jiboia da sala',
        photo: {
          id: saved.photo.id,
          url: saved.photo.url,
          expiresAt: expect.any(String) as unknown,
        },
        species: {
          id: speciesId,
          commonName: 'Jiboia',
          scientificName: 'Epipremnum aureum',
          referencePhoto: {
            url: expect.stringMatching(
              /^https:\/\/upload\.example\.org\//,
            ) as unknown,
            author: 'Ana Autora',
            license: 'CC BY-SA 4.0',
            sourceUrl: expect.stringMatching(
              /^https:\/\/commons\.example\.org\//,
            ) as unknown,
          },
          otherNames: [],
          careGuide: content,
          careGuideStatus: 'ready',
        },
      });
      expect(careGuideWriter.asked).toEqual(['Epipremnum aureum']);
      const [guide] = await databaseOf(app)
        .select({ requestedBy: careGuides.requestedBy })
        .from(careGuides)
        .where(eq(careGuides.speciesId, speciesId));
      expect(guide?.requestedBy).toBe(session.user.id);
      // Now the list shows the watering summary too.
      const [item] = (await listPlants(session).expect(200))
        .body as PlantItemBody[];
      expect(item?.species?.wateringSummary).toBe(content.watering.summary);
    });

    it('shows a new species under the name Claude gave it', async () => {
      const session = await newSession();
      const speciesId = await addSpecies('Planta nova');
      careGuideWriter.writes(
        'Planta nova',
        careGuideContent({ commonName: 'planta-nova' }),
      );
      const saved = await savePlant(session, { commonName: 'Nova', speciesId });

      const response = await getPlant(session, saved.id).expect(200);

      expect((response.body as PlantBody).species?.commonName).toBe(
        'planta-nova',
      );
    });

    it('answers "unavailable" when Claude fails, without failing the plant', async () => {
      const session = await newSession();
      const speciesId = await addSpecies('Dracaena trifasciata', 'Espada');
      const saved = await savePlant(session, {
        commonName: 'Espada',
        speciesId,
      });
      careGuideWriter.failing = true;

      const response = await getPlant(session, saved.id).expect(200);

      expect((response.body as PlantBody).species).toMatchObject({
        careGuide: null,
        careGuideStatus: 'unavailable',
      });
    });

    it('answers 202 CARE_GUIDE_GENERATING while another request is generating', async () => {
      const session = await newSession();
      const speciesId = await addSpecies('Dracaena trifasciata', 'Espada');
      await guideFor(speciesId, 'generating');
      const saved = await savePlant(session, {
        commonName: 'Espada',
        speciesId,
      });

      const response = await getPlant(session, saved.id)
        .expect(202)
        .expect('Retry-After', '3')
        .expect('Content-Type', /^application\/problem\+json/);

      expect(response.body).toMatchObject({ code: 'CARE_GUIDE_GENERATING' });
      expect(careGuideWriter.requests).toEqual([]);
    });

    it('answers a plant saved with only a name, without asking Claude', async () => {
      const session = await newSession();
      const saved = await savePlant(session, { commonName: 'Pimenta da vó' });

      const response = await getPlant(session, saved.id).expect(200);

      expect(response.body).toEqual({
        id: saved.id,
        commonName: 'Pimenta da vó',
        photo: expect.objectContaining({ id: saved.photo.id }) as unknown,
        species: null,
      });
      expect(careGuideWriter.requests).toEqual([]);
    });

    it("answers NOT_FOUND for another User's plant", async () => {
      const owner = await newSession();
      const saved = await savePlant(owner, { commonName: 'Jiboia' });
      const session = await newSession();

      const response = await getPlant(session, saved.id).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
    });

    it('answers NOT_FOUND for a plant that does not exist', async () => {
      const session = await newSession();

      const response = await getPlant(session, UNKNOWN_ID).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
    });

    it('answers VALIDATION_FAILED for an id that is not a UUID', async () => {
      const session = await newSession();

      const response = await getPlant(session, 'abc').expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path: 'id' })],
      });
    });
  });

  describe('PATCH /plants/:id', () => {
    it('renames the plant, trimmed, and answers it as a list item', async () => {
      const session = await newSession();
      const speciesId = await addSpecies('Epipremnum aureum', 'Jiboia');
      const saved = await savePlant(session, {
        commonName: 'Jiboia',
        speciesId,
      });

      const response = await patchPlant(session, saved.id, {
        commonName: '  Jiboia da sala  ',
      }).expect(200);

      expect(response.body).toEqual({
        ...saved,
        commonName: 'Jiboia da sala',
        photo: { ...saved.photo, expiresAt: expect.any(String) as unknown },
      });
      const list = await listPlants(session).expect(200);
      expect(list.body).toEqual([
        expect.objectContaining({ id: saved.id, commonName: 'Jiboia da sala' }),
      ]);
    });

    it("answers NOT_FOUND for another User's plant, and keeps its name", async () => {
      const owner = await newSession();
      const saved = await savePlant(owner, { commonName: 'Jiboia' });
      const session = await newSession();

      const response = await patchPlant(session, saved.id, {
        commonName: 'Minha',
      }).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
      const plant = await getPlant(owner, saved.id).expect(200);
      expect(plant.body).toMatchObject({ commonName: 'Jiboia' });
    });

    it.each([
      ['an empty name', { commonName: '   ' }, 'commonName'],
      [
        'a name over 80 characters',
        { commonName: 'a'.repeat(81) },
        'commonName',
      ],
      ['no field', {}, ''],
    ])('answers VALIDATION_FAILED for %s', async (_case, body, path) => {
      const session = await newSession();
      const saved = await savePlant(session, { commonName: 'Jiboia' });

      const response = await patchPlant(session, saved.id, body).expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path })],
      });
    });
  });

  describe('DELETE /plants/:id', () => {
    it('removes the plant and its photo, from the database and the storage', async () => {
      const session = await newSession();
      const speciesId = await addSpecies('Epipremnum aureum', 'Jiboia');
      const saved = await savePlant(session, {
        commonName: 'Jiboia',
        speciesId,
      });
      const key = keyOf(saved.photo);
      expect(photoStorage.has(key)).toBe(true);

      await deletePlant(session, saved.id).expect(204);

      const response = await getPlant(session, saved.id).expect(404);
      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
      expect(photoStorage.has(key)).toBe(false);
      const list = await listPlants(session).expect(200);
      expect(list.body).toEqual([]);
      const rows = await databaseOf(app)
        .select({ id: photos.id })
        .from(photos)
        .where(eq(photos.id, saved.photo.id));
      expect(rows).toEqual([]);
    });

    it('still removes the plant when the storage fails, and logs the photo left behind', async () => {
      const session = await newSession();
      const saved = await savePlant(session, { commonName: 'Jiboia' });
      const key = keyOf(saved.photo);
      photoStorage.failing = true;

      await deletePlant(session, saved.id).expect(204);

      photoStorage.failing = false;
      await getPlant(session, saved.id).expect(404);
      expect(photoStorage.has(key)).toBe(true);
      expect(logger.lines.join('\n')).toContain(key);
    });

    it("answers NOT_FOUND for another User's plant, and keeps it", async () => {
      const owner = await newSession();
      const saved = await savePlant(owner, { commonName: 'Jiboia' });
      const session = await newSession();

      const response = await deletePlant(session, saved.id).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
      await getPlant(owner, saved.id).expect(200);
      expect(photoStorage.has(keyOf(saved.photo))).toBe(true);
    });

    it('answers NOT_FOUND for a plant that does not exist', async () => {
      const session = await newSession();

      const response = await deletePlant(session, UNKNOWN_ID).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
    });
  });
});
