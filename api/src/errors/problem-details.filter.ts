import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
} from '@nestjs/common';
import type { Response } from 'express';
import { STATUS_CODES } from 'node:http';
import { DomainError } from './domain-error';

/** RFC 9457 problem details, extended with the API's stable `code`. */
export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  code: string;
}

@Catch(DomainError)
export class ProblemDetailsFilter implements ExceptionFilter<DomainError> {
  catch(error: DomainError, host: ArgumentsHost): void {
    const body: ProblemDetails = {
      type: 'about:blank',
      title: STATUS_CODES[error.status] ?? 'Error',
      status: error.status,
      code: error.code,
    };
    host
      .switchToHttp()
      .getResponse<Response>()
      .status(error.status)
      .type('application/problem+json')
      .json(body);
  }
}
