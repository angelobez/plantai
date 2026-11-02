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

const template = Template.fromStack(
  new ApiStack(new App({ context }), 'TestApi', {
    env: { account: '123456789012', region: 'us-east-1' },
    code: Code.fromInline('exports.handler = async () => ({});'),
    alertEmail: 'alerts@example.com',
  }),
);

/** The logical id of the only resource of [type] matching [properties]. */
function logicalIdOf(type: string, properties: object = {}): string {
  const found = Object.keys(
    template.findResources(type, { Properties: properties }),
  );
  expect(found).toHaveLength(1);
  return found[0] ?? '';
}

interface DistributionConfig {
  Aliases: string[];
  ViewerCertificate: { AcmCertificateArn: unknown };
  Origins: {
    DomainName: unknown;
    OriginCustomHeaders: { HeaderName: string; HeaderValue: unknown }[];
  }[];
  DefaultCacheBehavior: {
    AllowedMethods: string[];
    CachePolicyId: string;
    OriginRequestPolicyId: unknown;
  };
}

function distribution(): DistributionConfig {
  const id = logicalIdOf('AWS::CloudFront::Distribution');
  return (
    template.findResources('AWS::CloudFront::Distribution')[id] as {
      Properties: { DistributionConfig: DistributionConfig };
    }
  ).Properties.DistributionConfig;
}

describe('ApiStack public endpoint', () => {
  describe('certificate', () => {
    it('covers api.plantai.ia.br, validated by DNS (in Registro.br)', () => {
      template.hasResourceProperties('AWS::CertificateManager::Certificate', {
        DomainName: 'api.plantai.ia.br',
        ValidationMethod: 'DNS',
        // No Route 53 zone: the validation record is added by hand.
        DomainValidationOptions: Match.absent(),
      });
    });
  });

  describe('CloudFront distribution', () => {
    it('answers on api.plantai.ia.br with the certificate', () => {
      const config = distribution();
      expect(config.Aliases).toEqual(['api.plantai.ia.br']);
      expect(config.ViewerCertificate).toMatchObject({
        AcmCertificateArn: {
          Ref: logicalIdOf('AWS::CertificateManager::Certificate'),
        },
        SslSupportMethod: 'sni-only',
      });
    });

    it('forwards to the Function URL', () => {
      const [origin] = distribution().Origins;
      expect(JSON.stringify(origin?.DomainName)).toContain(
        logicalIdOf('AWS::Lambda::Url'),
      );
    });

    it('caches nothing (managed CachingDisabled policy)', () => {
      expect(distribution().DefaultCacheBehavior.CachePolicyId).toBe(
        '4135ea2d-6df8-44a3-9df3-4b5a84be39ad',
      );
    });

    it('allows every HTTP method', () => {
      expect(
        [...distribution().DefaultCacheBehavior.AllowedMethods].sort(),
      ).toEqual(['DELETE', 'GET', 'HEAD', 'OPTIONS', 'PATCH', 'POST', 'PUT']);
    });

    it('waits as long as the function runs', () => {
      template.hasResourceProperties('AWS::CloudFront::Distribution', {
        DistributionConfig: {
          Origins: [
            Match.objectLike({
              CustomOriginConfig: Match.objectLike({
                OriginReadTimeout: 60,
                OriginProtocolPolicy: 'https-only',
              }),
            }),
          ],
        },
      });
    });
  });

  describe('origin request policy', () => {
    it('forwards every viewer header but Host, and no cloudfront-viewer-*', () => {
      const policy = logicalIdOf('AWS::CloudFront::OriginRequestPolicy');
      expect(distribution().DefaultCacheBehavior.OriginRequestPolicyId).toEqual(
        { Ref: policy },
      );
      template.hasResourceProperties('AWS::CloudFront::OriginRequestPolicy', {
        OriginRequestPolicyConfig: {
          // allExcept never adds CloudFront's own headers: those need
          // allViewerAndWhitelistCloudFront or a whitelist.
          HeadersConfig: { HeaderBehavior: 'allExcept', Headers: ['Host'] },
          CookiesConfig: { CookieBehavior: 'all' },
          QueryStringsConfig: { QueryStringBehavior: 'all' },
        },
      });
      const headers = JSON.stringify(
        template.findResources('AWS::CloudFront::OriginRequestPolicy'),
      );
      expect(headers.toLowerCase()).not.toContain('cloudfront-viewer');
    });
  });

  describe('origin secret header', () => {
    it('carries the SecureString of SSM, read at deploy time', () => {
      const reader = logicalIdOf('Custom::AWS');
      const [origin] = distribution().Origins;
      expect(origin?.OriginCustomHeaders).toEqual([
        {
          HeaderName: 'X-Origin-Verify',
          HeaderValue: { 'Fn::GetAtt': [reader, 'Parameter.Value'] },
        },
      ]);
      const { Create, Update } = (
        template.findResources('Custom::AWS')[reader] as {
          Properties: { Create: string; Update: string };
        }
      ).Properties;
      for (const call of [Create, Update]) {
        expect(JSON.parse(call)).toMatchObject({
          service: 'SSM',
          action: 'GetParameter',
          parameters: {
            Name: '/plantai/production/CLOUDFRONT_ORIGIN_SECRET',
            WithDecryption: true,
          },
          // Never the value itself in the custom resource's log.
          logApiResponseData: false,
        });
      }
    });

    it('is read by a role allowed that one parameter only', () => {
      template.hasResourceProperties('AWS::IAM::Policy', {
        PolicyDocument: {
          Statement: [
            {
              Effect: 'Allow',
              Action: 'ssm:GetParameter',
              Resource:
                'arn:aws:ssm:us-east-1:123456789012:parameter/plantai/production/CLOUDFRONT_ORIGIN_SECRET',
            },
          ],
        },
      });
    });

    it('keeps the logs of the reader for 30 days', () => {
      const reader = Object.values(
        template.findResources('AWS::Lambda::Function', {
          Properties: { Handler: 'index.handler' },
        }),
      ) as { Properties: { LoggingConfig: { LogGroup: { Ref: string } } } }[];
      expect(reader).toHaveLength(1);
      const group = reader[0]?.Properties.LoggingConfig.LogGroup.Ref ?? '';
      expect(
        template.findResources('AWS::Logs::LogGroup')[group]?.Properties,
      ).toEqual({ RetentionInDays: 30 });
    });
  });

  describe('GitHub Actions deploy role', () => {
    function deployRole(): string {
      return logicalIdOf('AWS::IAM::Role', {
        AssumeRolePolicyDocument: {
          Statement: [
            Match.objectLike({ Action: 'sts:AssumeRoleWithWebIdentity' }),
          ],
        },
      });
    }

    it('trusts GitHub OIDC tokens', () => {
      template.hasResourceProperties('AWS::IAM::OIDCProvider', {
        Url: 'https://token.actions.githubusercontent.com',
        ClientIdList: ['sts.amazonaws.com'],
      });
    });

    it('trusts only the production environment of angelobez/plantai', () => {
      const role = template.findResources('AWS::IAM::Role')[deployRole()];
      expect(role?.Properties).toMatchObject({
        AssumeRolePolicyDocument: {
          Statement: [
            {
              Effect: 'Allow',
              Action: 'sts:AssumeRoleWithWebIdentity',
              Principal: {
                Federated: {
                  Ref: logicalIdOf('AWS::IAM::OIDCProvider'),
                },
              },
              Condition: {
                StringEquals: {
                  'token.actions.githubusercontent.com:aud':
                    'sts.amazonaws.com',
                  // The immutable format (owner and repository ids). Only
                  // `main` may deploy to the environment (its branch policy).
                  'token.actions.githubusercontent.com:sub':
                    'repo:angelobez@109678169/plantai@1426449697:environment:production',
                },
              },
            },
          ],
        },
      });
    });

    it('may only assume the CDK bootstrap roles and read the concurrency quota', () => {
      const statements = Object.values(
        template.findResources('AWS::IAM::Policy', {
          Properties: { Roles: [{ Ref: deployRole() }] },
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
          Action: 'sts:AssumeRole',
          Resource: [
            'arn:aws:iam::123456789012:role/cdk-hnb659fds-deploy-role-123456789012-us-east-1',
            'arn:aws:iam::123456789012:role/cdk-hnb659fds-file-publishing-role-123456789012-us-east-1',
            'arn:aws:iam::123456789012:role/cdk-hnb659fds-lookup-role-123456789012-us-east-1',
          ],
        },
        {
          // infra/check-concurrency-quota.ts, before cdk deploy (US 42).
          Effect: 'Allow',
          Action: 'lambda:GetAccountSettings',
          Resource: '*',
        },
      ]);
      const role = template.findResources('AWS::IAM::Role')[deployRole()];
      expect(role?.Properties).not.toHaveProperty('ManagedPolicyArns');
    });
  });

  describe('outputs', () => {
    it('give the CloudFront URL and its domain, the target of the api. CNAME', () => {
      const id = logicalIdOf('AWS::CloudFront::Distribution');
      template.hasOutput('ApiDistributionDomainName', {
        Value: { 'Fn::GetAtt': [id, 'DomainName'] },
      });
      template.hasOutput('ApiDistributionUrl', {
        Value: {
          'Fn::Join': ['', ['https://', { 'Fn::GetAtt': [id, 'DomainName'] }]],
        },
      });
      template.hasOutput('ApiUrl', { Value: 'https://api.plantai.ia.br' });
    });

    it('give the deploy role ARN, for the production environment of GitHub', () => {
      template.hasOutput('GithubDeployRoleArn', {
        Value: Match.objectLike({ 'Fn::GetAtt': Match.anyValue() }),
      });
    });
  });
});
