import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { configureApp } from './bootstrap';
import { loadEnv } from './config/env';

/** Local HTTP server. Deployed environments use the Lambda handler instead. */
async function startHttpServer(): Promise<void> {
  const env = loadEnv();

  const app = await NestFactory.create(AppModule.forRoot(env));
  await configureApp(app);
  // Closes the database pool on Ctrl+C or when `nest start --watch` reloads.
  app.enableShutdownHooks();
  await app.listen(env.PORT);
}

void startHttpServer();
