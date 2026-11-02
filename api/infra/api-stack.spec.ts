import { App } from 'aws-cdk-lib';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { Code } from 'aws-cdk-lib/aws-lambda';
import { ApiStack } from './api-stack';

/** The feature flags of cdk.json, so the test synthesizes what `cdk` does. */
const { context } = JSON.parse(
  readFileSync(join(__dirname, '..', 'cdk.json'), 'utf8'),
) as { context: Record<string, unknown> };

/** The stack as `infra/app.ts` builds it, with a stand-in for the package. */
function synthesize(): Template {
  const app = new App({ context });
  const stack = new ApiStack(app, 'TestApi', {
    env: { account: '123456789012', region: 'us-east-1' },
    code: Code.fromInline('exports.handler = async () => ({});'),
  });
  return Template.fromStack(stack);
}

const template = synthesize();

/** The logical id of the only resource of [type] matching [properties]. */
function logicalIdOf(type: string, properties: object = {}): string {
  const found = Object.keys(
    template.findResources(type, { Properties: properties }),
  );
  expect(found).toHaveLength(1);
  return found[0] ?? '';
}

/** The role of the API function. */
function apiRole(): string {
  const api = Object.values(
    template.findResources('AWS::Lambda::Function', {
      Properties: { Handler: 'dist/lambda.handler' },
    }),
  )[0] as { Properties: { Role: { 'Fn::GetAtt': [string, string] } } };
  return api.Properties.Role['Fn::GetAtt'][0];
}

describe('ApiStack', () => {
  describe('API function', () => {
    it('runs the serverless-express handler on Node.js 24 with 1 GB', () => {
      template.hasResourceProperties('AWS::Lambda::Function', {
        Handler: 'dist/lambda.handler',
        Runtime: 'nodejs24.x',
        Architectures: ['x86_64'],
        MemorySize: 1024,
      });
    });

    it('waits long enough for Pl@ntNet and a care guide (two Claude calls)', () => {
      template.hasResourceProperties('AWS::Lambda::Function', {
        Handler: 'dist/lambda.handler',
        Timeout: 60,
      });
    });

    it('never runs more than 20 executions at once (ADR 0004)', () => {
      template.hasResourceProperties('AWS::Lambda::Function', {
        Handler: 'dist/lambda.handler',
        ReservedConcurrentExecutions: 20,
      });
    });

    it('reads the secrets from the production SSM prefix and S3 with its role', () => {
      const bucket = logicalIdOf('AWS::S3::Bucket');
      template.hasResourceProperties('AWS::Lambda::Function', {
        Handler: 'dist/lambda.handler',
        Environment: {
          Variables: {
            SSM_PARAMETER_PREFIX: '/plantai/production',
            S3_BUCKET: { Ref: bucket },
            S3_REGION: 'us-east-1',
            // The Lambda runtime turns require(esm) off; Nest is ESM.
            NODE_OPTIONS: Match.stringLikeRegexp(
              '--experimental-require-module',
            ),
          },
        },
      });
      const variables = Object.values(
        template.findResources('AWS::Lambda::Function'),
      ).map((fn) =>
        Object.keys(
          (fn as { Properties: { Environment?: { Variables: object } } })
            .Properties.Environment?.Variables ?? {},
        ),
      );
      for (const names of variables) {
        expect(names).not.toContain('S3_ENDPOINT');
        expect(names).not.toContain('S3_ACCESS_KEY_ID');
        expect(names).not.toContain('S3_SECRET_ACCESS_KEY');
      }
    });

    it('is reachable through a Function URL without IAM auth', () => {
      template.hasResourceProperties('AWS::Lambda::Url', {
        AuthType: 'NONE',
        TargetFunctionArn: {
          'Fn::GetAtt': [
            logicalIdOf('AWS::Lambda::Function', {
              Handler: 'dist/lambda.handler',
            }),
            'Arn',
          ],
        },
      });
    });
  });

  describe('logs', () => {
    it('keeps the function logs for 30 days in a group of the stack', () => {
      const api = Object.values(
        template.findResources('AWS::Lambda::Function', {
          Properties: { Handler: 'dist/lambda.handler' },
        }),
      )[0] as { Properties: { LoggingConfig: { LogGroup: { Ref: string } } } };
      const group = api.Properties.LoggingConfig.LogGroup.Ref;
      expect(
        template.findResources('AWS::Logs::LogGroup')[group]?.Properties,
      ).toEqual({ RetentionInDays: 30 });
    });
  });

  describe('photo bucket', () => {
    it('is private, encrypted and only reachable over TLS', () => {
      template.hasResourceProperties('AWS::S3::Bucket', {
        PublicAccessBlockConfiguration: {
          BlockPublicAcls: true,
          BlockPublicPolicy: true,
          IgnorePublicAcls: true,
          RestrictPublicBuckets: true,
        },
        BucketEncryption: {
          ServerSideEncryptionConfiguration: [
            { ServerSideEncryptionByDefault: { SSEAlgorithm: 'AES256' } },
          ],
        },
      });
      template.hasResourceProperties('AWS::S3::BucketPolicy', {
        PolicyDocument: {
          Statement: Match.arrayWith([
            Match.objectLike({
              Effect: 'Deny',
              Condition: { Bool: { 'aws:SecureTransport': 'false' } },
            }),
          ]),
        },
      });
    });

    it('survives the removal of the stack', () => {
      template.hasResource('AWS::S3::Bucket', {
        DeletionPolicy: 'Retain',
        UpdateReplacePolicy: 'Retain',
      });
    });

    it('deletes the photos tagged unattached after 1 day', () => {
      template.hasResourceProperties('AWS::S3::Bucket', {
        LifecycleConfiguration: {
          Rules: [
            {
              Status: 'Enabled',
              ExpirationInDays: 1,
              TagFilters: [{ Key: 'unattached', Value: 'true' }],
            },
          ],
        },
      });
    });
  });

  describe('permissions of the API function', () => {
    it('reach only the photo objects and the production SSM prefix', () => {
      const bucket = logicalIdOf('AWS::S3::Bucket');
      const statements = Object.values(
        template.findResources('AWS::IAM::Policy', {
          Properties: { Roles: [{ Ref: apiRole() }] },
        }),
      ).flatMap(
        (policy) =>
          (
            policy as {
              Properties: { PolicyDocument: { Statement: unknown[] } };
            }
          ).Properties.PolicyDocument.Statement,
      );

      expect(statements).toEqual([
        {
          Effect: 'Allow',
          Action: 'ssm:GetParametersByPath',
          Resource: [
            'arn:aws:ssm:us-east-1:123456789012:parameter/plantai/production',
            'arn:aws:ssm:us-east-1:123456789012:parameter/plantai/production/*',
          ],
        },
        {
          Effect: 'Allow',
          Action: [
            's3:DeleteObject',
            's3:DeleteObjectTagging',
            's3:GetObject',
            's3:PutObject',
            's3:PutObjectTagging',
          ],
          Resource: {
            'Fn::Join': ['', [{ 'Fn::GetAtt': [bucket, 'Arn'] }, '/*']],
          },
        },
        {
          // Without it, a missing photo reads as 403 instead of NoSuchKey.
          Effect: 'Allow',
          Action: 's3:ListBucket',
          Resource: { 'Fn::GetAtt': [bucket, 'Arn'] },
        },
      ]);
    });

    it('have no managed policy beyond writing its own logs', () => {
      const role = template.findResources('AWS::IAM::Role')[apiRole()];
      expect(role?.Properties).toMatchObject({
        ManagedPolicyArns: [
          {
            'Fn::Join': [
              '',
              [
                'arn:',
                { Ref: 'AWS::Partition' },
                ':iam::aws:policy/service-role/AWSLambdaBasicExecutionRole',
              ],
            ],
          },
        ],
      });
    });
  });

  it('outputs the Function URL, for the CloudFront origin', () => {
    template.hasOutput('ApiFunctionUrl', {
      Value: {
        'Fn::GetAtt': [logicalIdOf('AWS::Lambda::Url'), 'FunctionUrl'],
      },
    });
  });
});
