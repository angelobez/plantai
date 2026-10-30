import { Body, Controller, Get, Patch, Put } from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { ApiProblems } from '../openapi/api-problems.decorator';
import { DonationProfileRequest } from './donation-profile.dto';
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

  /**
   * Sets the WhatsApp phone and the donation location, used by the first
   * listing and by the Profile. Answers the body of `GET /me`, which never
   * carries the coordinates.
   */
  @Put('donation-profile')
  @ZodResponse({ status: 200, type: UserProfile })
  @ApiProblems('UNAUTHENTICATED', 'INVALID_PHONE')
  async setDonationProfile(
    @CurrentUser() current: AuthenticatedUser,
    @Body() body: DonationProfileRequest,
  ): Promise<UserProfile> {
    return toUserProfile(
      await this.profileService.setDonationProfile(current.id, body),
    );
  }
}
