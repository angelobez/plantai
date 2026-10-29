import semver from 'semver';

/**
 * Whether `value` is written exactly as a semantic version (`1.2.3`,
 * `1.2.3-beta.1`, `1.2.3+7`). The `semver` parser also accepts a leading `v`
 * or `=` and surrounding spaces; the API contract does not, so the parsed
 * version must spell back to the original text.
 */
export function isSemanticVersion(value: string): boolean {
  const parsed = semver.parse(value);
  if (parsed === null) return false;

  const build = parsed.build.length > 0 ? `+${parsed.build.join('.')}` : '';
  return `${parsed.version}${build}` === value;
}
