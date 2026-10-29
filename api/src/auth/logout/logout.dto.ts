import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export class LogoutRequest extends createZodDto(
  z.object({
    refreshToken: z
      .string()
      .min(1)
      .describe('The refresh token of the session to end'),
  }),
) {}
