import argon2 from 'argon2';
import { createHash, randomBytes, randomInt } from 'node:crypto';

// Hashing for what the User knows (password, e-mail code) and for the opaque
// refresh token. None of these values is ever stored or logged in the clear.

/** argon2id, for passwords and e-mail codes. */
export function hashSecret(secret: string): Promise<string> {
  return argon2.hash(secret, { type: argon2.argon2id });
}

/** Whether [secret] matches a {@link hashSecret} hash. */
export function verifySecret(hash: string, secret: string): Promise<boolean> {
  return argon2.verify(hash, secret);
}

/** A random 6-digit code, such as `042137`. */
export function newEmailCode(): string {
  return String(randomInt(0, 1_000_000)).padStart(6, '0');
}

/** A random opaque token (256 bits, base64url). */
export function newOpaqueToken(): string {
  return randomBytes(32).toString('base64url');
}

/**
 * SHA-256 of an opaque token. Enough for 256 random bits, and deterministic,
 * so the token can be looked up by its hash.
 */
export function hashOpaqueToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
