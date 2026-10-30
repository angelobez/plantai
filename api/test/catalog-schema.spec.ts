import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import type { Database } from '../src/database/database.module';
import * as schema from '../src/database/schema';
import { startPostgis } from './support/postgis';

// The Catalog has no routes yet (the search comes later), so these check the
// constraints the migration promises straight in the database.
describe('Catalog schema', () => {
  let container: StartedPostgreSqlContainer;
  let db: Database;
  let gbifKeys = 1000;

  beforeAll(async () => {
    container = await startPostgis();
    db = drizzle(
      postgres(container.getConnectionUri(), { onnotice: () => undefined }),
      { schema },
    );
  });

  afterAll(async () => {
    await db.$client.end();
    await container.stop();
  });

  function newSpecies(
    photo: { referencePhotoS3Key?: string; referencePhotoUrl?: string } = {
      referencePhotoUrl: 'https://example.org/photo.jpg',
    },
  ) {
    gbifKeys += 1;
    return db
      .insert(schema.species)
      .values({
        gbifKey: gbifKeys,
        scientificName: `Testus species${String(gbifKeys)}`,
        referencePhotoAuthor: 'Autor',
        referencePhotoLicense: 'CC BY 4.0',
        referencePhotoSourceUrl: 'https://example.org/file',
        origin: 'seed',
        ...photo,
      })
      .returning();
  }

  async function speciesId(): Promise<string> {
    const [row] = await newSpecies();
    if (!row) throw new Error('no species');
    return row.id;
  }

  it('normalizes the names without accents or capitals', async () => {
    const id = await speciesId();
    const [row] = await db
      .insert(schema.speciesNames)
      .values({ speciesId: id, name: 'Costela-de-Adão Jibóia' })
      .returning();

    expect(row?.nameNormalized).toBe('costela-de-adao jiboia');
  });

  it('keeps a single primary name per species', async () => {
    const id = await speciesId();
    await db
      .insert(schema.speciesNames)
      .values({ speciesId: id, name: 'jiboia', isPrimary: true });

    await expect(
      db
        .insert(schema.speciesNames)
        .values({ speciesId: id, name: 'hera-do-diabo', isPrimary: true }),
    ).rejects.toThrow();
  });

  it('requires exactly one of the two reference photo fields', async () => {
    await expect(newSpecies({})).rejects.toThrow();
    await expect(
      newSpecies({
        referencePhotoS3Key: 'species/x.jpg',
        referencePhotoUrl: 'https://example.org/photo.jpg',
      }),
    ).rejects.toThrow();
    await expect(
      newSpecies({ referencePhotoS3Key: 'species/x.jpg' }),
    ).resolves.toHaveLength(1);
  });
});
