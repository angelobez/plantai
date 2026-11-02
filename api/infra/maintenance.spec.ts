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

const ALERT_EMAIL = 'alerts@example.com';

const template = Template.fromStack(
  new ApiStack(new App({ context }), 'TestApi', {
    env: { account: '123456789012', region: 'us-east-1' },
    code: Code.fromInline('exports.handler = async () => ({});'),
    alertEmail: ALERT_EMAIL,
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

const routine = (): string =>
  logicalIdOf('AWS::Lambda::Function', {
    Handler: 'dist/maintenance-lambda.handler',
  });
const topic = (): string => logicalIdOf('AWS::SNS::Topic');

describe('maintenance routine', () => {
  it('is a second function of the API package, with its own entry', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      Handler: 'dist/maintenance-lambda.handler',
      Runtime: 'nodejs24.x',
      Architectures: ['x86_64'],
      Environment: {
        Variables: Match.objectLike({
          // The same SSM loader (and prefix) as the API.
          SSM_PARAMETER_PREFIX: '/plantai/production',
        }),
      },
    });
  });

  it('keeps its logs for 30 days', () => {
    const fn = template.findResources('AWS::Lambda::Function')[routine()] as {
      Properties: { LoggingConfig: { LogGroup: { Ref: string } } };
    };
    const group = fn.Properties.LoggingConfig.LogGroup.Ref;
    expect(
      template.findResources('AWS::Logs::LogGroup')[group]?.Properties,
    ).toMatchObject({ RetentionInDays: 30 });
  });

  it('pings the database every week, through the EventBridge Scheduler', () => {
    template.hasResourceProperties('AWS::Scheduler::Schedule', {
      ScheduleExpression: 'cron(0 9 ? * MON *)',
      ScheduleExpressionTimezone: 'America/Sao_Paulo',
      State: 'ENABLED',
      FlexibleTimeWindow: { Mode: 'OFF' },
      Target: {
        Arn: { 'Fn::GetAtt': [routine(), 'Arn'] },
        Input: JSON.stringify({ task: 'ping-database' }),
      },
    });
  });

  it('e-mails the alerts topic', () => {
    template.hasResourceProperties('AWS::SNS::Subscription', {
      Protocol: 'email',
      Endpoint: ALERT_EMAIL,
      TopicArn: { Ref: topic() },
    });
  });

  it('alarms on any error of the routine, publishing to the alerts topic', () => {
    template.hasResourceProperties('AWS::CloudWatch::Alarm', {
      Namespace: 'AWS/Lambda',
      MetricName: 'Errors',
      Dimensions: [{ Name: 'FunctionName', Value: { Ref: routine() } }],
      Statistic: 'Sum',
      ComparisonOperator: 'GreaterThanOrEqualToThreshold',
      Threshold: 1,
      // No run in the period is not a failure: it runs once a week.
      TreatMissingData: 'notBreaching',
      AlarmActions: [{ Ref: topic() }],
    });
  });

  it('checks the Neon usage every day, through the EventBridge Scheduler', () => {
    template.hasResourceProperties('AWS::Scheduler::Schedule', {
      ScheduleExpression: 'cron(0 8 * * ? *)',
      ScheduleExpressionTimezone: 'America/Sao_Paulo',
      State: 'ENABLED',
      Target: {
        Arn: { 'Fn::GetAtt': [routine(), 'Arn'] },
        Input: JSON.stringify({ task: 'check-neon-usage' }),
      },
    });
  });

  it('tells the routine which topic gets the alerts', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      Handler: 'dist/maintenance-lambda.handler',
      Environment: {
        Variables: Match.objectLike({ ALERTS_TOPIC_ARN: { Ref: topic() } }),
      },
    });
  });

  it('lets the routine publish to the alerts topic, and to nothing else', () => {
    const fn = template.findResources('AWS::Lambda::Function')[routine()] as {
      Properties: { Role: { 'Fn::GetAtt': [string, string] } };
    };
    const role = fn.Properties.Role['Fn::GetAtt'][0];
    const statements = Object.values(
      template.findResources('AWS::IAM::Policy', {
        Properties: { Roles: [{ Ref: role }] },
      }),
    ).flatMap(
      (policy) =>
        (policy as { Properties: { PolicyDocument: { Statement: unknown[] } } })
          .Properties.PolicyDocument.Statement,
    ) as { Action: string | string[]; Resource: unknown }[];

    const sns = statements.filter((statement) =>
      [statement.Action].flat().some((action) => action.startsWith('sns:')),
    );
    expect(sns).toEqual([
      expect.objectContaining({
        Action: 'sns:Publish',
        Effect: 'Allow',
        Resource: { Ref: topic() },
      }),
    ]);
  });
});
