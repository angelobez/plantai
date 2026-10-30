import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { IdParam } from '../http/id-param.dto';
import { ApiProblems } from '../openapi/api-problems.decorator';
import type { LatLng } from '../profile/donation-grid';
import {
  CreateListingRequest,
  ListingDetail,
  type ListingDetailResponse,
  MyListing,
  type MyListingResponse,
  UpdateListingRequest,
  NearbyListing,
  type NearbyListingResponse,
  NearbyListingsQuery,
} from './listing.dto';
import { ListingsService } from './listings.service';
import { ApiSearchLocation, SearchLocation } from './search-location';

/** Listings as anyone reaches them (`/listings`). */
@ApiBearerAuth()
@Controller('listings')
export class ListingsController {
  constructor(private readonly listingsService: ListingsService) {}

  /**
   * Mudas por perto: the effectively active listings of other Users within
   * 30 km of the searcher (`X-Search-Location`), nearest first and, in a
   * tie, newest first; 30 per page. Declared before `:id`, which would
   * otherwise take `nearby`.
   */
  @Get('nearby')
  @ApiSearchLocation()
  @ZodResponse({ status: 200, type: [NearbyListing] })
  @ApiProblems('UNAUTHENTICATED', 'LOCATION_REQUIRED')
  nearby(
    @Query() { page }: NearbyListingsQuery,
    @SearchLocation() from: LatLng,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<NearbyListingResponse[]> {
    return this.listingsService.nearby(user.id, from, page);
  }

  /**
   * One listing, with the distance from the searcher (`X-Search-Location`),
   * also when it is no longer active (its effective `status` says so). The
   * care guide shows only when ready; this never has Claude write one.
   * Never the donor's phone.
   */
  @Get(':id')
  @ApiSearchLocation()
  @ZodResponse({ status: 200, type: ListingDetail })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND', 'LOCATION_REQUIRED')
  detail(
    @Param() { id }: IdParam,
    @SearchLocation() from: LatLng,
  ): Promise<ListingDetailResponse> {
    return this.listingsService.detail(id, from);
  }

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
