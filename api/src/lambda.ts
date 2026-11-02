import serverlessExpress from '@codegenie/serverless-express';
import type { Handler } from 'aws-lambda';
import { createApp } from './bootstrap';
import { lambdaEntry, loadLambdaEnv } from './lambda-entry';

/**
 * AWS Lambda entry (ADR 0004), behind a Function URL. The secrets are read
 * and the app is created on the first invocation, then reused while the
 * instance stays warm.
 */
export const handler: Handler = lambdaEntry(async () => {
  const app = await createApp(await loadLambdaEnv());
  return serverlessExpress({
    app: app.getHttpAdapter().getInstance(),
  });
});
