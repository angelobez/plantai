import { Inject, Injectable } from '@nestjs/common';
import { and, desc, eq, sql } from 'drizzle-orm';
import { DATABASE, type Database } from '../database/database.module';
import { type EmailCodePurpose, emailCodes } from '../database/schema';
import { DomainError } from '../errors/domain-error';
import { hashSecret, newEmailCode, verifySecret } from './secrets';

export const EMAIL_CODE_TTL_MINUTES = 15;

/** Attempts per code; the next one fails even with the right code. */
export const EMAIL_CODE_MAX_ATTEMPTS = 5;

/**
 * The 6-digit codes sent by e-mail (`signup` confirms the e-mail,
 * `password_reset` lets the User set a new password). Only the hash is stored.
 */
@Injectable()
export class EmailCodes {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /**
   * A new code for [userId] and [purpose], valid for 15 minutes. It replaces
   * the previous ones of the same purpose, which stop working. The caller
   * e-mails it; the code itself is never stored.
   */
  async issue(userId: string, purpose: EmailCodePurpose): Promise<string> {
    const code = newEmailCode();
    const codeHash = await hashSecret(code);
    await this.db.transaction(async (tx) => {
      await tx
        .delete(emailCodes)
        .where(
          and(eq(emailCodes.userId, userId), eq(emailCodes.purpose, purpose)),
        );
      await tx.insert(emailCodes).values({
        userId,
        purpose,
        codeHash,
        expiresAt: sql`now() + make_interval(mins => ${EMAIL_CODE_TTL_MINUTES})`,
      });
    });
    return code;
  }

  /**
   * Spends [code]: it must be the current one of [userId] and [purpose], not
   * expired, not used and with attempts left. Otherwise it throws
   * `INVALID_CODE`, and a wrong code counts an attempt.
   */
  async consume(
    userId: string,
    purpose: EmailCodePurpose,
    code: string,
  ): Promise<void> {
    const valid = await this.db.transaction(async (tx) => {
      // Locks the row, so parallel guesses cannot share one attempt.
      const [current] = await tx
        .select({
          id: emailCodes.id,
          codeHash: emailCodes.codeHash,
          attempts: emailCodes.attempts,
          expired: sql<boolean>`${emailCodes.expiresAt} <= now()`,
        })
        .from(emailCodes)
        .where(
          and(
            eq(emailCodes.userId, userId),
            eq(emailCodes.purpose, purpose),
            sql`${emailCodes.usedAt} IS NULL`,
          ),
        )
        .orderBy(desc(emailCodes.createdAt))
        .limit(1)
        .for('update');

      if (
        !current ||
        current.expired ||
        current.attempts >= EMAIL_CODE_MAX_ATTEMPTS
      ) {
        return false;
      }

      const matches = await verifySecret(current.codeHash, code);
      await tx
        .update(emailCodes)
        .set(
          matches
            ? { attempts: current.attempts + 1, usedAt: sql`now()` }
            : { attempts: current.attempts + 1 },
        )
        .where(eq(emailCodes.id, current.id));
      return matches;
    });

    if (!valid) throw new DomainError('INVALID_CODE');
  }
}
