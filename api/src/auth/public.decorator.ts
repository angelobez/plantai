import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC = 'auth:isPublic';

/**
 * Lets a route (or every route of a controller) through without a Bearer
 * token. Every other route requires one, so forgetting this never opens a
 * route; it only makes it answer `401 UNAUTHENTICATED`.
 */
export const Public = (): MethodDecorator & ClassDecorator =>
  SetMetadata(IS_PUBLIC, true);
