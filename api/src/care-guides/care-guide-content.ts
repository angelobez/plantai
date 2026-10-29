import { z } from 'zod';

const careTipSchema = z.object({
  summary: z
    .string()
    .trim()
    .min(1)
    .max(40)
    .describe('A short line, about 25 characters: "1x por semana"'),
  details: z.string().trim().min(1).max(1500).describe('The full tip'),
});

/**
 * The `content` of a care guide (`care_guides.content`): what Claude writes,
 * what the database keeps and what the responses show. The tool Claude
 * answers through is built from this same schema.
 */
export const careGuideContentSchema = z.object({
  commonName: z
    .string()
    .trim()
    .min(1)
    .max(80)
    .describe('The most used common name in Brazil'),
  watering: careTipSchema.describe('Rega'),
  light: careTipSchema.describe('Luz'),
  propagation: careTipSchema.describe('Como fazer muda'),
});

export type CareGuideContent = z.infer<typeof careGuideContentSchema>;
