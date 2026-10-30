import { Module } from '@nestjs/common';
import { CatalogModule } from '../catalog/catalog.module';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env';
import { PhotosModule } from '../photos/photos.module';
import { IdentificationsController } from './identifications.controller';
import { IdentificationsService } from './identifications.service';
import { PlantIdentifier } from './plant-identifier';
import { PlantNetIdentifier } from './plantnet-identifier';

export function createPlantIdentifier(env: Env): PlantIdentifier {
  return new PlantNetIdentifier({ apiKey: env.PLANTNET_API_KEY });
}

/** Identification by photo (`/identifications`), over Pl@ntNet. */
@Module({
  imports: [PhotosModule, CatalogModule],
  controllers: [IdentificationsController],
  providers: [
    IdentificationsService,
    {
      provide: PlantIdentifier,
      inject: [ENV],
      useFactory: createPlantIdentifier,
    },
  ],
})
export class IdentificationsModule {}
