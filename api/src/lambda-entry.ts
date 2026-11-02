import type { Handler } from 'aws-lambda';
import { type Env, loadEnv } from './config/env';
import { loadSsmParameters } from './config/ssm-parameters';

/**
 * The environment of a Lambda function: the secrets from the SSM (when
 * `SSM_PARAMETER_PREFIX` is set), then the usual validation of `loadEnv()`.
 */
export async function loadLambdaEnv(): Promise<Env> {
  await loadSsmParameters(process.env);
  return loadEnv();
}

/**
 * Wraps a Lambda entry so [start] (reading the SSM, creating the app) runs
 * once per cold start, and the handler it gives is reused while the instance
 * stays warm. A failed start fails every invocation of that instance.
 */
export function lambdaEntry(start: () => Promise<Handler>): Handler {
  let started: Promise<Handler> | undefined;
  return async (event, context, callback) => {
    started ??= start();
    const handler = await started;
    return handler(event, context, callback) as unknown;
  };
}
