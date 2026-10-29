import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { asc, eq, sql } from 'drizzle-orm';
import request from 'supertest';
import type { App } from 'supertest/types';
import { careGuides, species, speciesNames } from '../src/database/schema';
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
import { startPostgis } from './support/postgis';

interface SpeciesBody {
  id: string;
  commonName: string;
  otherNames: string[];
  careGuide: unknown;
  careGuideStatus: string;
}

describe('care guides (Dicas de cuidado) in GET /species/:id', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  let writer: FakeCareGuideWriter;
  let session: AuthTokensBody;
  let gbifKeys = 5000;

  beforeAll(async () => {
    container = await startPostgis();
    writer = new FakeCareGuideWriter();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      careGuideWriter: writer,
    });
    session = await signUpAndVerify(app, outbox);
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  beforeEach(async () => {
    await databaseOf(app).execute(sql`TRUNCATE ${species} CASCADE`);
    writer.requests.length = 0;
    writer.failing = false;
    writer.gate = undefined;
  });

  async function addSpecies(
    scientificName: string,
    { primary, others = [] }: { primary?: string; others?: string[] } = {},
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
        origin: primary ? 'seed' : 'identification',
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

  function getSpecies(id: string): request.Test {
    return request(app.getHttpServer())
      .get(`/v1/species/${id}`)
      .set('Authorization', `Bearer ${session.accessToken}`);
  }

  async function guideRow(speciesId: string) {
    const [row] = await databaseOf(app)
      .select()
      .from(careGuides)
      .where(eq(careGuides.speciesId, speciesId));
    return row;
  }

  async function namesOf(speciesId: string) {
    return databaseOf(app)
      .select({ name: speciesNames.name, isPrimary: speciesNames.isPrimary })
      .from(speciesNames)
      .where(eq(speciesNames.speciesId, speciesId))
      .orderBy(asc(speciesNames.name));
  }

  /** A `generating` row started [secondsAgo] seconds ago. */
  async function generatingSince(speciesId: string, secondsAgo: number) {
    await databaseOf(app)
      .insert(careGuides)
      .values({
        speciesId,
        status: 'generating',
        model: 'claude-sonnet-5-5',
        promptVersion: 1,
        startedAt: sql`now() - make_interval(secs => ${secondsAgo})`,
      });
  }

  it('generates the care guide on the first opening and answers it', async () => {
    const id = await addSpecies('Monstera deliciosa', {
      primary: 'costela-de-adão',
      others: ['banana-de-macaco'],
    });
    const content = careGuideContent({ commonName: 'costela-de-adão' });
    writer.writes('Monstera deliciosa', content);

    const response = await getSpecies(id).expect(200);

    expect(response.body).toMatchObject({
      careGuide: content,
      careGuideStatus: 'ready',
    });
    expect(writer.requests).toEqual([
      {
        scientificName: 'Monstera deliciosa',
        knownNames: ['costela-de-adão', 'banana-de-macaco'],
      },
    ]);
  });

  it('answers the stored guide from the second opening on, without asking Claude', async () => {
    const id = await addSpecies('Monstera deliciosa', {
      primary: 'costela-de-adão',
    });
    const first = await getSpecies(id).expect(200);

    const second = await getSpecies(id).expect(200);

    expect((second.body as SpeciesBody).careGuide).toEqual(
      (first.body as SpeciesBody).careGuide,
    );
    expect(writer.requests).toHaveLength(1);
  });

  it('keeps who caused the generation, the model, the prompt version and when', async () => {
    const id = await addSpecies('Monstera deliciosa', {
      primary: 'costela-de-adão',
    });

    await getSpecies(id).expect(200);

    const row = await guideRow(id);
    expect(row).toMatchObject({
      status: 'ready',
      model: 'fake-care-guide-model',
      promptVersion: 1,
      requestedBy: session.user.id,
      content: careGuideContent({ commonName: 'costela-de-adão' }),
    });
    expect(row?.generatedAt).toBeInstanceOf(Date);
  });

  it('answers "unavailable" when Claude fails, and the next opening tries again', async () => {
    const id = await addSpecies('Monstera deliciosa', {
      primary: 'costela-de-adão',
    });
    writer.failing = true;

    const failed = await getSpecies(id).expect(200);

    expect(failed.body).toMatchObject({
      commonName: 'costela-de-adão',
      careGuide: null,
      careGuideStatus: 'unavailable',
    });
    expect((await guideRow(id))?.status).toBe('failed');

    writer.failing = false;
    const retried = await getSpecies(id).expect(200);

    expect(retried.body).toMatchObject({ careGuideStatus: 'ready' });
    expect(writer.requests).toHaveLength(2);
  });

  it('answers 202 CARE_GUIDE_GENERATING while another request is generating', async () => {
    const id = await addSpecies('Monstera deliciosa', {
      primary: 'costela-de-adão',
    });
    let release = (): void => undefined;
    writer.gate = new Promise((resolve) => {
      release = resolve;
    });
    const first = getSpecies(id).then((response) => response);
    await waitFor(async () => (await guideRow(id))?.status === 'generating');

    const second = await getSpecies(id).expect(202);

    expect(second.headers['retry-after']).toBe('3');
    expect(second.headers['content-type']).toMatch(
      /application\/problem\+json/,
    );
    expect(second.body).toMatchObject({
      status: 202,
      code: 'CARE_GUIDE_GENERATING',
    });
    release();
    expect((await first).status).toBe(200);
    expect(writer.requests).toHaveLength(1);
  });

  it('answers 202 for a recent "generating" row, without asking Claude', async () => {
    const id = await addSpecies('Monstera deliciosa', {
      primary: 'costela-de-adão',
    });
    await generatingSince(id, 10);

    await getSpecies(id).expect(202);

    expect(writer.requests).toHaveLength(0);
  });

  it('generates again when a "generating" row is older than 60 s', async () => {
    const id = await addSpecies('Monstera deliciosa', {
      primary: 'costela-de-adão',
    });
    await generatingSince(id, 61);

    const response = await getSpecies(id).expect(200);

    expect(response.body).toMatchObject({ careGuideStatus: 'ready' });
    expect(writer.requests).toHaveLength(1);
    expect((await guideRow(id))?.requestedBy).toBe(session.user.id);
  });

  it("makes Claude's common name the primary one of a species that has none", async () => {
    const id = await addSpecies('Calathea orbifolia');
    writer.writes(
      'Calathea orbifolia',
      careGuideContent({ commonName: 'calateia-orbifólia' }),
    );

    const response = await getSpecies(id).expect(200);

    expect(writer.requests[0]?.knownNames).toEqual([]);
    expect(response.body).toMatchObject({
      commonName: 'calateia-orbifólia',
      otherNames: [],
    });
    expect(await namesOf(id)).toEqual([
      { name: 'calateia-orbifólia', isPrimary: true },
    ]);
  });

  it("adds Claude's common name as an alternative one when it differs from the primary", async () => {
    const id = await addSpecies('Epipremnum aureum', {
      primary: 'jiboia',
      others: ['hera-do-diabo'],
    });
    writer.writes(
      'Epipremnum aureum',
      careGuideContent({ commonName: 'jiboia-dourada' }),
    );

    const response = await getSpecies(id).expect(200);

    expect(response.body).toMatchObject({
      commonName: 'jiboia',
      otherNames: ['hera-do-diabo', 'jiboia-dourada'],
    });
  });

  it("adds no name when Claude's is one the species has, accents and capitals aside", async () => {
    const id = await addSpecies('Monstera deliciosa', {
      primary: 'costela-de-adão',
    });
    writer.writes(
      'Monstera deliciosa',
      careGuideContent({ commonName: 'Costela-de-Adao' }),
    );

    await getSpecies(id).expect(200);

    expect(await namesOf(id)).toEqual([
      { name: 'costela-de-adão', isPrimary: true },
    ]);
  });

  it("promotes an alternative name equal to Claude's when there is no primary", async () => {
    const id = await addSpecies('Calathea orbifolia', {
      others: ['calateia'],
    });
    writer.writes(
      'Calathea orbifolia',
      careGuideContent({ commonName: 'Calateia' }),
    );

    await getSpecies(id).expect(200);

    expect(await namesOf(id)).toEqual([{ name: 'calateia', isPrimary: true }]);
  });

  it('answers NOT_FOUND without asking Claude for a species that does not exist', async () => {
    await getSpecies('01890a5d-ac96-774b-bcce-b302099a8057').expect(404);

    expect(writer.requests).toHaveLength(0);
  });
});

/** Polls [condition] until it holds (at most ~5 s). */
async function waitFor(condition: () => Promise<boolean>): Promise<void> {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (await condition()) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error('The condition never held');
}
