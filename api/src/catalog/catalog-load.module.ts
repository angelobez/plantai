import { type DynamicModule, Module } from '@nestjs/common';
import { CareGuidesModule } from '../care-guides/care-guides.module';
import { ConfigModule } from '../config/config.module';
import type { Env } from '../config/env';
import { DatabaseModule } from '../database/database.module';
import { PhotoStorageModule } from '../photo-storage/photo-storage.module';
import { CatalogLoader } from './catalog-loader';
import {
  HttpReferencePhotoDownloader,
  ReferencePhotoDownloader,
} from './reference-photo-downloader';

/**
 * Only what `npm run catalog:load` needs (database, photo storage, the
 * Wikimedia download, the care guides), without the HTTP server or the rest of the API.
 */
@Module({})
export class CatalogLoadModule {
  static forRoot(env: Env): DynamicModule {
    return {
      module: CatalogLoadModule,
      imports: [
        ConfigModule.forRoot(env),
        DatabaseModule,
        PhotoStorageModule,
        CareGuidesModule,
      ],
      providers: [
        CatalogLoader,
        {
          provide: ReferencePhotoDownloader,
          useFactory: () => new HttpReferencePhotoDownloader(),
        },
      ],
    };
  }
}
