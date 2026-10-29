import { fixture, fixtureObject } from './__fixtures__/fixture';
import { gbifPortugueseNames, resolveGbifMatch } from './gbif';

const accepted = fixtureObject('gbif-match-accepted.json');
const synonym = fixtureObject('gbif-match-synonym.json');

describe('resolveGbifMatch', () => {
  it('keeps an accepted species with its usage key', () => {
    expect(resolveGbifMatch('Epipremnum aureum', accepted)).toEqual({
      ok: true,
      gbifKey: 2868323,
      scientificName: 'Epipremnum aureum',
    });
  });

  it('swaps a synonym for the accepted species', () => {
    expect(resolveGbifMatch('Sansevieria trifasciata', synonym)).toEqual({
      ok: true,
      gbifKey: 11041822,
      scientificName: 'Dracaena trifasciata',
    });
  });

  it('discards a name without an exact match', () => {
    expect(
      resolveGbifMatch('Monstera deliciosaa', fixture('gbif-match-none.json')),
    ).toEqual({ ok: false, reason: 'GBIF: sem match exato (NONE)' });
  });

  it('discards a match that is not a species', () => {
    expect(
      resolveGbifMatch('Monstera', fixture('gbif-match-genus.json')),
    ).toEqual({ ok: false, reason: 'GBIF: não é espécie (GENUS)' });
  });

  it('discards an exact match whose name differs from the proposed one', () => {
    expect(resolveGbifMatch('Epipremnum pinnatum', accepted)).toEqual({
      ok: false,
      reason: 'GBIF: o match é outro nome (Epipremnum aureum)',
    });
  });

  it('ignores case and extra spaces when comparing the names', () => {
    expect(resolveGbifMatch(' epipremnum  aureum ', accepted)).toMatchObject({
      ok: true,
    });
  });

  it('discards a doubtful name for the review to decide', () => {
    expect(
      resolveGbifMatch('Epipremnum aureum', {
        ...accepted,
        status: 'DOUBTFUL',
      }),
    ).toEqual({ ok: false, reason: 'GBIF: status DOUBTFUL' });
  });

  it('discards a synonym whose accepted name is not a species', () => {
    expect(
      resolveGbifMatch('Sansevieria trifasciata', {
        ...synonym,
        acceptedUsageKey: 123,
      }),
    ).toEqual({
      ok: false,
      reason: 'GBIF: nome aceito não é espécie (123)',
    });
  });

  it('rejects a response that is not a GBIF match', () => {
    expect(() => resolveGbifMatch('Epipremnum aureum', { foo: 1 })).toThrow();
  });
});

describe('gbifPortugueseNames', () => {
  it('keeps only the Portuguese names, in the order GBIF lists them', () => {
    expect(
      gbifPortugueseNames(fixture('gbif-vernacular-dracaena-trifasciata.json')),
    ).toEqual([
      'espada-de-são-jorge',
      'espadinha',
      'língua-de-sogra',
      'rabo-de-lagarto',
      'sanseviéria',
    ]);
  });

  it('returns nothing when GBIF has no Portuguese name', () => {
    expect(
      gbifPortugueseNames({
        results: [{ vernacularName: 'snake plant', language: 'eng' }],
      }),
    ).toEqual([]);
  });
});
