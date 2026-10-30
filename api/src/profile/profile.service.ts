import { Inject, Injectable } from '@nestjs/common';
import { and, eq, isNotNull } from 'drizzle-orm';
import { DATABASE, type Database } from '../database/database.module';
import { geographyOf } from '../database/geography';
import { type User, users } from '../database/schema';
import { DomainError } from '../errors/domain-error';
import { Users } from '../users/users';
import { toBrazilianMobile } from './brazilian-mobile';
import { cellCenter } from './donation-grid';
import type { DonationProfileInput } from './donation-profile.dto';

/** The User's own profile (`/me`). */
@Injectable()
export class ProfileService {
  constructor(
    @Inject(DATABASE) private readonly db: Database,
    private readonly users: Users,
  ) {}

  /**
   * The User of a valid access token. One that no longer exists means the
   * session is over: `UNAUTHENTICATED`.
   */
  async get(userId: string): Promise<User> {
    const user = await this.users.findById(userId);
    if (!user) throw new DomainError('UNAUTHENTICATED');
    return user;
  }

  /** Changes the name; the e-mail does not change in the MVP. */
  async rename(userId: string, name: string): Promise<User> {
    const [user] = await this.db
      .update(users)
      .set({ name })
      .where(eq(users.id, userId))
      .returning();
    if (!user) throw new DomainError('UNAUTHENTICATED');
    return user;
  }

  /**
   * Sets the WhatsApp phone and the donation location. The phone must be a
   * Brazilian mobile (`INVALID_PHONE`), stored in E.164; the point is rounded
   * to the center of its ~1 km cell before saving, so the exact one is never
   * stored (ADR 0002). Without a point the saved location stays, and with no
   * saved location that is `VALIDATION_FAILED` on `lat` and `lng`. Listings
   * already published keep their own copy.
   */
  async setDonationProfile(
    userId: string,
    { phone, lat, lng, neighborhood }: DonationProfileInput,
  ): Promise<User> {
    const mobile = toBrazilianMobile(phone);
    if (mobile === null) throw new DomainError('INVALID_PHONE');
    const point = lat !== undefined && lng !== undefined ? { lat, lng } : null;
    const [user] = await this.db
      .update(users)
      .set({
        phone: mobile,
        donationNeighborhood: neighborhood,
        ...(point && { donationLocation: geographyOf(cellCenter(point)) }),
      })
      .where(
        point
          ? eq(users.id, userId)
          : and(eq(users.id, userId), isNotNull(users.donationLocation)),
      )
      .returning();
    if (user) return user;
    await this.get(userId); // UNAUTHENTICATED when the User is gone
    throw new DomainError('VALIDATION_FAILED', {
      errors: ['lat', 'lng'].map((path) => ({
        path,
        message: 'required while there is no saved donation location',
      })),
    });
  }
}
