import { Module } from '@nestjs/common';
import { CatalogModule } from '../catalog/catalog.module';
import { PhotosModule } from '../photos/photos.module';
import {
  ListingsController,
  MyListingsController,
} from './listings.controller';
import { ListingsService } from './listings.service';

/** Donation in the API: `/listings` and `/me/listings`. */
@Module({
  imports: [PhotosModule, CatalogModule],
  controllers: [ListingsController, MyListingsController],
  providers: [ListingsService],
})
export class ListingsModule {}
