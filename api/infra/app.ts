import { App } from 'aws-cdk-lib';
import { Code } from 'aws-cdk-lib/aws-lambda';
import { existsSync } from 'node:fs';
import { ApiStack } from './api-stack';
import { LAMBDA_PACKAGE_DIR, STACK_NAME, STACK_REGION } from './stack-config';

/** The CDK app (cdk.json); run from api/ by the cdk:* scripts. */
if (!existsSync(`${LAMBDA_PACKAGE_DIR}/dist/lambda.js`)) {
  throw new Error(
    `No Lambda package in ${LAMBDA_PACKAGE_DIR}; run npm run lambda:package`,
  );
}

const app = new App();
new ApiStack(app, STACK_NAME, {
  env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: STACK_REGION },
  code: Code.fromAsset(LAMBDA_PACKAGE_DIR),
});
