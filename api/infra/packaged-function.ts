import { Duration, RemovalPolicy, Stack } from 'aws-cdk-lib';
import { PolicyStatement } from 'aws-cdk-lib/aws-iam';
import {
  Architecture,
  type Code,
  Function as LambdaFunction,
  type FunctionProps,
  Runtime,
} from 'aws-cdk-lib/aws-lambda';
import { LogGroup, RetentionDays } from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';
import { SSM_PARAMETER_PREFIX } from '../src/config/ssm-parameters';

/** Where the production secrets live, one `SecureString` per variable. */
export const PRODUCTION_SSM_PREFIX = '/plantai/production';

/**
 * The Lambda runtime starts Node.js with `--no-experimental-require-module`
 * unless NODE_OPTIONS asks for it, and Nest 12 is ESM required from the
 * compiled CommonJS. Keep in sync with scripts/check-lambda-package.sh.
 */
export const LAMBDA_NODE_OPTIONS =
  '--experimental-require-module --enable-source-maps';

export interface PackagedFunctionProps {
  /** The package of `npm run lambda:package` (or a stand-in in tests). */
  code: Code;
  /** An entry of the package, such as `dist/lambda.handler`. */
  handler: string;
  memorySize: number;
  timeout: Duration;
  reservedConcurrentExecutions?: number;
  /** On top of SSM_PARAMETER_PREFIX and NODE_OPTIONS. */
  environment?: Record<string, string>;
  description?: string;
}

/**
 * A function of the API package: Node.js 24 on x86_64 (the platform of the
 * native argon2 and sharp in the package), its own log group kept 30 days
 * (#77), and the production secrets read from the SSM at cold start (only
 * that prefix, read-only).
 */
export class PackagedFunction extends Construct {
  readonly function: LambdaFunction;
  readonly logGroup: LogGroup;

  constructor(scope: Construct, id: string, props: PackagedFunctionProps) {
    super(scope, id);

    this.logGroup = new LogGroup(this, 'Logs', {
      retention: RetentionDays.ONE_MONTH,
      removalPolicy: RemovalPolicy.DESTROY,
    });

    const functionProps: FunctionProps = {
      code: props.code,
      handler: props.handler,
      runtime: Runtime.NODEJS_24_X,
      architecture: Architecture.X86_64,
      memorySize: props.memorySize,
      timeout: props.timeout,
      reservedConcurrentExecutions: props.reservedConcurrentExecutions,
      description: props.description,
      logGroup: this.logGroup,
      environment: {
        ...props.environment,
        [SSM_PARAMETER_PREFIX]: PRODUCTION_SSM_PREFIX,
        NODE_OPTIONS: LAMBDA_NODE_OPTIONS,
      },
    };
    this.function = new LambdaFunction(this, 'Function', functionProps);

    const stack = Stack.of(this);
    const prefix = PRODUCTION_SSM_PREFIX.replace(/^\//, '');
    this.function.addToRolePolicy(
      new PolicyStatement({
        actions: ['ssm:GetParametersByPath'],
        // GetParametersByPath is authorized on the path itself.
        resources: [
          stack.formatArn({
            service: 'ssm',
            resource: 'parameter',
            resourceName: prefix,
          }),
          stack.formatArn({
            service: 'ssm',
            resource: 'parameter',
            resourceName: `${prefix}/*`,
          }),
        ],
      }),
    );
  }
}
