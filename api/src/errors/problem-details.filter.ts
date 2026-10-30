import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
  Logger,
} from '@nestjs/common';
import type { Response } from 'express';
import { STATUS_CODES } from 'node:http';
import {
  DomainError,
  ERROR_STATUS,
  type ErrorCode,
  type FieldError,
} from './domain-error';
import { stackOf } from './message-of';

/** RFC 9457 problem details, extended with the API's stable `code`. */
export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  code: string;
  errors?: FieldError[];
}

export function sendProblem(response: Response, error: DomainError): void {
  const body: ProblemDetails = {
    type: 'about:blank',
    title: STATUS_CODES[error.status] ?? 'Error',
    status: error.status,
    code: error.code,
    ...(error.errors && { errors: error.errors }),
  };
  if (error.retryAfterSeconds !== undefined) {
    response.setHeader('Retry-After', String(error.retryAfterSeconds));
  }
  response.status(error.status).type('application/problem+json').json(body);
}

/**
 * Codes a framework {@link HttpException} may be translated to, matched by
 * its status in `ERROR_STATUS`. Anything else Nest throws has no mapping.
 */
const FRAMEWORK_CODES = [
  'VALIDATION_FAILED',
  'NOT_FOUND',
  'TOO_MANY_REQUESTS',
] as const satisfies readonly ErrorCode[];

/** Sent instead of Nest's own message, which may describe its internals. */
const MALFORMED_REQUEST: FieldError = {
  path: '',
  message: 'malformed request',
};

/**
 * Answers every error as `application/problem+json`. Errors that are not a
 * {@link DomainError} are translated: Nest's 400 (malformed JSON, for
 * instance) becomes `VALIDATION_FAILED` with a generic message, its 404
 * `NOT_FOUND` and its 429 `TOO_MANY_REQUESTS`. Anything else, other HTTP
 * exceptions included, becomes `INTERNAL_ERROR`, logged here (through
 * {@link stackOf}, so no query parameter reaches the log) and never echoed.
 */
@Catch()
export class ProblemDetailsFilter implements ExceptionFilter {
  private readonly logger = new Logger(ProblemDetailsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    sendProblem(
      host.switchToHttp().getResponse<Response>(),
      this.toDomainError(exception),
    );
  }

  private toDomainError(exception: unknown): DomainError {
    if (exception instanceof DomainError) return exception;

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const code = FRAMEWORK_CODES.find((candidate) => {
        const candidateStatus: number = ERROR_STATUS[candidate];
        return candidateStatus === status;
      });
      if (code === 'VALIDATION_FAILED') {
        return new DomainError(code, {
          cause: exception,
          errors: [MALFORMED_REQUEST],
        });
      }
      if (code !== undefined) {
        return new DomainError(code, { cause: exception });
      }
    }

    this.logger.error(
      'Exception has no problem-details mapping; answering INTERNAL_ERROR',
      stackOf(exception),
    );
    return new DomainError('INTERNAL_ERROR', { cause: exception });
  }
}
