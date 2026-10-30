import { Module } from '@nestjs/common';
import { CareGuidesModule } from '../care-guides/care-guides.module';
import { CatalogService } from './catalog.service';
import { SpeciesController } from './species.controller';

/**
 * The Catalog in the API (`/species`). Exports {@link CatalogService}, so the
 * features that show a species (identification, garden) present it the same
 * way.
 */
@Module({
  imports: [CareGuidesModule],
  controllers: [SpeciesController],
  providers: [CatalogService],
  exports: [CatalogService],
})
export class CatalogModule {}
