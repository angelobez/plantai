import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

/**
 * `POST /listings/:id/interest`: the only answer of the API with the donor's
 * phone, already as the WhatsApp link (ADR 0007).
 */
export const interestResponseSchema = z.object({
  whatsappUrl: z
    .url()
    .describe(
      'https://wa.me/<the donor’s E.164 phone without +>?text=<the ready message, encoded>',
    ),
});

export type InterestResponse = z.infer<typeof interestResponseSchema>;

export class Interest extends createZodDto(interestResponseSchema) {}
