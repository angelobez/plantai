import { z } from 'zod';

/** SPARQL for the Wikidata items whose taxon name (P225) is exactly this. */
export function wikidataTaxonQueryUrl(scientificName: string): string {
  const literal = JSON.stringify(scientificName);
  const query = `SELECT ?item WHERE { ?item wdt:P225 ${literal} . }`;
  return `https://query.wikidata.org/sparql?${new URLSearchParams({ query }).toString()}`;
}

/** The image (P18) claims of one Wikidata item. */
export function wikidataP18Url(itemId: string): string {
  const query = new URLSearchParams({
    action: 'wbgetclaims',
    format: 'json',
    entity: itemId,
    property: 'P18',
  });
  return `https://www.wikidata.org/w/api.php?${query.toString()}`;
}

/** `imageinfo` with the licensing fields of `extmetadata`. */
export function commonsImageInfoUrl(fileName: string): string {
  const query = new URLSearchParams({
    action: 'query',
    format: 'json',
    formatversion: '2',
    prop: 'imageinfo',
    iiprop: 'url|extmetadata',
    iiextmetadatafilter:
      'LicenseShortName|Artist|LicenseUrl|License|AttributionRequired',
    titles: `File:${fileName}`,
  });
  return `https://commons.wikimedia.org/w/api.php?${query.toString()}`;
}

const sparqlSchema = z.object({
  results: z.object({
    bindings: z.array(z.object({ item: z.object({ value: z.string() }) })),
  }),
});

/** Item ids of a SPARQL response, oldest (lowest number) first. */
export function wikidataItemIds(response: unknown): string[] {
  const ids = sparqlSchema
    .parse(response)
    .results.bindings.map(({ item }) => item.value.split('/').pop() ?? '')
    .filter((id) => /^Q\d+$/.test(id));
  return [...new Set(ids)].sort(
    (a, b) => Number(a.slice(1)) - Number(b.slice(1)),
  );
}

const claimsSchema = z.object({
  claims: z.object({
    P18: z
      .array(
        z.object({
          rank: z.string(),
          mainsnak: z.object({
            datavalue: z.object({ value: z.string() }).optional(),
          }),
        }),
      )
      .optional(),
  }),
});

/** Commons file names of the P18 claims: preferred first, never deprecated. */
export function p18FileNames(response: unknown): string[] {
  const claims = claimsSchema.parse(response).claims.P18 ?? [];
  const byRank = (rank: string) =>
    claims
      .filter((claim) => claim.rank === rank)
      .flatMap((claim) => claim.mainsnak.datavalue?.value ?? []);
  return [...byRank('preferred'), ...byRank('normal')];
}

/**
 * Only CC0, CC BY, CC BY-SA and public domain, read from the machine-readable
 * `License` field of Commons. NC, ND, GFDL-only and the rest are refused.
 */
export function acceptLicense(
  license: string | undefined,
  shortName: string | undefined,
): boolean {
  if (license === undefined || shortName === undefined || shortName === '') {
    return false;
  }
  return /^(cc0|pd|cc-by-\d|cc-by-sa-\d)/.test(license.trim().toLowerCase());
}

const ENTITIES: Record<string, string> = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  nbsp: ' ',
  eacute: 'é',
  aacute: 'á',
  iacute: 'í',
  oacute: 'ó',
  uacute: 'ú',
  ccedil: 'ç',
  atilde: 'ã',
  otilde: 'õ',
};

/** The `Artist` field comes as HTML; the credit needs plain text. */
export function cleanArtist(html: string): string {
  return (
    html
      // Commons repeats some names inside hidden elements.
      .replace(/<(\w+)[^>]*display:\s*none[^>]*>.*?<\/\1>/gis, '')
      // Block tags separate words; inline tags (links, bold) do not.
      .replace(/<(br|\/?(p|div|li|tr|td))\b[^>]*>/gi, ' ')
      .replace(/<[^>]*>/g, '')
      .replace(/&#(\d+);/g, (_, code: string) =>
        String.fromCodePoint(Number(code)),
      )
      .replace(/&#x([0-9a-f]+);/gi, (_, code: string) =>
        String.fromCodePoint(parseInt(code, 16)),
      )
      .replace(/&([a-z]+);/gi, (entity, name: string) => {
        return ENTITIES[name.toLowerCase()] ?? entity;
      })
      .replace(/\s+/g, ' ')
      .trim()
  );
}

export interface ReferencePhoto {
  sourceUrl: string;
  imageUrl: string;
  author: string;
  license: string;
}

const metadataValue = z.object({ value: z.string() }).optional();

const imageInfoSchema = z.object({
  query: z.object({
    pages: z.array(
      z.object({
        missing: z.boolean().optional(),
        imageinfo: z
          .array(
            z.object({
              url: z.string(),
              descriptionurl: z.string(),
              extmetadata: z
                .object({
                  Artist: metadataValue,
                  License: metadataValue,
                  LicenseShortName: metadataValue,
                })
                .optional(),
            }),
          )
          .optional(),
      }),
    ),
  }),
});

/** Commons adds tracking parameters to the file URL; the seed keeps it clean. */
function withoutQuery(url: string): string {
  const parsed = new URL(url);
  parsed.search = '';
  return parsed.toString();
}

export type PhotoResult =
  { ok: true; photo: ReferencePhoto } | { ok: false; reason: string };

/** Credit and URLs of a Commons file, or why it cannot be used. */
export function referencePhotoFromImageInfo(response: unknown): PhotoResult {
  const page = imageInfoSchema.parse(response).query.pages[0];
  const info = page?.imageinfo?.[0];
  if (page === undefined || page.missing === true || info === undefined) {
    return { ok: false, reason: 'arquivo não encontrado' };
  }

  const metadata = info.extmetadata ?? {};
  const license = metadata.License?.value;
  const shortName = metadata.LicenseShortName?.value;
  if (!acceptLicense(license, shortName) || shortName === undefined) {
    return {
      ok: false,
      reason: `licença recusada (${license ?? shortName ?? 'sem licença'})`,
    };
  }

  const author = cleanArtist(metadata.Artist?.value ?? '');
  if (author === '') return { ok: false, reason: 'sem autor' };

  return {
    ok: true,
    photo: {
      sourceUrl: info.descriptionurl,
      imageUrl: withoutQuery(info.url),
      author,
      license: shortName,
    },
  };
}
