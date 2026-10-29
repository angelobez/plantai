import type { INestApplication } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import sharp from 'sharp';
import request from 'supertest';
import type { App } from 'supertest/types';
import { photos } from '../src/database/schema';
import { createTestApp } from './support/app';
import {
  type AuthTokensBody,
  databaseOf,
  signUpAndVerify,
} from './support/auth';
import { testEnv } from './support/env';
import { FakeOutbox } from './support/fake-outbox';
import {
  FAKE_PHOTO_STORAGE_URL,
  FakePhotoStorage,
} from './support/fake-photo-storage';
import { startPostgis } from './support/postgis';

interface PhotoBody {
  id: string;
  url: string;
  expiresAt: string;
}

const MAX_BYTES = 6 * 1024 * 1024;

/** A small JPEG, as the app sends it after `image_picker` reduced it. */
function jpeg(width = 40, height = 20): sharp.Sharp {
  return sharp({
    create: { width, height, channels: 3, background: '#7FA886' },
  }).jpeg();
}

/** A JPEG with the GPS position and camera data a phone writes. */
function jpegWithGps(): Promise<Buffer> {
  return jpeg()
    .withExif({
      IFD0: { Make: 'PhoneMaker', Model: 'Phone 12' },
      IFD3: {
        GPSLatitudeRef: 'S',
        GPSLatitude: '23/1 33/1 0/1',
        GPSLongitudeRef: 'W',
        GPSLongitude: '46/1 38/1 0/1',
      },
    })
    .toBuffer();
}

describe('POST /photos', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const outbox = new FakeOutbox();
  const photoStorage = new FakePhotoStorage();

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      outbox,
      photoStorage,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  function upload(
    session: AuthTokensBody,
    file: Buffer,
    { field = 'file', filename = 'planta.jpg' } = {},
  ): request.Test {
    return request(app.getHttpServer())
      .post('/v1/photos')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .attach(field, file, filename);
  }

  /** What the storage holds for the photo the API answered with. */
  function storedObject(body: PhotoBody) {
    const key = body.url.slice(`${FAKE_PHOTO_STORAGE_URL}/`.length);
    const object = photoStorage.get(key);
    if (!object) throw new Error(`Nothing stored at ${key}`);
    return { key, ...object };
  }

  /** Adds [count] photo rows for [session]'s User, created at [createdAt]. */
  async function seedPhotos(
    session: AuthTokensBody,
    count: number,
    createdAt: Date,
  ): Promise<void> {
    await databaseOf(app)
      .insert(photos)
      .values(
        Array.from({ length: count }, (_, index) => ({
          ownerId: session.user.id,
          s3Key: `seeded/${session.user.id}/${String(index)}.jpg`,
          width: 40,
          height: 20,
          createdAt,
        })),
      );
  }

  it('stores the photo and answers its id with a presigned URL', async () => {
    const session = await signUpAndVerify(app, outbox);
    const before = Date.now();

    const response = await upload(session, await jpeg().toBuffer()).expect(201);

    const body = response.body as PhotoBody;
    expect(body).toEqual({
      id: expect.stringMatching(
        /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$/,
      ) as string,
      url: expect.stringContaining(body.id) as string,
      expiresAt: expect.any(String) as string,
    });
    const expiresIn = Date.parse(body.expiresAt) - before;
    expect(expiresIn).toBeGreaterThan(59 * 60 * 1000);
    expect(expiresIn).toBeLessThanOrEqual(61 * 60 * 1000);

    const stored = storedObject(body);
    expect(stored.contentType).toBe('image/jpeg');
    expect(stored.tags).toEqual({ unattached: 'true' });
  });

  it('removes the GPS position and every other metadata', async () => {
    const session = await signUpAndVerify(app, outbox);
    const original = await jpegWithGps();
    expect((await sharp(original).metadata()).exif).toBeDefined();

    const response = await upload(session, original).expect(201);

    const stored = storedObject(response.body as PhotoBody);
    const metadata = await sharp(stored.bytes).metadata();
    expect(metadata.format).toBe('jpeg');
    expect(metadata.exif).toBeUndefined();
    expect(metadata.icc).toBeUndefined();
    expect(metadata.xmp).toBeUndefined();
    expect(stored.bytes.includes('PhoneMaker')).toBe(false);
  });

  it('turns the photo upright by its orientation', async () => {
    const session = await signUpAndVerify(app, outbox);
    // Taken sideways: 40 × 20 pixels that should be shown rotated 90°.
    const sideways = await jpeg(40, 20)
      .withMetadata({ orientation: 6 })
      .toBuffer();

    const response = await upload(session, sideways).expect(201);

    const metadata = await sharp(
      storedObject(response.body as PhotoBody).bytes,
    ).metadata();
    expect([metadata.width, metadata.height]).toEqual([20, 40]);
    expect(metadata.orientation).toBeUndefined();
  });

  it('re-encodes a PNG as JPEG', async () => {
    const session = await signUpAndVerify(app, outbox);
    const png = await sharp({
      create: { width: 8, height: 8, channels: 4, background: '#3F6B4A' },
    })
      .png()
      .toBuffer();

    const response = await upload(session, png, {
      filename: 'planta.png',
    }).expect(201);

    const metadata = await sharp(
      storedObject(response.body as PhotoBody).bytes,
    ).metadata();
    expect(metadata.format).toBe('jpeg');
  });

  it.each([
    ['a file that is not an image', () => Buffer.from('not a photo at all')],
    ['a file over 6 MB', () => Buffer.alloc(MAX_BYTES + 1, 0xff)],
  ])('rejects %s with VALIDATION_FAILED', async (_case, file) => {
    const session = await signUpAndVerify(app, outbox);
    const storedBefore = photoStorage.keys().length;

    const response = await upload(session, file()).expect(400);

    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path: 'file' }],
    });
    expect(photoStorage.keys()).toHaveLength(storedBefore);
  });

  it('rejects a request without the file field with VALIDATION_FAILED', async () => {
    const session = await signUpAndVerify(app, outbox);

    const response = await upload(session, await jpeg().toBuffer(), {
      field: 'photo',
    }).expect(400);

    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path: 'file' }],
    });
  });

  it('rejects a request that is not multipart with VALIDATION_FAILED', async () => {
    const session = await signUpAndVerify(app, outbox);

    const response = await request(app.getHttpServer())
      .post('/v1/photos')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({ file: 'planta.jpg' })
      .expect(400);

    expect(response.body).toMatchObject({
      code: 'VALIDATION_FAILED',
      errors: [{ path: 'file' }],
    });
  });

  it('answers the 51st photo of the day with PHOTO_DAILY_LIMIT', async () => {
    const session = await signUpAndVerify(app, outbox);
    await seedPhotos(session, 49, new Date());
    await upload(session, await jpeg().toBuffer()).expect(201);
    const storedBefore = photoStorage.keys().length;

    const response = await upload(session, await jpeg().toBuffer()).expect(429);

    expect(response.body).toMatchObject({ code: 'PHOTO_DAILY_LIMIT' });
    expect(photoStorage.keys()).toHaveLength(storedBefore);
  });

  it("does not count yesterday's photos in the daily limit", async () => {
    const session = await signUpAndVerify(app, outbox);
    // A day ago is always before today's midnight in São Paulo.
    await seedPhotos(session, 50, new Date(Date.now() - 24 * 60 * 60 * 1000));

    await upload(session, await jpeg().toBuffer()).expect(201);
  });

  it("does not count another User's photos in the daily limit", async () => {
    const marina = await signUpAndVerify(app, outbox);
    const joao = await signUpAndVerify(app, outbox);
    await seedPhotos(marina, 50, new Date());

    await upload(joao, await jpeg().toBuffer()).expect(201);
  });

  it('without a token answers 401 UNAUTHENTICATED', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/photos')
      .attach('file', await jpeg().toBuffer(), 'planta.jpg')
      .expect(401);
    expect(response.body).toMatchObject({ code: 'UNAUTHENTICATED' });
  });
});
