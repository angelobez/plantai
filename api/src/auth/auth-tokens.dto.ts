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
