import { PublishCommand, SNSClient } from '@aws-sdk/client-sns';

/** An e-mail alert for Ângelo, in Portuguese. */
export interface Alert {
  /** The e-mail subject: SNS only takes ASCII, under 100 characters. */
  subject: string;
  message: string;
}

/** Sends the alerts: the SNS topic in AWS, a fake in the tests. */
export interface AlertPublisher {
  publish(alert: Alert): Promise<void>;
}

/** Publishes to the alerts topic, whose subscription e-mails them. */
export function snsAlertPublisher(
  topicArn: string,
  client: SNSClient = new SNSClient({}),
): AlertPublisher {
  return {
    async publish({ subject, message }) {
      await client.send(
        new PublishCommand({
          TopicArn: topicArn,
          Subject: subject,
          Message: message,
        }),
      );
    },
  };
}
