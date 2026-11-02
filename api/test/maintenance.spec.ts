import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import postgres from 'postgres';
import { InvalidEnvError } from '../src/config/env';
import type { ParameterReader } from '../src/config/ssm-parameters';
import {
  MAINTENANCE_APPLICATION_NAME,
  type Maintenance,
  startMaintenance,
} from '../src/maintenance/maintenance';
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

/** Starts the routine as its Lambda entry does, closed after each test. */
async function start(
  source: Record<string, string | undefined>,
  readParameters?: ParameterReader,
): Promise<Maintenance> {
  const maintenance = await startMaintenance(source, {
    readParameters,
    log: (line) => logged.push(line),
  });
  started.push(maintenance);
  return maintenance;
}

afterEach(async () => {
  await Promise.all(started.splice(0).map((m) => m.close()));
  logged.length = 0;
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
      const maintenance = await start({ DATABASE_URL: databaseUrl });

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
      const maintenance = await start({
        DATABASE_URL: wrongPassword.toString(),
      });

      await expect(maintenance.run({ task: 'ping-database' })).rejects.toThrow(
        /password authentication failed/,
      );
    });
  });

  it('reads its secrets through the SSM loader of the API', async () => {
    const reads: string[] = [];
    const maintenance = await start(
      { SSM_PARAMETER_PREFIX: '/plantai/test' },
      (path) => {
        reads.push(path);
        return Promise.resolve({
          parameters: [
            { name: '/plantai/test/DATABASE_URL', value: databaseUrl },
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

  it('does not start without DATABASE_URL', async () => {
    await expect(start({})).rejects.toThrow(InvalidEnvError);
  });

  it('fails on an event that names no known task', async () => {
    const maintenance = await start({ DATABASE_URL: databaseUrl });

    await expect(maintenance.run({ task: 'make-coffee' })).rejects.toThrow(
      /Invalid maintenance event/,
    );
    await expect(maintenance.run({})).rejects.toThrow(
      /Invalid maintenance event/,
    );
  });
});
