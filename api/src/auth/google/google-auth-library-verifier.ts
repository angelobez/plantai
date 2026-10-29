import { Logger } from '@nestjs/common';
import { OAuth2Client } from 'google-auth-library';
import type { Env } from '../../config/env';
import {
  type GoogleIdentity,
  GoogleTokenVerifier,
} from './google-token-verifier';

/**
 * Checks the ID token with `google-auth-library`: Google's signature (the
 * certificates are fetched and cached by the client), expiry, issuer and
 * audience = the Web client.
 */
export class GoogleAuthLibraryVerifier extends GoogleTokenVerifier {
  private readonly logger = new Logger(GoogleAuthLibraryVerifier.name);
  private readonly client = new OAuth2Client();

  constructor(private readonly audience: string) {
    super();
  }

  async verify(idToken: string): Promise<GoogleIdentity | undefined> {
    let payload;
    try {
      const ticket = await this.client.verifyIdToken({
        idToken,
        audience: this.audience,
      });
      payload = ticket.getPayload();
    } catch (error) {
      // Only the reason, cut before the first colon: the library appends the
      // token or its payload (with the e-mail) after it.
      const reason =
        error instanceof Error ? error.message.split(/[:\n]/)[0] : undefined;
      this.logger.warn(`Google ID token rejected: ${reason ?? 'unknown'}`);
      return undefined;
    }
    if (!payload?.email) return undefined;
    return {
      sub: payload.sub,
      email: payload.email,
      emailVerified: payload.email_verified === true,
      name: payload.name,
      hd: payload.hd,
    };
  }
}

export function createGoogleTokenVerifier(env: Env): GoogleTokenVerifier {
  return new GoogleAuthLibraryVerifier(env.GOOGLE_WEB_CLIENT_ID);
}
