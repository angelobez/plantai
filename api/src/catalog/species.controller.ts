import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { CareGuideService } from '../care-guides/care-guide.service';
import { IdParam } from '../http/id-param.dto';
import { ApiProblems } from '../openapi/api-problems.decorator';
import { CatalogService } from './catalog.service';
import {
  SearchSpeciesQuery,
  Species,
  SpeciesItem,
  type SpeciesItemResponse,
  type SpeciesResponse,
} from './species.dto';

@ApiBearerAuth()
@Controller('species')
export class SpeciesController {
  constructor(
    private readonly catalogService: CatalogService,
    private readonly careGuideService: CareGuideService,
  ) {}

  /**
   * Searches the Catalog by part of a common or scientific name, accents and
   * capitals aside. Names that start with the term come first; at most 20.
   */
  @Get()
  @ZodResponse({ status: 200, type: [SpeciesItem] })
  @ApiProblems('UNAUTHENTICATED')
  search(@Query() { q }: SearchSpeciesQuery): Promise<SpeciesItemResponse[]> {
    return this.catalogService.search(q);
  }

  /**
   * One species with its care guide. The first opening of a species has
   * Claude write the guide (5 to 10 s); while another request is writing it,
   * answers `202 CARE_GUIDE_GENERATING` with `Retry-After`.
   */
  @Get(':id')
  @ZodResponse({ status: 200, type: Species })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND', 'CARE_GUIDE_GENERATING')
  async get(
    @Param() { id }: IdParam,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<SpeciesResponse> {
    // The guide first: a new species gets its primary name from Claude.
    const careGuide = await this.careGuideService.forResponse(id, user.id);
    return { ...(await this.catalogService.get(id)), ...careGuide };
  }
}
