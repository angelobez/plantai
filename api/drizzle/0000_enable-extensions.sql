-- PostGIS for donation locations, unaccent for accent-insensitive species
-- search and citext for case-insensitive e-mails.
CREATE EXTENSION IF NOT EXISTS postgis;--> statement-breakpoint
CREATE EXTENSION IF NOT EXISTS unaccent;--> statement-breakpoint
CREATE EXTENSION IF NOT EXISTS citext;
