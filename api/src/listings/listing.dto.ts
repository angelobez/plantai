import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import { listingStatus } from '../database/schema';
import { photoSchema } from '../photos/photo.dto';
import { plantCommonNameSchema } from '../plants/plant.dto';

/** How many seedlings a listing may offer when published or edited. */
export const LISTING_QUANTITY = { min: 1, max: 99 } as const;

/** The longest note, after the trim. */
export const LISTING_NOTE_MAX_LENGTH = 200;

/** How many seedlings: an integer from 1 to 99. `PATCH` takes the same. */
export const listingQuantitySchema = z
  .int()
  .min(LISTING_QUANTITY.min)
  .max(LISTING_QUANTITY.max)
  .describe('How many seedlings, 1 to 99');

/**
 * The optional note ("pegar à tarde"), up to 200 characters after the trim;
 * an empty one is stored as no note. `PATCH` takes the same.
 */
export const listingNoteSchema = z
  .string()
  .trim()
  .max(LISTING_NOTE_MAX_LENGTH)
  .describe('Up to 200 characters after the trim; empty means no note');

/** The effective status: an expired `active` listing is `closed`. */
export const listingStatusSchema = z
  .enum(listingStatus.enumValues)
  .describe('Effective status: an expired active listing is closed');

export class CreateListingRequest extends createZodDto(
  z.object({
    photoId: z
      .uuid()
      .describe(
        'One of the User’s photos: the plant’s, or a new one of the seedling',
      ),
    commonName: plantCommonNameSchema,
    speciesId: z
      .uuid()
      .optional()
      .describe('A Catalog species; without it, the listing has only the name'),
    plantId: z
      .uuid()
      .optional()
      .describe('The User’s plant the seedlings came from'),
    quantity: listingQuantitySchema,
    note: listingNoteSchema.optional(),
  }),
) {}

/**
 * `PATCH /listings/:id`: a new quantity, a new note, or both. At least one of
 * them. A `null`, empty or blank note clears it.
 */
export const updateListingRequestSchema = z
  .object({
    quantity: listingQuantitySchema.optional(),
    note: listingNoteSchema
      .meta({ example: 'pegar à tarde' })
      .nullable()
      .optional()
      .describe(
        'Up to 200 characters after the trim; null, empty or blank clears it',
      ),
  })
  .refine((body) => body.quantity !== undefined || body.note !== undefined, {
    message: 'send quantity, note or both',
  });

export class UpdateListingRequest extends createZodDto(
  updateListingRequestSchema,
) {}

/**
 * One of the donor's listings, as `GET /me/listings` shows it; also the
 * answer of `POST /listings` and of the donor's actions.
 */
export const myListingSchema = z.object({
  id: z.uuid(),
  commonName: z.string(),
  photo: photoSchema,
  status: listingStatusSchema,
  quantity: z.int().describe('Seedlings left; 0 only once donated'),
  note: z
    .string()
    .meta({ example: 'pegar à tarde' })
    .nullable()
    .describe('The donor’s note, so "Editar" starts from it; null without one'),
  interestCount: z
    .int()
    .describe('How many Users tapped "Tenho interesse"; no names'),
  expiresAt: z.iso.datetime().describe('Publishing or renewing + 30 days'),
  canRenew: z
    .boolean()
    .describe('True only while effectively active and within 7 days of expiry'),
});

export type MyListingResponse = z.infer<typeof myListingSchema>;

export class MyListing extends createZodDto(myListingSchema) {}
