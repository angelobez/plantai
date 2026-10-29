import { fixture } from '../../scripts/catalog-seed/__fixtures__/fixture';
import { gbifMatchUrl } from './gbif-match';
import { GbifUnavailableError } from './gbif-names';
import { HttpGbifNames } from './http-gbif-names';

/** Serves one recorded `species/match` answer per name. */
function gbifAnswering(answers: Record<string, string>): HttpGbifNames {
  return new HttpGbifNames((url) => {
    const entry = Object.entries(answers).find(
      ([name]) => gbifMatchUrl(name) === url,
    );
    return entry
      ? Promise.resolve(fixture(entry[1]))
      : Promise.reject(new Error(`unexpected ${url}`));
  });
}

describe('HttpGbifNames', () => {
  it('resolves an accepted name to its gbifKey', async () => {
    const gbif = gbifAnswering({
      'Epipremnum aureum': 'gbif-match-accepted.json',
    });

    expect(await gbif.resolve('Epipremnum aureum')).toEqual({
      ok: true,
      gbifKey: 2868323,
      scientificName: 'Epipremnum aureum',
    });
  });

  it('resolves a synonym to the accepted species', async () => {
    const gbif = gbifAnswering({
      'Sansevieria trifasciata': 'gbif-match-synonym.json',
    });

    expect(await gbif.resolve('Sansevieria trifasciata')).toMatchObject({
      ok: true,
      gbifKey: 11041822,
    });
  });

  it('resolves nothing for a genus', async () => {
    const gbif = gbifAnswering({ Monstera: 'gbif-match-genus.json' });

    expect(await gbif.resolve('Monstera')).toMatchObject({ ok: false });
  });

  it('fails as unavailable when GBIF cannot be reached', async () => {
    await expect(
      gbifAnswering({}).resolve('Epipremnum aureum'),
    ).rejects.toBeInstanceOf(GbifUnavailableError);
  });

  it('fails as unavailable when GBIF answers something else', async () => {
    const gbif = new HttpGbifNames(() => Promise.resolve({ foo: 1 }));

    await expect(gbif.resolve('Epipremnum aureum')).rejects.toBeInstanceOf(
      GbifUnavailableError,
    );
  });
});
