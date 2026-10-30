import { Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
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
   * stored (ADR 0002). Listings already published keep their own copy.
   */
  async setDonationProfile(
    userId: string,
    { phone, lat, lng, neighborhood }: DonationProfileInput,
  ): Promise<User> {
    const mobile = toBrazilianMobile(phone);
    if (mobile === null) throw new DomainError('INVALID_PHONE');
    const center = cellCenter({ lat, lng });
    const [user] = await this.db
      .update(users)
      .set({
        phone: mobile,
        donationLocation: geographyOf(center),
        donationNeighborhood: neighborhood,
      })
      .where(eq(users.id, userId))
      .returning();
    if (!user) throw new DomainError('UNAUTHENTICATED');
    return user;
  }
}
