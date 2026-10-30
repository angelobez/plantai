import { plausibleCommonName } from './candidate-common-name';

// Names from the Pl@ntNet test (docs/research/teste-plantnet.md).
describe('plausibleCommonName', () => {
  it('takes the first name', () => {
    expect(plausibleCommonName(['Jibóia', 'Jiboia verde'])).toBe('Jibóia');
  });

  it.each([
    ['Costela de-adão', 'Costela-de-adão'],
    ['Espada de-são-jorge', 'Espada-de-são-jorge'],
    ['Hera do-diabo', 'Hera-do-diabo'],
    ['Mini espada de-são-jorge', 'Mini espada-de-são-jorge'],
  ])('puts back the hyphen Pl@ntNet turned into a space: %s', (raw, fixed) => {
    expect(plausibleCommonName([raw])).toBe(fixed);
  });

  it.each([
    'Jiboia verde',
    'Costela-de-adão',
    'Mini espada de são Jorge',
    'Filodendro Sanguíneo',
  ])('keeps a name with nothing to fix: %s', (name) => {
    expect(plausibleCommonName([name])).toBe(name);
  });

  it.each([
    ['a digit', 'Dourados 1'],
    ['a comma', 'Fica maiorzinha, trocar de vazo'],
    ['a period', 'Planta da vó.'],
    ['more than 40 characters', 'Planta bonita que ganhei da minha vizinha'],
    ['nothing but spaces', '   '],
  ])('skips a name with %s and takes the next', (_case, bad) => {
    expect(plausibleCommonName([bad, 'Hortelã'])).toBe('Hortelã');
  });

  it('accepts a name of exactly 40 characters', () => {
    const name = 'a'.repeat(40);

    expect(plausibleCommonName([name])).toBe(name);
  });

  it('trims the name', () => {
    expect(plausibleCommonName(['  Babosa '])).toBe('Babosa');
  });

  it('is null when no name passes', () => {
    expect(plausibleCommonName(['Dourados 1', 'Sei lá, achei na rua'])).toBe(
      null,
    );
    expect(plausibleCommonName([])).toBe(null);
  });
});
