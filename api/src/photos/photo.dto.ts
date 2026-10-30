import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

/**
 * A User's photo as every response shows it: the URL is presigned when the
 * response is made and works until `expiresAt` (1 h). The app caches the
 * image by `id`, since the URL changes on every response.
 */
export const photoSchema = z.object({
  id: z.uuid(),
  url: z.url().describe('Presigned GET URL of the JPEG'),
  expiresAt: z.iso.datetime().describe('When the URL stops working'),
});

export type PhotoResponse = z.infer<typeof photoSchema>;

export class Photo extends createZodDto(photoSchema) {}
