import { Controller, Get, Inject } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { API_VERSION } from '../app-version';
import { DATABASE, type Database } from '../database/database.module';
import { DomainError } from '../errors/domain-error';

interface HealthResponse {
  status: 'ok';
  apiVersion: string;
  postgisVersion: string;
}

@Controller('health')
export class HealthController {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  @Get()
  async check(): Promise<HealthResponse> {
    const postgisVersion = await this.readPostgisVersion();
    return { status: 'ok', apiVersion: API_VERSION, postgisVersion };
  }

  /** Reads from the database itself, so a healthy answer proves PostGIS is up. */
  private async readPostgisVersion(): Promise<string> {
    try {
      const [row] = await this.db.execute<{ version: string }>(
        sql`SELECT postgis_lib_version() AS version`,
      );
      if (!row) throw new Error('postgis_lib_version() returned no rows');
      return row.version;
    } catch (error) {
      throw new DomainError('HEALTH_CHECK_FAILED', { cause: error });
    }
  }
}
