import { randomUUIDv7 } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { and, count, eq, gte, isNull } from 'drizzle-orm';
import sharp from 'sharp';
import { DATABASE, type Database } from '../database/database.module';
import { photos } from '../database/schema';
import { startOfToday } from '../database/today';
import { DomainError } from '../errors/domain-error';
import {
  PhotoStorage,
  StoredPhotoNotFoundError,
} from '../photo-storage/photo-storage';
import type { PhotoResponse } from './photo.dto';
import { invalidPhoto } from './photo-upload.interceptor';

/** How many photos a User may send per day (`PHOTO_DAILY_LIMIT`). */
export const PHOTO_DAILY_LIMIT = 50;

/** Where a User's photo lives in the bucket. */
export function photoKey(photoId: string): string {
  return `photos/${photoId}.jpg`;
}

/** Same quality the app uses when `image_picker` reduces the photo. */
const JPEG_QUALITY = 85;

/** A User's photo row, as {@link PhotosService.findOwned} answers it. */
export type OwnedPhoto = typeof photos.$inferSelect;

interface CleanJpeg {
  bytes: Buffer;
  width: number;
  height: number;
}

/**
 * Decodes [original], turns it upright by its EXIF orientation and writes it
 * again as JPEG. sharp keeps no metadata unless asked, so the EXIF (GPS
 * included, ADR 0007), ICC and XMP are all gone. Anything sharp cannot decode
 * is not an image: `VALIDATION_FAILED`.
 */
async function cleanJpeg(original: Buffer): Promise<CleanJpeg> {
  try {
    const { data, info } = await sharp(original)
      .rotate()
      .jpeg({ quality: JPEG_QUALITY, mozjpeg: true })
      .toBuffer({ resolveWithObject: true });
    return { bytes: data, width: info.width, height: info.height };
  } catch (error) {
    throw invalidPhoto('file is not an image', error);
  }
}

/** A User's photos: upload, and how responses show them. */
@Injectable()
export class PhotosService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    @Inject(PhotoStorage) private readonly storage: PhotoStorage,
  ) {}

  /**
   * Stores [original] for [ownerId], tagged `unattached` until an
   * identification or a plant uses it.
   *
   * The object goes in before the row: if the insert fails, the orphan object
   * still has the tag, and the bucket's lifecycle rule deletes it.
   */
  async upload(ownerId: string, original: Buffer): Promise<PhotoResponse> {
    await this.checkDailyLimit(ownerId);
    const jpeg = await cleanJpeg(original);

    const id = randomUUIDv7();
    const s3Key = photoKey(id);
    await this.storage.put(s3Key, jpeg.bytes, { unattached: true });
    const [photo] = await this.db
      .insert(photos)
      .values({
        id,
        ownerId,
        s3Key,
        width: jpeg.width,
        height: jpeg.height,
      })
      .returning();
    if (!photo) throw new Error('The photo insert returned no row');
    return this.present(photo);
  }

  /**
   * The photo as every response shows it, with a URL presigned now. Other
   * features (identification, garden) answer their photos through this.
   */
  async present(photo: { id: string; s3Key: string }): Promise<PhotoResponse> {
    const { url, expiresAt } = await this.storage.presignedGetUrl(photo.s3Key);
    return { id: photo.id, url, expiresAt: expiresAt.toISOString() };
  }

  /**
   * [ownerId]'s photo [photoId]; `NOT_FOUND` when there is none, or when it
   * is someone else's, so its existence is not revealed.
   */
  async findOwned(ownerId: string, photoId: string): Promise<OwnedPhoto> {
    const [photo] = await this.db
      .select()
      .from(photos)
      .where(and(eq(photos.id, photoId), eq(photos.ownerId, ownerId)));
    if (!photo) throw new DomainError('NOT_FOUND');
    return photo;
  }

  /** The stored JPEG; `NOT_FOUND` when the object is gone. */
  async read(photo: OwnedPhoto): Promise<Buffer> {
    try {
      return await this.storage.read(photo.s3Key);
    } catch (error) {
      if (error instanceof StoredPhotoNotFoundError) {
        throw new DomainError('NOT_FOUND', { cause: error });
      }
      throw error;
    }
  }

  /**
   * Marks [photo] as used (by an identification or a plant): the
   * `unattached` tag goes, so the lifecycle rule keeps it, and `attached_at`
   * is set. A photo already attached is left as it is, S3 included.
   *
   * The tag goes first: if the update fails, the photo is kept anyway, which
   * is the safe side.
   */
  async attach(photo: OwnedPhoto): Promise<void> {
    if (photo.attachedAt) return;
    await this.storage.markAttached(photo.s3Key);
    await this.db
      .update(photos)
      .set({ attachedAt: new Date() })
      .where(and(eq(photos.id, photo.id), isNull(photos.attachedAt)));
  }

  /**
   * `PHOTO_DAILY_LIMIT` once [ownerId] sent {@link PHOTO_DAILY_LIMIT} photos
   * since today's midnight in São Paulo. Two uploads at the same instant may
   * both pass; the limit guards the storage against a runaway app, so one
   * photo over it does no harm.
   */
  private async checkDailyLimit(ownerId: string): Promise<void> {
    const [today] = await this.db
      .select({ photos: count() })
      .from(photos)
      .where(
        and(eq(photos.ownerId, ownerId), gte(photos.createdAt, startOfToday())),
      );
    if ((today?.photos ?? 0) >= PHOTO_DAILY_LIMIT) {
      throw new DomainError('PHOTO_DAILY_LIMIT');
    }
  }
}
