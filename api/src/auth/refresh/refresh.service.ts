import { Inject, Injectable } from '@nestjs/common';
import { and, eq, gt, isNull, sql } from 'drizzle-orm';
import { DATABASE, type Database } from '../../database/database.module';
import { refreshTokens } from '../../database/schema';
import { DomainError } from '../../errors/domain-error';
import { Users } from '../../users/users';
import type { AuthTokens } from '../auth-tokens.dto';
import { hashOpaqueToken } from '../secrets';
import { Sessions } from '../sessions';

@Injectable()
export class RefreshService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    private readonly users: Users,
    private readonly sessions: Sessions,
  ) {}

  /**
   * Rotates [refreshToken]: revokes it and answers a new pair of the same
   * family. Unknown, expired or revoked: `UNAUTHENTICATED`. Revoked means it
   * was already used (or stolen and used), so the whole family goes too.
   */
  async renew(refreshToken: string): Promise<AuthTokens> {
    const tokenHash = hashOpaqueToken(refreshToken);

    // One atomic UPDATE: of two requests racing with the same token, only one
    // gets the row back; the other finds it revoked, as a reuse.
    const [used] = await this.db
      .update(refreshTokens)
      .set({ revokedAt: sql`now()` })
      .where(
        and(
          eq(refreshTokens.tokenHash, tokenHash),
          isNull(refreshTokens.revokedAt),
          gt(refreshTokens.expiresAt, sql`now()`),
        ),
      )
      .returning();

    if (!used) {
      await this.revokeFamilyIfReused(tokenHash);
      throw new DomainError('UNAUTHENTICATED');
    }

    const user = await this.users.findById(used.userId);
    if (!user) throw new DomainError('UNAUTHENTICATED');
    return this.sessions.resume(user, used.familyId);
  }

  private async revokeFamilyIfReused(tokenHash: string): Promise<void> {
    const [known] = await this.db
      .select({
        familyId: refreshTokens.familyId,
        revokedAt: refreshTokens.revokedAt,
      })
      .from(refreshTokens)
      .where(eq(refreshTokens.tokenHash, tokenHash));
    if (!known?.revokedAt) return; // unknown, or only expired
    await this.sessions.revokeFamily(known.familyId);
  }
}
