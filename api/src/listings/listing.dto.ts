import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import { careGuideContentSchema } from '../care-guides/care-guide-content';
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
 * `POST /listings/:id/donations`: how many seedlings left, an integer from 1;
 * above the listing's quantity is `INVALID_DONATION_COUNT`.
 */
export class DonationRequest extends createZodDto(
  z.object({
    count: z
      .int()
      .min(1)
      .describe('Seedlings donated, from 1 up to the listing’s quantity'),
  }),
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

/** How many listings one page of `GET /listings/nearby` answers. */
export const NEARBY_PAGE_SIZE = 30;

/** How far a neighbor's listing may be, in meters (30 km). */
export const NEARBY_RADIUS_METERS = 30_000;

export class NearbyListingsQuery extends createZodDto(
  z.object({
    page: z.coerce
      .number()
      .int()
      .min(1)
      .default(1)
      .describe(
        `From 1; ${String(NEARBY_PAGE_SIZE)} listings per page. The app asks for the next page while it gets a full one`,
      ),
  }),
) {}

/** One listing near the searcher, as `GET /listings/nearby` shows it. */
export const nearbyListingSchema = z.object({
  id: z.uuid(),
  commonName: z.string(),
  scientificName: z
    .string()
    .meta({ example: 'Monstera deliciosa' })
    .nullable()
    .describe('The species’ scientific name; null when listed by name only'),
  photo: photoSchema,
  quantity: z.int().describe('Seedlings left'),
  distanceKm: z
    .int()
    .describe(
      'From the searcher to the center of the listing’s ~1 km cell, rounded; 0 means "menos de 1 km"',
    ),
  neighborhood: z.string().describe('The donor’s, when publishing'),
});

export type NearbyListingResponse = z.infer<typeof nearbyListingSchema>;

export class NearbyListing extends createZodDto(nearbyListingSchema) {}

/**
 * `GET /listings/:id`: the item of `nearby` plus what the detail shows. Never
 * the donor's phone, which only `POST /listings/:id/interest` hands out
 * (ADR 0007).
 */
export const listingDetailSchema = nearbyListingSchema.extend({
  status: listingStatusSchema,
  note: z
    .string()
    .meta({ example: 'Pegar à tarde' })
    .nullable()
    .describe('The donor’s note; null without one'),
  donorFirstName: z.string().describe('The first word of the donor’s name'),
  createdAt: z.iso.datetime(),
  careGuide: careGuideContentSchema
    .nullable()
    .describe(
      'The species’ care guide when it is ready, or null. This route never has Claude write one',
    ),
});

export type ListingDetailResponse = z.infer<typeof listingDetailSchema>;

export class ListingDetail extends createZodDto(listingDetailSchema) {}
