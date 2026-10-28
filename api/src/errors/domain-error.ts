import { HttpStatus } from '@nestjs/common';

/** Stable error codes from the API contract (docs/spec/modelo-de-dados-e-api.md). */
export const ERROR_STATUS = {
  HEALTH_CHECK_FAILED: HttpStatus.SERVICE_UNAVAILABLE,
} as const satisfies Record<string, HttpStatus>;

export type ErrorCode = keyof typeof ERROR_STATUS;

/**
 * An error the client is meant to handle. The API answers it as
 * `application/problem+json` carrying the stable `code`; the message shown to
 * the person lives in the app.
 */
export class DomainError extends Error {
  override readonly name = 'DomainError';
  readonly status: HttpStatus;

  constructor(
    readonly code: ErrorCode,
    options?: ErrorOptions,
  ) {
    super(code, options);
    this.status = ERROR_STATUS[code];
  }
}
