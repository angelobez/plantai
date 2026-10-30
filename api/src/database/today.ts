import { type SQL, sql } from 'drizzle-orm';

/**
 * The time zone where the day turns, for every daily limit: midnight in
 * Brasília ("Hoje" in docs/spec/modelo-de-dados-e-api.md).
 */
export const DAILY_LIMIT_TIME_ZONE = 'America/Sao_Paulo';

/**
 * Today's midnight in {@link DAILY_LIMIT_TIME_ZONE}, as a `timestamptz`
 * computed by the database, so the API's own clock never matters. Daily limits
 * count the rows with `created_at >= startOfToday()`.
 */
export function startOfToday(): SQL<Date> {
  const zone = DAILY_LIMIT_TIME_ZONE;
  return sql<Date>`(date_trunc('day', now() at time zone ${zone}) at time zone ${zone})`;
}
