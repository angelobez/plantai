import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
import { species, speciesNames } from '../src/database/schema';
import { createTestApp } from './support/app';
import {
  type AuthTokensBody,
  databaseOf,
  signUpAndVerify,
} from './support/auth';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import { FakePhotoStorage } from './support/fake-photo-storage';
import { startPostgis } from './support/postgis';

interface ReferencePhotoBody {
  url: string;
  author: string;
  license: string;
  sourceUrl: string;
}

interface SpeciesItemBody {
  id: string;
  commonName: string;
  scientificName: string;
  referencePhoto: ReferencePhotoBody;
  matchedAlternativeName: string | null;
}

interface SpeciesBody {
  id: string;
  commonName: string;
  scientificName: string;
  referencePhoto: ReferencePhotoBody;
  otherNames: string[];
}

interface NewSpecies {
  scientificName: string;
  /** The primary name; none for a species that came from an identification. */
  primary?: string;
  others?: string[];
  /** Our own copy in the storage; without it, an external URL. */
  s3Key?: string;
}

describe('species (Catálogo)', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const photoStorage = new FakePhotoStorage();
  let session: AuthTokensBody;
  let gbifKeys = 1000;

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      photoStorage,
    });
    session = await signUpAndVerify(app, outbox);
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  // Every test starts from an empty Catalog, so results never mix.
  beforeEach(async () => {
    await databaseOf(app).execute(sql`TRUNCATE ${species} CASCADE`);
  });

  async function addSpecies({
    scientificName,
    primary,
    others = [],
    s3Key,
  }: NewSpecies): Promise<string> {
    const db = databaseOf(app);
    gbifKeys += 1;
    const [row] = await db
      .insert(species)
      .values({
        gbifKey: gbifKeys,
        scientificName,
        referencePhotoS3Key: s3Key ?? null,
        referencePhotoUrl: s3Key
          ? null
          : `https://upload.example.org/${String(gbifKeys)}.jpg`,
        referencePhotoAuthor: 'Ana Autora',
        referencePhotoLicense: 'CC BY-SA 4.0',
        referencePhotoSourceUrl: `https://commons.example.org/File:${String(gbifKeys)}`,
        origin: 'seed',
      })
      .returning();
    if (!row) throw new Error('no species');
    const names = [
      ...(primary ? [{ name: primary, isPrimary: true }] : []),
      ...others.map((name) => ({ name, isPrimary: false })),
    ];
    if (names.length > 0) {
      await db
        .insert(speciesNames)
        .values(names.map((name) => ({ speciesId: row.id, ...name })));
    }
    return row.id;
  }

  function search(q: string | undefined, auth = session): request.Test {
    const call = request(app.getHttpServer())
      .get('/v1/species')
      .set('Authorization', `Bearer ${auth.accessToken}`);
    return q === undefined ? call : call.query({ q });
  }

  async function found(q: string): Promise<SpeciesItemBody[]> {
    const response = await search(q).expect(200);
    return response.body as SpeciesItemBody[];
  }

  async function commonNamesFound(q: string): Promise<string[]> {
    return (await found(q)).map((item) => item.commonName);
  }

  function getSpecies(id: string): request.Test {
    return request(app.getHttpServer())
      .get(`/v1/species/${id}`)
      .set('Authorization', `Bearer ${session.accessToken}`);
  }

  describe('GET /species?q=', () => {
    it('answers each species with its names and reference photo', async () => {
      const id = await addSpecies({
        scientificName: 'Monstera deliciosa',
        primary: 'Costela-de-adão',
        others: ['banana-de-macaco'],
      });

      expect(await found('costela')).toEqual([
        {
          id,
          commonName: 'Costela-de-adão',
          scientificName: 'Monstera deliciosa',
          referencePhoto: {
            url: expect.stringMatching(
              /^https:\/\/upload\.example\.org\//,
            ) as string,
            author: 'Ana Autora',
            license: 'CC BY-SA 4.0',
            sourceUrl: expect.stringMatching(
              /^https:\/\/commons\.example\.org\//,
            ) as string,
          },
          matchedAlternativeName: null,
        },
      ]);
    });

    it.each([
      ['JIBOIA', 'capitals'],
      ['jibóia', 'an accent the name does not have'],
      ['Jibóia', 'both'],
    ])('ignores accents and capitals (%s: %s)', async (q) => {
      await addSpecies({
        scientificName: 'Epipremnum aureum',
        primary: 'jiboia',
      });
      await addSpecies({
        scientificName: 'Maranta leuconeura',
        primary: 'Maranta',
        others: ['Pé-de-Jibóia'],
      });

      expect(await commonNamesFound(q)).toEqual(['jiboia', 'Maranta']);
    });

    it('finds a species by a piece of its name', async () => {
      await addSpecies({
        scientificName: 'Monstera deliciosa',
        primary: 'Costela-de-adão',
      });

      expect(await commonNamesFound('de-ad')).toEqual(['Costela-de-adão']);
      expect(await commonNamesFound('  ADAO ')).toEqual(['Costela-de-adão']);
    });

    it('finds a species by its scientific name, accents and capitals aside', async () => {
      await addSpecies({
        scientificName: 'Monstera deliciosa',
        primary: 'Costela-de-adão',
        others: ['banana-de-macaco'],
      });

      const [item] = await found('DELICIOSA');
      expect(item?.commonName).toBe('Costela-de-adão');
      expect(item?.matchedAlternativeName).toBeNull();
      expect(await commonNamesFound('monstéra')).toEqual(['Costela-de-adão']);
    });

    it('tells which alternative name matched when neither the primary nor the scientific one did', async () => {
      await addSpecies({
        scientificName: 'Monstera deliciosa',
        primary: 'Costela-de-adão',
        others: ['banana-de-macaco', 'imbé-de-folha-furada'],
      });

      const [item] = await found('Banana-de-Macaco');
      expect(item).toMatchObject({
        commonName: 'Costela-de-adão',
        matchedAlternativeName: 'banana-de-macaco',
      });
      const [byPiece] = await found('macaco');
      expect(byPiece).toMatchObject({
        commonName: 'Costela-de-adão',
        matchedAlternativeName: 'banana-de-macaco',
      });
      const [byAccent] = await found('IMBE');
      expect(byAccent?.matchedAlternativeName).toBe('imbé-de-folha-furada');
    });

    it('leaves the alternative out when the primary name also matched', async () => {
      await addSpecies({
        scientificName: 'Dracaena trifasciata',
        primary: 'Espada-de-são-jorge',
        others: ['espada-de-santa-bárbara'],
      });

      const [item] = await found('espada');
      expect(item?.matchedAlternativeName).toBeNull();
    });

    it('answers one row per species, even when many of its names match', async () => {
      await addSpecies({
        scientificName: 'Epipremnum aureum',
        primary: 'jiboia',
        others: ['jiboia-amarela', 'jiboia-verde'],
      });

      expect(await commonNamesFound('jiboia')).toEqual(['jiboia']);
    });

    it('lists the names that start with the term first, then by primary name', async () => {
      await addSpecies({
        scientificName: 'Testus zebra',
        primary: 'Zebra-rosa',
      });
      await addSpecies({
        scientificName: 'Testus branca',
        primary: 'Rosa-branca',
      });
      await addSpecies({ scientificName: 'Testus amor', primary: 'Amor-rosa' });
      await addSpecies({
        scientificName: 'Testus begonia',
        primary: 'Begônia',
        others: ['rosa-de-pedra'],
      });
      await addSpecies({
        scientificName: 'Testus amarela',
        primary: 'Rosa-amarela',
      });

      expect(await commonNamesFound('rosa')).toEqual([
        'Begônia',
        'Rosa-amarela',
        'Rosa-branca',
        'Amor-rosa',
        'Zebra-rosa',
      ]);
    });

    it('sorts by the primary name without minding accents or capitals', async () => {
      await addSpecies({ scientificName: 'Testus b', primary: 'begônia-x' });
      await addSpecies({ scientificName: 'Testus a', primary: 'Áster-x' });
      await addSpecies({ scientificName: 'Testus c', primary: 'Cacto-x' });

      expect(await commonNamesFound('-x')).toEqual([
        'Áster-x',
        'begônia-x',
        'Cacto-x',
      ]);
    });

    it('answers at most 20 species', async () => {
      for (let index = 0; index < 25; index += 1) {
        await addSpecies({
          scientificName: `Testus number${String(index)}`,
          primary: `Planta ${String(index).padStart(2, '0')}`,
        });
      }

      const names = await commonNamesFound('planta');
      expect(names).toHaveLength(20);
      expect(names[0]).toBe('Planta 00');
      expect(names[19]).toBe('Planta 19');
    });

    it('shows the scientific name for a species without a primary name', async () => {
      await addSpecies({ scientificName: 'Calathea orbifolia' });

      expect(await found('orbifolia')).toEqual([
        expect.objectContaining({
          commonName: 'Calathea orbifolia',
          scientificName: 'Calathea orbifolia',
          matchedAlternativeName: null,
        }),
      ]);
    });

    it('presigns the reference photo kept in the storage', async () => {
      await addSpecies({
        scientificName: 'Epipremnum aureum',
        primary: 'jiboia',
        s3Key: 'species/jiboia.jpg',
      });

      const [item] = await found('jiboia');
      expect(item?.referencePhoto.url).toBe(
        FakePhotoStorage.urlOf('species/jiboia.jpg'),
      );
    });

    it('takes the wildcards of LIKE as plain characters', async () => {
      await addSpecies({
        scientificName: 'Epipremnum aureum',
        primary: 'jiboia',
      });

      expect(await found('%%')).toEqual([]);
      expect(await found('j_boia')).toEqual([]);
      expect(await found('\\%')).toEqual([]);
    });

    it('answers an empty list when nothing matches', async () => {
      await addSpecies({
        scientificName: 'Epipremnum aureum',
        primary: 'jiboia',
      });

      expect(await found('samambaia')).toEqual([]);
    });

    it.each([
      ['missing', undefined],
      ['empty', ''],
      ['one character', 'a'],
      ['one character among spaces', '  a  '],
      ['over 50 characters', 'a'.repeat(51)],
    ])('refuses a term that is %s', async (_, q) => {
      const response = await search(q)
        .expect(400)
        .expect('Content-Type', /^application\/problem\+json/);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path: 'q' })],
      });
    });

    it('accepts 50 characters after the trim', async () => {
      await search(`  ${'a'.repeat(50)}  `).expect(200);
    });

    it('needs a session', async () => {
      await request(app.getHttpServer())
        .get('/v1/species')
        .query({ q: 'jiboia' })
        .expect(401);
    });
  });

  describe('GET /species/:id', () => {
    it('answers the species with its other names in alphabetical order', async () => {
      const id = await addSpecies({
        scientificName: 'Monstera deliciosa',
        primary: 'Costela-de-adão',
        others: ['imbé-de-folha-furada', 'banana-de-macaco'],
        s3Key: 'species/monstera.jpg',
      });

      const response = await getSpecies(id).expect(200);

      expect(response.body as SpeciesBody).toEqual({
        id,
        commonName: 'Costela-de-adão',
        scientificName: 'Monstera deliciosa',
        referencePhoto: {
          url: FakePhotoStorage.urlOf('species/monstera.jpg'),
          author: 'Ana Autora',
          license: 'CC BY-SA 4.0',
          sourceUrl: expect.stringMatching(
            /^https:\/\/commons\.example\.org\//,
          ) as string,
        },
        otherNames: ['banana-de-macaco', 'imbé-de-folha-furada'],
      });
    });

    it('shows an external reference photo by its own URL', async () => {
      const id = await addSpecies({
        scientificName: 'Epipremnum aureum',
        primary: 'jiboia',
      });

      const response = await getSpecies(id).expect(200);

      expect((response.body as SpeciesBody).referencePhoto.url).toMatch(
        /^https:\/\/upload\.example\.org\//,
      );
    });

    it('shows the scientific name for a species without a primary name', async () => {
      const id = await addSpecies({ scientificName: 'Calathea orbifolia' });

      const response = await getSpecies(id).expect(200);

      expect(response.body).toMatchObject({
        commonName: 'Calathea orbifolia',
        otherNames: [],
      });
    });

    it('answers NOT_FOUND for a species that does not exist', async () => {
      const response = await getSpecies(
        '01890a5d-ac96-774b-bcce-b302099a8057',
      ).expect(404);

      expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
    });

    it('refuses an id that is not a UUID', async () => {
      const response = await getSpecies('jiboia').expect(400);

      expect(response.body).toMatchObject({
        code: 'VALIDATION_FAILED',
        errors: [expect.objectContaining({ path: 'id' })],
      });
    });
  });
});
