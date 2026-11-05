import { type Duration, RemovalPolicy, Stack } from 'aws-cdk-lib';
import {
  Certificate,
  CertificateValidation,
} from 'aws-cdk-lib/aws-certificatemanager';
import {
  AllowedMethods,
  CachePolicy,
  Distribution,
  OriginRequestCookieBehavior,
  OriginRequestHeaderBehavior,
  OriginRequestPolicy,
  OriginRequestQueryStringBehavior,
  ViewerProtocolPolicy,
} from 'aws-cdk-lib/aws-cloudfront';
import { FunctionUrlOrigin } from 'aws-cdk-lib/aws-cloudfront-origins';
import { PolicyStatement } from 'aws-cdk-lib/aws-iam';
import type { IFunctionUrl } from 'aws-cdk-lib/aws-lambda';
import { LogGroup, RetentionDays } from 'aws-cdk-lib/aws-logs';
import {
  AwsCustomResource,
  AwsCustomResourcePolicy,
  Logging,
  PhysicalResourceId,
} from 'aws-cdk-lib/custom-resources';
import { Construct } from 'constructs';
import { PRODUCTION_SSM_PREFIX } from './packaged-function';

/** The address of the API for the app (#16). */
export const API_DOMAIN = 'api.plantai.ia.br';

/** The origin header the API checks (`ORIGIN_SECRET_HEADER`, #88). */
const ORIGIN_SECRET_HEADER = 'X-Origin-Verify';

/** The SecureString the API also loads as `CLOUDFRONT_ORIGIN_SECRET`. */
const ORIGIN_SECRET_PARAMETER = `${PRODUCTION_SSM_PREFIX}/CLOUDFRONT_ORIGIN_SECRET`;

/**
 * Bump it after changing the origin secret in SSM: the reader only runs when
 * its properties change, so this is what makes the next deploy read it again.
 */
const ORIGIN_SECRET_GENERATION = '1';

export interface PublicEndpointProps {
  /** The Function URL of the API, the only origin. */
  functionUrl: IFunctionUrl;
  /** How long the API may take to answer (the function's timeout). */
  readTimeout: Duration;
}

/**
 * `https://api.plantai.ia.br`: a CloudFront distribution in front of the
 * Function URL, with an ACM certificate validated by DNS in Registro.br and
 * the origin secret header the API demands (#88).
 */
export class PublicEndpoint extends Construct {
  readonly distribution: Distribution;
  readonly certificate: Certificate;

  constructor(scope: Construct, id: string, props: PublicEndpointProps) {
    super(scope, id);

    // No hosted zone: the DNS lives in Registro.br, so CloudFormation waits
    // on the first deploy until the validation CNAME is added there by hand.
    this.certificate = new Certificate(this, 'Certificate', {
      domainName: API_DOMAIN,
      validation: CertificateValidation.fromDns(),
    });

    this.distribution = new Distribution(this, 'Distribution', {
      comment: `PlantAí API (${API_DOMAIN})`,
      domainNames: [API_DOMAIN],
      certificate: this.certificate,
      defaultBehavior: {
        origin: new FunctionUrlOrigin(props.functionUrl, {
          readTimeout: props.readTimeout,
          customHeaders: { [ORIGIN_SECRET_HEADER]: this.readOriginSecret() },
        }),
        allowedMethods: AllowedMethods.ALLOW_ALL,
        viewerProtocolPolicy: ViewerProtocolPolicy.HTTPS_ONLY,
        // Answers are per user: none may reach another user (US 16).
        cachePolicy: CachePolicy.CACHING_DISABLED,
        originRequestPolicy: new OriginRequestPolicy(
          this,
          'OriginRequestPolicy',
          {
            comment: 'Every viewer header but Host, and no CloudFront header',
            // The Function URL needs its own Host. allExcept never adds
            // CloudFront's headers, so no viewer location or IP (#77).
            headerBehavior: OriginRequestHeaderBehavior.denyList('Host'),
            cookieBehavior: OriginRequestCookieBehavior.all(),
            queryStringBehavior: OriginRequestQueryStringBehavior.all(),
          },
        ),
      },
    });
  }

  /**
   * The origin secret, read from its SSM SecureString at deploy time by a
   * custom resource. CloudFormation resolves no `ssm-secure` reference in
   * CloudFront, and an `ssm` one (plain String) is resolved with the
   * credentials of the CDK deploy role, which may only read the bootstrap
   * version. The template keeps a `Fn::GetAtt`, never the value.
   */
  private readOriginSecret(): string {
    const parameterArn = Stack.of(this).formatArn({
      service: 'ssm',
      resource: 'parameter',
      resourceName: ORIGIN_SECRET_PARAMETER.slice(1),
    });
    const reader = new AwsCustomResource(this, 'OriginSecret', {
      onUpdate: {
        service: 'SSM',
        action: 'GetParameter',
        parameters: {
          Name: ORIGIN_SECRET_PARAMETER,
          WithDecryption: true,
        },
        outputPaths: ['Parameter.Value'],
        physicalResourceId: PhysicalResourceId.of(
          `${ORIGIN_SECRET_PARAMETER}#${ORIGIN_SECRET_GENERATION}`,
        ),
        logging: Logging.withDataHidden(),
      },
      policy: AwsCustomResourcePolicy.fromStatements([
        new PolicyStatement({
          actions: ['ssm:GetParameter'],
          resources: [parameterArn],
        }),
      ]),
      installLatestAwsSdk: false,
      // The same 30 days as the API's logs, not the default of 2 years.
      logGroup: new LogGroup(this, 'OriginSecretLogs', {
        retention: RetentionDays.ONE_MONTH,
        removalPolicy: RemovalPolicy.DESTROY,
      }),
    });
    return reader.getResponseField('Parameter.Value');
  }
}
