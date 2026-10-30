# Gotchas

Traps that no config or error message reveals, found while building the deliveries. Each one names where it lives.

## API

- **Migrations with SQL Drizzle can't express.** `drizzle-kit generate` quotes custom types and has no way to write extensions, `IMMUTABLE` functions, generated columns over them, or trigram indexes. Generate the migration, then edit the `.sql` by hand, with a header comment saying what was edited (see `api/drizzle/0001_account.sql` and `0002_catalog-photos-garden.sql`). Search SQL goes through `normalized()` from `api/src/database/schema.ts`, so it matches the trigram indexes.
- **Scripts run on `tsx`, which emits no decorator metadata.** A provider that a script mounts (`npm run catalog:load` mounts `CatalogLoadModule`) needs an explicit `@Inject(TOKEN)` on every constructor parameter. Nest's type-based injection works in the server and in tests (`ts-jest`) but silently injects `undefined` under `tsx`.
- **`timestamptz` round-trips lose microseconds through a JS `Date`.** Postgres keeps microseconds and `Date` keeps milliseconds. To match a row by a timestamp you read (as the care-guide reservation does with `started_at` in `api/src/care-guides/care-guide.service.ts`), select it as text and compare with `= $1::timestamptz`.
- **Run Jest through `npm test`.** It passes `--experimental-vm-modules`, and a bare `npx jest` fails on the ESM in `@nestjs/common`.

## App

- **A `202` with `problem+json` is a success to Dio.** `ProblemAnswerInterceptor` in `app/lib/data/services/api/api_client.dart` turns any 2xx `problem+json` answer (such as `CARE_GUIDE_GENERATING`) into an `ApiException`, with `retryAfter` read from the header.
- **In go_router 18, `pushReplacement` never completes the replaced route's result.** If a caller awaits `context.push<T>(...)` for a result, every screen on the way back has to `pop` with it. A `pushReplacement` in between loses it (this is why the "Definir espécie" flow under the Tela da planta avoids it).
- **New `ApiErrorCode` values** need a Portuguese message in the failure-message function of each feature that can receive them (`app/lib/ui/<feature>/<feature>_failure_message.dart`). The shared texts live in `app/lib/ui/core/failure_messages.dart`.

## Local environment

- **`api/.env` drifts from `api/.env.example`** when a ticket adds a variable. `scripts/check-env.sh` lists what is missing, and `dev:phone` and `catalog:load` run it first. In `.env.example`, a commented key is optional and an uncommented one is required.
