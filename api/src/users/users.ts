import { Global, Inject, Injectable, Module } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DATABASE, type Database } from '../database/database.module';
import { type User, users } from '../database/schema';

/** Reads Users; each flow that changes one writes its own columns. */
@Injectable()
export class Users {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async findById(id: string): Promise<User | undefined> {
    const [user] = await this.db.select().from(users).where(eq(users.id, id));
    return user;
  }

  /** Case-insensitive, since `email` is citext. */
  async findByEmail(email: string): Promise<User | undefined> {
    const [user] = await this.db
      .select()
      .from(users)
      .where(eq(users.email, email));
    return user;
  }
}

@Global()
@Module({ providers: [Users], exports: [Users] })
export class UsersModule {}
