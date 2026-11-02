import { Injectable, Logger, type NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import type { IncomingHttpHeaders } from 'node:http';
import { ORIGIN_SECRET_HEADER } from './origin-secret';

/**
 * Headers whose values never reach the logs. `X-Search-Location` carries the
 * searcher's coordinates, which stay out of every log (data spec); the
 * forwarding ones carry the visitor's IP (#77); the origin one, the
 * CloudFront secret.
 */
export const REDACTED_HEADERS: ReadonlySet<string> = new Set([
  'authorization',
  'cookie',
  'proxy-authorization',
  'set-cookie',
  'x-search-location',
  'x-forwarded-for',
  'x-real-ip',
  'forwarded',
  ORIGIN_SECRET_HEADER,
]);

/**
 * CloudFront's viewer headers carry the visitor's IP and location; matched by
 * prefix, so the rule holds whatever CloudFront adds later.
 */
const REDACTED_HEADER_PREFIX = 'cloudfront-viewer-';

function isRedacted(name: string): boolean {
  const lower = name.toLowerCase();
  return (
    REDACTED_HEADERS.has(lower) || lower.startsWith(REDACTED_HEADER_PREFIX)
  );
}

export function redactHeaders(
  headers: IncomingHttpHeaders,
): IncomingHttpHeaders {
  return Object.fromEntries(
    Object.entries(headers).map(([name, value]) => [
      name,
      isRedacted(name) ? '[REDACTED]' : value,
    ]),
  );
}

/**
 * One log line per request, written when the response finishes. It never
 * logs the body: the `/auth` ones carry passwords, codes and tokens.
 */
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
