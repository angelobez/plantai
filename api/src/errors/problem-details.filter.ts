import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import type { Response } from 'express';
import { STATUS_CODES } from 'node:http';
import { DomainError, type FieldError } from './domain-error';

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
  response.status(error.status).type('application/problem+json').json(body);
}

/**
 * Answers every error as `application/problem+json`. Errors that are not a
 * {@link DomainError} are translated: Nest's 404 becomes `NOT_FOUND`, any other
 * client error (malformed JSON, for instance) becomes `VALIDATION_FAILED`, and
 * everything else becomes `INTERNAL_ERROR`, logged here and never echoed.
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
      if (exception instanceof NotFoundException) {
        return new DomainError('NOT_FOUND', { cause: exception });
      }
      const status = exception.getStatus();
      if (status >= 400 && status < 500) {
        return new DomainError('VALIDATION_FAILED', {
          cause: exception,
          errors: [{ path: '', message: exception.message }],
        });
      }
    }

    this.logger.error(
      exception instanceof Error ? exception.stack : String(exception),
    );
    return new DomainError('INTERNAL_ERROR', { cause: exception });
  }
}
