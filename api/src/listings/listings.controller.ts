import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { IdParam } from '../http/id-param.dto';
import { ApiProblems } from '../openapi/api-problems.decorator';
import {
  CreateListingRequest,
  MyListing,
  type MyListingResponse,
  UpdateListingRequest,
} from './listing.dto';
import { ListingsService } from './listings.service';

/** Listings as anyone reaches them (`/listings`). */
@ApiBearerAuth()
@Controller('listings')
export class ListingsController {
  constructor(private readonly listingsService: ListingsService) {}

  /**
   * Publishes a listing for 30 days, with a copy of the donor's donation
   * location and neighborhood. Without a phone or a donation location,
   * `DONATION_PROFILE_REQUIRED`. Another User's photo is `NOT_FOUND`; a
   * `plantId` that is not the User's, or a `speciesId` that does not exist,
   * is `VALIDATION_FAILED`.
   */
  @Post()
  @ZodResponse({ status: 201, type: MyListing })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND', 'DONATION_PROFILE_REQUIRED')
  create(
    @Body() body: CreateListingRequest,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<MyListingResponse> {
    return this.listingsService.create(user.id, body);
  }

  /**
   * The donor changes the quantity and/or the note of an active listing; a
   * `null` or empty note clears it. Common donor rules: another User's
   * listing, or one that does not exist, is `NOT_FOUND`; one that is not
   * effectively active (expired included) is `LISTING_NOT_ACTIVE`.
   */
  @Patch(':id')
  @ZodResponse({ status: 200, type: MyListing })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND', 'LISTING_NOT_ACTIVE')
  update(
    @Param() { id }: IdParam,
    @Body() body: UpdateListingRequest,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<MyListingResponse> {
    return this.listingsService.update(user.id, id, body);
  }

  /**
   * The donor closes an active listing: it stays in Meus anúncios as
   * `closed`, leaves Por perto and cannot reopen. Same common donor rules as
   * `PATCH`.
   */
  @Post(':id/close')
  @HttpCode(HttpStatus.OK)
  @ZodResponse({ status: 200, type: MyListing })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND', 'LISTING_NOT_ACTIVE')
  close(
    @Param() { id }: IdParam,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<MyListingResponse> {
    return this.listingsService.close(user.id, id);
  }
}

/** The donor's own listings (`/me/listings`). */
@ApiBearerAuth()
@Controller('me/listings')
export class MyListingsController {
  constructor(private readonly listingsService: ListingsService) {}

  /** All the User's listings, newest first, with the effective status. */
  @Get()
  @ZodResponse({ status: 200, type: [MyListing] })
  @ApiProblems('UNAUTHENTICATED')
  list(@CurrentUser() user: AuthenticatedUser): Promise<MyListingResponse[]> {
    return this.listingsService.mine(user.id);
  }
}
