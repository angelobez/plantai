import { Module } from '@nestjs/common';
import { CatalogModule } from '../catalog/catalog.module';
import { PhotosModule } from '../photos/photos.module';
import { InterestController } from './interest.controller';
import { InterestService } from './interest.service';
import {
  ListingsController,
  MyListingsController,
} from './listings.controller';
import { ListingsService } from './listings.service';

/** Donation in the API: `/listings` (with the interest) and `/me/listings`. */
@Module({
  imports: [PhotosModule, CatalogModule],
  controllers: [ListingsController, MyListingsController, InterestController],
  providers: [ListingsService, InterestService],
})
export class ListingsModule {}
