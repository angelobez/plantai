import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const healthResponseSchema = z.object({
  status: z.literal('ok'),
  apiVersion: z.string().describe('Version of the API package'),
  postgisVersion: z.string().describe('Read from the database itself'),
});

export class HealthResponse extends createZodDto(healthResponseSchema) {}
