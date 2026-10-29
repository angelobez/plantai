import {
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiConsumes } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import {
  type AuthenticatedUser,
  CurrentUser,
} from '../auth/current-user.decorator';
import { ApiProblems } from '../openapi/api-problems.decorator';
import { Photo, type PhotoResponse } from './photo.dto';
import {
  invalidPhoto,
  MAX_PHOTO_BYTES,
  PHOTO_FIELD,
  PhotoUploadInterceptor,
} from './photo-upload.interceptor';
import { PHOTO_DAILY_LIMIT, PhotosService } from './photos.service';

@ApiBearerAuth()
@Controller('photos')
export class PhotosController {
  constructor(private readonly photosService: PhotosService) {}

  /**
   * Stores a photo the User just took or picked, before they decide what to
   * do with it. The metadata (GPS included) is removed before it is stored.
   */
  @Post()
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(PhotoUploadInterceptor)
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    description: `The photo in the \`${PHOTO_FIELD}\` field, at most ${String(MAX_PHOTO_BYTES / 1024 / 1024)} MB. Any format sharp reads; it is stored as JPEG, upright and without metadata. At most ${String(PHOTO_DAILY_LIMIT)} per User per day.`,
    schema: {
      type: 'object',
      required: [PHOTO_FIELD],
      properties: { [PHOTO_FIELD]: { type: 'string', format: 'binary' } },
    },
  })
  @ZodResponse({ status: 201, type: Photo })
  @ApiProblems('UNAUTHENTICATED', 'PHOTO_DAILY_LIMIT')
  async upload(
    @CurrentUser() current: AuthenticatedUser,
    @UploadedFile() file: Express.Multer.File | undefined,
  ): Promise<PhotoResponse> {
    if (!file) throw invalidPhoto(`the ${PHOTO_FIELD} field is missing`);
    return this.photosService.upload(current.id, file.buffer);
  }
}
