import { defineConfig } from 'drizzle-kit';
import { z } from 'zod';
import { loadDotEnv, parseEnvWith } from './src/config/env';

// drizzle-kit only needs the database. The deploy job (.github/workflows/ci.yml)
// migrates Neon with nothing but DATABASE_URL set, so the rest of the API's
// environment is not validated here.
loadDotEnv();
const { DATABASE_URL } = parseEnvWith(
  z.object({ DATABASE_URL: z.url() }),
  process.env,
);

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/database/schema.ts',
  out: './drizzle',
  dbCredentials: { url: DATABASE_URL },
});
