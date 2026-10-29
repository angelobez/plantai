import { fixture } from './__fixtures__/fixture';
import { floraPortugueseNames, splitCommonNames } from './common-names';

describe('floraPortugueseNames', () => {
  it('reads the names of the species entry, in the order Flora lists them', () => {
    expect(
      floraPortugueseNames(
        'Dracaena trifasciata',
        fixture('flora-dracaena-trifasciata.json'),
      ),
    ).toEqual([
      'espada-de-são-jorge',
      'língua-de-sogra',
      'sanseviéria',
      'rabo-de-lagarto',
      'espadinha',
    ]);
  });

  it('ignores the infraspecific entries that come with the species', () => {
    // The response also has "Sansevieria trifasciata var. laurentii".
    expect(
      floraPortugueseNames(
        'Sansevieria trifasciata',
        fixture('flora-sansevieria-trifasciata.json'),
      ),
    ).toEqual(['sanseveria', 'língua-de-sogra', 'espada-de-são-jorge']);
  });

  it('returns nothing when Flora does not know the name', () => {
    expect(
      floraPortugueseNames(
        'Foobarus inexistens',
        fixture('flora-not-found.json'),
      ),
    ).toEqual([]);
  });
});

describe('splitCommonNames', () => {
  it('makes the first Flora name the main one and keeps the rest as others', () => {
    expect(
      splitCommonNames(['jiboia-verde', 'jiboia', 'pothos'], ['hera-do-diabo']),
    ).toEqual({ commonName: 'jiboia-verde', otherNames: ['jiboia', 'pothos'] });
  });

  it('falls back to the GBIF names when Flora has none', () => {
    expect(splitCommonNames([], ['espada-de-são-jorge', 'espadinha'])).toEqual({
      commonName: 'espada-de-são-jorge',
      otherNames: ['espadinha'],
    });
  });

  it('drops blanks and repeated names, ignoring case and spaces', () => {
    expect(splitCommonNames([' Jiboia ', 'jiboia', '', 'jibóia'], [])).toEqual({
      commonName: 'Jiboia',
      otherNames: ['jibóia'],
    });
  });

  it('returns null when no source has a name', () => {
    expect(splitCommonNames([], [' '])).toBeNull();
  });
});
