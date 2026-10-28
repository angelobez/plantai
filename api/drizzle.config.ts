import { existsSync } from 'node:fs';
import { defineConfig } from 'drizzle-kit';
import { parseEnv } from './src/config/env';

if (existsSync('.env')) process.loadEnvFile('.env');

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/database/schema.ts',
  out: './drizzle',
  dbCredentials: { url: parseEnv(process.env).DATABASE_URL },
});
