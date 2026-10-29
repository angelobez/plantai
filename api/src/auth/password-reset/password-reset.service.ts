import { Inject, Injectable } from '@nestjs/common';
import { eq, sql } from 'drizzle-orm';
import { DATABASE, type Database } from '../../database/database.module';
import { users } from '../../database/schema';
import { DomainError } from '../../errors/domain-error';
import { EmailSender } from '../../email/email-sender';
import { passwordResetCodeEmail } from '../../email/emails';
import { Users } from '../../users/users';
import type { AuthTokens } from '../auth-tokens.dto';
import { EmailCodes } from '../email-codes';
import { hashSecret } from '../secrets';
import { Sessions } from '../sessions';
import type {
  PasswordResetConfirmRequest,
  PasswordResetRequest,
} from './password-reset.dto';

/**
 * "Esqueci a senha": a `password_reset` code by e-mail, then a new password.
 * Also how an account made with Google (no password) gets one.
 */
@Injectable()
export class PasswordResetService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    private readonly users: Users,
    private readonly emailCodes: EmailCodes,
    private readonly emailSender: EmailSender,
    private readonly sessions: Sessions,
  ) {}

  /**
   * E-mails a `password_reset` code if [email] has an account. The caller
   * answers the same either way, so nobody learns who uses PlantAí.
   */
  async request({ email }: PasswordResetRequest): Promise<void> {
    const user = await this.users.findByEmail(email);
    if (!user) return;

    const code = await this.emailCodes.issue(user.id, 'password_reset');
    await this.emailSender.send(
      user.email,
      passwordResetCodeEmail(user.name, code),
    );
  }

  /**
   * Spends the code and sets the new password. The code proves the e-mail,
   * so an unconfirmed one becomes confirmed. Every session of the User ends
   * (whoever had the old password loses access) and a new one starts.
   */
  async confirm({
    email,
    code,
    newPassword,
  }: PasswordResetConfirmRequest): Promise<AuthTokens> {
    const user = await this.users.findByEmail(email);
    if (!user) throw new DomainError('INVALID_CODE');

    await this.emailCodes.consume(user.id, 'password_reset', code);
    const passwordHash = await hashSecret(newPassword);
    const [updated] = await this.db
      .update(users)
      .set({
        passwordHash,
        emailVerifiedAt: sql`coalesce(${users.emailVerifiedAt}, now())`,
      })
      .where(eq(users.id, user.id))
      .returning();
    await this.sessions.revokeAll(user.id);
    return this.sessions.start(updated ?? user);
  }
}
