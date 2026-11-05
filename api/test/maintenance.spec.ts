import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import postgres from 'postgres';
import { InvalidEnvError } from '../src/config/env';
import type { ParameterReader } from '../src/config/ssm-parameters';
import {
  MAINTENANCE_APPLICATION_NAME,
  type Maintenance,
  startMaintenance,
} from '../src/maintenance/maintenance';
import { FakeAlertPublisher } from './support/fake-alert-publisher';
import { DECEMBER, FakeNeonApi, NOVEMBER } from './support/fake-neon-api';
import { startPostgis } from './support/postgis';

let container: StartedPostgreSqlContainer;
let databaseUrl: string;
/** A connection of the test itself, to look at what the routine did. */
let observer: postgres.Sql;

beforeAll(async () => {
  container = await startPostgis();
  databaseUrl = container.getConnectionUri();
  observer = postgres(databaseUrl, { max: 1, onnotice: () => undefined });
});

afterAll(async () => {
  await observer.end();
  await container.stop();
});

const started: Maintenance[] = [];
const logged: string[] = [];
let neon: FakeNeonApi;
let alerts: FakeAlertPublisher;

beforeEach(() => {
  neon = new FakeNeonApi();
  alerts = new FakeAlertPublisher();
});

/** Everything the routine needs, as the Lambda gets it in AWS. */
function routineEnv(
  overrides: Record<string, string | undefined> = {},
): Record<string, string | undefined> {
  return {
    DATABASE_URL: databaseUrl,
    NEON_API_KEY: 'neon-test-key',
    NEON_PROJECT_ID: 'test-project',
    ALERTS_TOPIC_ARN: 'arn:aws:sns:us-east-1:123456789012:TestAlerts',
    ...overrides,
  };
}

/**
 * Starts the routine as its Lambda entry does, with the fake Neon API and
 * alerts topic, closed after each test.
 */
async function start(
  source: Record<string, string | undefined>,
  readParameters?: ParameterReader,
): Promise<Maintenance> {
  const maintenance = await startMaintenance(source, {
    readParameters,
    neon,
    alerts,
    log: (line) => logged.push(line),
  });
  started.push(maintenance);
  return maintenance;
}

afterEach(async () => {
  await Promise.all(started.splice(0).map((m) => m.close()));
  logged.length = 0;
  // Each test starts with no cycle alerted yet.
  await observer`DELETE FROM maintenance_state`;
});

/** The last statement of each open session of the routine. */
async function routineQueries(): Promise<string[]> {
  const sessions = await observer<{ query: string }[]>`
    SELECT query FROM pg_stat_activity
    WHERE application_name = ${MAINTENANCE_APPLICATION_NAME}`;
  return sessions.map((session) => session.query);
}

describe('maintenance routine', () => {
  describe('ping-database', () => {
    it('runs a query on the database, not only a connection', async () => {
      const maintenance = await start(routineEnv());

      await expect(maintenance.run({ task: 'ping-database' })).resolves.toEqual(
        { task: 'ping-database' },
      );
      // Neon only promises that a query (not a bare connection) keeps it.
      expect(await routineQueries()).toEqual([
        expect.stringMatching(/^select 1$/i),
      ]);
      expect(logged).toEqual(['[maintenance] ping-database done']);
    });

    it('fails when the database does, instead of swallowing it', async () => {
      const wrongPassword = new URL(databaseUrl);
      wrongPassword.password = 'not-the-password';
      const maintenance = await start(
        routineEnv({ DATABASE_URL: wrongPassword.toString() }),
      );

      await expect(maintenance.run({ task: 'ping-database' })).rejects.toThrow(
        /password authentication failed/,
      );
    });
  });

  it('reads its secrets through the SSM loader of the API', async () => {
    const reads: string[] = [];
    const maintenance = await start(
      {
        SSM_PARAMETER_PREFIX: '/plantai/test',
        // Set by the stack on the function, not a secret.
        ALERTS_TOPIC_ARN: 'arn:aws:sns:us-east-1:123456789012:TestAlerts',
      },
      (path) => {
        reads.push(path);
        return Promise.resolve({
          parameters: [
            { name: '/plantai/test/DATABASE_URL', value: databaseUrl },
            { name: '/plantai/test/NEON_API_KEY', value: 'neon-test-key' },
            { name: '/plantai/test/NEON_PROJECT_ID', value: 'test-project' },
            { name: '/plantai/test/JWT_SECRET', value: 'not-for-the-routine' },
          ],
        });
      },
    );

    await expect(maintenance.run({ task: 'ping-database' })).resolves.toEqual({
      task: 'ping-database',
    });
    expect(reads).toEqual(['/plantai/test']);
  });

  it.each([
    'DATABASE_URL',
    'NEON_API_KEY',
    'NEON_PROJECT_ID',
    'ALERTS_TOPIC_ARN',
  ])('does not start without %s', async (name) => {
    await expect(start(routineEnv({ [name]: undefined }))).rejects.toThrow(
      InvalidEnvError,
    );
  });

  it('fails on an event that names no known task', async () => {
    const maintenance = await start(routineEnv());

    await expect(maintenance.run({ task: 'make-coffee' })).rejects.toThrow(
      /Invalid maintenance event/,
    );
    await expect(maintenance.run({})).rejects.toThrow(
      /Invalid maintenance event/,
    );
  });

  describe('check-neon-usage', () => {
    const check = { task: 'check-neon-usage' };

    it('publishes nothing up to 80 CU-hours', async () => {
      const maintenance = await start(routineEnv());

      neon.uses(12.5);
      await expect(maintenance.run(check)).resolves.toEqual({
        task: 'check-neon-usage',
        cuHours: 12.5,
        periodStart: NOVEMBER,
        alerted: false,
      });
      neon.uses(80);
      await expect(maintenance.run(check)).resolves.toMatchObject({
        cuHours: 80,
        alerted: false,
      });
      expect(alerts.published).toEqual([]);
      expect(logged).toEqual([
        '[maintenance] check-neon-usage done',
        '[maintenance] check-neon-usage done',
      ]);
    });

    it('alerts once above 80 CU-hours in a billing cycle', async () => {
      const maintenance = await start(routineEnv());

      neon.uses(80.4);
      await expect(maintenance.run(check)).resolves.toEqual({
        task: 'check-neon-usage',
        cuHours: 80.4,
        periodStart: NOVEMBER,
        alerted: true,
      });
      expect(alerts.published).toHaveLength(1);
      expect(alerts.published[0]?.subject).toMatch(/Neon.*80 CU-horas/);
      expect(alerts.published[0]?.message).toContain('80,4 CU-horas');
      expect(alerts.published[0]?.message).toMatch(/Launch/);

      // The next days of the same cycle: still above, but already alerted.
      neon.uses(93);
      await expect(maintenance.run(check)).resolves.toMatchObject({
        alerted: false,
      });
      expect(alerts.published).toHaveLength(1);
    });

    it('alerts again in the next billing cycle', async () => {
      const maintenance = await start(routineEnv());
      await maintenance.run(neonAt(85, NOVEMBER));

      await expect(
        maintenance.run(neonAt(81, DECEMBER)),
      ).resolves.toMatchObject({ periodStart: DECEMBER, alerted: true });
      await expect(
        maintenance.run(neonAt(90, DECEMBER)),
      ).resolves.toMatchObject({ alerted: false });
      expect(alerts.published).toHaveLength(2);
    });

    it('remembers the alerted cycle across cold starts', async () => {
      neon.uses(85);
      await (await start(routineEnv())).run(check);

      const restarted = await start(routineEnv());
      await expect(restarted.run(check)).resolves.toMatchObject({
        alerted: false,
      });
      expect(alerts.published).toHaveLength(1);
    });

    it('fails when the Neon API does, publishing nothing', async () => {
      const maintenance = await start(routineEnv());
      neon.failing = true;

      await expect(maintenance.run(check)).rejects.toThrow(
        /Maintenance task check-neon-usage failed: .*503/,
      );
      expect(alerts.published).toEqual([]);
    });

    it('alerts on the next run when publishing fails', async () => {
      const maintenance = await start(routineEnv());
      neon.uses(85);
      alerts.failing = true;

      await expect(maintenance.run(check)).rejects.toThrow(
        /check-neon-usage failed: The fake SNS is down/,
      );
      // The cycle is not marked as alerted, so the next run tries again.
      alerts.failing = false;
      await expect(maintenance.run(check)).resolves.toMatchObject({
        alerted: true,
      });
      expect(alerts.published).toHaveLength(1);
    });

    /** Makes the fake Neon answer [cuHours] and returns the check event. */
    function neonAt(cuHours: number, periodStart: string): typeof check {
      neon.uses(cuHours, periodStart);
      return check;
    }
  });
});
