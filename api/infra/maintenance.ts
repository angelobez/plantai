import { Duration, TimeZone } from 'aws-cdk-lib';
import {
  Alarm,
  ComparisonOperator,
  TreatMissingData,
} from 'aws-cdk-lib/aws-cloudwatch';
import { SnsAction } from 'aws-cdk-lib/aws-cloudwatch-actions';
import type { Code } from 'aws-cdk-lib/aws-lambda';
import {
  Schedule,
  ScheduleExpression,
  ScheduleTargetInput,
} from 'aws-cdk-lib/aws-scheduler';
import { LambdaInvoke } from 'aws-cdk-lib/aws-scheduler-targets';
import { Topic } from 'aws-cdk-lib/aws-sns';
import { EmailSubscription } from 'aws-cdk-lib/aws-sns-subscriptions';
import { Construct } from 'constructs';
import type {
  MaintenanceEvent,
  MaintenanceTask,
} from '../src/maintenance/maintenance-task';
import { PackagedFunction } from './packaged-function';

export interface MaintenanceProps {
  /** The package of `npm run lambda:package`, shared with the API. */
  code: Code;
  /** Who gets the alerts (ALERT_EMAIL at deploy time, see infra/app.ts). */
  alertEmail: string;
}

/**
 * The maintenance routine (#94): a second function of the API package,
 * called by the EventBridge Scheduler (in AWS, so it keeps running when the
 * repository goes quiet), and the e-mail alerts topic, which also gets an
 * alarm whenever the routine fails and the routine's own alerts (#95). Add a
 * task with {@link schedule}.
 */
export class Maintenance extends Construct {
  readonly routine: PackagedFunction;
  /** E-mails the alerts; the alarms of #78 publish here too. */
  readonly alerts: Topic;

  constructor(scope: Construct, id: string, props: MaintenanceProps) {
    super(scope, id);

    this.alerts = new Topic(this, 'Alerts', { displayName: 'PlantAí alerts' });
    this.alerts.addSubscription(new EmailSubscription(props.alertEmail));

    this.routine = new PackagedFunction(this, 'Routine', {
      code: props.code,
      handler: 'dist/maintenance-lambda.handler',
      description: 'PlantAí maintenance routine (scheduled tasks)',
      // No Nest: the database client and the SSM loader only.
      memorySize: 256,
      // Waking a suspended Neon compute takes a few seconds.
      timeout: Duration.seconds(30),
      environment: { ALERTS_TOPIC_ARN: this.alerts.topicArn },
    });
    this.alerts.grantPublish(this.routine.function);

    new Alarm(this, 'RoutineErrors', {
      alarmDescription:
        'The PlantAí maintenance routine failed (see its log group)',
      metric: this.routine.function.metricErrors({
        period: Duration.minutes(5),
        statistic: 'Sum',
      }),
      threshold: 1,
      evaluationPeriods: 1,
      comparisonOperator: ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      // Most periods have no run at all.
      treatMissingData: TreatMissingData.NOT_BREACHING,
    }).addAlarmAction(new SnsAction(this.alerts));

    // Neon deletes a Free project after 90 days without activity.
    this.schedule(
      'PingDatabase',
      ScheduleExpression.cron({
        weekDay: 'MON',
        hour: '9',
        minute: '0',
        timeZone: TimeZone.AMERICA_SAO_PAULO,
      }),
      'ping-database',
    );

    // Neon suspends a Free project past 100 CU-hours in the month (#95).
    this.schedule(
      'CheckNeonUsage',
      ScheduleExpression.cron({
        hour: '8',
        minute: '0',
        timeZone: TimeZone.AMERICA_SAO_PAULO,
      }),
      'check-neon-usage',
    );
  }

  /** Invokes the routine with `{ "task": [task] }` on [expression]. */
  schedule(
    id: string,
    expression: ScheduleExpression,
    task: MaintenanceTask,
  ): Schedule {
    const event: MaintenanceEvent = { task };
    return new Schedule(this, id, {
      description: `PlantAí maintenance: ${task}`,
      schedule: expression,
      target: new LambdaInvoke(this.routine.function, {
        input: ScheduleTargetInput.fromObject(event),
      }),
    });
  }
}
