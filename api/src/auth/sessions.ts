import { Inject, Injectable } from '@nestjs/common';
import { randomUUIDv7 } from 'node:crypto';
import { and, eq, isNull, sql } from 'drizzle-orm';
import { DATABASE, type Database } from '../database/database.module';
import { refreshTokens, type User } from '../database/schema';
import { toUserProfile } from '../profile/user-profile.dto';
import { AccessTokens } from './access-tokens';
import type { AuthTokens } from './auth-tokens.dto';
import { hashOpaqueToken, newOpaqueToken } from './secrets';

export const REFRESH_TOKEN_TTL_DAYS = 30;

/**
 * Signs Users in: every way in (code, password, Google, password reset) ends
 * in {@link start}, which answers with the tokens.
 */
@Injectable()
export class Sessions {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    private readonly accessTokens: AccessTokens,
  ) {}

  /** A new session for [user]: an access token and a new refresh token family. */
  start(user: User): Promise<AuthTokens> {
    return this.resume(user, randomUUIDv7());
  }

  /**
   * The tokens for [user] going on in [familyId]: a new access token and a
   * new refresh token of that family (`POST /auth/refresh`).
   */
  async resume(user: User, familyId: string): Promise<AuthTokens> {
    const refreshToken = await this.issueRefreshToken(user.id, familyId);
    return {
      accessToken: this.accessTokens.issue(user.id),
      refreshToken,
      user: toUserProfile(user),
    };
  }

  /**
   * Stores a refresh token of [familyId] for [userId], valid for 30 days, and
   * returns it. Only its hash is kept.
   */
  async issueRefreshToken(userId: string, familyId: string): Promise<string> {
    const token = newOpaqueToken();
    await this.db.insert(refreshTokens).values({
      userId,
      familyId,
      tokenHash: hashOpaqueToken(token),
      expiresAt: sql`now() + make_interval(days => ${REFRESH_TOKEN_TTL_DAYS})`,
    });
    return token;
  }

  /** Revokes every refresh token of [familyId] still in use. */
  async revokeFamily(familyId: string): Promise<void> {
    await this.db
      .update(refreshTokens)
      .set({ revokedAt: sql`now()` })
      .where(
        and(
          eq(refreshTokens.familyId, familyId),
          isNull(refreshTokens.revokedAt),
        ),
      );
  }
}
