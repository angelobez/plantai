/** The message of a caught [error], for logs and failure reasons. */
export function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
