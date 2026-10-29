import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export class UpdateProfileRequest extends createZodDto(
  z.object({
    name: z
      .string()
      .trim()
      .min(1)
      .max(80)
      .describe('Neighbors see only the first name in the listings'),
  }),
) {}
