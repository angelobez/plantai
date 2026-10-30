import { fixture } from './__fixtures__/fixture';
import { floraTaxonUrl } from './common-names';
import { gbifMatchUrl, gbifVernacularNamesUrl } from './gbif';
import {
  commonsImageInfoUrl,
  wikidataP18Url,
  wikidataTaxonQueryUrl,
} from './photo';
import { buildSeed, type FetchJson } from './pipeline';

/**
 * Serves recorded responses by URL. The Wikidata and Commons answers were
 * recorded for the jiboia and stand in for the sansevieria's here.
 */
function fakeFetch(responses: Record<string, string | object>): FetchJson {
  return (url) => {
    const response = responses[url];
    if (response === undefined) {
      return Promise.reject(new Error(`unexpected ${url}`));
    }
    return Promise.resolve(
      typeof response === 'string' ? fixture(response) : response,
    );
  };
}

const sansevieria = {
  [gbifMatchUrl('Sansevieria trifasciata')]: 'gbif-match-synonym.json',
  [floraTaxonUrl('Dracaena trifasciata')]: 'flora-dracaena-trifasciata.json',
  [gbifVernacularNamesUrl(11041822)]:
    'gbif-vernacular-dracaena-trifasciata.json',
  [wikidataTaxonQueryUrl('Dracaena trifasciata')]:
    'wikidata-taxon-epipremnum-aureum.json',
  [wikidataP18Url('Q161809')]: 'wikidata-p18-q161809.json',
  [commonsImageInfoUrl('Epipremnum aureum 31082012.jpg')]:
    'commons-imageinfo-epipremnum-aureum.json',
};

describe('buildSeed', () => {
  it('turns a synonym into an item under the accepted name', async () => {
    const result = await buildSeed(
      ['Sansevieria trifasciata'],
      fakeFetch(sansevieria),
    );

    expect(result.discards).toEqual([]);
    expect(result.species).toEqual([
      {
        gbifKey: 11041822,
        scientificName: 'Dracaena trifasciata',
        commonName: 'espada-de-são-jorge',
        otherNames: [
          'língua-de-sogra',
          'sanseviéria',
          'rabo-de-lagarto',
          'espadinha',
        ],
        referencePhoto: {
          sourceUrl:
            'https://commons.wikimedia.org/wiki/File:Epipremnum_aureum_31082012.jpg',
          imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/9/9d/Epipremnum_aureum_31082012.jpg',
          author: 'Joydeep',
          license: 'CC BY-SA 3.0',
        },
      },
    ]);
  });

  it('reports every name it leaves out and why', async () => {
    const result = await buildSeed(
      [
        'Monstera deliciosaa',
        'Sansevieria trifasciata',
        'Sansevieria trifasciata',
      ],
      fakeFetch({
        ...sansevieria,
        [gbifMatchUrl('Monstera deliciosaa')]: 'gbif-match-none.json',
      }),
    );

    expect(result.species).toHaveLength(1);
    expect(result.discards).toEqual([
      { name: 'Monstera deliciosaa', reason: 'GBIF: sem match exato (NONE)' },
      {
        name: 'Sansevieria trifasciata',
        reason: 'duplicada de Sansevieria trifasciata (gbifKey 11041822)',
      },
    ]);
  });

  it('discards a species without a free photo', async () => {
    const noItem = { results: { bindings: [] } };
    const result = await buildSeed(
      ['Sansevieria trifasciata'],
      fakeFetch({
        ...sansevieria,
        [wikidataTaxonQueryUrl('Dracaena trifasciata')]: noItem,
        [wikidataTaxonQueryUrl('Sansevieria trifasciata')]: noItem,
      }),
    );

    expect(result.species).toEqual([]);
    expect(result.discards).toEqual([
      {
        name: 'Sansevieria trifasciata',
        reason:
          'sem foto livre (Dracaena trifasciata sem item no Wikidata; Sansevieria trifasciata sem item no Wikidata)',
      },
    ]);
  });

  describe('with an override for the accepted name', () => {
    it('takes its names instead of Flora and GBIF ones', async () => {
      const result = await buildSeed(
        ['Sansevieria trifasciata'],
        fakeFetch(sansevieria),
        {
          overrides: {
            'Dracaena trifasciata': {
              commonName: 'espada-de-ogum',
              otherNames: ['espada-de-são-jorge'],
            },
          },
        },
      );

      expect(result.discards).toEqual([]);
      expect(result.species).toEqual([
        expect.objectContaining({
          scientificName: 'Dracaena trifasciata',
          commonName: 'espada-de-ogum',
          otherNames: ['espada-de-são-jorge'],
        }),
      ]);
    });

    it('takes the photo from its Commons file instead of Wikidata', async () => {
      const result = await buildSeed(
        ['Sansevieria trifasciata'],
        fakeFetch({
          [gbifMatchUrl('Sansevieria trifasciata')]: 'gbif-match-synonym.json',
          [commonsImageInfoUrl('Epipremnum aureum 31082012.jpg')]:
            'commons-imageinfo-epipremnum-aureum.json',
        }),
        {
          overrides: {
            'Dracaena trifasciata': {
              commonName: 'espada-de-são-jorge',
              otherNames: [],
              photoFile: 'Epipremnum aureum 31082012.jpg',
            },
          },
        },
      );

      expect(result.discards).toEqual([]);
      expect(result.species[0]?.referencePhoto).toEqual({
        sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Epipremnum_aureum_31082012.jpg',
        imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/9/9d/Epipremnum_aureum_31082012.jpg',
        author: 'Joydeep',
        license: 'CC BY-SA 3.0',
      });
    });

    it('discards the species when its Commons file is not free', async () => {
      const result = await buildSeed(
        ['Sansevieria trifasciata'],
        fakeFetch({
          [gbifMatchUrl('Sansevieria trifasciata')]: 'gbif-match-synonym.json',
          [commonsImageInfoUrl('Missing.jpg')]: {
            query: { pages: [{ missing: true }] },
          },
        }),
        {
          overrides: {
            'Dracaena trifasciata': {
              commonName: 'espada-de-são-jorge',
              otherNames: [],
              photoFile: 'Missing.jpg',
            },
          },
        },
      );

      expect(result.discards).toEqual([
        {
          name: 'Sansevieria trifasciata',
          reason: 'sem foto livre (Missing.jpg: arquivo não encontrado)',
        },
      ]);
    });
  });

  it('keeps going when a source fails, and reports the error', async () => {
    const result = await buildSeed(['Ficus lyrata'], fakeFetch({}));
    expect(result.discards).toEqual([
      {
        name: 'Ficus lyrata',
        reason: `erro: unexpected ${gbifMatchUrl('Ficus lyrata')}`,
      },
    ]);
  });
});
