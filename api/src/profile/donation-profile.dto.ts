import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const NEIGHBORHOOD_LENGTH = { min: 1, max: 60 } as const;

/**
 * `lat` and `lng` come together or not at all; without them the saved
 * donation location stays (and one must exist). One object with a refinement
 * rather than a union, since a DTO class needs an object schema.
 */
export const donationProfileRequestSchema = z
  .object({
    phone: z
      .string()
      .max(40)
      .describe(
        'Brazilian mobile with the area code, with or without +55; masks and spaces are fine',
      )
      .meta({ example: '(11) 98765-4321' }),
    lat: z
      .number()
      .min(-90)
      .max(90)
      .optional()
      .describe(
        'Latitude of the GPS; rounded to its ~1 km cell before saving. Send it with lng, or neither to keep the saved location',
      ),
    lng: z
      .number()
      .min(-180)
      .max(180)
      .optional()
      .describe(
        'Longitude of the GPS; rounded to its ~1 km cell before saving. Send it with lat, or neither to keep the saved location',
      ),
    neighborhood: z
      .string()
      .trim()
      .min(NEIGHBORHOOD_LENGTH.min)
      .max(NEIGHBORHOOD_LENGTH.max)
      .describe('What neighbors see instead of the address'),
  })
  .superRefine(({ lat, lng }, context) => {
    if ((lat === undefined) === (lng === undefined)) return;
    context.addIssue({
      code: 'custom',
      path: [lat === undefined ? 'lat' : 'lng'],
      message: 'send lat and lng together, or neither',
    });
  });

export type DonationProfileInput = z.infer<typeof donationProfileRequestSchema>;

export class DonationProfileRequest extends createZodDto(
  donationProfileRequestSchema,
) {}
