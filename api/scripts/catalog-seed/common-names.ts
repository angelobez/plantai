import { z } from 'zod';

/** Flora e Funga do Brasil (JBRJ). */
export function floraTaxonUrl(scientificName: string): string {
  return `https://servicos.jbrj.gov.br/v2/flora/taxon/${encodeURIComponent(scientificName)}`;
}

const floraResponseSchema = z.array(
  z.object({
    taxon: z.object({
      taxonrank: z.string().nullable(),
      genus: z.string().nullable(),
      specificepithet: z.string().nullable(),
      infraspecificepithet: z.string().nullable(),
    }),
    vernacular_name: z
      .array(
        z.object({
          vernacularname: z.string(),
          language_vernacularname: z.string().nullable(),
        }),
      )
      .nullable()
      .optional(),
  }),
);

function normalize(text: string): string {
  return text.trim().replace(/\s+/g, ' ').toLowerCase();
}

/**
 * The Portuguese names Flora gives to the species itself. The response also
 * lists varieties and subspecies of the same name, which are skipped.
 */
export function floraPortugueseNames(
  scientificName: string,
  response: unknown,
): string[] {
  const wanted = normalize(scientificName);
  const entry = floraResponseSchema
    .parse(response)
    .find(
      ({ taxon }) =>
        taxon.taxonrank === 'ESPECIE' &&
        taxon.infraspecificepithet === null &&
        normalize(`${taxon.genus ?? ''} ${taxon.specificepithet ?? ''}`) ===
          wanted,
    );
  return (entry?.vernacular_name ?? [])
    .filter((name) => name.language_vernacularname === 'PORTUGUES')
    .map((name) => name.vernacularname);
}

export interface CommonNames {
  commonName: string;
  otherNames: string[];
}

/**
 * Flora first, GBIF only when Flora has nothing. The first name becomes the
 * main one and the others keep their order, without blanks or repeats.
 */
export function splitCommonNames(
  floraNames: string[],
  gbifNames: string[],
): CommonNames | null {
  const clean = (names: string[]): string[] => {
    const seen = new Set<string>();
    const result: string[] = [];
    for (const raw of names) {
      const name = raw.trim().replace(/\s+/g, ' ');
      const key = normalize(name);
      if (key === '' || seen.has(key)) continue;
      seen.add(key);
      result.push(name);
    }
    return result;
  };

  const fromFlora = clean(floraNames);
  const [commonName, ...otherNames] =
    fromFlora.length > 0 ? fromFlora : clean(gbifNames);
  return commonName === undefined ? null : { commonName, otherNames };
}
