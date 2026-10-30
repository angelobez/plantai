import { Global, Module } from '@nestjs/common';
import { GbifNames } from './gbif-names';
import { HttpGbifNames } from './http-gbif-names';

/** Provides {@link GbifNames} over GBIF's public API. */
@Global()
@Module({
  providers: [{ provide: GbifNames, useFactory: () => new HttpGbifNames() }],
  exports: [GbifNames],
})
export class GbifModule {}
