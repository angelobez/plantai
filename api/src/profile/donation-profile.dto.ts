import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const NEIGHBORHOOD_LENGTH = { min: 1, max: 60 } as const;

export const donationProfileRequestSchema = z.object({
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
    .describe('Latitude of the GPS; rounded to its ~1 km cell before saving'),
  lng: z
    .number()
    .min(-180)
    .max(180)
    .describe('Longitude of the GPS; rounded to its ~1 km cell before saving'),
  neighborhood: z
    .string()
    .trim()
    .min(NEIGHBORHOOD_LENGTH.min)
    .max(NEIGHBORHOOD_LENGTH.max)
    .describe('What neighbors see instead of the address'),
});

export type DonationProfileInput = z.infer<typeof donationProfileRequestSchema>;

export class DonationProfileRequest extends createZodDto(
  donationProfileRequestSchema,
) {}
