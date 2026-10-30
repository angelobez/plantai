import { Module } from '@nestjs/common';
import { PhotosController } from './photos.controller';
import { PhotosService } from './photos.service';

/**
 * A User's photos (`/photos`). Exports {@link PhotosService}, so the features
 * that use a photo (identification, garden) show it the same way.
 */
@Module({
  controllers: [PhotosController],
  providers: [PhotosService],
  exports: [PhotosService],
})
export class PhotosModule {}
