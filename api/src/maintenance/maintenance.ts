import { sql } from 'drizzle-orm';
import { z } from 'zod';
import { parseEnvWith } from '../config/env';
import {
  loadSsmParameters,
  type ParameterReader,
} from '../config/ssm-parameters';
import { connectDatabase, type Database } from '../database/connect';
import { messageOf } from '../errors/message-of';
import { MAINTENANCE_TASKS, type MaintenanceTask } from './maintenance-task';

/** How the routine's sessions show in `pg_stat_activity`. */
export const MAINTENANCE_APPLICATION_NAME = 'plantai-maintenance';

/** Only what the routine uses; the other SSM parameters are ignored. */
const maintenanceEnvSchema = z.object({
  DATABASE_URL: z.url(),
});

export type MaintenanceEnv = z.infer<typeof maintenanceEnvSchema>;

const eventSchema = z.object({ task: z.enum(MAINTENANCE_TASKS) });

/** What a run answers: the task, plus whatever the task reports. */
export interface MaintenanceResult {
  task: MaintenanceTask;
}

/** What the tasks work with, created once per cold start. */
interface MaintenanceContext {
  db: Database;
}

type TaskRunner = (context: MaintenanceContext) => Promise<object>;

const TASKS: Record<MaintenanceTask, TaskRunner> = {
  /**
   * Keeps the Neon project alive: Neon deletes a Free project after 90 days
   * without activity, and only a query (not a bare connection) counts.
   */
  'ping-database': async ({ db }) => {
    await db.execute(sql`select 1`);
    return {};
  },
};

/** Stand-ins for the outside services, for the tests. */
export interface MaintenanceAdapters {
  readParameters?: ParameterReader;
  /** Where a finished task is reported; the function log by default. */
  log?: (line: string) => void;
}

export interface Maintenance {
  /** Runs the task the event names; any failure rejects (and alarms). */
  run(event: unknown): Promise<MaintenanceResult>;
  close(): Promise<void>;
}

/**
 * Starts the maintenance routine (#94): reads the secrets through the API's
 * SSM loader, validates its own environment and connects to the database.
 * No Nest, so the cold start stays light. The database connects on the first
 * query, so a database that is down fails the run, not the start.
 */
export async function startMaintenance(
  source: Record<string, string | undefined> = process.env,
  adapters: MaintenanceAdapters = {},
): Promise<Maintenance> {
  await loadSsmParameters(source, adapters.readParameters);
  const env = parseEnvWith(maintenanceEnvSchema, source);
  const db = connectDatabase(env.DATABASE_URL, {
    max: 1,
    connection: { application_name: MAINTENANCE_APPLICATION_NAME },
  });
  const context: MaintenanceContext = { db };
  const log = adapters.log ?? console.log;

  return {
    async run(event) {
      const parsed = eventSchema.safeParse(event);
      if (!parsed.success) {
        throw new Error(
          `Invalid maintenance event: expected { "task": ${MAINTENANCE_TASKS.map((task) => `"${task}"`).join(' | ')} }`,
        );
      }
      const { task } = parsed.data;
      let report: object;
      try {
        report = await TASKS[task](context);
      } catch (error) {
        // The Lambda log shows only the message: keep the cause in it.
        throw new Error(
          `Maintenance task ${task} failed: ${messageOf(error)}`,
          {
            cause: error,
          },
        );
      }
      log(`[maintenance] ${task} done`);
      return { ...report, task };
    },
    close: () => db.$client.end(),
  };
}
