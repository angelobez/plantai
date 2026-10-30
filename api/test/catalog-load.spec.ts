import type { INestApplicationContext } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { asc, eq } from 'drizzle-orm';
import postgres from 'postgres';
import sharp from 'sharp';
import { CatalogLoader } from '../src/catalog/catalog-loader';
import type { CatalogSeedSpecies } from '../src/catalog/catalog-seed';
import { DATABASE, type Database } from '../src/database/database.module';
import { careGuides, species, speciesNames } from '../src/database/schema';
import { createTestCatalogLoad } from './support/catalog-load';
import { testEnv } from './support/env';
import {
  careGuideContent,
  FakeCareGuideWriter,
} from './support/fake-care-guide-writer';
import { FakePhotoStorage } from './support/fake-photo-storage';
import { FakeReferencePhotoDownloader } from './support/fake-reference-photo-downloader';
import { startPostgis } from './support/postgis';

const jiboia: CatalogSeedSpecies = {
  gbifKey: 2868323,
  scientificName: 'Epipremnum aureum',
  commonName: 'jiboia',
  otherNames: ['hera-do-diabo', 'jiboia-amarela'],
  referencePhoto: {
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Epipremnum.jpg',
    imageUrl: 'https://upload.wikimedia.org/epipremnum.jpg',
    author: 'Forest & Kim Starr',
    license: 'CC BY 3.0',
  },
};

const avenca: CatalogSeedSpecies = {
  gbifKey: 2651826,
  scientificName: 'Adiantum raddianum',
  commonName: 'avenca',
  otherNames: [],
  referencePhoto: {
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Adiantum.jpg',
    imageUrl: 'https://upload.wikimedia.org/adiantum.jpg',
    author: 'ZSM',
    license: 'CC BY-SA 4.0',
  },
};

const seed = [jiboia, avenca];

/** A real JPEG, larger than what the Catalog keeps. */
function photo(width: number, height: number): Promise<Buffer> {
  return sharp({
    create: { width, height, channels: 3, background: '#2e7d32' },
  })
    .jpeg()
    .toBuffer();
}

describe('catalog load (npm run catalog:load)', () => {
  let container: StartedPostgreSqlContainer;

  beforeAll(async () => {
    container = await startPostgis();
  });

  afterAll(async () => {
    await container.stop();
  });

  let context: INestApplicationContext;
  let db: Database;
  let photoStorage: FakePhotoStorage;
  let photoDownloader: FakeReferencePhotoDownloader;
  let careGuideWriter: FakeCareGuideWriter;

  // Every test starts from an empty Catalog in its own database.
  beforeEach(async () => {
    const name = `catalog_${String(Date.now())}`;
    const admin = postgres(container.getConnectionUri(), {
      max: 1,
      onnotice: () => undefined,
    });
    await admin.unsafe(
      `CREATE DATABASE ${name} TEMPLATE ${container.getDatabase()}`,
    );
    await admin.end();
    const url = new URL(container.getConnectionUri());
    url.pathname = `/${name}`;

    photoStorage = new FakePhotoStorage();
    photoDownloader = new FakeReferencePhotoDownloader()
      .serves(jiboia.referencePhoto.imageUrl, await photo(2400, 1600))
      .serves(avenca.referencePhoto.imageUrl, await photo(800, 1000));
    careGuideWriter = new FakeCareGuideWriter();
    context = await createTestCatalogLoad(testEnv(url.toString()), {
      photoStorage,
      photoDownloader,
      careGuideWriter,
    });
    db = context.get<Database>(DATABASE);
  });

  afterEach(async () => {
    await context.close();
  });

  const load = (items = seed) => context.get(CatalogLoader).load(items);

  async function speciesRow(gbifKey: number) {
    const row = await db.query.species.findFirst({
      where: eq(species.gbifKey, gbifKey),
    });
    if (!row) throw new Error(`no species ${String(gbifKey)}`);
    return row;
  }

  async function namesOf(gbifKey: number) {
    const { id } = await speciesRow(gbifKey);
    return db
      .select({ name: speciesNames.name, isPrimary: speciesNames.isPrimary })
      .from(speciesNames)
      .where(eq(speciesNames.speciesId, id))
      .orderBy(asc(speciesNames.name));
  }

  it('creates each species from the seed, with its names', async () => {
    const summary = await load();

    expect(summary).toMatchObject({ species: 2, newSpecies: 2, failures: [] });
    expect(await speciesRow(jiboia.gbifKey)).toMatchObject({
      scientificName: 'Epipremnum aureum',
      origin: 'seed',
      referencePhotoAuthor: 'Forest & Kim Starr',
      referencePhotoLicense: 'CC BY 3.0',
      referencePhotoSourceUrl:
        'https://commons.wikimedia.org/wiki/File:Epipremnum.jpg',
    });
    expect(await namesOf(jiboia.gbifKey)).toEqual([
      { name: 'hera-do-diabo', isPrimary: false },
      { name: 'jiboia', isPrimary: true },
      { name: 'jiboia-amarela', isPrimary: false },
    ]);
  });

  it('copies each reference photo to the storage, untagged and at most 1200 px', async () => {
    const summary = await load();

    expect(summary.photosCopied).toBe(2);
    const row = await speciesRow(jiboia.gbifKey);
    expect(row.referencePhotoUrl).toBeNull();
    const stored = photoStorage.get(row.referencePhotoS3Key ?? '');
    expect(stored?.tags).toEqual({});
    const size = await sharp(stored?.bytes).metadata();
    expect([size.width, size.height, size.format]).toEqual([1200, 800, 'jpeg']);

    // A photo already smaller than that is not enlarged.
    const small = await speciesRow(avenca.gbifKey);
    const smallSize = await sharp(
      photoStorage.get(small.referencePhotoS3Key ?? '')?.bytes,
    ).metadata();
    expect([smallSize.width, smallSize.height]).toEqual([800, 1000]);
  });

  it('duplicates nothing when it runs again', async () => {
    await load();
    const firstNames = await namesOf(jiboia.gbifKey);
    const firstKeys = photoStorage.keys();
    photoDownloader.downloaded.length = 0;

    const summary = await load();

    expect(summary).toMatchObject({
      species: 2,
      newSpecies: 0,
      photosCopied: 0,
      failures: [],
    });
    expect(await db.$count(species)).toBe(2);
    expect(await namesOf(jiboia.gbifKey)).toEqual(firstNames);
    expect(photoStorage.keys()).toEqual(firstKeys);
    expect(photoDownloader.downloaded).toEqual([]);
  });

  it('copies on the next run a photo that failed, showing the original meanwhile', async () => {
    photoDownloader.forget(avenca.referencePhoto.imageUrl);

    const first = await load();

    expect(first.photosCopied).toBe(1);
    expect(first.failures).toEqual([
      {
        scientificName: 'Adiantum raddianum',
        step: 'photo',
        reason: `HTTP 404 for ${avenca.referencePhoto.imageUrl}`,
      },
    ]);
    expect(await speciesRow(avenca.gbifKey)).toMatchObject({
      referencePhotoS3Key: null,
      referencePhotoUrl: avenca.referencePhoto.imageUrl,
    });

    photoDownloader.serves(
      avenca.referencePhoto.imageUrl,
      await photo(500, 500),
    );
    const second = await load();

    expect(second).toMatchObject({ photosCopied: 1, failures: [] });
    const row = await speciesRow(avenca.gbifKey);
    expect(row.referencePhotoUrl).toBeNull();
    expect(photoStorage.has(row.referencePhotoS3Key ?? '')).toBe(true);
  });

  it("brings back the seed's primary name over one Claude made primary", async () => {
    await load();
    const { id } = await speciesRow(jiboia.gbifKey);
    // As if a care guide had named it before the seed did.
    await db
      .update(speciesNames)
      .set({ isPrimary: false })
      .where(eq(speciesNames.speciesId, id));
    await db
      .insert(speciesNames)
      .values({ speciesId: id, name: 'jiboia-verde', isPrimary: true });

    await load();

    expect(await namesOf(jiboia.gbifKey)).toEqual([
      { name: 'hera-do-diabo', isPrimary: false },
      { name: 'jiboia', isPrimary: true },
      { name: 'jiboia-amarela', isPrimary: false },
      { name: 'jiboia-verde', isPrimary: false },
    ]);
  });

  it('makes a corrected primary name primary, keeping the old one as an alternative', async () => {
    await load();

    // The seed's primary name was corrected by hand (seed-overrides.json).
    await load([
      {
        ...jiboia,
        commonName: 'jiboia-amarela',
        otherNames: ['jiboia', 'hera-do-diabo'],
      },
      avenca,
    ]);

    expect(await namesOf(jiboia.gbifKey)).toEqual([
      { name: 'hera-do-diabo', isPrimary: false },
      { name: 'jiboia', isPrimary: false },
      { name: 'jiboia-amarela', isPrimary: true },
    ]);
  });

  it('keeps going when a photo cannot be decoded', async () => {
    photoDownloader.serves(
      jiboia.referencePhoto.imageUrl,
      Buffer.from('<html>not an image</html>'),
    );

    const summary = await load();

    expect(summary.photosCopied).toBe(1);
    expect(summary.failures).toMatchObject([
      { scientificName: 'Epipremnum aureum', step: 'photo' },
    ]);
  });

  describe('care guides', () => {
    async function guideOf(gbifKey: number) {
      const { id } = await speciesRow(gbifKey);
      const [row] = await db
        .select()
        .from(careGuides)
        .where(eq(careGuides.speciesId, id));
      return row;
    }

    it('writes the care guide of each species, caused by no User', async () => {
      const summary = await load();

      expect(summary).toMatchObject({ careGuidesGenerated: 2, failures: [] });
      expect(careGuideWriter.asked.sort()).toEqual([
        'Adiantum raddianum',
        'Epipremnum aureum',
      ]);
      expect(await guideOf(jiboia.gbifKey)).toMatchObject({
        status: 'ready',
        requestedBy: null,
        promptVersion: 1,
        content: careGuideContent({ commonName: 'jiboia' }),
      });
    });

    it('does not ask Claude again on the next run', async () => {
      await load();
      careGuideWriter.requests.length = 0;

      const summary = await load();

      expect(summary.careGuidesGenerated).toBe(0);
      expect(careGuideWriter.requests).toEqual([]);
    });

    it('writes on the next run a care guide that failed', async () => {
      careGuideWriter.failingFor.add('Adiantum raddianum');

      const first = await load();

      expect(first.careGuidesGenerated).toBe(1);
      expect(first.failures).toEqual([
        {
          scientificName: 'Adiantum raddianum',
          step: 'careGuide',
          reason: 'The fake Claude is down',
        },
      ]);
      expect((await guideOf(avenca.gbifKey))?.status).toBe('failed');

      careGuideWriter.failingFor.clear();
      careGuideWriter.requests.length = 0;
      const second = await load();

      expect(second).toMatchObject({ careGuidesGenerated: 1, failures: [] });
      expect(careGuideWriter.asked).toEqual(['Adiantum raddianum']);
      expect((await guideOf(avenca.gbifKey))?.status).toBe('ready');
    });

    it("keeps the seed's primary name, with Claude's as an alternative one", async () => {
      careGuideWriter.writes(
        'Epipremnum aureum',
        careGuideContent({ commonName: 'jiboia-dourada' }),
      );

      await load();

      expect(await namesOf(jiboia.gbifKey)).toEqual([
        { name: 'hera-do-diabo', isPrimary: false },
        { name: 'jiboia', isPrimary: true },
        { name: 'jiboia-amarela', isPrimary: false },
        { name: 'jiboia-dourada', isPrimary: false },
      ]);
    });

    it('asks Claude for at most 3 care guides at once', async () => {
      const many = Array.from({ length: 7 }, (_, index) => ({
        ...avenca,
        gbifKey: 9000 + index,
        scientificName: `Adiantum species${String(index)}`,
        commonName: `avenca-${String(index)}`,
      }));
      careGuideWriter.delayMs = 100;

      const summary = await load(many);

      expect(summary.careGuidesGenerated).toBe(7);
      expect(careGuideWriter.maxConcurrent).toBe(3);
    });
  });
});
