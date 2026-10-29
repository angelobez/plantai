import { GetObjectTaggingCommand, S3Client } from '@aws-sdk/client-s3';
import { StoredPhotoNotFoundError } from '../src/photo-storage/photo-storage';
import {
  S3PhotoStorage,
  type S3PhotoStorageConfig,
} from '../src/photo-storage/s3-photo-storage';
import { startS3Emulator, type StartedS3Emulator } from './support/s3';

const ONE_HOUR_MS = 60 * 60 * 1000;

describe('S3PhotoStorage against the S3 emulator', () => {
  let emulator: StartedS3Emulator;
  let storage: S3PhotoStorage;
  let s3: S3Client;

  beforeAll(async () => {
    emulator = await startS3Emulator();
    storage = new S3PhotoStorage(emulator.config);
    s3 = clientFor(emulator.config);
  });

  afterAll(async () => {
    s3.destroy();
    storage.close();
    await emulator.container.stop();
  });

  /** The object's tags, read straight from S3: the port does not expose them. */
  async function tagsOf(key: string): Promise<Record<string, string>> {
    const { TagSet = [] } = await s3.send(
      new GetObjectTaggingCommand({ Bucket: emulator.config.bucket, Key: key }),
    );
    return Object.fromEntries(
      TagSet.map((tag): [string, string] => [tag.Key ?? '', tag.Value ?? '']),
    );
  }

  it('saves an unattached photo with the tag and reads its bytes back', async () => {
    const bytes = Buffer.from('a photo of a monstera');
    await storage.put('photos/tagged.jpg', bytes, { unattached: true });

    expect(await tagsOf('photos/tagged.jpg')).toEqual({ unattached: 'true' });
    expect(await storage.read('photos/tagged.jpg')).toEqual(bytes);
  });

  it('saves a photo without the tag when it is not unattached', async () => {
    await storage.put('species/untagged.jpg', Buffer.from('x'), {
      unattached: false,
    });

    expect(await tagsOf('species/untagged.jpg')).toEqual({});
  });

  it('removes the unattached tag when the photo is attached', async () => {
    await storage.put('photos/attached.jpg', Buffer.from('x'), {
      unattached: true,
    });

    await storage.markAttached('photos/attached.jpg');

    expect(await tagsOf('photos/attached.jpg')).toEqual({});
  });

  it('serves the photo through a presigned GET URL valid for 1 hour', async () => {
    const bytes = Buffer.from('a photo of a fern');
    await storage.put('photos/presigned.jpg', bytes, { unattached: true });
    const before = Date.now();

    const { url, expiresAt } = await storage.presignedGetUrl(
      'photos/presigned.jpg',
    );

    const response = await fetch(url);
    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toBe('image/jpeg');
    expect(Buffer.from(await response.arrayBuffer())).toEqual(bytes);
    // Signed at whole seconds.
    expect(expiresAt.getTime()).toBeGreaterThan(before + ONE_HOUR_MS - 1000);
    expect(expiresAt.getTime()).toBeLessThanOrEqual(Date.now() + ONE_HOUR_MS);
  });

  it('keeps the bucket private: the URL without signature is refused', async () => {
    await storage.put('photos/private.jpg', Buffer.from('x'), {
      unattached: true,
    });
    const { url } = await storage.presignedGetUrl('photos/private.jpg');

    const response = await fetch(url.split('?')[0] ?? url);

    expect(response.status).toBe(403);
  });

  it('deletes the photo', async () => {
    await storage.put('photos/deleted.jpg', Buffer.from('x'), {
      unattached: true,
    });

    await storage.delete('photos/deleted.jpg');

    await expect(storage.read('photos/deleted.jpg')).rejects.toBeInstanceOf(
      StoredPhotoNotFoundError,
    );
  });
});

function clientFor(config: S3PhotoStorageConfig): S3Client {
  return new S3Client({
    region: config.region,
    endpoint: config.endpoint,
    forcePathStyle: true,
    credentials: config.credentials,
  });
}
