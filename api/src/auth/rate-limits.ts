import { type ExecutionContext, Injectable } from '@nestjs/common';
import {
  Throttle,
  ThrottlerGuard,
  type ThrottlerModuleOptions,
} from '@nestjs/throttler';
import type { Request } from 'express';

const MINUTE = 60_000;

/** Every `/auth` route, whatever the prefix and version (`/v1/auth/login`). */
const AUTH_PATH = /^\/v\d+\/auth\//;

/** The e-mail in the request body, in lower case (citext in the database). */
function emailOf(request: { body?: unknown }): string | undefined {
  const body = request.body;
  if (typeof body !== 'object' || body === null || !('email' in body)) {
    return undefined;
  }
  return typeof body.email === 'string' ? body.email.toLowerCase() : undefined;
}

function requestOf(context: ExecutionContext): Request {
  return context.switchToHttp().getRequest<Request>();
}

/**
 * The two buckets of every `/auth` route, kept in memory (enough for the
 * notebook and for a Lambda with low concurrency):
 *
 * - `ip`: 20 per minute per IP, one bucket for all the `/auth` routes.
 * - `email`: 5 per 15 minutes per e-mail of the body, one bucket per route.
 *   Routes without an e-mail in the body (refresh, logout, Google) skip it;
 *   the ones that send an e-mail lower it with {@link LimitsEmailsSent}.
 *
 * Going over answers `429 TOO_MANY_REQUESTS` (the problem-details filter maps
 * the throttler's exception).
 */
export const AUTH_RATE_LIMITS: ThrottlerModuleOptions = {
  throttlers: [
    {
      name: 'ip',
      limit: 20,
      ttl: MINUTE,
      generateKey: (_context, ip, name) => `${name}-${ip}`,
    },
    {
      name: 'email',
      limit: 5,
      ttl: 15 * MINUTE,
      skipIf: (context) => emailOf(requestOf(context)) === undefined,
      getTracker: (request) => emailOf(request) ?? '',
    },
  ],
};

/** For the routes that send an e-mail: 3 per 15 minutes per e-mail. */
export const LimitsEmailsSent = (): MethodDecorator =>
  Throttle({ email: { limit: 3 } });

/**
 * Global, so a new `/auth` route is limited without remembering to; every
 * other route passes untouched.
 */
@Injectable()
export class AuthRateLimitGuard extends ThrottlerGuard {
  protected override shouldSkip(context: ExecutionContext): Promise<boolean> {
    return Promise.resolve(!AUTH_PATH.test(requestOf(context).path));
  }
}
