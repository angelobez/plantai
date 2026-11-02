import {
  CfnOutput,
  Duration,
  RemovalPolicy,
  Stack,
  StackProps,
} from 'aws-cdk-lib';
import { PolicyStatement } from 'aws-cdk-lib/aws-iam';
import {
  type Code,
  FunctionUrlAuthType,
  type FunctionUrl,
} from 'aws-cdk-lib/aws-lambda';
import {
  BlockPublicAccess,
  Bucket,
  BucketEncryption,
} from 'aws-cdk-lib/aws-s3';
import type { Construct } from 'constructs';
import { UNATTACHED_TAG } from '../src/photo-storage/photo-storage';
import { GithubDeployRole } from './github-deploy-role';
import { Maintenance } from './maintenance';
import { PackagedFunction } from './packaged-function';
import { API_DOMAIN, PublicEndpoint } from './public-endpoint';

/**
 * The cap on simultaneous executions of the API (ADR 0004): it contains the
 * spending and matches Pl@ntNet's 20 simultaneous calls per client.
 */
export const API_RESERVED_CONCURRENCY = 20;

/** Pl@ntNet answers in ~2 s; a care guide is up to two 25 s Claude calls. */
const API_TIMEOUT = Duration.seconds(60);

export interface ApiStackProps extends StackProps {
  /** The package of `npm run lambda:package`; every function runs from it. */
  code: Code;
  /** Receives the alerts topic's e-mails (infra/maintenance.ts). */
  alertEmail: string;
}

/**
 * The production infrastructure of the API (#87), in `us-east-1`: the API
 * function behind a Function URL and CloudFront (api.plantai.ia.br), its logs,
 * the photo bucket, the maintenance routine with its alerts and the role of
 * the GitHub deploy.
 */
export class ApiStack extends Stack {
  readonly code: Code;
  readonly api: PackagedFunction;
  readonly functionUrl: FunctionUrl;
  readonly photoBucket: Bucket;
  readonly maintenance: Maintenance;

  constructor(scope: Construct, id: string, props: ApiStackProps) {
    super(scope, id, props);
    this.code = props.code;

    // Private, photos only leave it through presigned URLs (ADR 0007).
    this.photoBucket = new Bucket(this, 'Photos', {
      blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
      encryption: BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      // The users' photos outlive the stack.
      removalPolicy: RemovalPolicy.RETAIN,
      lifecycleRules: [
        {
          // Uploads nobody attached to an identification or a plant.
          tagFilters: { [UNATTACHED_TAG.key]: UNATTACHED_TAG.value },
          expiration: Duration.days(1),
        },
      ],
    });

    this.api = new PackagedFunction(this, 'Api', {
      code: this.code,
      handler: 'dist/lambda.handler',
      description: 'PlantAí API (NestJS through serverless-express)',
      // The premise of docs/research/custos-fase-2.md.
      memorySize: 1024,
      timeout: API_TIMEOUT,
      reservedConcurrentExecutions: API_RESERVED_CONCURRENCY,
      environment: {
        // No S3_ENDPOINT nor keys: the SDK uses the function's role.
        S3_BUCKET: this.photoBucket.bucketName,
        S3_REGION: this.region,
      },
    });

    this.api.function.addToRolePolicy(
      new PolicyStatement({
        actions: [
          's3:DeleteObject',
          's3:DeleteObjectTagging',
          's3:GetObject',
          's3:PutObject',
          's3:PutObjectTagging',
        ],
        resources: [this.photoBucket.arnForObjects('*')],
      }),
    );
    this.api.function.addToRolePolicy(
      new PolicyStatement({
        // Without it, S3 answers a missing photo with 403 instead of
        // NoSuchKey, and the API with 500 instead of 404.
        actions: ['s3:ListBucket'],
        resources: [this.photoBucket.bucketArn],
      }),
    );

    // The lock (the CloudFront origin secret) is in the API itself (#88).
    this.functionUrl = this.api.function.addFunctionUrl({
      authType: FunctionUrlAuthType.NONE,
    });

    this.maintenance = new Maintenance(this, 'Maintenance', {
      code: this.code,
      alertEmail: props.alertEmail,
    });

    new CfnOutput(this, 'ApiFunctionUrl', {
      value: this.functionUrl.url,
      description: 'The origin of the CloudFront distribution',
    });

    this.addPublicEndpoint();
  }

  /** api.plantai.ia.br and the role of the GitHub deploy (#91). */
  private addPublicEndpoint(): void {
    const endpoint = new PublicEndpoint(this, 'PublicEndpoint', {
      functionUrl: this.functionUrl,
      readTimeout: API_TIMEOUT,
    });
    const { distributionDomainName } = endpoint.distribution;
    new CfnOutput(this, 'ApiUrl', {
      value: `https://${API_DOMAIN}`,
      description: 'The address of the API for the app',
    });
    new CfnOutput(this, 'ApiDistributionUrl', {
      value: `https://${distributionDomainName}`,
      description: 'The CloudFront URL, before the api. CNAME exists',
    });
    new CfnOutput(this, 'ApiDistributionDomainName', {
      value: distributionDomainName,
      description: `The target of the ${API_DOMAIN} CNAME in Registro.br`,
    });

    const deploy = new GithubDeployRole(this, 'GithubDeploy');
    new CfnOutput(this, 'GithubDeployRoleArn', {
      value: deploy.role.roleArn,
      description: 'AWS_DEPLOY_ROLE_ARN of the production environment',
    });
  }
}
