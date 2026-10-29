import { createParamDecorator, type ExecutionContext } from '@nestjs/common';
import type { Request } from 'express';

/** Who sent the request, as proven by the access token. */
export interface AuthenticatedUser {
  id: string;
}

/** Where the guard leaves the {@link AuthenticatedUser} on the request. */
export interface AuthenticatedRequest extends Request {
  user?: AuthenticatedUser;
}

/**
 * The authenticated User of a protected route, the one way controllers get it.
 *
 * @example me(@CurrentUser() user: AuthenticatedUser)
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): AuthenticatedUser => {
    const { user } = context.switchToHttp().getRequest<AuthenticatedRequest>();
    // Only reachable on a @Public() route, which has no User to give.
    if (!user)
      throw new Error('@CurrentUser() used on a route without a session');
    return user;
  },
);
