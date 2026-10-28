import {
  type DynamicModule,
  type MiddlewareConsumer,
  Module,
  type NestModule,
} from '@nestjs/common';
import { ConfigModule } from './config/config.module';
import type { Env } from './config/env';
import { DatabaseModule } from './database/database.module';
import { HealthModule } from './health/health.module';
import { AppVersionMiddleware } from './http/app-version.middleware';
import { RequestLoggerMiddleware } from './http/request-logger.middleware';

@Module({})
export class AppModule implements NestModule {
  static forRoot(env: Env): DynamicModule {
    return {
      module: AppModule,
      imports: [ConfigModule.forRoot(env), DatabaseModule, HealthModule],
    };
  }

  configure(consumer: MiddlewareConsumer): void {
    // The logger goes first, so rejected requests are logged too.
    consumer
      .apply(RequestLoggerMiddleware, AppVersionMiddleware)
      .forRoutes('*path');
  }
}
