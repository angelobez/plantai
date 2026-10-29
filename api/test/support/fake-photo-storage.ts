import {
  PHOTO_CONTENT_TYPE,
  PHOTO_URL_TTL_SECONDS,
  type PhotoStorage,
  type PresignedUrl,
  type PutPhotoOptions,
  StoredPhotoNotFoundError,
  UNATTACHED_TAG,
} from '../../src/photo-storage/photo-storage';

export interface FakeStoredPhoto {
  bytes: Buffer;
  contentType: string;
  tags: Record<string, string>;
}

/** Where the fake's URLs point; a test can match a URL against it. */
export const FAKE_PHOTO_STORAGE_URL = 'https://photo-storage.fake';

/**
 * Stands in for S3: keeps the objects in memory, with their tags, so a test
 * can check what the API stored, as one would by browsing the bucket. Its
 * presigned URLs are deterministic (`<FAKE_PHOTO_STORAGE_URL>/<key>`) and only
 * the expiry changes with the clock.
 */
export class FakePhotoStorage implements PhotoStorage {
  private readonly objects = new Map<string, FakeStoredPhoto>();

  /**
   * While true, every call fails the way the real adapter does when S3 is
   * down, and nothing changes.
   */
  failing = false;

  put(key: string, bytes: Buffer, { unattached }: PutPhotoOptions) {
    return this.run(() => {
      this.objects.set(key, {
        bytes: Buffer.from(bytes),
        contentType: PHOTO_CONTENT_TYPE,
        tags: unattached ? { [UNATTACHED_TAG.key]: UNATTACHED_TAG.value } : {},
      });
    });
  }

  markAttached(key: string) {
    return this.run(() => {
      const object = this.objects.get(key);
      if (object) object.tags = {};
    });
  }

  delete(key: string) {
    return this.run(() => {
      this.objects.delete(key);
    });
  }

  read(key: string) {
    return this.run(() => {
      const object = this.objects.get(key);
      if (!object) throw new StoredPhotoNotFoundError(key);
      return Buffer.from(object.bytes);
    });
  }

  presignedGetUrl(key: string) {
    return this.run((): PresignedUrl => ({
      url: FakePhotoStorage.urlOf(key),
      expiresAt: new Date(Date.now() + PHOTO_URL_TTL_SECONDS * 1000),
    }));
  }

  /** The URL the fake hands out for [key]. */
  static urlOf(key: string): string {
    return `${FAKE_PHOTO_STORAGE_URL}/${key}`;
  }

  /** The object at [key], or `undefined` when there is none. */
  get(key: string): FakeStoredPhoto | undefined {
    return this.objects.get(key);
  }

  has(key: string): boolean {
    return this.objects.has(key);
  }

  /** Every stored key, in the order they were first saved. */
  keys(): string[] {
    return [...this.objects.keys()];
  }

  private run<T>(operation: () => T): Promise<T> {
    return Promise.resolve().then(() => {
      if (this.failing) throw new Error('The fake photo storage is failing');
      return operation();
    });
  }
}
