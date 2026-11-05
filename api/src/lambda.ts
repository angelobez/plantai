import serverlessExpress from '@codegenie/serverless-express';
import { createApp } from './bootstrap';
import { type LambdaHandler, lambdaEntry, loadLambdaEnv } from './lambda-entry';

/**
 * AWS Lambda entry (ADR 0004), behind a Function URL. The secrets are read
 * and the app is created on the first invocation, then reused while the
 * instance stays warm.
 */
export const handler: LambdaHandler = lambdaEntry(async () => {
  const app = await createApp(await loadLambdaEnv());
  const serve = serverlessExpress({
    app: app.getHttpAdapter().getInstance(),
  });
  // Typed as a callback-style `Handler`, but it takes (event, context) only
  // and answers with a promise; the callback is ignored.
  return (event, context) =>
    serve(event, context, () => undefined) as Promise<unknown>;
});
