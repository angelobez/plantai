import { Module } from '@nestjs/common';
import { CareGuidesModule } from '../care-guides/care-guides.module';
import { CatalogModule } from '../catalog/catalog.module';
import { PhotosModule } from '../photos/photos.module';
import { PlantsController } from './plants.controller';
import { PlantsService } from './plants.service';

/** Meu jardim in the API (`/plants`). */
@Module({
  imports: [PhotosModule, CatalogModule, CareGuidesModule],
  controllers: [PlantsController],
  providers: [PlantsService],
})
export class PlantsModule {}
