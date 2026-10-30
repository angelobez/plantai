import { Injectable, Logger } from '@nestjs/common';
import type { User } from '../database/schema';
import type { Email } from '../email/email-sender';
import { EmailSender } from '../email/email-sender';
import {
  accountExistsEmail,
  passwordResetCodeEmail,
  signupCodeEmail,
} from '../email/emails';
import { messageOf } from '../errors/message-of';
import { EmailCodes } from './email-codes';

/**
 * The e-mails the `/auth` routes send. A failed send never reaches the caller:
 * the routes answer the same whether the e-mail has an account or not, and a
 * 500 only when there is one would tell who uses PlantAí. The failure goes to
 * the log, without the address or the code.
 */
@Injectable()
export class AuthEmails {
  private readonly logger = new Logger(AuthEmails.name);

  constructor(
    private readonly emailCodes: EmailCodes,
    private readonly emailSender: EmailSender,
  ) {}

  /**
   * Issues a new `signup` code for [user] and e-mails it, to [to] when given
   * (the address as typed at sign-up) or else to the stored one.
   */
  async sendSignupCode(user: User, to = user.email): Promise<void> {
    const code = await this.emailCodes.issue(user.id, 'signup');
    await this.send(user, to, signupCodeEmail(user.name, code));
  }

  /** Issues a new `password_reset` code for [user] and e-mails it. */
  async sendPasswordResetCode(user: User): Promise<void> {
    const code = await this.emailCodes.issue(user.id, 'password_reset');
    await this.send(user, user.email, passwordResetCodeEmail(user.name, code));
  }

  /**
   * Tells [user], who tried to sign up again, that the account exists; to
   * [to] as in {@link sendSignupCode}.
   */
  async sendAccountExists(user: User, to = user.email): Promise<void> {
    await this.send(user, to, accountExistsEmail(user.name));
  }

  private async send(user: User, to: string, email: Email): Promise<void> {
    try {
      await this.emailSender.send(to, email);
    } catch (error) {
      const reason = messageOf(error);
      this.logger.error(
        `The ${email.template} e-mail to User ${user.id} was not sent: ${reason}`,
      );
    }
  }
}
