import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  HttpException,
  HttpStatus,
  type INestApplication,
  type LoggerService,
  Post,
} from '@nestjs/common';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { createZodDto } from 'nestjs-zod';
import request from 'supertest';
import type { App } from 'supertest/types';
import { z } from 'zod';
import { Public } from '../src/auth/public.decorator';
import { createTestApp } from './support/app';
import { testEnv } from './support/env';
import { startPostgis } from './support/postgis';

class CreateProbeDto extends createZodDto(
  z.object({
    name: z.string().min(1),
    quantity: z.int().min(1).max(99),
    tags: z.array(z.string()).optional(),
  }),
) {}

/** Registered only in the test module: no real route of v0.0 takes a body. */
@Public()
@Controller('test-probe')
class ProbeController {
  @Post()
  create(@Body() body: CreateProbeDto): CreateProbeDto {
    return body;
  }

  @Get('boom')
  boom(): never {
    throw new Error('connection string postgres://secret@db leaked');
  }

  @Get('throttled')
  throttled(): never {
    throw new HttpException('ThrottlerException', HttpStatus.TOO_MANY_REQUESTS);
  }

  @Get('forbidden')
  forbidden(): never {
    throw new ForbiddenException('Forbidden resource for guard internals');
  }
}

/** Keeps the error log lines so a test can check what was logged. */
class CapturingLogger implements LoggerService {
  readonly errors: string[] = [];

  log(): void {}
  warn(): void {}
  error(...messages: unknown[]): void {
    this.errors.push(messages.map((m) => String(m)).join(' '));
  }
}

describe('error contract', () => {
  let container: StartedPostgreSqlContainer;
  let app: INestApplication<App>;
  const logger = new CapturingLogger();

  beforeAll(async () => {
    container = await startPostgis();
    app = await createTestApp(testEnv(container.getConnectionUri()), {
      controllers: [ProbeController],
      logger,
    });
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  it('answers an unknown route with 404 NOT_FOUND as problem+json', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/does-not-exist')
      .expect(404)
      .expect('Content-Type', /^application\/problem\+json/);

    expect(response.body).toEqual({
      type: 'about:blank',
      title: 'Not Found',
      status: 404,
      code: 'NOT_FOUND',
    });
  });

  it('answers a route outside /v1 with 404 NOT_FOUND too', async () => {
    const response = await request(app.getHttpServer())
      .get('/health')
      .expect(404)
      .expect('Content-Type', /^application\/problem\+json/);

    expect(response.body).toMatchObject({ code: 'NOT_FOUND' });
  });

  it('accepts a body that matches the Zod schema', async () => {
    await request(app.getHttpServer())
      .post('/v1/test-probe')
      .send({ name: 'Jiboia', quantity: 2 })
      .expect(201, { name: 'Jiboia', quantity: 2 });
  });

  it('answers an invalid body with 400 VALIDATION_FAILED and errors[]', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/test-probe')
      .send({ name: '', quantity: 100, tags: ['ok', 3] })
      .expect(400)
      .expect('Content-Type', /^application\/problem\+json/);

    expect(response.body).toEqual({
      type: 'about:blank',
      title: 'Bad Request',
      status: 400,
      code: 'VALIDATION_FAILED',
      errors: [
        { path: 'name', message: expect.any(String) as unknown },
        { path: 'quantity', message: expect.any(String) as unknown },
        { path: 'tags.1', message: expect.any(String) as unknown },
      ],
    });
  });

  it('answers a malformed JSON body with 400 VALIDATION_FAILED', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/test-probe')
      .set('Content-Type', 'application/json')
      .send('{"name": ')
      .expect(400)
      .expect('Content-Type', /^application\/problem\+json/);

    expect(response.body).toEqual({
      type: 'about:blank',
      title: 'Bad Request',
      status: 400,
      code: 'VALIDATION_FAILED',
      errors: [{ path: '', message: 'malformed request' }],
    });
  });

  it('answers a 429 thrown by Nest with 429 TOO_MANY_REQUESTS', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/test-probe/throttled')
      .expect(429)
      .expect('Content-Type', /^application\/problem\+json/);

    expect(response.body).toEqual({
      type: 'about:blank',
      title: 'Too Many Requests',
      status: 429,
      code: 'TOO_MANY_REQUESTS',
    });
  });

  it('answers an unmapped HttpException with 500 INTERNAL_ERROR and logs it', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/test-probe/forbidden')
      .expect(500)
      .expect('Content-Type', /^application\/problem\+json/);

    expect(response.body).toEqual({
      type: 'about:blank',
      title: 'Internal Server Error',
      status: 500,
      code: 'INTERNAL_ERROR',
    });
    expect(response.text).not.toMatch(/guard internals/);
    expect(logger.errors.join('\n')).toMatch(
      /has no problem-details mapping[\s\S]*ForbiddenException/,
    );
  });

  it('answers an unexpected error with 500 INTERNAL_ERROR and no details', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/test-probe/boom')
      .expect(500)
      .expect('Content-Type', /^application\/problem\+json/);

    expect(response.body).toEqual({
      type: 'about:blank',
      title: 'Internal Server Error',
      status: 500,
      code: 'INTERNAL_ERROR',
    });
    expect(response.text).not.toMatch(/secret|at .*\.ts|stack/i);
  });
});
