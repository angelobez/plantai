import { PublishCommand, type SNSClient } from '@aws-sdk/client-sns';
import { snsAlertPublisher } from './alert-publisher';

describe('snsAlertPublisher', () => {
  it('publishes the alert to the topic', async () => {
    const sent: unknown[] = [];
    const client = {
      send: (command: unknown) => {
        sent.push(command);
        return Promise.resolve({ MessageId: 'm-1' });
      },
    } as unknown as SNSClient;

    await snsAlertPublisher(
      'arn:aws:sns:us-east-1:123456789012:Alerts',
      client,
    ).publish({ subject: 'PlantAi: test', message: 'Corpo do aviso' });

    expect(sent).toHaveLength(1);
    expect(sent[0]).toBeInstanceOf(PublishCommand);
    expect((sent[0] as PublishCommand).input).toEqual({
      TopicArn: 'arn:aws:sns:us-east-1:123456789012:Alerts',
      Subject: 'PlantAi: test',
      Message: 'Corpo do aviso',
    });
  });
});
