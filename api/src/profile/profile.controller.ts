import { Body, Controller, Get, Inject, Patch } from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { eq } from 'drizzle-orm';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { DATABASE, type Database } from '../database/database.module';
import { users } from '../database/schema';
import { DomainError } from '../errors/domain-error';
import { ApiProblems } from '../openapi/api-problems.decorator';
import { Users } from '../users/users';
import { UpdateProfileRequest } from './update-profile.dto';
import { toUserProfile, UserProfile } from './user-profile.dto';

@ApiBearerAuth()
@Controller('me')
export class ProfileController {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    private readonly users: Users,
  ) {}

  @Get()
  @ZodResponse({ status: 200, type: UserProfile })
  @ApiProblems('UNAUTHENTICATED')
  async me(@CurrentUser() current: AuthenticatedUser): Promise<UserProfile> {
    const user = await this.users.findById(current.id);
    // A valid token for a User that no longer exists: the session is over.
    if (!user) throw new DomainError('UNAUTHENTICATED');
    return toUserProfile(user);
  }

  /** Changes the name; the e-mail does not change in the MVP. */
  @Patch()
  @ZodResponse({ status: 200, type: UserProfile })
  @ApiProblems('UNAUTHENTICATED')
  async update(
    @CurrentUser() current: AuthenticatedUser,
    @Body() { name }: UpdateProfileRequest,
  ): Promise<UserProfile> {
    const [user] = await this.db
      .update(users)
      .set({ name })
      .where(eq(users.id, current.id))
      .returning();
    if (!user) throw new DomainError('UNAUTHENTICATED');
    return toUserProfile(user);
  }
}
