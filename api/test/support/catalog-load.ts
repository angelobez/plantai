import type { INestApplicationContext } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { CatalogLoadModule } from '../../src/catalog/catalog-load.module';
import { ReferencePhotoDownloader } from '../../src/catalog/reference-photo-downloader';
import type { Env } from '../../src/config/env';
import { PhotoStorage } from '../../src/photo-storage/photo-storage';
import { FakePhotoStorage } from './fake-photo-storage';
import { FakeReferencePhotoDownloader } from './fake-reference-photo-downloader';

export interface TestCatalogLoadOptions {
  /** Where the reference photos go; pass one to look at them. */
  photoStorage?: FakePhotoStorage;
  /** Serves the Wikimedia photos; pass one with `serves()`. */
  photoDownloader?: FakeReferencePhotoDownloader;
}

/**
 * The same modules `npm run catalog:load` mounts (no HTTP server), with the
 * ports to external services swapped for fakes, like {@link createTestApp}.
 */
export async function createTestCatalogLoad(
  env: Env,
  {
    photoStorage = new FakePhotoStorage(),
    photoDownloader = new FakeReferencePhotoDownloader(),
  }: TestCatalogLoadOptions = {},
): Promise<INestApplicationContext> {
  const moduleRef = await Test.createTestingModule({
    imports: [CatalogLoadModule.forRoot(env)],
  })
    .overrideProvider(PhotoStorage)
    .useValue(photoStorage)
    .overrideProvider(ReferencePhotoDownloader)
    .useValue(photoDownloader)
    .compile();
  return moduleRef.init();
}
