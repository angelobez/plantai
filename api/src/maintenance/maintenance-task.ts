/**
 * The tasks of the maintenance routine, one per schedule of the stack
 * (`infra/maintenance.ts`). The schedule sends `{ "task": "<name>" }`.
 * Kept free of runtime dependencies: the CDK app imports it too.
 */
export const MAINTENANCE_TASKS = ['ping-database'] as const;

export type MaintenanceTask = (typeof MAINTENANCE_TASKS)[number];

/** The event a schedule sends to the maintenance function. */
export interface MaintenanceEvent {
  task: MaintenanceTask;
}
