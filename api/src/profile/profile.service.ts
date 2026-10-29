import { Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DATABASE, type Database } from '../database/database.module';
import { type User, users } from '../database/schema';
import { DomainError } from '../errors/domain-error';
import { Users } from '../users/users';

/** The User's own profile (`/me`). */
@Injectable()
export class ProfileService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    private readonly users: Users,
  ) {}

  /**
   * The User of a valid access token. One that no longer exists means the
   * session is over: `UNAUTHENTICATED`.
   */
  async get(userId: string): Promise<User> {
    const user = await this.users.findById(userId);
    if (!user) throw new DomainError('UNAUTHENTICATED');
    return user;
  }

  /** Changes the name; the e-mail does not change in the MVP. */
  async rename(userId: string, name: string): Promise<User> {
    const [user] = await this.db
      .update(users)
      .set({ name })
      .where(eq(users.id, userId))
      .returning();
    if (!user) throw new DomainError('UNAUTHENTICATED');
    return user;
  }
}
