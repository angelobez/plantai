import { createHash, timingSafeEqual } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';
import { DomainError } from '../errors/domain-error';
import { sendProblem } from '../errors/problem-details.filter';

/**
 * The origin header CloudFront adds to every request it forwards to the
 * Function URL, carrying `CLOUDFRONT_ORIGIN_SECRET` (lowercase, as Node
 * reads it).
 */
export const ORIGIN_SECRET_HEADER = 'x-origin-verify';

function digest(value: string): Buffer {
  return createHash('sha256').update(value).digest();
}

/**
 * Express middleware that refuses, with `403 DIRECT_ACCESS_FORBIDDEN`, every
 * request without the CloudFront origin header carrying [secret], so no one
 * reaches the Function URL around the domain. It sits on the HTTP adapter,
 * ahead of the router, `/docs` and the not-found fallback. Without a secret
 * (local runs, `dev:phone`, tests) it returns `undefined`: no check at all.
 */
export function originSecretCheck(
  secret: string | undefined,
):
  | ((request: Request, response: Response, next: NextFunction) => void)
  | undefined {
  if (secret === undefined) return undefined;
  const expected = digest(secret);

  return (request, response, next) => {
    const value = request.header(ORIGIN_SECRET_HEADER);
    // Hashing first gives equal lengths, so the comparison is constant-time.
    if (value !== undefined && timingSafeEqual(digest(value), expected)) {
      next();
      return;
    }
    sendProblem(response, new DomainError('DIRECT_ACCESS_FORBIDDEN'));
  };
}
