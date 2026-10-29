import type {
  GoogleIdentity,
  GoogleTokenVerifier,
} from '../../src/auth/google/google-token-verifier';

let tokens = 0;

/**
 * Stands in for Google: a test hands out an ID token for the identity it
 * wants, and the API gets that identity back when it verifies the token. Any
 * other token is invalid.
 */
export class FakeGoogleVerifier implements GoogleTokenVerifier {
  private readonly identities = new Map<string, GoogleIdentity>();

  /** An ID token that verifies to [identity]. */
  tokenFor(identity: GoogleIdentity): string {
    tokens += 1;
    const token = `fake-google-id-token-${String(tokens)}`;
    this.identities.set(token, identity);
    return token;
  }

  verify(idToken: string): Promise<GoogleIdentity | undefined> {
    return Promise.resolve(this.identities.get(idToken));
  }
}

let identities = 0;

/**
 * A Google identity for one test: a unique `sub` and `@gmail.com` e-mail,
 * verified and with a name. Pass [overrides] for what the test is about.
 */
export function googleIdentity(
  overrides: Partial<GoogleIdentity> = {},
): GoogleIdentity {
  identities += 1;
  const id = `${String(identities)}${String(Date.now())}`;
  return {
    sub: `1${id}`,
    email: `google${id}@gmail.com`,
    emailVerified: true,
    name: 'Marina Souza',
    hd: undefined,
    ...overrides,
  };
}
