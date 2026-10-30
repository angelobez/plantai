import Anthropic from '@anthropic-ai/sdk';
import { transformJSONSchema } from '@anthropic-ai/sdk/lib/transform-json-schema';
import { z } from 'zod';
import type { Env } from '../config/env';
import { careGuideContentSchema } from './care-guide-content';
import {
  CareGuideNotWrittenError,
  type CareGuideRequest,
  CareGuideWriter,
  type WrittenCareGuide,
} from './care-guide-writer';

/** Bump it when the prompt or the tool changes. */
export const CARE_GUIDE_PROMPT_VERSION = 1;

const TOOL_NAME = 'record_care_guide';

/**
 * The tool Claude answers through. Its JSON Schema comes from the Zod one,
 * with the constraints strict tools do not take moved into the descriptions;
 * the Zod parse of the answer still checks them.
 */
const RECORD_CARE_GUIDE_TOOL: Anthropic.Beta.BetaTool = {
  name: TOOL_NAME,
  description: 'Records the care guide of the species.',
  input_schema: transformJSONSchema(
    z.toJSONSchema(careGuideContentSchema),
  ) as Anthropic.Beta.BetaTool.InputSchema,
  strict: true,
};

const SYSTEM_PROMPT = `Você escreve as dicas de cuidado do PlantAí, um app brasileiro para quem cuida de plantas em casa, no apartamento ou no quintal, e troca mudas com os vizinhos. Escreva em português do Brasil, com linguagem simples e prática, para quem não é especialista, pensando no clima e nas condições do Brasil.

Responda chamando a ferramenta ${TOOL_NAME} uma vez, sem texto fora dela.`;

function userPrompt({ scientificName, knownNames }: CareGuideRequest): string {
  const names = knownNames.length > 0 ? knownNames.join(', ') : 'nenhum';
  return `Espécie: ${scientificName}
Nomes populares que o app já conhece: ${names}

Preencha as dicas:
- commonName: o nome popular mais usado no Brasil para essa espécie, em minúsculas (a não ser que tenha nome próprio), como "costela-de-adão".
- watering (rega), light (luz) e propagation (como fazer muda): cada um com
  - summary: uma linha curta, de no máximo uns 25 caracteres, como "1x por semana", "Meia-sombra" ou "Estaca";
  - details: de 2 a 4 frases com o que fazer na prática.
- watering: de quanto em quanto tempo regar e como saber a hora.
- light: quanta luz ela quer e se aguenta sol direto.
- propagation: o jeito mais fácil de fazer muda para doar (estaca, divisão, semente…).`;
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/**
 * Writes the care guides with Claude (Anthropic SDK). The answer comes
 * through a strict tool and is validated by `careGuideContentSchema`; any
 * failure, an invalid answer included, is a {@link CareGuideNotWrittenError}.
 */
export class ClaudeCareGuideWriter extends CareGuideWriter {
  readonly promptVersion = CARE_GUIDE_PROMPT_VERSION;

  constructor(
    private readonly client: Anthropic,
    readonly model: string,
  ) {
    super();
  }

  async write(request: CareGuideRequest): Promise<WrittenCareGuide> {
    let response: Anthropic.Beta.BetaMessage;
    try {
      response = await this.client.beta.messages.create({
        model: this.model,
        max_tokens: 8000,
        // On a policy decline, the API retries on its recommended fallback.
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        // Someone is waiting on the screen; short tips need little thought.
        output_config: { effort: 'low' },
        system: SYSTEM_PROMPT,
        tools: [RECORD_CARE_GUIDE_TOOL],
        // Not a forced tool (`any` or `tool`): Sonnet 5.5 rejects that with a
        // 400. The system prompt asks for the tool, `strict` keeps its input
        // schema-valid, and a reply without it fails below.
        tool_choice: { type: 'auto' },
        messages: [{ role: 'user', content: userPrompt(request) }],
      });
    } catch (error) {
      throw new CareGuideNotWrittenError(
        `The Claude call failed: ${messageOf(error)}`,
        { cause: error },
      );
    }

    if (response.stop_reason === 'refusal') {
      throw new CareGuideNotWrittenError(
        `Claude refused (${response.stop_details?.category ?? 'no category'})`,
      );
    }
    if (response.stop_reason === 'max_tokens') {
      throw new CareGuideNotWrittenError(
        'The Claude answer was cut off (max_tokens)',
      );
    }
    const call = response.content.find(
      (block): block is Anthropic.Beta.BetaToolUseBlock =>
        block.type === 'tool_use' && block.name === TOOL_NAME,
    );
    if (!call) {
      throw new CareGuideNotWrittenError('Claude answered no care guide');
    }
    const parsed = careGuideContentSchema.safeParse(call.input);
    if (!parsed.success) {
      throw new CareGuideNotWrittenError(
        `Claude wrote an invalid care guide: ${parsed.error.message}`,
      );
    }
    return { content: parsed.data, model: response.model };
  }
}

/**
 * The timeout of one Claude call. With one retry, a generation ends well
 * before 60 s, when a `generating` row counts as abandoned.
 */
const CLAUDE_TIMEOUT_MS = 25_000;

export function createCareGuideWriter(env: Env): CareGuideWriter {
  return new ClaudeCareGuideWriter(
    new Anthropic({
      apiKey: env.ANTHROPIC_API_KEY,
      timeout: CLAUDE_TIMEOUT_MS,
      maxRetries: 1,
    }),
    env.CARE_GUIDE_MODEL,
  );
}
