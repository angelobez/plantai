import { Inject, Injectable } from '@nestjs/common';
import { and, eq, sql } from 'drizzle-orm';
import { DATABASE, type Database } from '../../database/database.module';
import { emailCodes, type User, users } from '../../database/schema';
import { DomainError } from '../../errors/domain-error';
import { Users } from '../../users/users';
import type { AuthTokens } from '../auth-tokens.dto';
import { Sessions } from '../sessions';
import type { GoogleRequest } from './google.dto';
import {
  type GoogleIdentity,
  GoogleTokenVerifier,
} from './google-token-verifier';

@Injectable()
export class GoogleService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    private readonly users: Users,
    private readonly verifier: GoogleTokenVerifier,
    private readonly sessions: Sessions,
  ) {}

  /**
   * Signs in with a Google ID token (ADR 0001):
   * - invalid token: `INVALID_CREDENTIALS`; e-mail not verified by Google:
   *   `GOOGLE_ACCOUNT_LINK_REFUSED`;
   * - a User with that `sub`: signs into it;
   * - no User with that e-mail: creates a confirmed one, named by Google (or
   *   after the e-mail's local part);
   * - a User with that e-mail: joins it only when Google vouches for the
   *   e-mail (`@gmail.com` or `hd`) and it has no other Google account, else
   *   `GOOGLE_ACCOUNT_LINK_REFUSED`. A confirmed account keeps its password;
   *   one never confirmed is taken over, losing its pending password, name
   *   and codes, so whoever signed up with someone else's e-mail keeps
   *   nothing.
   */
  async signIn({ idToken }: GoogleRequest): Promise<AuthTokens> {
    const identity = await this.verifier.verify(idToken);
    if (!identity) throw new DomainError('INVALID_CREDENTIALS');
    if (!identity.emailVerified) {
      throw new DomainError('GOOGLE_ACCOUNT_LINK_REFUSED');
    }

    const bySub = await this.findByGoogleSub(identity.sub);
    if (bySub) return this.sessions.start(bySub);

    const byEmail = await this.users.findByEmail(identity.email);
    if (!byEmail) return this.sessions.start(await this.create(identity));

    if (byEmail.googleSub !== null || !googleVouchesFor(identity)) {
      throw new DomainError('GOOGLE_ACCOUNT_LINK_REFUSED');
    }
    const joined = byEmail.emailVerifiedAt
      ? await this.join(byEmail, identity)
      : await this.takeOver(byEmail, identity);
    return this.sessions.start(joined);
  }

  private async findByGoogleSub(sub: string): Promise<User | undefined> {
    const [user] = await this.db
      .select()
      .from(users)
      .where(eq(users.googleSub, sub));
    return user;
  }

  private async create(identity: GoogleIdentity): Promise<User> {
    const [created] = await this.db
      .insert(users)
      .values({
        name: nameFrom(identity),
        email: identity.email,
        googleSub: identity.sub,
        emailVerifiedAt: sql`now()`,
      })
      .returning();
    if (!created) throw new Error('INSERT INTO users returned no row');
    return created;
  }

  /** A confirmed account gains Google as a second way in. */
  private async join(user: User, identity: GoogleIdentity): Promise<User> {
    const [joined] = await this.db
      .update(users)
      .set({ googleSub: identity.sub })
      .where(eq(users.id, user.id))
      .returning();
    return joined ?? user;
  }

  /** An account never confirmed becomes the Google account's, from scratch. */
  private async takeOver(user: User, identity: GoogleIdentity): Promise<User> {
    return this.db.transaction(async (tx) => {
      await tx
        .delete(emailCodes)
        .where(
          and(eq(emailCodes.userId, user.id), eq(emailCodes.purpose, 'signup')),
        );
      const [taken] = await tx
        .update(users)
        .set({
          googleSub: identity.sub,
          name: nameFrom(identity),
          passwordHash: null,
          emailVerifiedAt: sql`now()`,
        })
        .where(eq(users.id, user.id))
        .returning();
      return taken ?? user;
    });
  }
}

/**
 * Whether Google's `email_verified` proves the e-mail is this person's today:
 * Gmail addresses belong to Google, and `hd` means a Workspace domain managed
 * at Google. Any other address may have been verified long ago, for a previous
 * owner.
 */
function googleVouchesFor({ email, hd }: GoogleIdentity): boolean {
  return email.toLowerCase().endsWith('@gmail.com') || Boolean(hd);
}

function nameFrom({ name, email }: GoogleIdentity): string {
  const trimmed = name?.trim().slice(0, 80);
  return trimmed || (email.split('@')[0] ?? email);
}
