import {
  Global,
  Inject,
  Module,
  type OnApplicationShutdown,
} from '@nestjs/common';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env';
import { connectDatabase, type Database } from './connect';

export type { Database } from './connect';

/** Injection token for the Drizzle {@link Database}. */
export const DATABASE = Symbol('DATABASE');

@Global()
@Module({
  providers: [
    {
      provide: DATABASE,
      inject: [ENV],
      useFactory: (env: Env): Database => connectDatabase(env.DATABASE_URL),
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
