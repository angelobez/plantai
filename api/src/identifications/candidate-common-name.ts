/** The longest Pl@ntNet common name that still looks like a name. */
const MAX_LENGTH = 40;

/**
 * Whether [name] looks like a plant's name and not a note someone typed into
 * Pl@ntNet ("Fica maiorzinha, trocar de vazo…", "Dourados 1").
 */
function looksLikeName(name: string): boolean {
  return name.length > 0 && name.length <= MAX_LENGTH && !/[\d,.]/.test(name);
}

/**
 * Pl@ntNet sometimes turns the first hyphen of a name into a space
 * ("Costela de-adão"): the space before the first hyphenated word goes back
 * to a hyphen.
 */
function withFirstHyphen(name: string): string {
  return name.replace(/ (?=[^\s-]+-)/, '-');
}

/**
 * The common name a candidate shows when its species is not in the Catalog:
 * the first of Pl@ntNet's names that looks like a name, with its first hyphen
 * fixed; null when none does, and the app shows the scientific name.
 */
export function plausibleCommonName(names: readonly string[]): string | null {
  const name = names.map((raw) => raw.trim()).find(looksLikeName);
  return name === undefined ? null : withFirstHyphen(name);
}
