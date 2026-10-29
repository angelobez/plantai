/** What the API keeps from a valid Google ID token. */
export interface GoogleIdentity {
  /** The Google account id; never changes, unlike the e-mail. */
  sub: string;
  email: string;
  emailVerified: boolean;
  name: string | undefined;
  /** The Google Workspace domain, only for Workspace accounts. */
  hd: string | undefined;
}

/**
 * The port for checking a Google ID token: signature, expiry, issuer and
 * audience (`GOOGLE_WEB_CLIENT_ID`). The real adapter uses
 * `google-auth-library`; tests swap in a fake that answers what they choose.
 *
 * An abstract class rather than an interface, so it doubles as the Nest
 * injection token.
 */
export abstract class GoogleTokenVerifier {
  /** The token's identity, or `undefined` if the token is not valid. */
  abstract verify(idToken: string): Promise<GoogleIdentity | undefined>;
}
