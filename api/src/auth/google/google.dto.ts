import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export class GoogleRequest extends createZodDto(
  z.object({
    idToken: z
      .string()
      .min(1)
      .describe(
        'The ID token from Google Sign-In, issued for the Web client (GOOGLE_WEB_CLIENT_ID)',
      ),
  }),
) {}
