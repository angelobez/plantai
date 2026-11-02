import { drizzle, type PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema';

export type Database = PostgresJsDatabase<typeof schema> & {
  $client: postgres.Sql;
};

/**
 * Connects Drizzle to [url], with the schema. Shared by the API
 * (`DatabaseModule`) and the maintenance routine, which runs without Nest.
 * Close it with `db.$client.end()`.
 */
export function connectDatabase(
  url: string,
  options: postgres.Options<Record<string, postgres.PostgresType>> = {},
): Database {
  return drizzle(
    postgres(url, {
      // Fail fast when the database is down instead of hanging.
      connect_timeout: 5,
      onnotice: () => undefined,
      ...options,
    }),
    { schema },
  );
}
