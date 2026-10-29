import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { DomainError } from '../errors/domain-error';
import { ApiProblems } from '../openapi/api-problems.decorator';
import { Users } from '../users/users';
import { toUserProfile, UserProfile } from './user-profile.dto';

@ApiBearerAuth()
@Controller('me')
export class ProfileController {
  constructor(private readonly users: Users) {}

  @Get()
  @ZodResponse({ status: 200, type: UserProfile })
  @ApiProblems('UNAUTHENTICATED')
  async me(@CurrentUser() current: AuthenticatedUser): Promise<UserProfile> {
    const user = await this.users.findById(current.id);
    // A valid token for a User that no longer exists: the session is over.
    if (!user) throw new DomainError('UNAUTHENTICATED');
    return toUserProfile(user);
  }
}
