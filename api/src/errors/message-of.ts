import { DrizzleQueryError } from 'drizzle-orm';

/**
 * The message of a caught [error], for logs and failure reasons. A failed
 * query keeps its SQL and its cause (`relation "x" does not exist`, say) but
 * loses the parameter values Drizzle puts in its message, which may be
 * personal data such as the searcher's location.
 */
export function messageOf(error: unknown): string {
  if (error instanceof DrizzleQueryError && error.cause !== undefined) {
    return `${ownMessage(error)} (cause: ${describe(error.cause)})`;
  }
  return ownMessage(error);
}

/**
 * What the log may show of [error]: name, safe message and the stack
 * frames, followed by its chain of causes. The frames are taken apart from
 * the message, so the values of a failed query never come along.
 */
export function stackOf(error: unknown): string {
  if (!(error instanceof Error)) return String(error);
  const frames = (error.stack ?? '')
    .split('\n')
    .filter((line) => /^\s+at /.test(line));
  const lines = [`${error.name}: ${ownMessage(error)}`, ...frames];
  for (
    let cause: unknown = error.cause, depth = 0;
    cause !== undefined && depth < 5;
    cause = cause instanceof Error ? cause.cause : undefined, depth++
  ) {
    lines.push(`Caused by: ${describe(cause)}`);
  }
  return lines.join('\n');
}

/** [error]'s message without its causes, and without a query's values. */
function ownMessage(error: unknown): string {
  if (error instanceof DrizzleQueryError) return `Failed query: ${error.query}`;
  return error instanceof Error ? error.message : String(error);
}

/** `<name> <code>: <message>`; Postgres errors carry their SQLSTATE in `code`. */
function describe(error: unknown): string {
  if (!(error instanceof Error)) return String(error);
  const code = (error as { code?: unknown }).code;
  const label = typeof code === 'string' ? `${error.name} ${code}` : error.name;
  return `${label}: ${ownMessage(error)}`;
}
