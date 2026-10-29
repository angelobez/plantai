import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { ApiProblems } from '../openapi/api-problems.decorator';
import { ProfileService } from './profile.service';
import { UpdateProfileRequest } from './update-profile.dto';
import { toUserProfile, UserProfile } from './user-profile.dto';

@ApiBearerAuth()
@Controller('me')
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Get()
  @ZodResponse({ status: 200, type: UserProfile })
  @ApiProblems('UNAUTHENTICATED')
  async me(@CurrentUser() current: AuthenticatedUser): Promise<UserProfile> {
    return toUserProfile(await this.profileService.get(current.id));
  }

  /** Changes the name; the e-mail does not change in the MVP. */
  @Patch()
  @ZodResponse({ status: 200, type: UserProfile })
  @ApiProblems('UNAUTHENTICATED')
  async update(
    @CurrentUser() current: AuthenticatedUser,
    @Body() { name }: UpdateProfileRequest,
  ): Promise<UserProfile> {
    return toUserProfile(await this.profileService.rename(current.id, name));
  }
}
