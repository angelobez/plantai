import {
  DeleteObjectCommand,
  DeleteObjectTaggingCommand,
  GetObjectCommand,
  NoSuchKey,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { Env } from '../config/env';
import {
  PHOTO_CONTENT_TYPE,
  PHOTO_URL_TTL_SECONDS,
  PhotoStorage,
  type PresignedUrl,
  type PutPhotoOptions,
  StoredPhotoNotFoundError,
  UNATTACHED_TAG,
} from './photo-storage';

export interface S3PhotoStorageConfig {
  bucket: string;
  region: string;
  /** Only for the local emulator; it also turns on path-style URLs. */
  endpoint?: string;
  /** Only for the emulator; without them the SDK finds them (Lambda role). */
  credentials?: { accessKeyId: string; secretAccessKey: string };
}

export function s3PhotoStorageConfig(env: Env): S3PhotoStorageConfig {
  return {
    bucket: env.S3_BUCKET,
    region: env.S3_REGION,
    endpoint: env.S3_ENDPOINT,
    credentials:
      env.S3_ACCESS_KEY_ID !== undefined &&
      env.S3_SECRET_ACCESS_KEY !== undefined
        ? {
            accessKeyId: env.S3_ACCESS_KEY_ID,
            secretAccessKey: env.S3_SECRET_ACCESS_KEY,
          }
        : undefined,
  };
}

/**
 * {@link PhotoStorage} on S3 with the AWS SDK. The same code talks to the
 * local emulator (with `endpoint`) and, in phase 2, to S3 itself, so the swap
 * is only in `.env`. Presigned URLs are signed against the configured
 * endpoint, so on the phone they work through `adb reverse` of its port.
 */
export class S3PhotoStorage extends PhotoStorage {
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor({ bucket, region, endpoint, credentials }: S3PhotoStorageConfig) {
    super();
    this.bucket = bucket;
    this.client = new S3Client({
      region,
      endpoint,
      forcePathStyle: endpoint !== undefined,
      credentials,
    });
  }

  async put(
    key: string,
    bytes: Buffer,
    { unattached }: PutPhotoOptions,
  ): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: bytes,
        ContentType: PHOTO_CONTENT_TYPE,
        Tagging: unattached
          ? `${UNATTACHED_TAG.key}=${UNATTACHED_TAG.value}`
          : undefined,
      }),
    );
  }

  async markAttached(key: string): Promise<void> {
    // `unattached` is the only tag photos ever get.
    await this.client.send(
      new DeleteObjectTaggingCommand({ Bucket: this.bucket, Key: key }),
    );
  }

  async delete(key: string): Promise<void> {
    await this.client.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
    );
  }

  async read(key: string): Promise<Buffer> {
    try {
      const { Body } = await this.client.send(
        new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      if (Body === undefined) throw new StoredPhotoNotFoundError(key);
      return Buffer.from(await Body.transformToByteArray());
    } catch (error) {
      if (error instanceof NoSuchKey) throw new StoredPhotoNotFoundError(key);
      throw error;
    }
  }

  async presignedGetUrl(key: string): Promise<PresignedUrl> {
    // SigV4 signs at whole seconds, so the expiry is counted from there too.
    const signedAt = Math.floor(Date.now() / 1000) * 1000;
    const url = await getSignedUrl(
      this.client,
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      { expiresIn: PHOTO_URL_TTL_SECONDS, signingDate: new Date(signedAt) },
    );
    return {
      url,
      expiresAt: new Date(signedAt + PHOTO_URL_TTL_SECONDS * 1000),
    };
  }

  /** Closes the SDK's sockets, so a script can exit. */
  close(): void {
    this.client.destroy();
  }
}
