import { Inject, Injectable } from '@nestjs/common';
import { and, desc, eq, type SQL, sql } from 'drizzle-orm';
import { CatalogService } from '../catalog/catalog.service';
import { DATABASE, type Database } from '../database/database.module';
import { interests, listings, photos, plants, users } from '../database/schema';
import type { PgUpdateSetSource } from 'drizzle-orm/pg-core';
import { DomainError, type ErrorCode } from '../errors/domain-error';
import { invalidField } from '../errors/validation';
import { PhotosService } from '../photos/photos.service';
import type { MyListingResponse } from './listing.dto';
import {
  canRenew,
  effectiveStatus,
  isEffectivelyActive,
  newExpiry,
} from './listing-status';

/** What `POST /listings` takes, already validated. */
export interface NewListing {
  photoId: string;
  commonName: string;
  speciesId?: string | undefined;
  plantId?: string | undefined;
  quantity: number;
  note?: string | undefined;
}

/** What `PATCH /listings/:id` takes, already validated: at least one field. */
export interface ListingChanges {
  quantity?: number | undefined;
  /** `null` or empty clears the note; `undefined` keeps it. */
  note?: string | null | undefined;
}

/**
 * A rule a donor action checks on top of the common ones, in the same
 * atomic `UPDATE`: [where] must hold, or the action answers [error].
 */
export interface DonorActionPrecondition {
  where: SQL;
  error: ErrorCode;
}

/**
 * Donation listings (Anúncios). A listing keeps a copy of the donor's
 * donation location and neighborhood from when it was published, its own
 * photo (which outlives the plant it came from) and a stored status that
 * only the donor's actions change; every query reads the effective status
 * from `listing-status.ts`.
 */
@Injectable()
export class ListingsService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    @Inject(PhotosService) private readonly photosService: PhotosService,
    @Inject(CatalogService) private readonly catalogService: CatalogService,
  ) {}

  /**
   * Publishes a listing for [userId], valid for 30 days. Without a phone or
   * a donation location, `DONATION_PROFILE_REQUIRED` comes before any other
   * rule. The photo must be the User's (`NOT_FOUND`); it may be one of their
   * plant's, which keeps it, or a new one, and it is attached either way. A
   * [NewListing.plantId] that is not one of the User's plants, or a
   * [NewListing.speciesId] that does not exist, is `VALIDATION_FAILED`.
   */
  async create(userId: string, input: NewListing): Promise<MyListingResponse> {
    const [donor] = await this.db
      .select({
        hasProfile: sql<boolean>`(${users.phone} IS NOT NULL AND ${users.donationLocation} IS NOT NULL)`,
      })
      .from(users)
      .where(eq(users.id, userId));
    if (!donor) throw new DomainError('UNAUTHENTICATED');
    if (!donor.hasProfile) throw new DomainError('DONATION_PROFILE_REQUIRED');

    const photo = await this.photosService.findOwned(userId, input.photoId);
    if (input.plantId && !(await this.ownsPlant(userId, input.plantId))) {
      throw invalidField('plantId', 'no such plant');
    }
    if (
      input.speciesId &&
      !(await this.catalogService.exists(input.speciesId))
    ) {
      throw invalidField('speciesId', 'no such species');
    }

    await this.photosService.attach(photo);
    const [listing] = await this.db
      .insert(listings)
      .values({
        userId,
        plantId: input.plantId ?? null,
        photoId: photo.id,
        commonName: input.commonName,
        speciesId: input.speciesId ?? null,
        quantity: input.quantity,
        note: input.note ? input.note : null,
        // Copies, so a later change of the profile leaves the listing as is.
        location: sql`(SELECT ${users.donationLocation} FROM ${users} WHERE ${users.id} = ${userId})`,
        neighborhood: sql`(SELECT ${users.donationNeighborhood} FROM ${users} WHERE ${users.id} = ${userId})`,
        expiresAt: newExpiry(),
      })
      .returning({ id: listings.id });
    if (!listing) throw new Error('The listing insert returned no row');

    return this.mineItem(userId, listing.id);
  }

  /**
   * [userId]'s listings, newest first, with the effective status, how many
   * Users had interest and whether renewing is allowed now; [filter]
   * narrows them.
   */
  async mine(userId: string, filter?: SQL): Promise<MyListingResponse[]> {
    const rows = await this.db
      .select({
        id: listings.id,
        commonName: listings.commonName,
        photoId: photos.id,
        photoS3Key: photos.s3Key,
        status: effectiveStatus(),
        quantity: listings.quantity,
        interestCount:
          sql<number>`(SELECT count(*) FROM ${interests} WHERE ${interests.listingId} = ${listings.id})`.mapWith(
            Number,
          ),
        expiresAt: listings.expiresAt,
        canRenew: canRenew(),
      })
      .from(listings)
      .innerJoin(photos, eq(photos.id, listings.photoId))
      .where(and(eq(listings.userId, userId), filter))
      .orderBy(desc(listings.createdAt), desc(listings.id));

    return Promise.all(
      rows.map(async ({ photoId, photoS3Key, expiresAt, ...row }) => ({
        ...row,
        photo: await this.photosService.present({
          id: photoId,
          s3Key: photoS3Key,
        }),
        expiresAt: expiresAt.toISOString(),
      })),
    );
  }

  /** One of [userId]'s listings as `GET /me/listings` shows it. */
  async mineItem(
    userId: string,
    listingId: string,
  ): Promise<MyListingResponse> {
    const [item] = await this.mine(userId, eq(listings.id, listingId));
    if (!item) throw new Error(`The listing ${listingId} was not found`);
    return item;
  }

  /**
   * `PATCH /listings/:id`: a new quantity and/or note on one of [userId]'s
   * active listings; an empty note clears it. Answers the listing as
   * `GET /me/listings` shows it. See {@link actOnActive} for the errors.
   */
  update(
    userId: string,
    listingId: string,
    changes: ListingChanges,
  ): Promise<MyListingResponse> {
    return this.actOnActive(userId, listingId, {
      quantity: changes.quantity,
      note: changes.note === undefined ? undefined : changes.note || null,
    });
  }

  /**
   * `POST /listings/:id/close`: the donor gives up on one of their active
   * listings, which stays in Meus anúncios as `closed` and cannot reopen.
   */
  close(userId: string, listingId: string): Promise<MyListingResponse> {
    return this.actOnActive(userId, listingId, { status: 'closed' });
  }

  /**
   * The common rules of the donor routes (`PATCH`, `close`, `donations`,
   * `renew`), applied in one atomic `UPDATE` so a concurrent action cannot
   * slip between the check and the write: another User's listing, or one
   * that does not exist, is `NOT_FOUND`; one that is not effectively active
   * (expired included) is `LISTING_NOT_ACTIVE`. An action with a rule of its
   * own passes it as [precondition]. Answers the changed listing as
   * `GET /me/listings` shows it.
   */
  async actOnActive(
    userId: string,
    listingId: string,
    changes: PgUpdateSetSource<typeof listings>,
    precondition?: DonorActionPrecondition,
  ): Promise<MyListingResponse> {
    const [changed] = await this.db
      .update(listings)
      .set({ ...changes, updatedAt: sql`now()` })
      .where(
        and(
          eq(listings.id, listingId),
          eq(listings.userId, userId),
          isEffectivelyActive(),
          precondition?.where,
        ),
      )
      .returning({ id: listings.id });
    if (!changed) {
      throw await this.whyNotChanged(userId, listingId, precondition);
    }
    return this.mineItem(userId, listingId);
  }

  /** Which rule stopped a donor action that changed no row. */
  private async whyNotChanged(
    userId: string,
    listingId: string,
    precondition: DonorActionPrecondition | undefined,
  ): Promise<DomainError> {
    const [listing] = await this.db
      .select({ active: isEffectivelyActive() })
      .from(listings)
      .where(and(eq(listings.id, listingId), eq(listings.userId, userId)));
    if (!listing) return new DomainError('NOT_FOUND');
    if (!listing.active || !precondition) {
      return new DomainError('LISTING_NOT_ACTIVE');
    }
    return new DomainError(precondition.error);
  }

  private async ownsPlant(userId: string, plantId: string): Promise<boolean> {
    const [row] = await this.db
      .select({ id: plants.id })
      .from(plants)
      .where(and(eq(plants.id, plantId), eq(plants.userId, userId)));
    return row !== undefined;
  }
}
