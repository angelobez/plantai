import { z } from 'zod';
import { GBIF_API } from '../../src/gbif/gbif-match';

// The `species/match` logic lives in the API, which also uses it; the script
// imports it from there.
export {
  GBIF_API,
  gbifMatchUrl,
  resolveGbifMatch,
  type GbifResolution,
} from '../../src/gbif/gbif-match';

export function gbifVernacularNamesUrl(gbifKey: number): string {
  return `${GBIF_API}/species/${String(gbifKey)}/vernacularNames?limit=1000`;
}

const gbifVernacularSchema = z.object({
  results: z.array(
    z.object({
      vernacularName: z.string(),
      language: z.string().optional(),
    }),
  ),
});

/** The Portuguese (`por`) names of a `vernacularNames` response. */
export function gbifPortugueseNames(response: unknown): string[] {
  return gbifVernacularSchema
    .parse(response)
    .results.filter((result) => result.language === 'por')
    .map((result) => result.vernacularName);
}
