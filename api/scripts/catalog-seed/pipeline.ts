import {
  floraPortugueseNames,
  floraTaxonUrl,
  splitCommonNames,
} from './common-names';
import { messageOf } from '../../src/errors/message-of';
import { type FetchJson, HttpGbifNames } from '../../src/gbif/http-gbif-names';
import { gbifPortugueseNames, gbifVernacularNamesUrl } from './gbif';
import {
  commonsImageInfoUrl,
  p18FileNames,
  referencePhotoFromImageInfo,
  wikidataItemIds,
  wikidataP18Url,
  wikidataTaxonQueryUrl,
  type ReferencePhoto,
} from './photo';
import type { Discard, SeedSpecies } from './seed';

/** GET a URL and parse the JSON body. The real one caches on disk. */
export type { FetchJson };

export interface SeedResult {
  species: SeedSpecies[];
  discards: Discard[];
}

/** Tries the accepted name first, then the proposed one if it differs. */
function lookupNames(accepted: string, proposed: string): string[] {
  const trimmed = proposed.trim().replace(/\s+/g, ' ');
  return trimmed.toLowerCase() === accepted.toLowerCase()
    ? [accepted]
    : [accepted, trimmed];
}

async function findPhoto(
  names: string[],
  fetchJson: FetchJson,
): Promise<{ photo: ReferencePhoto } | { reasons: string[] }> {
  const reasons: string[] = [];
  for (const name of names) {
    const items = wikidataItemIds(await fetchJson(wikidataTaxonQueryUrl(name)));
    if (items.length === 0) reasons.push(`${name} sem item no Wikidata`);
    for (const item of items) {
      const files = p18FileNames(await fetchJson(wikidataP18Url(item)));
      if (files.length === 0) reasons.push(`${item} sem imagem (P18)`);
      for (const file of files) {
        const result = referencePhotoFromImageInfo(
          await fetchJson(commonsImageInfoUrl(file)),
        );
        if (result.ok) return { photo: result.photo };
        reasons.push(`${file}: ${result.reason}`);
      }
    }
  }
  return { reasons };
}

async function buildOne(
  proposed: string,
  fetchJson: FetchJson,
  seenKeys: Map<number, string>,
): Promise<SeedSpecies | Discard> {
  const discard = (reason: string): Discard => ({ name: proposed, reason });

  // The same GBIF resolution as the API's.
  const gbif = await new HttpGbifNames(fetchJson).resolve(proposed);
  if (!gbif.ok) return discard(gbif.reason);
  const duplicateOf = seenKeys.get(gbif.gbifKey);
  if (duplicateOf !== undefined) {
    return discard(
      `duplicada de ${duplicateOf} (gbifKey ${String(gbif.gbifKey)})`,
    );
  }
  const names = lookupNames(gbif.scientificName, proposed);
  let floraNames: string[] = [];
  for (const name of names) {
    floraNames = floraPortugueseNames(
      name,
      await fetchJson(floraTaxonUrl(name)),
    );
    if (floraNames.length > 0) break;
  }
  const gbifNames = gbifPortugueseNames(
    await fetchJson(gbifVernacularNamesUrl(gbif.gbifKey)),
  );
  const commonNames = splitCommonNames(floraNames, gbifNames);
  if (commonNames === null) return discard('sem nome popular (Flora e GBIF)');

  const photo = await findPhoto(names, fetchJson);
  if ('reasons' in photo) {
    return discard(`sem foto livre (${photo.reasons.join('; ')})`);
  }

  seenKeys.set(gbif.gbifKey, proposed);
  return {
    gbifKey: gbif.gbifKey,
    scientificName: gbif.scientificName,
    ...commonNames,
    referencePhoto: photo.photo,
  };
}

/**
 * Validates each proposed name in GBIF, then looks up its common names and a
 * free reference photo. Every name ends either in the seed or in the discards.
 */
export async function buildSeed(
  proposedNames: string[],
  fetchJson: FetchJson,
  onProgress: (name: string, index: number) => void = () => undefined,
): Promise<SeedResult> {
  const species: SeedSpecies[] = [];
  const discards: Discard[] = [];
  const seenKeys = new Map<number, string>();

  for (const [index, name] of proposedNames.entries()) {
    onProgress(name, index);
    try {
      const result = await buildOne(name, fetchJson, seenKeys);
      if ('reason' in result) discards.push(result);
      else species.push(result);
    } catch (error) {
      const message = messageOf(error);
      discards.push({ name, reason: `erro: ${message}` });
    }
  }
  return { species, discards };
}
