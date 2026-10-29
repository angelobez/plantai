import { CreateBucketCommand, S3Client } from '@aws-sdk/client-s3';
import {
  GenericContainer,
  type StartedTestContainer,
  Wait,
} from 'testcontainers';
import type { S3PhotoStorageConfig } from '../../src/photo-storage/s3-photo-storage';

// Keep in sync with the image of the `s3` service in compose.yaml.
const S3_EMULATOR_IMAGE = 'rustfs/rustfs:1.0.4';
const S3_PORT = 9000;

export interface StartedS3Emulator {
  container: StartedTestContainer;
  /** Points at the emulator, with its bucket already created. */
  config: S3PhotoStorageConfig;
}

/** Starts a throwaway S3 emulator with an empty private bucket. */
export async function startS3Emulator(): Promise<StartedS3Emulator> {
  const credentials = {
    accessKeyId: 'plantai-test',
    secretAccessKey: 'plantai-test-secret',
  };
  const container = await new GenericContainer(S3_EMULATOR_IMAGE)
    .withEnvironment({
      RUSTFS_ACCESS_KEY: credentials.accessKeyId,
      RUSTFS_SECRET_KEY: credentials.secretAccessKey,
      RUSTFS_CONSOLE_ENABLE: 'false',
    })
    .withExposedPorts(S3_PORT)
    .withWaitStrategy(Wait.forHttp('/health', S3_PORT))
    .start();

  const config: S3PhotoStorageConfig = {
    bucket: 'plantai-photos-test',
    region: 'us-east-1',
    endpoint: `http://${container.getHost()}:${String(container.getMappedPort(S3_PORT))}`,
    credentials,
  };
  const client = new S3Client({
    region: config.region,
    endpoint: config.endpoint,
    forcePathStyle: true,
    credentials,
  });
  try {
    await client.send(new CreateBucketCommand({ Bucket: config.bucket }));
  } finally {
    client.destroy();
  }
  return { container, config };
}
