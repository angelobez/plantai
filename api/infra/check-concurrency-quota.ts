import {
  GetAccountSettingsCommand,
  LambdaClient,
} from '@aws-sdk/client-lambda';
import { STACK_REGION } from './stack-config';
import { concurrencyQuotaProblem } from './concurrency-quota';

/**
 * Runs before `cdk deploy` (npm run cdk:deploy): CloudFormation's own error
 * for a reservation above the quota does not say what to do (US 42).
 */
async function checkConcurrencyQuota(): Promise<void> {
  const client = new LambdaClient({ region: STACK_REGION });
  try {
    const { AccountLimit } = await client.send(new GetAccountSettingsCommand());
    const quota = AccountLimit?.ConcurrentExecutions;
    if (quota === undefined) {
      throw new Error('GetAccountSettings returned no ConcurrentExecutions');
    }
    const problem = concurrencyQuotaProblem(quota);
    if (problem !== undefined) {
      console.error(problem);
      process.exitCode = 1;
      return;
    }
    console.log(`[check-concurrency-quota] quota ${String(quota)}: OK`);
  } finally {
    client.destroy();
  }
}

void checkConcurrencyQuota();
