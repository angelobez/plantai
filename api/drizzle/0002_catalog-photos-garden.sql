-- Hand-edited after drizzle-kit generate: the first two statements are not in
-- the Drizzle schema. pg_trgm gives the trigram indexes that make the species
-- search (ILIKE '%term%') indexable. unaccent is only STABLE, so the generated
-- name_normalized column and the indexes go through an IMMUTABLE wrapper that
-- names the dictionary explicitly (the known pattern; safe because the
-- dictionary never changes under us).
CREATE EXTENSION IF NOT EXISTS pg_trgm;--> statement-breakpoint
CREATE OR REPLACE FUNCTION public.immutable_unaccent(text) RETURNS text
	LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
	RETURN public.unaccent('public.unaccent'::regdictionary, $1);--> statement-breakpoint
CREATE TYPE "public"."care_guide_status" AS ENUM('generating', 'ready', 'failed');--> statement-breakpoint
CREATE TYPE "public"."identification_result" AS ENUM('recognized', 'not_recognized');--> statement-breakpoint
CREATE TYPE "public"."species_origin" AS ENUM('seed', 'identification');--> statement-breakpoint
CREATE TABLE "care_guides" (
	"species_id" uuid PRIMARY KEY NOT NULL,
	"status" "care_guide_status" NOT NULL,
	"content" jsonb,
	"model" text NOT NULL,
	"prompt_version" integer NOT NULL,
	"requested_by" uuid,
	"started_at" timestamp with time zone NOT NULL,
	"generated_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "identifications" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"photo_id" uuid,
	"result" "identification_result" NOT NULL,
	"candidates" jsonb NOT NULL,
	"chosen_species_id" uuid,
	"chosen_none" boolean DEFAULT false NOT NULL,
	"chosen_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "photos" (
	"id" uuid PRIMARY KEY NOT NULL,
	"owner_id" uuid NOT NULL,
	"s3_key" text NOT NULL,
	"width" integer NOT NULL,
	"height" integer NOT NULL,
	"plant_id" uuid,
	"attached_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "photos_s3_key_unique" UNIQUE("s3_key")
);
--> statement-breakpoint
CREATE TABLE "plants" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"common_name" text NOT NULL,
	"species_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "species" (
	"id" uuid PRIMARY KEY NOT NULL,
	"gbif_key" integer NOT NULL,
	"scientific_name" text NOT NULL,
	"reference_photo_s3_key" text,
	"reference_photo_url" text,
	"reference_photo_author" text NOT NULL,
	"reference_photo_license" text NOT NULL,
	"reference_photo_source_url" text NOT NULL,
	"origin" "species_origin" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "species_gbif_key_unique" UNIQUE("gbif_key"),
	CONSTRAINT "species_scientific_name_unique" UNIQUE("scientific_name"),
	CONSTRAINT "species_one_reference_photo" CHECK (("species"."reference_photo_s3_key" IS NULL) <> ("species"."reference_photo_url" IS NULL))
);
--> statement-breakpoint
CREATE TABLE "species_names" (
	"id" uuid PRIMARY KEY NOT NULL,
	"species_id" uuid NOT NULL,
	"name" text NOT NULL,
	"name_normalized" text GENERATED ALWAYS AS (lower(public.immutable_unaccent(name))) STORED NOT NULL,
	"is_primary" boolean DEFAULT false NOT NULL,
	CONSTRAINT "species_names_species_id_name_unique" UNIQUE("species_id","name")
);
--> statement-breakpoint
ALTER TABLE "care_guides" ADD CONSTRAINT "care_guides_species_id_species_id_fk" FOREIGN KEY ("species_id") REFERENCES "public"."species"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_guides" ADD CONSTRAINT "care_guides_requested_by_users_id_fk" FOREIGN KEY ("requested_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identifications" ADD CONSTRAINT "identifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identifications" ADD CONSTRAINT "identifications_photo_id_photos_id_fk" FOREIGN KEY ("photo_id") REFERENCES "public"."photos"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identifications" ADD CONSTRAINT "identifications_chosen_species_id_species_id_fk" FOREIGN KEY ("chosen_species_id") REFERENCES "public"."species"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "photos" ADD CONSTRAINT "photos_owner_id_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "photos" ADD CONSTRAINT "photos_plant_id_plants_id_fk" FOREIGN KEY ("plant_id") REFERENCES "public"."plants"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "plants" ADD CONSTRAINT "plants_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "plants" ADD CONSTRAINT "plants_species_id_species_id_fk" FOREIGN KEY ("species_id") REFERENCES "public"."species"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "species_names" ADD CONSTRAINT "species_names_species_id_species_id_fk" FOREIGN KEY ("species_id") REFERENCES "public"."species"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "identifications_user_id_created_at_idx" ON "identifications" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "photos_owner_id_created_at_idx" ON "photos" USING btree ("owner_id","created_at");--> statement-breakpoint
CREATE INDEX "photos_plant_id_idx" ON "photos" USING btree ("plant_id");--> statement-breakpoint
CREATE INDEX "plants_user_id_idx" ON "plants" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "species_scientific_name_trgm_idx" ON "species" USING gin (lower(public.immutable_unaccent("scientific_name")) gin_trgm_ops);--> statement-breakpoint
CREATE UNIQUE INDEX "species_names_one_primary_idx" ON "species_names" USING btree ("species_id") WHERE "species_names"."is_primary";--> statement-breakpoint
CREATE INDEX "species_names_name_normalized_trgm_idx" ON "species_names" USING gin ("name_normalized" gin_trgm_ops);