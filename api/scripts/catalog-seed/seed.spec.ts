import { join } from 'node:path';
import { formatDiscardReport, serializeSeed, type SeedSpecies } from './seed';

const photo = {
  sourceUrl: 'https://commons.wikimedia.org/wiki/File:A.jpg',
  imageUrl: 'https://upload.wikimedia.org/a.jpg',
  author: 'Ana',
  license: 'CC0',
};

const item = (scientificName: string, gbifKey: number): SeedSpecies => ({
  referencePhoto: photo,
  otherNames: [],
  commonName: scientificName.toLowerCase(),
  scientificName,
  gbifKey,
});

describe('serializeSeed', () => {
  const output = join(__dirname, '..', '..', 'catalog', 'catalog-seed.json');

  it('sorts the items by scientific name with a fixed key order', async () => {
    const json = await serializeSeed(
      [item('Monstera deliciosa', 2), item('Aloe vera', 1)],
      output,
    );
    const parsed = JSON.parse(json) as SeedSpecies[];

    expect(parsed.map((species) => species.scientificName)).toEqual([
      'Aloe vera',
      'Monstera deliciosa',
    ]);
    expect(Object.keys(parsed[0] ?? {})).toEqual([
      'gbifKey',
      'scientificName',
      'commonName',
      'otherNames',
      'referencePhoto',
    ]);
    expect(Object.keys(parsed[0]?.referencePhoto ?? {})).toEqual([
      'sourceUrl',
      'imageUrl',
      'author',
      'license',
    ]);
  });

  it('gives the same text for the same species in any order', async () => {
    const a = await serializeSeed([item('B b', 2), item('A a', 1)], output);
    const b = await serializeSeed([item('A a', 1), item('B b', 2)], output);
    expect(a).toBe(b);
    expect(a.endsWith(']\n')).toBe(true);
  });
});

describe('formatDiscardReport', () => {
  it('lists each discarded name with its reason', () => {
    expect(
      formatDiscardReport([
        { name: 'Monstera', reason: 'GBIF: não é espécie (GENUS)' },
        { name: 'Aloe x', reason: 'GBIF: sem match exato (NONE)' },
      ]),
    ).toBe(
      [
        'Descartes (2):',
        '  - Monstera: GBIF: não é espécie (GENUS)',
        '  - Aloe x: GBIF: sem match exato (NONE)',
      ].join('\n'),
    );
  });
});
