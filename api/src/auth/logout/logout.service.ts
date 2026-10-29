import { Inject, Injectable } from '@nestjs/common';
import { and, eq, isNull, sql } from 'drizzle-orm';
import { DATABASE, type Database } from '../../database/database.module';
import { refreshTokens } from '../../database/schema';
import { hashOpaqueToken } from '../secrets';

@Injectable()
export class LogoutService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /**
   * Revokes [refreshToken], so neither the app nor a copy of it can renew the
   * session. Only that token: the User's other sessions go on. A token that is
   * unknown, expired or already revoked changes nothing (the first revocation
   * time stays).
   */
  async logout(refreshToken: string): Promise<void> {
    await this.db
      .update(refreshTokens)
      .set({ revokedAt: sql`now()` })
      .where(
        and(
          eq(refreshTokens.tokenHash, hashOpaqueToken(refreshToken)),
          isNull(refreshTokens.revokedAt),
        ),
      );
  }
}
