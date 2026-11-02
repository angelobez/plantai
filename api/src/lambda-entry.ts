import type { Context } from 'aws-lambda';
import { type Env, loadEnv } from './config/env';
import { loadSsmParameters } from './config/ssm-parameters';

/**
 * A promise-based Lambda handler. The Node.js 24 runtime refuses to load a
 * handler that declares a third (callback) parameter.
 */
export type LambdaHandler<TEvent = unknown, TResult = unknown> = (
  event: TEvent,
  context: Context,
) => Promise<TResult>;

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
export function lambdaEntry<TEvent, TResult>(
  start: () => Promise<LambdaHandler<TEvent, TResult>>,
): LambdaHandler<TEvent, TResult> {
  let started: Promise<LambdaHandler<TEvent, TResult>> | undefined;
  return async (event, context) => {
    started ??= start();
    const handler = await started;
    return handler(event, context);
  };
}
