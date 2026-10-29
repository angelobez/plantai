import { Injectable } from '@nestjs/common';
import { DomainError } from '../../errors/domain-error';
import { Users } from '../../users/users';
import type { AuthTokens } from '../auth-tokens.dto';
import { AuthEmails } from '../auth-emails';
import { hashSecret, verifySecret } from '../secrets';
import { Sessions } from '../sessions';
import type { LoginRequest } from './login.dto';

/**
 * Checked when there is no hash to check against (no account, or Google
 * only), so the time to answer does not tell those cases apart.
 */
let dummyHash: Promise<string> | undefined;

@Injectable()
export class LoginService {
  constructor(
    private readonly users: Users,
    private readonly authEmails: AuthEmails,
    private readonly sessions: Sessions,
  ) {}

  /**
   * Signs the User in with e-mail and password.
   * - no account, wrong password or no password (Google only):
   *   `INVALID_CREDENTIALS`, the same for all three;
   * - right password on an unconfirmed account: e-mails a new `signup` code
   *   and answers `EMAIL_NOT_VERIFIED`, so the app goes to the code screen.
   */
  async logIn({ email, password }: LoginRequest): Promise<AuthTokens> {
    const user = await this.users.findByEmail(email);
    const hash = user?.passwordHash;
    dummyHash ??= hashSecret('not the password of anyone');
    const matches = await verifySecret(hash ?? (await dummyHash), password);
    if (!user || !hash || !matches) {
      throw new DomainError('INVALID_CREDENTIALS');
    }

    if (!user.emailVerifiedAt) {
      await this.authEmails.sendSignupCode(user);
      throw new DomainError('EMAIL_NOT_VERIFIED');
    }

    return this.sessions.start(user);
  }
}
