import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { IdParam } from '../http/id-param.dto';
import { ApiProblems } from '../openapi/api-problems.decorator';
import {
  CreatePlantRequest,
  Plant,
  PlantItem,
  type PlantItemResponse,
  type PlantResponse,
  UpdatePlantRequest,
} from './plant.dto';
import { PlantsService } from './plants.service';

@ApiBearerAuth()
@Controller('plants')
export class PlantsController {
  constructor(private readonly plantsService: PlantsService) {}

  /** The User's plants, newest first. */
  @Get()
  @ZodResponse({ status: 200, type: [PlantItem] })
  @ApiProblems('UNAUTHENTICATED')
  list(@CurrentUser() user: AuthenticatedUser): Promise<PlantItemResponse[]> {
    return this.plantsService.list(user.id);
  }

  /**
   * Saves a plant with one of the User's photos, which becomes the plant's.
   * A `speciesId` that does not exist, or a photo another plant has, is
   * `VALIDATION_FAILED`.
   */
  @Post()
  @ZodResponse({ status: 201, type: PlantItem })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND')
  create(
    @Body() body: CreatePlantRequest,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<PlantItemResponse> {
    return this.plantsService.create(user.id, body);
  }

  /**
   * One plant, with its species and care guide as `GET /species/:id`: the
   * first reading of a species has Claude write the guide; while another
   * request is writing it, answers `202 CARE_GUIDE_GENERATING` with
   * `Retry-After`.
   */
  @Get(':id')
  @ZodResponse({ status: 200, type: Plant })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND', 'CARE_GUIDE_GENERATING')
  get(
    @Param() { id }: IdParam,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<PlantResponse> {
    return this.plantsService.get(user.id, id);
  }

  /** Renames the plant; answers it as a list item. */
  @Patch(':id')
  @ZodResponse({ status: 200, type: PlantItem })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND')
  update(
    @Param() { id }: IdParam,
    @Body() body: UpdatePlantRequest,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<PlantItemResponse> {
    return this.plantsService.update(user.id, id, body);
  }

  /**
   * Removes the plant and its photo, from the database and then the storage.
   * A photo that fails to leave the storage is logged, not answered.
   */
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiNoContentResponse({ description: 'The plant is gone' })
  @ApiProblems('UNAUTHENTICATED', 'NOT_FOUND')
  async remove(
    @Param() { id }: IdParam,
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<void> {
    await this.plantsService.remove(user.id, id);
  }
}
