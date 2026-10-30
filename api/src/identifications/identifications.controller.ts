import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Res,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
} from '@nestjs/swagger';
import type { Response } from 'express';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { IdParam } from '../http/id-param.dto';
import { ApiProblems } from '../openapi/api-problems.decorator';
import {
  ChoiceRequest,
  ChoiceResponse,
  type ChoiceResponseBody,
  choiceResponseSchema,
  Identification,
  type IdentificationResponse,
  IdentifyRequest,
} from './identification.dto';
import {
  IDENTIFICATION_DAILY_LIMIT,
  IdentificationsService,
} from './identifications.service';

@ApiBearerAuth()
@Controller('identifications')
export class IdentificationsController {
  constructor(
    private readonly identificationsService: IdentificationsService,
  ) {}

  /**
   * Identifies the plant in a photo the User sent, through Pl@ntNet (about
   * 2 s). Counts against the daily limit of 10 even when the photo is not
   * recognized; a Pl@ntNet failure does not count.
   */
  @Post()
  @ZodResponse({
    status: 201,
    type: Identification,
    description: `At most ${String(IDENTIFICATION_DAILY_LIMIT)} per User per day (midnight in America/Sao_Paulo). "not_recognized" (no candidate, or the top one scores below 0.2) is not an error.`,
  })
  @ApiProblems(
    'UNAUTHENTICATED',
    'NOT_FOUND',
    'IDENTIFICATION_DAILY_LIMIT',
    'IDENTIFICATION_SERVICE_UNAVAILABLE',
  )
  identify(
    @CurrentUser() current: AuthenticatedUser,
    @Body() { photoId }: IdentifyRequest,
  ): Promise<IdentificationResponse> {
    return this.identificationsService.identify(current.id, photoId);
  }

  /**
   * Records the User's choice: a candidate, which enters the Catalog if new,
   * or "nenhuma destas". One choice per identification.
   */
  @Post(':id/choice')
  @HttpCode(HttpStatus.OK)
  // Not @ZodResponse: the 204 has no body to serialize.
  @ApiOkResponse({ type: ChoiceResponse.Output, description: 'A candidate' })
  @ApiNoContentResponse({ description: '"Nenhuma destas"' })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND', 'IDENTIFICATION_ALREADY_CHOSEN')
  async choose(
    @CurrentUser() current: AuthenticatedUser,
    @Param() { id }: IdParam,
    @Body() choice: ChoiceRequest,
    @Res({ passthrough: true }) response: Response,
  ): Promise<ChoiceResponseBody | undefined> {
    const chosen = await this.identificationsService.choose(
      current.id,
      id,
      choice,
    );
    if (chosen === null) {
      response.status(HttpStatus.NO_CONTENT);
      return undefined;
    }
    return choiceResponseSchema.parse({ species: chosen });
  }
}
