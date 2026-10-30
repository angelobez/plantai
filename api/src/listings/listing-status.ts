import { type SQL, sql } from 'drizzle-orm';
import { type ListingStatus, listings } from '../database/schema';

/** How long a listing stays up after publishing or renewing. */
export const LISTING_LIFETIME = '30 days';

/** Renewing is only allowed this close to the expiry. */
export const RENEWAL_WINDOW = '7 days';

/**
 * The listing's effective status, computed by the database: an `active`
 * listing whose `expires_at` has passed is `closed`, with no job flipping it
 * (docs/spec/modelo-de-dados-e-api.md, "Expiração sem job").
 *
 * The single place that knows the rule: every query that filters by status
 * and every response that shows one goes through this (or through
 * {@link isEffectivelyActive}, built on it), never through `listings.status`.
 */
export function effectiveStatus(): SQL<ListingStatus> {
  return sql<ListingStatus>`(CASE WHEN ${listings.status} = 'active' AND ${listings.expiresAt} <= now() THEN 'closed' ELSE ${listings.status} END)`;
}

/**
 * Whether the listing is effectively active: shown to neighbors, open to
 * interest and to the donor's actions.
 */
export function isEffectivelyActive(): SQL<boolean> {
  return sql<boolean>`(${effectiveStatus()} = 'active')`;
}

/**
 * Whether the donor may renew now: effectively active and expiring within
 * {@link RENEWAL_WINDOW}. Once expired, it is `closed` and cannot be renewed.
 */
export function canRenew(): SQL<boolean> {
  return sql<boolean>`(${isEffectivelyActive()} AND ${listings.expiresAt} <= now() + ${RENEWAL_WINDOW}::interval)`;
}

/** `now()` + {@link LISTING_LIFETIME}: the expiry of a new or renewed listing. */
export function newExpiry(): SQL<Date> {
  return sql<Date>`now() + ${LISTING_LIFETIME}::interval`;
}
