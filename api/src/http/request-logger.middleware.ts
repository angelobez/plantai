import { Injectable, Logger, type NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import type { IncomingHttpHeaders } from 'node:http';

/**
 * Headers whose values never reach the logs. `X-Search-Location` carries the
 * searcher's coordinates, which stay out of every log (data spec).
 */
export const REDACTED_HEADERS: ReadonlySet<string> = new Set([
  'authorization',
  'cookie',
  'proxy-authorization',
  'set-cookie',
  'x-search-location',
]);

export function redactHeaders(
  headers: IncomingHttpHeaders,
): IncomingHttpHeaders {
  return Object.fromEntries(
    Object.entries(headers).map(([name, value]) => [
      name,
      REDACTED_HEADERS.has(name.toLowerCase()) ? '[REDACTED]' : value,
    ]),
  );
}

/** One log line per request, written when the response finishes. */
@Injectable()
export class RequestLoggerMiddleware implements NestMiddleware {
  private readonly logger = new Logger('HTTP');

  use(request: Request, response: Response, next: NextFunction): void {
    const startedAt = performance.now();
    response.on('finish', () => {
      const elapsedMs = Math.round(performance.now() - startedAt);
      this.logger.log(
        `${request.method} ${request.originalUrl} ${String(response.statusCode)} ${String(elapsedMs)}ms ${JSON.stringify(redactHeaders(request.headers))}`,
      );
    });
    next();
  }
}
