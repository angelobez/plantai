import { join } from 'node:path';
import { readCatalogSeed } from '../../src/catalog/catalog-seed';
import { readSeedOverrides } from './overrides';

const CATALOG_DIR = join(__dirname, '..', '..', 'catalog');

describe('the checked-in seed overrides', () => {
  it('are all applied to the checked-in seed', async () => {
    const overrides = await readSeedOverrides(
      join(CATALOG_DIR, 'seed-overrides.json'),
    );
    const seed = await readCatalogSeed(join(CATALOG_DIR, 'catalog-seed.json'));

    for (const [scientificName, override] of Object.entries(overrides)) {
      const item = seed.find(
        (entry) => entry.scientificName === scientificName,
      );
      expect(item).toMatchObject({
        scientificName,
        commonName: override.commonName,
        otherNames: override.otherNames,
      });
      if (override.photoFile !== undefined) {
        expect(item?.referencePhoto.sourceUrl).toBe(
          `https://commons.wikimedia.org/wiki/File:${override.photoFile.replaceAll(' ', '_')}`,
        );
      }
    }
  });

  it('correct the costela-de-adão and the costela-de-eva', async () => {
    const seed = await readCatalogSeed(join(CATALOG_DIR, 'catalog-seed.json'));
    const byName = (name: string) =>
      seed.find((entry) => entry.scientificName === name);

    expect(byName('Monstera adansonii')).toMatchObject({
      gbifKey: 2868136,
      commonName: 'costela-de-eva',
      otherNames: ['costela-de-adão', 'monstera-adansonii'],
    });
    expect(byName('Monstera deliciosa')).toMatchObject({
      gbifKey: 2868241,
      commonName: 'costela-de-adão',
      otherNames: ['monstera'],
    });
  });
});
