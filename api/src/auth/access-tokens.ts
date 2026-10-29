import { Inject, Injectable } from '@nestjs/common';
import jwt from 'jsonwebtoken';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env';

/** How long an access token lasts; the app renews it with the refresh token. */
export const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;

/** The access token: a JWT (HS256) whose `sub` is the User id. */
@Injectable()
export class AccessTokens {
  constructor(@Inject(ENV) private readonly env: Env) {}

  issue(userId: string): string {
    return jwt.sign({}, this.env.JWT_SECRET, {
      algorithm: 'HS256',
      subject: userId,
      expiresIn: ACCESS_TOKEN_TTL_SECONDS,
    });
  }

  /** The User id of a valid token; null when it is malformed, forged or expired. */
  verify(token: string): string | null {
    try {
      const payload = jwt.verify(token, this.env.JWT_SECRET, {
        algorithms: ['HS256'],
      });
      if (typeof payload === 'string' || typeof payload.sub !== 'string') {
        return null;
      }
      return payload.sub;
    } catch {
      return null;
    }
  }
}
