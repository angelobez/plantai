import {
  Global,
  Inject,
  Module,
  type OnApplicationShutdown,
} from '@nestjs/common';
import { drizzle, type PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env';
import * as schema from './schema';

export type Database = PostgresJsDatabase<typeof schema> & {
  $client: postgres.Sql;
};

/** Injection token for the Drizzle {@link Database}. */
export const DATABASE = Symbol('DATABASE');

@Global()
@Module({
  providers: [
    {
      provide: DATABASE,
      inject: [ENV],
      useFactory: (env: Env): Database =>
        drizzle(
          postgres(env.DATABASE_URL, {
            // Fail fast when the database is down instead of hanging requests.
            connect_timeout: 5,
            onnotice: () => undefined,
          }),
          { schema },
        ),
    },
  ],
  exports: [DATABASE],
})
export class DatabaseModule implements OnApplicationShutdown {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async onApplicationShutdown(): Promise<void> {
    await this.db.$client.end();
  }
}
