import Anthropic from '@anthropic-ai/sdk';
import { z } from 'zod';

const MODEL = 'claude-sonnet-5-5';

const proposalSchema = z.object({
  species: z.array(z.object({ scientificName: z.string().min(1) })).min(1),
});

const PROMPT = `List about 110 plant species that are popular in Brazilian homes, balconies and backyards: houseplants, ornamentals, succulents and cacti, herbs and spices, and small fruit trees or vegetables people grow at home and give away as cuttings or seedlings.

Rules:
- One entry per species, never a genus, hybrid group or cultivar.
- Use the currently accepted binomial (genus and epithet), without author.
- Prefer species that people in Brazil actually know by a Portuguese common name.
- No duplicates.`;

/**
 * Asks Claude for the candidate species. Only the names come from Claude:
 * every one is still validated in GBIF, Flora and Commons.
 * ANTHROPIC_API_KEY comes from the script's environment, not from the API's.
 */
export async function proposeSpecies(): Promise<string[]> {
  const client = new Anthropic();
  const response = await client.beta.messages.create({
    model: MODEL,
    max_tokens: 16000,
    // On a policy decline, the API retries on its recommended fallback model.
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: {
      effort: 'medium',
      format: {
        type: 'json_schema',
        schema: {
          type: 'object',
          properties: {
            species: {
              type: 'array',
              items: {
                type: 'object',
                properties: { scientificName: { type: 'string' } },
                required: ['scientificName'],
                additionalProperties: false,
              },
            },
          },
          required: ['species'],
          additionalProperties: false,
        },
      },
    },
    messages: [{ role: 'user', content: PROMPT }],
  });

  if (response.stop_reason === 'refusal') {
    throw new Error(
      `Claude recusou o pedido (${response.stop_details?.category ?? 'sem categoria'})`,
    );
  }
  if (response.stop_reason === 'max_tokens') {
    throw new Error('A resposta do Claude foi cortada (max_tokens)');
  }
  const text = response.content
    .flatMap((block) => (block.type === 'text' ? [block.text] : []))
    .join('');
  return proposalSchema
    .parse(JSON.parse(text))
    .species.map((item) => item.scientificName);
}
