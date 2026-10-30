import {
  Global,
  Inject,
  Module,
  type OnApplicationShutdown,
} from '@nestjs/common';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env';
import { PhotoStorage } from './photo-storage';
import { S3PhotoStorage, s3PhotoStorageConfig } from './s3-photo-storage';

/** Provides the {@link PhotoStorage}: S3, or the emulator with `S3_ENDPOINT`. */
@Global()
@Module({
  providers: [
    {
      provide: PhotoStorage,
      inject: [ENV],
      useFactory: (env: Env): PhotoStorage =>
        new S3PhotoStorage(s3PhotoStorageConfig(env)),
    },
  ],
  exports: [PhotoStorage],
})
export class PhotoStorageModule implements OnApplicationShutdown {
  constructor(@Inject(PhotoStorage) private readonly storage: PhotoStorage) {}

  onApplicationShutdown(): void {
    // Tests swap in a fake, which has nothing to close.
    if (this.storage instanceof S3PhotoStorage) this.storage.close();
  }
}
