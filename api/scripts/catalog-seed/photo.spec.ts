import { fixture, fixtureObject } from './__fixtures__/fixture';
import {
  acceptLicense,
  cleanArtist,
  p18FileNames,
  referencePhotoFromImageInfo,
  wikidataItemIds,
} from './photo';

describe('acceptLicense', () => {
  it.each([
    ['cc0', 'CC0'],
    ['pd', 'Public domain'],
    ['cc-by-4.0', 'CC BY 4.0'],
    ['cc-by-sa-3.0', 'CC BY-SA 3.0'],
    ['cc-by-sa-3.0-de', 'CC BY-SA 3.0 de'],
    ['cc-by-2.0', 'CC BY 2.0'],
  ])('accepts %s', (license, shortName) => {
    expect(acceptLicense(license, shortName)).toBe(true);
  });

  it.each([
    ['cc-by-nc-sa-4.0', 'CC BY-NC-SA 4.0'],
    ['cc-by-nc-4.0', 'CC BY-NC 4.0'],
    ['cc-by-nd-4.0', 'CC BY-ND 4.0'],
    ['gfdl', 'GFDL'],
    ['', 'Attribution'],
    [undefined, 'CC BY-SA 4.0'],
  ])('refuses %s', (license, shortName) => {
    expect(acceptLicense(license, shortName)).toBe(false);
  });
});

describe('cleanArtist', () => {
  it('turns the HTML of the Artist field into plain text', () => {
    expect(
      cleanArtist(
        '<p><a href="//commons.wikimedia.org/wiki/User:Joydeep" title="User:Joydeep">Joydeep</a>\n</p>',
      ),
    ).toBe('Joydeep');
  });

  it('decodes entities and collapses spaces', () => {
    expect(cleanArtist('Jos&eacute;  &amp; <b>Ana</b>&#39;s')).toBe(
      "José & Ana's",
    );
  });
});

describe('wikidataItemIds', () => {
  it('lists the items that carry the taxon name', () => {
    expect(
      wikidataItemIds(fixture('wikidata-taxon-epipremnum-aureum.json')),
    ).toEqual(['Q161809']);
  });

  it('sorts the items by number, so the oldest comes first', () => {
    const uri = (id: string) => ({
      item: { type: 'uri', value: `http://www.wikidata.org/entity/${id}` },
    });
    expect(
      wikidataItemIds({
        results: { bindings: [uri('Q900'), uri('Q12'), uri('Q100')] },
      }),
    ).toEqual(['Q12', 'Q100', 'Q900']);
  });
});

describe('p18FileNames', () => {
  it('keeps the order of the image claims', () => {
    expect(p18FileNames(fixture('wikidata-p18-q161809.json'))).toEqual([
      'Epipremnum aureum 31082012.jpg',
      'Epipremnum pinnatum var.jpg',
      'Epipremnum aurem flower.png',
    ]);
  });

  it('puts preferred claims first and drops deprecated ones', () => {
    const claim = (rank: string, value: string) => ({
      rank,
      mainsnak: { datavalue: { value } },
    });
    expect(
      p18FileNames({
        claims: {
          P18: [
            claim('normal', 'a.jpg'),
            claim('deprecated', 'b.jpg'),
            claim('preferred', 'c.jpg'),
          ],
        },
      }),
    ).toEqual(['c.jpg', 'a.jpg']);
  });

  it('returns nothing for an item without image', () => {
    expect(p18FileNames({ claims: {} })).toEqual([]);
  });
});

describe('referencePhotoFromImageInfo', () => {
  const imageInfo = fixtureObject('commons-imageinfo-epipremnum-aureum.json');

  it('builds the credited photo of a free file', () => {
    expect(referencePhotoFromImageInfo(imageInfo)).toEqual({
      ok: true,
      photo: {
        sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Epipremnum_aureum_31082012.jpg',
        imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/9/9d/Epipremnum_aureum_31082012.jpg',
        author: 'Joydeep',
        license: 'CC BY-SA 3.0',
      },
    });
  });

  it('refuses a file whose license is not free enough', () => {
    const nonCommercial = JSON.parse(
      JSON.stringify(imageInfo).replace('"cc-by-sa-3.0"', '"cc-by-nc-sa-3.0"'),
    ) as unknown;
    expect(referencePhotoFromImageInfo(nonCommercial)).toEqual({
      ok: false,
      reason: 'licença recusada (cc-by-nc-sa-3.0)',
    });
  });

  it('refuses a file without author', () => {
    const anonymous = JSON.parse(
      JSON.stringify(imageInfo).replace(/"Artist":\{[^}]*\},/, ''),
    ) as unknown;
    expect(JSON.stringify(anonymous)).not.toContain('Artist');
    expect(referencePhotoFromImageInfo(anonymous)).toEqual({
      ok: false,
      reason: 'sem autor',
    });
  });

  it('refuses a file that does not exist on Commons', () => {
    expect(
      referencePhotoFromImageInfo({
        query: { pages: [{ title: 'File:Nada.jpg', missing: true }] },
      }),
    ).toEqual({ ok: false, reason: 'arquivo não encontrado' });
  });
});
