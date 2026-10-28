import { NestFactory } from '@nestjs/core';
import { existsSync } from 'node:fs';
import { AppModule } from './app.module';
import { configureApp } from './bootstrap';
import { parseEnv } from './config/env';

/** Local HTTP server. Deployed environments use the Lambda handler instead. */
async function bootstrap(): Promise<void> {
  if (existsSync('.env')) process.loadEnvFile('.env');
  const env = parseEnv(process.env);

  const app = await NestFactory.create(AppModule.forRoot(env));
  configureApp(app);
  await app.listen(env.PORT);
}

void bootstrap();
