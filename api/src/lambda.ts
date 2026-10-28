import serverlessExpress from '@codegenie/serverless-express';
import type { Handler } from 'aws-lambda';
import { createApp } from './bootstrap';
import { loadEnv } from './config/env';

/**
 * AWS Lambda entry (ADR 0004), behind a Function URL. The app is created on
 * the first invocation and reused while the instance stays warm.
 */
async function createHandler(): Promise<Handler> {
  const app = await createApp(loadEnv());
  return serverlessExpress({
    app: app.getHttpAdapter().getInstance(),
  });
}

let handlerPromise: Promise<Handler> | undefined;

export const handler: Handler = async (event, context, callback) => {
  handlerPromise ??= createHandler();
  const serverlessHandler = await handlerPromise;
  return serverlessHandler(event, context, callback) as unknown;
};
