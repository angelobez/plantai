import { defineConfig } from 'drizzle-kit';
import { loadEnv } from './src/config/env';

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/database/schema.ts',
  out: './drizzle',
  dbCredentials: { url: loadEnv().DATABASE_URL },
});
