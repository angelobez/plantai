import {
  type DynamicModule,
  type MiddlewareConsumer,
  Module,
  type NestModule,
} from '@nestjs/common';
import { AuthModule } from './auth/auth.module';
import { CatalogModule } from './catalog/catalog.module';
import { ConfigModule } from './config/config.module';
import type { Env } from './config/env';
import { DatabaseModule } from './database/database.module';
import { EmailModule } from './email/email.module';
import { GbifModule } from './gbif/gbif.module';
import { HealthModule } from './health/health.module';
import { AppVersionMiddleware } from './http/app-version.middleware';
import { RequestLoggerMiddleware } from './http/request-logger.middleware';
import { PhotoStorageModule } from './photo-storage/photo-storage.module';
import { PhotosModule } from './photos/photos.module';
import { ProfileModule } from './profile/profile.module';
import { UsersModule } from './users/users';

@Module({})
export class AppModule implements NestModule {
  static forRoot(env: Env): DynamicModule {
    return {
      module: AppModule,
      imports: [
        ConfigModule.forRoot(env),
        DatabaseModule,
        EmailModule,
        PhotoStorageModule,
        GbifModule,
        UsersModule,
        AuthModule,
        HealthModule,
        ProfileModule,
        PhotosModule,
        CatalogModule,
      ],
    };
  }

  configure(consumer: MiddlewareConsumer): void {
    // The logger goes first, so rejected requests are logged too.
    consumer
      .apply(RequestLoggerMiddleware, AppVersionMiddleware)
      .forRoutes('*path');
  }
}
