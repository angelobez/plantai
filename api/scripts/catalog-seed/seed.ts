import { format, resolveConfig } from 'prettier';
import type { ReferencePhoto } from './photo';

/** One item of `catalog/catalog-seed.json`. */
export interface SeedSpecies {
  gbifKey: number;
  scientificName: string;
  commonName: string;
  otherNames: string[];
  referencePhoto: ReferencePhoto;
}

export interface Discard {
  name: string;
  reason: string;
}

/**
 * Items sorted by scientific name, keys in a fixed order and Prettier's JSON
 * style, so a new run of the script gives a readable diff.
 */
export async function serializeSeed(
  species: SeedSpecies[],
  outputPath: string,
): Promise<string> {
  const items = [...species]
    .sort((a, b) =>
      a.scientificName < b.scientificName
        ? -1
        : a.scientificName > b.scientificName
          ? 1
          : 0,
    )
    .map((item) => ({
      gbifKey: item.gbifKey,
      scientificName: item.scientificName,
      commonName: item.commonName,
      otherNames: item.otherNames,
      referencePhoto: {
        sourceUrl: item.referencePhoto.sourceUrl,
        imageUrl: item.referencePhoto.imageUrl,
        author: item.referencePhoto.author,
        license: item.referencePhoto.license,
      },
    }));
  const options = (await resolveConfig(outputPath)) ?? {};
  return format(JSON.stringify(items, null, 2), { ...options, parser: 'json' });
}

export function formatDiscardReport(discards: Discard[]): string {
  if (discards.length === 0) return 'Nenhum descarte.';
  const lines = [...discards]
    .sort(
      (a, b) =>
        a.reason.localeCompare(b.reason) || a.name.localeCompare(b.name),
    )
    .map(({ name, reason }) => `  - ${name}: ${reason}`);
  return [`Descartes (${String(discards.length)}):`, ...lines].join('\n');
}
