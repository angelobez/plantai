import {
  PostgreSqlContainer,
  type StartedPostgreSqlContainer,
} from '@testcontainers/postgresql';
import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import postgres from 'postgres';

// Keep in sync with the image in compose.yaml.
const POSTGIS_IMAGE = 'postgis/postgis:17-3.5';

/** Starts a throwaway PostGIS with every migration applied. */
export async function startPostgis(): Promise<StartedPostgreSqlContainer> {
  const container = await new PostgreSqlContainer(POSTGIS_IMAGE).start();

  const client = postgres(container.getConnectionUri(), {
    max: 1,
    onnotice: () => undefined,
  });
  try {
    await migrate(drizzle(client), { migrationsFolder: 'drizzle' });
  } finally {
    await client.end();
  }
  return container;
}
