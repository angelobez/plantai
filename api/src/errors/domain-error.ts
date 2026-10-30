import { HttpStatus } from '@nestjs/common';

/** Stable error codes from the API contract (docs/spec/modelo-de-dados-e-api.md). */
export const ERROR_STATUS = {
  VALIDATION_FAILED: HttpStatus.BAD_REQUEST,
  NOT_FOUND: HttpStatus.NOT_FOUND,
  APP_UPDATE_REQUIRED: 426, // Upgrade Required; HttpStatus has no member for it
  UNAUTHENTICATED: HttpStatus.UNAUTHORIZED,
  INVALID_CREDENTIALS: HttpStatus.UNAUTHORIZED,
  EMAIL_NOT_VERIFIED: HttpStatus.FORBIDDEN,
  INVALID_CODE: HttpStatus.BAD_REQUEST,
  GOOGLE_ACCOUNT_LINK_REFUSED: HttpStatus.CONFLICT,
  TOO_MANY_REQUESTS: HttpStatus.TOO_MANY_REQUESTS,
  PHOTO_DAILY_LIMIT: HttpStatus.TOO_MANY_REQUESTS,
  IDENTIFICATION_DAILY_LIMIT: HttpStatus.TOO_MANY_REQUESTS,
  IDENTIFICATION_SERVICE_UNAVAILABLE: HttpStatus.SERVICE_UNAVAILABLE,
  IDENTIFICATION_ALREADY_CHOSEN: HttpStatus.CONFLICT,
  SPECIES_ALREADY_SET: HttpStatus.CONFLICT,
  INVALID_PHONE: HttpStatus.BAD_REQUEST,
  DONATION_PROFILE_REQUIRED: HttpStatus.CONFLICT,
  /** Not a failure: another request is writing the care guide; try again. */
  CARE_GUIDE_GENERATING: HttpStatus.ACCEPTED,
  INTERNAL_ERROR: HttpStatus.INTERNAL_SERVER_ERROR,
  HEALTH_CHECK_FAILED: HttpStatus.SERVICE_UNAVAILABLE,
} as const satisfies Record<string, number>;

export type ErrorCode = keyof typeof ERROR_STATUS;

/** One rejected field of a `VALIDATION_FAILED` problem. */
export interface FieldError {
  /** Dotted path inside the validated input (`tags.1`); empty for the whole input. */
  path: string;
  message: string;
}

export interface DomainErrorOptions extends ErrorOptions {
  /** Per-field details, sent as the `errors` extension member. */
  errors?: FieldError[];
  /** Sent as `Retry-After`: when the client should try again. */
  retryAfterSeconds?: number;
}

/**
 * An error the client is meant to handle. The API answers it as
 * `application/problem+json` carrying the stable `code`; the message shown to
 * the person lives in the app.
 */
export class DomainError extends Error {
  override readonly name = 'DomainError';
  readonly status: number;
  readonly errors: FieldError[] | undefined;
  readonly retryAfterSeconds: number | undefined;

  constructor(
    readonly code: ErrorCode,
    options?: DomainErrorOptions,
  ) {
    super(code, options);
    this.status = ERROR_STATUS[code];
    this.errors = options?.errors;
    this.retryAfterSeconds = options?.retryAfterSeconds;
  }
}
