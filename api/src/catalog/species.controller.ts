import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
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
  constructor(private readonly catalogService: CatalogService) {}

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

  @Get(':id')
  @ZodResponse({ status: 200, type: Species })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND')
  get(@Param() { id }: IdParam): Promise<SpeciesResponse> {
    return this.catalogService.get(id);
  }
}
