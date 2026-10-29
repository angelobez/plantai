// The `species/match` logic shared by the API (GbifNames) and the Catalog
// seed script: one exact match, a synonym becomes its accepted species, and a
// genus or no match is discarded. The discard reasons are in Portuguese
// because they end up in the seed script's report for Ângelo.
import { z } from 'zod';

export const GBIF_API = 'https://api.gbif.org/v1';

/** `species/match`, restricted to plants and without fuzzy guesses. */
export function gbifMatchUrl(name: string): string {
  const query = new URLSearchParams({
    name,
    kingdom: 'Plantae',
    strict: 'true',
  });
  return `${GBIF_API}/species/match?${query.toString()}`;
}

const gbifMatchSchema = z.object({
  matchType: z.string(),
  usageKey: z.number().optional(),
  acceptedUsageKey: z.number().optional(),
  canonicalName: z.string().optional(),
  rank: z.string().optional(),
  status: z.string().optional(),
  species: z.string().optional(),
  speciesKey: z.number().optional(),
});

export type GbifResolution =
  | { ok: true; gbifKey: number; scientificName: string }
  | { ok: false; reason: string };

/** Lowercases and collapses spaces, so "Epipremnum  Aureum" matches. */
function normalizeName(name: string): string {
  return name.trim().replace(/\s+/g, ' ').toLowerCase();
}

/**
 * Turns a `species/match` response into the accepted species: an accepted
 * name stays as is, a synonym becomes its accepted species, and anything else
 * (no exact match, not a species, doubtful) is discarded with a reason.
 */
export function resolveGbifMatch(
  proposedName: string,
  response: unknown,
): GbifResolution {
  const match = gbifMatchSchema.parse(response);

  if (match.matchType !== 'EXACT') {
    return { ok: false, reason: `GBIF: sem match exato (${match.matchType})` };
  }
  if (match.rank !== 'SPECIES') {
    return {
      ok: false,
      reason: `GBIF: não é espécie (${match.rank ?? 'sem rank'})`,
    };
  }
  if (
    match.canonicalName === undefined ||
    normalizeName(match.canonicalName) !== normalizeName(proposedName)
  ) {
    return {
      ok: false,
      reason: `GBIF: o match é outro nome (${match.canonicalName ?? '?'})`,
    };
  }

  const status = match.status ?? '';
  if (status === 'ACCEPTED' && match.usageKey !== undefined) {
    return {
      ok: true,
      gbifKey: match.usageKey,
      scientificName: match.canonicalName,
    };
  }
  if (status.endsWith('SYNONYM')) {
    if (
      match.acceptedUsageKey === undefined ||
      match.acceptedUsageKey !== match.speciesKey ||
      match.species === undefined
    ) {
      return {
        ok: false,
        reason: `GBIF: nome aceito não é espécie (${String(match.acceptedUsageKey ?? '?')})`,
      };
    }
    return {
      ok: true,
      gbifKey: match.acceptedUsageKey,
      scientificName: match.species,
    };
  }
  return { ok: false, reason: `GBIF: status ${status || 'desconhecido'}` };
}
