import { Controller, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { IdParam } from '../http/id-param.dto';
import { ApiProblems } from '../openapi/api-problems.decorator';
import { Interest, type InterestResponse } from './interest.dto';
import { InterestService } from './interest.service';

/** "Tenho interesse" on a listing (`/listings/:id/interest`). */
@ApiBearerAuth()
@Controller('listings')
export class InterestController {
  constructor(private readonly interestService: InterestService) {}

  /**
   * Records the User's interest in another User's active listing, once per
   * User (tapping again reopens the chat without counting), and answers the
   * `wa.me` link to the donor with the message ready: the only route that
   * hands out the donor's phone (ADR 0007). Missing: `NOT_FOUND`; the User's
   * own: `OWN_LISTING`; not effectively active: `LISTING_NOT_ACTIVE`.
   */
  @Post(':id/interest')
  @HttpCode(HttpStatus.OK)
  @ZodResponse({ status: 200, type: Interest })
  @ApiProblems(
    'UNAUTHENTICATED',
    'NOT_FOUND',
    'OWN_LISTING',
    'LISTING_NOT_ACTIVE',
  )
  show(
    @Param() { id }: IdParam,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<InterestResponse> {
    return this.interestService.show(user.id, id);
  }
}
