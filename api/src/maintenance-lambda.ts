import { type LambdaHandler, lambdaEntry } from './lambda-entry';
import {
  type MaintenanceResult,
  startMaintenance,
} from './maintenance/maintenance';

/**
 * AWS Lambda entry of the maintenance routine (#94), invoked by the
 * EventBridge Scheduler with `{ "task": "<name>" }`. A second function of the
 * API package, without Nest: it only needs the database.
 */
export const handler: LambdaHandler<unknown, MaintenanceResult> = lambdaEntry(
  async () => {
    const maintenance = await startMaintenance();
    return (event) => maintenance.run(event);
  },
);
