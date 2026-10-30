import { Inject, Injectable } from '@nestjs/common';
import { eq, sql } from 'drizzle-orm';
import { DATABASE, type Database } from '../database/database.module';
import { interests, listings, users } from '../database/schema';
import { DomainError } from '../errors/domain-error';
import type { InterestResponse } from './interest.dto';
import { isEffectivelyActive } from './listing-status';
import { firstWordOf } from './listings.service';

/**
 * Interesse: a User tapped "Tenho interesse" on another User's listing. It is
 * what hands out the donor's phone, as a `wa.me` link, and what the donor
 * counts in Meus anúncios (ADR 0007).
 */
@Injectable()
export class InterestService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /**
   * Records that [userId] has interest in [listingId] (once per User:
   * tapping again only moves `last_opened_at`) and answers the link to the
   * donor's WhatsApp with the message ready. Missing: `NOT_FOUND`; the
   * User's own: `OWN_LISTING`; not effectively active (expired included):
   * `LISTING_NOT_ACTIVE`.
   */
  async show(userId: string, listingId: string): Promise<InterestResponse> {
    const [listing] = await this.db
      .select({
        donorId: listings.userId,
        active: isEffectivelyActive(),
        commonName: listings.commonName,
        donorName: users.name,
        donorPhone: users.phone,
      })
      .from(listings)
      .innerJoin(users, eq(users.id, listings.userId))
      .where(eq(listings.id, listingId));
    if (!listing) throw new DomainError('NOT_FOUND');
    if (listing.donorId === userId) throw new DomainError('OWN_LISTING');
    if (!listing.active) throw new DomainError('LISTING_NOT_ACTIVE');
    // Publishing requires a phone and the profile cannot drop it.
    if (!listing.donorPhone) {
      throw new Error(`The donor of listing ${listingId} has no phone`);
    }

    // A listing that ends between the check and this write keeps one more
    // interest than it would: harmless, the donor only sees a count.
    await this.db
      .insert(interests)
      .values({ listingId, userId })
      .onConflictDoUpdate({
        target: [interests.listingId, interests.userId],
        set: { lastOpenedAt: sql`now()` },
      });

    return {
      whatsappUrl: whatsappUrl(
        listing.donorPhone,
        `Oi, ${firstWordOf(listing.donorName)}! Vi no PlantAí seu anúncio de ${listing.commonName} e tenho interesse.`,
      ),
    };
  }
}

/** The `wa.me` link that opens a chat with [phone] (E.164) and [message] typed. */
function whatsappUrl(phone: string, message: string): string {
  return `https://wa.me/${phone.replace(/^\+/, '')}?text=${encodeURIComponent(message)}`;
}
