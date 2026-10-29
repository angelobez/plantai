import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

/** The opaque refresh token, as some answer with tokens sent it. */
export const refreshTokenField = z
  .string()
  .min(1)
  .max(256)
  .describe('The refresh token from the last answer with tokens');

export class RefreshRequest extends createZodDto(
  z.object({ refreshToken: refreshTokenField }),
) {}
