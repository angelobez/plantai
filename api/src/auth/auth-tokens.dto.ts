import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import { userProfileSchema } from '../profile/user-profile.dto';

/** The answer of every route that signs the User in. */
export const authTokensSchema = z.object({
  accessToken: z
    .string()
    .describe('JWT for `Authorization: Bearer`; lasts 15 minutes'),
  refreshToken: z
    .string()
    .describe('Opaque; renews the session at POST /auth/refresh for 30 days'),
  user: userProfileSchema,
});

export class AuthTokens extends createZodDto(authTokensSchema) {}

// Fields every auth body validates the same way, so the routes agree.

/** citext in the database: the case does not matter. */
export const emailField = z.email().max(254);

/** At least 8 characters, no composition rule. */
export const passwordField = z.string().min(8).max(128);

export const emailCodeField = z
  .string()
  .regex(/^\d{6}$/, 'must be 6 digits')
  .describe('The 6-digit code from the e-mail');
