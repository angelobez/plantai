// Drizzle table definitions, as in "Modelo de dados" of
// docs/spec/modelo-de-dados-e-api.md. Every id is a UUIDv7 made by the API.
import { randomUUIDv7 } from 'node:crypto';
import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  customType,
  index,
  integer,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  type AnyPgColumn,
  unique,
  uniqueIndex,
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

// Catalog -------------------------------------------------------------------

/**
 * `lower(unaccent(...))` through `immutable_unaccent`, the IMMUTABLE wrapper
 * the catalog migration creates (`unaccent` itself is only STABLE, so it
 * cannot go in a generated column or an index). Species search compares
 * `normalized(term)` with these.
 */
export const normalized = (value: unknown) =>
  sql`lower(public.immutable_unaccent(${value}))`;

export const speciesOrigin = pgEnum('species_origin', [
  'seed',
  'identification',
]);

export type SpeciesOrigin = (typeof speciesOrigin.enumValues)[number];

export const species = pgTable(
  'species',
  {
    id: id(),
    /** The Species' identity: the seed and Pl@ntNet meet through it. */
    gbifKey: integer('gbif_key').notNull().unique(),
    /** Without author. */
    scientificName: text('scientific_name').notNull().unique(),
    /** Our own copy in the photo storage (the seed's, from Wikimedia). */
    referencePhotoS3Key: text('reference_photo_s3_key'),
    /** An external photo, shown by its URL (Pl@ntNet's, for instance). */
    referencePhotoUrl: text('reference_photo_url'),
    referencePhotoAuthor: text('reference_photo_author').notNull(),
    referencePhotoLicense: text('reference_photo_license').notNull(),
    /** The photo's page, for the credit. */
    referencePhotoSourceUrl: text('reference_photo_source_url').notNull(),
    origin: speciesOrigin('origin').notNull(),
    createdAt: createdAt(),
  },
  (table) => [
    check(
      'species_one_reference_photo',
      sql`(${table.referencePhotoS3Key} IS NULL) <> (${table.referencePhotoUrl} IS NULL)`,
    ),
    index('species_scientific_name_trgm_idx').using(
      'gin',
      sql`${normalized(sql`${table.scientificName}`)} gin_trgm_ops`,
    ),
  ],
);

export type Species = typeof species.$inferSelect;

export const speciesNames = pgTable(
  'species_names',
  {
    id: id(),
    speciesId: uuid('species_id')
      .notNull()
      .references(() => species.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    nameNormalized: text('name_normalized')
      .notNull()
      .generatedAlwaysAs((): ReturnType<typeof sql> =>
        normalized(sql.raw('name')),
      ),
    /** One per species: the seed's comes from Flora e Funga do Brasil. */
    isPrimary: boolean('is_primary').notNull().default(false),
  },
  (table) => [
    unique('species_names_species_id_name_unique').on(
      table.speciesId,
      table.name,
    ),
    uniqueIndex('species_names_one_primary_idx')
      .on(table.speciesId)
      .where(sql`${table.isPrimary}`),
    index('species_names_name_normalized_trgm_idx').using(
      'gin',
      table.nameNormalized.op('gin_trgm_ops'),
    ),
  ],
);

export const careGuideStatus = pgEnum('care_guide_status', [
  'generating',
  'ready',
  'failed',
]);

export type CareGuideStatus = (typeof careGuideStatus.enumValues)[number];

/** Care guide (Dicas de cuidado): one per species, written by Claude. */
export const careGuides = pgTable('care_guides', {
  speciesId: uuid('species_id')
    .primaryKey()
    .references(() => species.id, { onDelete: 'cascade' }),
  status: careGuideStatus('status').notNull(),
  /** Validated by Zod; null until `ready`. */
  content: jsonb('content'),
  /** Such as `claude-sonnet-5-5`. */
  model: text('model').notNull(),
  /** To generate again when the prompt changes. */
  promptVersion: integer('prompt_version').notNull(),
  /** Who caused the generation (AI usage per User); null for the seed. */
  requestedBy: uuid('requested_by').references(() => users.id, {
    onDelete: 'set null',
  }),
  startedAt: timestamptz('started_at').notNull(),
  generatedAt: timestamptz('generated_at'),
});

// Photos and identification --------------------------------------------------

export const photos = pgTable(
  'photos',
  {
    id: id(),
    ownerId: uuid('owner_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** In the private bucket; the EXIF is already gone. */
    s3Key: text('s3_key').notNull().unique(),
    width: integer('width').notNull(),
    height: integer('height').notNull(),
    /** The Plant the photo belongs to; a table of its own for many per plant. */
    plantId: uuid('plant_id').references((): AnyPgColumn => plants.id, {
      onDelete: 'set null',
    }),
    /** Set when an identification, plant or listing starts using it. */
    attachedAt: timestamptz('attached_at'),
    createdAt: createdAt(),
  },
  (table) => [
    // The daily upload limit counts a User's photos since midnight.
    index('photos_owner_id_created_at_idx').on(table.ownerId, table.createdAt),
    index('photos_plant_id_idx').on(table.plantId),
  ],
);

export const identificationResult = pgEnum('identification_result', [
  'recognized',
  'not_recognized',
]);

export type IdentificationResult =
  (typeof identificationResult.enumValues)[number];

export const identifications = pgTable(
  'identifications',
  {
    id: id(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /**
     * Null once the photo is deleted (with its plant): the row stays, since
     * it is what counts the Pl@ntNet usage.
     */
    photoId: uuid('photo_id').references(() => photos.id, {
      onDelete: 'set null',
    }),
    result: identificationResult('result').notNull(),
    /** Up to 3, raw from Pl@ntNet. */
    candidates: jsonb('candidates').notNull(),
    chosenSpeciesId: uuid('chosen_species_id').references(() => species.id),
    /** The User picked "nenhuma destas". */
    chosenNone: boolean('chosen_none').notNull().default(false),
    chosenAt: timestamptz('chosen_at'),
    createdAt: createdAt(),
  },
  (table) => [
    // The daily identification limit counts a User's rows since midnight.
    index('identifications_user_id_created_at_idx').on(
      table.userId,
      table.createdAt,
    ),
  ],
);

// Garden ---------------------------------------------------------------------

export const plants = pgTable(
  'plants',
  {
    id: id(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** A free nickname, required. */
    commonName: text('common_name').notNull(),
    /** Set once, then immutable. */
    speciesId: uuid('species_id').references(() => species.id),
    createdAt: createdAt(),
  },
  (table) => [index('plants_user_id_idx').on(table.userId)],
);
