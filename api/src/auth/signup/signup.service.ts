import { Inject, Injectable } from '@nestjs/common';
import { eq, sql } from 'drizzle-orm';
import { DATABASE, type Database } from '../../database/database.module';
import { type User, users } from '../../database/schema';
import { DomainError } from '../../errors/domain-error';
import { Users } from '../../users/users';
import type { AuthTokens } from '../auth-tokens.dto';
import { AuthEmails } from '../auth-emails';
import { EmailCodes } from '../email-codes';
import { hashSecret } from '../secrets';
import { Sessions } from '../sessions';
import type { SignupRequest, VerifyEmailRequest } from './signup.dto';

@Injectable()
export class SignupService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    private readonly users: Users,
    private readonly emailCodes: EmailCodes,
    private readonly authEmails: AuthEmails,
    private readonly sessions: Sessions,
  ) {}

  /**
   * Starts a sign-up, answering the same whether the e-mail is in use or not:
   * - new e-mail: creates the unconfirmed User and e-mails a code;
   * - unconfirmed account: takes the new name and password and e-mails a new
   *   code (this is also the app's "resend code");
   * - confirmed account: changes nothing and e-mails "you already have an
   *   account".
   */
  async signUp({ name, email, password }: SignupRequest): Promise<void> {
    // Hashed in every case, so the time to answer does not tell them apart.
    const passwordHash = await hashSecret(password);
    const existing = await this.users.findByEmail(email);

    if (existing?.emailVerifiedAt) {
      await this.authEmails.sendAccountExists(existing, email);
      return;
    }

    const user = existing
      ? await this.updatePending(existing, name, passwordHash)
      : await this.createPending(name, email, passwordHash);
    await this.authEmails.sendSignupCode(user, email);
  }

  /** Confirms the e-mail with the `signup` code and signs the User in. */
  async verifyEmail({ email, code }: VerifyEmailRequest): Promise<AuthTokens> {
    const user = await this.users.findByEmail(email);
    if (!user) throw new DomainError('INVALID_CODE');

    await this.emailCodes.consume(user.id, 'signup', code);
    const [verified] = await this.db
      .update(users)
      .set({ emailVerifiedAt: sql`coalesce(${users.emailVerifiedAt}, now())` })
      .where(eq(users.id, user.id))
      .returning();
    return this.sessions.start(verified ?? user);
  }

  private async createPending(
    name: string,
    email: string,
    passwordHash: string,
  ): Promise<User> {
    const [created] = await this.db
      .insert(users)
      .values({ name, email, passwordHash })
      .returning();
    if (!created) throw new Error('INSERT INTO users returned no row');
    return created;
  }

  private async updatePending(
    user: User,
    name: string,
    passwordHash: string,
  ): Promise<User> {
    const [updated] = await this.db
      .update(users)
      .set({ name, passwordHash })
      .where(eq(users.id, user.id))
      .returning();
    return updated ?? user;
  }
}
