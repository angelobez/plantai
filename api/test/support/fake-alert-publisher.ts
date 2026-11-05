import type {
  Alert,
  AlertPublisher,
} from '../../src/maintenance/alert-publisher';

/**
 * Stands in for the SNS alerts topic: keeps every alert it was given. Refuses
 * what SNS would, a subject that is not ASCII or has 100 characters or more.
 */
export class FakeAlertPublisher implements AlertPublisher {
  readonly published: Alert[] = [];

  /** While true, every publish fails as if SNS were down. */
  failing = false;

  publish(alert: Alert): Promise<void> {
    if (this.failing) {
      return Promise.reject(new Error('The fake SNS is down'));
    }
    if (!/^[\x20-\x7e]{1,99}$/.test(alert.subject)) {
      return Promise.reject(
        new Error(`SNS refuses the subject ${JSON.stringify(alert.subject)}`),
      );
    }
    this.published.push(structuredClone(alert));
    return Promise.resolve();
  }
}
