import Anthropic from '@anthropic-ai/sdk';
import { betaZodOutputFormat } from '@anthropic-ai/sdk/helpers/beta/zod';
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
      // The JSON schema comes from the Zod one, without the constraints
      // structured outputs do not take; the parse below still checks them.
      format: betaZodOutputFormat(proposalSchema),
    },
    messages: [{ role: 'user', content: PROMPT }],
  });

  if (response.stop_reason === 'refusal') {
    throw new Error(
      `Claude refused the request (${response.stop_details?.category ?? 'no category'})`,
    );
  }
  if (response.stop_reason === 'max_tokens') {
    throw new Error('The Claude response was cut off (max_tokens)');
  }
  const text = response.content
    .flatMap((block) => (block.type === 'text' ? [block.text] : []))
    .join('');
  return proposalSchema
    .parse(JSON.parse(text))
    .species.map((item) => item.scientificName);
}
