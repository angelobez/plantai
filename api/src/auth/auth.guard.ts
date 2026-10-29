import {
  type CanActivate,
  type ExecutionContext,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { DomainError } from '../errors/domain-error';
import { AccessTokens } from './access-tokens';
import type { AuthenticatedRequest } from './current-user.decorator';
import { IS_PUBLIC } from './public.decorator';

const BEARER = /^Bearer (\S+)$/i;

/**
 * Global guard: every route needs `Authorization: Bearer <access token>`,
 * except the ones marked {@link Public}. Without a valid token the answer is
 * `401 UNAUTHENTICATED`, which tells the app to refresh the session.
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly accessTokens: AccessTokens,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean | undefined>(
      IS_PUBLIC,
      [context.getHandler(), context.getClass()],
    );
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = BEARER.exec(request.header('authorization') ?? '')?.[1];
    const userId = token === undefined ? null : this.accessTokens.verify(token);
    if (userId === null) throw new DomainError('UNAUTHENTICATED');

    request.user = { id: userId };
    return true;
  }
}
