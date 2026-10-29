import type { INestApplication, LoggerService } from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createTestApp } from './support/app';
import { testEnv } from './support/env';
import { startPostgis } from './support/postgis';

/** Keeps every log line so the test can read what would reach CloudWatch. */
class CapturingLogger implements LoggerService {
  readonly lines: string[] = [];

  log(message: unknown): void {
    this.lines.push(JSON.stringify(message));
  }
  error(message: unknown): void {
    this.lines.push(JSON.stringify(message));
  }
  warn(message: unknown): void {
    this.lines.push(JSON.stringify(message));
  }
}

describe('request logger', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const logger = new CapturingLogger();

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      logger,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  it('logs the request without sensitive header values', async () => {
    await request(app.getHttpServer())
      .get('/v1/health')
      .set('Authorization', 'Bearer secret-access-token')
      .set('X-Search-Location', '-23.5505,-46.6333')
      .set('Cookie', 'session=secret-cookie')
      .set('X-App-Version', '0.0.7')
      .expect(200);

    const line = logger.lines.find((l) => l.includes('GET /v1/health 200'));
    expect(line).toBeDefined();
    expect(line).toContain('0.0.7');
    expect(line).toContain('authorization');
    expect(line).toContain('x-search-location');

    const everything = logger.lines.join('\n');
    expect(everything).not.toContain('secret-access-token');
    expect(everything).not.toContain('-23.5505');
    expect(everything).not.toContain('secret-cookie');
  });
});
