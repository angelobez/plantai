import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/** Loads a recorded API response from this folder. */
export function fixture(name: string): unknown {
  return JSON.parse(readFileSync(join(__dirname, name), 'utf8'));
}

/** A recorded response as an object, to derive variants with a spread. */
export function fixtureObject(name: string): Record<string, unknown> {
  return fixture(name) as Record<string, unknown>;
}
