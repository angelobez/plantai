/** How long a presigned photo URL stays valid: 1 hour (ADR 0007). */
export const PHOTO_URL_TTL_SECONDS = 60 * 60;

/** Every photo is re-encoded as JPEG before it is stored. */
export const PHOTO_CONTENT_TYPE = 'image/jpeg';

/** The tag a lifecycle rule uses to delete photos nobody attached after 1 day. */
export const UNATTACHED_TAG = { key: 'unattached', value: 'true' } as const;

export interface PutPhotoOptions {
  /**
   * Tags the object `unattached=true`: a User's upload, until an
   * identification or a plant uses it. The Catalog's own reference photos are
   * stored without it.
   */
  unattached: boolean;
}

/** A URL anyone can GET until [expiresAt]. */
export interface PresignedUrl {
  url: string;
  expiresAt: Date;
}

/** Reading a key that holds no object. */
export class StoredPhotoNotFoundError extends Error {
  override readonly name = 'StoredPhotoNotFoundError';
}

/**
 * The port for the photo storage: a private S3 bucket, or the local emulator
 * in development. The real adapter is {@link S3PhotoStorage}; tests swap in a
 * fake that keeps the objects in memory.
 *
 * Photos are addressed by key and are always JPEG. An abstract class rather
 * than an interface, so it doubles as the Nest injection token.
 */
export abstract class PhotoStorage {
  /** Saves (or replaces) the JPEG at [key]. */
  abstract put(
    key: string,
    bytes: Buffer,
    options: PutPhotoOptions,
  ): Promise<void>;

  /** Removes the `unattached` tag, so the lifecycle rule keeps the photo. */
  abstract markAttached(key: string): Promise<void>;

  /** Deletes the object; deleting a missing key is not an error. */
  abstract delete(key: string): Promise<void>;

  /** The stored bytes; {@link StoredPhotoNotFoundError} when there are none. */
  abstract read(key: string): Promise<Buffer>;

  /** A GET URL for the photo, valid for {@link PHOTO_URL_TTL_SECONDS}. */
  abstract presignedGetUrl(key: string): Promise<PresignedUrl>;
}
