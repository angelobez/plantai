import { Module } from '@nestjs/common';
import { ENV } from '../config/config.module';
import { CareGuideService } from './care-guide.service';
import { CareGuideWriter } from './care-guide-writer';
import { createCareGuideWriter } from './claude-care-guide-writer';

/**
 * The care guides (Dicas de cuidado) and their writer, Claude. Exports
 * {@link CareGuideService}, for every response that shows a species and for
 * the seed load.
 */
@Module({
  providers: [
    CareGuideService,
    {
      provide: CareGuideWriter,
      inject: [ENV],
      useFactory: createCareGuideWriter,
    },
  ],
  exports: [CareGuideService],
})
export class CareGuidesModule {}
