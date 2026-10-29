import { z } from 'zod';
import { careGuideContentSchema } from './care-guide-content';

/** How a response shows the care guide: written, or not this time. */
export const CARE_GUIDE_RESPONSE_STATUSES = ['ready', 'unavailable'] as const;

export type CareGuideResponseStatus =
  (typeof CARE_GUIDE_RESPONSE_STATUSES)[number];

/**
 * The care-guide fields of every response that shows a species
 * (`GET /species/:id`, `GET /plants/:id`), spread into its schema.
 */
export const careGuideFields = {
  careGuide: careGuideContentSchema
    .nullable()
    .describe('The care guide; null while it is unavailable'),
  careGuideStatus: z
    .enum(CARE_GUIDE_RESPONSE_STATUSES)
    .describe(
      '"unavailable" when Claude failed this time; the next request tries again',
    ),
};

export type CareGuideFieldsResponse = z.infer<
  z.ZodObject<typeof careGuideFields>
>;
