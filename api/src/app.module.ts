import { type DynamicModule, Module } from '@nestjs/common';
import { ConfigModule } from './config/config.module';
import type { Env } from './config/env';
import { DatabaseModule } from './database/database.module';
import { HealthModule } from './health/health.module';

@Module({})
export class AppModule {
  static forRoot(env: Env): DynamicModule {
    return {
      module: AppModule,
      imports: [ConfigModule.forRoot(env), DatabaseModule, HealthModule],
    };
  }
}
