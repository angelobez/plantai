// Drizzle table definitions, as in "Modelo de dados" of
// docs/spec/modelo-de-dados-e-api.md. Every id is a UUIDv7 made by the API.
import { randomUUIDv7 } from 'node:crypto';
import {
  customType,
  index,
  integer,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

/** Case-insensitive text (the `citext` extension), for e-mails. */
const citext = customType<{ data: string }>({
  dataType: () => 'citext',
});

/** A `geography(Point, 4326)`; read and written as WKT or GeoJSON later (v0.3). */
const geographyPoint = customType<{ data: string }>({
  dataType: () => 'geography(Point, 4326)',
});

const id = () =>
  uuid('id')
    .primaryKey()
    .$defaultFn(() => randomUUIDv7());

const timestamptz = (name: string) => timestamp(name, { withTimezone: true });

const createdAt = () => timestamptz('created_at').notNull().defaultNow();

// ADR 0001: one User per e-mail, signing in with a password, Google or both.
export const users = pgTable('users', {
  id: id(),
  email: citext('email').notNull().unique(),
  /** The account only works once the e-mail is confirmed. */
  emailVerifiedAt: timestamptz('email_verified_at'),
  /** argon2id; null for whoever only signed in with Google. */
  passwordHash: text('password_hash'),
  googleSub: text('google_sub').unique(),
  name: text('name').notNull(),
  /** E.164, Brazilian mobile; written from v0.3. */
  phone: text('phone'),
  /** Already rounded to the center of its ~1 km cell (ADR 0002); from v0.3. */
  donationLocation: geographyPoint('donation_location'),
  donationNeighborhood: text('donation_neighborhood'),
  createdAt: createdAt(),
});

export type User = typeof users.$inferSelect;

export const refreshTokens = pgTable(
  'refresh_tokens',
  {
    id: id(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** SHA-256 of the opaque token; the token itself is never stored. */
    tokenHash: text('token_hash').notNull().unique(),
    /** Every sign-in starts a family; a reused token revokes all of it. */
    familyId: uuid('family_id').notNull(),
    expiresAt: timestamptz('expires_at').notNull(),
    revokedAt: timestamptz('revoked_at'),
    createdAt: createdAt(),
  },
  (table) => [
    index('refresh_tokens_user_id_idx').on(table.userId),
    index('refresh_tokens_family_id_idx').on(table.familyId),
  ],
);

export const emailCodePurpose = pgEnum('email_code_purpose', [
  'signup',
  'password_reset',
]);

export type EmailCodePurpose = (typeof emailCodePurpose.enumValues)[number];

export const emailCodes = pgTable(
  'email_codes',
  {
    id: id(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    purpose: emailCodePurpose('purpose').notNull(),
    /** argon2id of the 6 digits. */
    codeHash: text('code_hash').notNull(),
    expiresAt: timestamptz('expires_at').notNull(),
    attempts: integer('attempts').notNull().default(0),
    usedAt: timestamptz('used_at'),
    createdAt: createdAt(),
  },
  (table) => [
    index('email_codes_user_id_purpose_idx').on(table.userId, table.purpose),
  ],
);
