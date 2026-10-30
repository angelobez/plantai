import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import Anthropic from '@anthropic-ai/sdk';
import {
  CARE_GUIDE_PROMPT_VERSION,
  ClaudeCareGuideWriter,
} from './claude-care-guide-writer';
import { CareGuideNotWrittenError } from './care-guide-writer';

/** A Messages API answer, in the shape the API sends it. */
function fixture(name: string): Record<string, unknown> {
  return JSON.parse(
    readFileSync(join(__dirname, '__fixtures__', name), 'utf8'),
  ) as Record<string, unknown>;
}

interface SentRequest {
  url: string;
  body: Record<string, unknown>;
  headers: Headers;
}

/** A writer whose SDK client gets [answer] from a fake `fetch`. */
function writerAnswering(
  answer: Record<string, unknown>,
  status = 200,
): { writer: ClaudeCareGuideWriter; sent: SentRequest[] } {
  const sent: SentRequest[] = [];
  const fetch = (input: string | URL | Request, init?: RequestInit) => {
    sent.push({
      url: input instanceof Request ? input.url : input.toString(),
      body: JSON.parse(
        typeof init?.body === 'string' ? init.body : '{}',
      ) as Record<string, unknown>,
      headers: new Headers(init?.headers),
    });
    return Promise.resolve(
      new Response(JSON.stringify(answer), {
        status,
        headers: { 'content-type': 'application/json' },
      }),
    );
  };
  const client = new Anthropic({ apiKey: 'test-key', fetch, maxRetries: 0 });
  return {
    writer: new ClaudeCareGuideWriter(client, 'claude-sonnet-5-5'),
    sent,
  };
}

const monstera = {
  scientificName: 'Monstera deliciosa',
  knownNames: ['costela-de-adão', 'banana-de-macaco'],
};

describe('ClaudeCareGuideWriter', () => {
  it('returns the care guide Claude recorded through the tool', async () => {
    const { writer } = writerAnswering(fixture('claude-care-guide-valid.json'));

    await expect(writer.write(monstera)).resolves.toEqual({
      model: 'claude-sonnet-5-5',
      content: {
        commonName: 'costela-de-adão',
        watering: {
          summary: '1x por semana',
          details: expect.stringContaining('2 a 3 cm') as unknown,
        },
        light: {
          summary: 'Meia-sombra',
          details: expect.stringContaining('sem sol direto') as unknown,
        },
        propagation: {
          summary: 'Estaca',
          details: expect.stringContaining('raiz aérea') as unknown,
        },
      },
    });
  });

  it('asks the configured model, in Portuguese, through a strict tool built from the Zod schema', async () => {
    const { writer, sent } = writerAnswering(
      fixture('claude-care-guide-valid.json'),
    );

    await writer.write(monstera);

    expect(sent).toHaveLength(1);
    const [{ body, url }] = sent as [SentRequest];
    expect(url).toContain('/v1/messages');
    expect(body.model).toBe('claude-sonnet-5-5');
    expect(body.tool_choice).toEqual({ type: 'auto' });
    expect(body.tools).toEqual([
      expect.objectContaining({
        name: 'record_care_guide',
        strict: true,
        input_schema: expect.objectContaining({
          type: 'object',
          additionalProperties: false,
          required: ['commonName', 'watering', 'light', 'propagation'],
        }) as unknown,
      }),
    ]);
    const prompt = JSON.stringify([body.system, body.messages]);
    expect(prompt).toContain('Monstera deliciosa');
    expect(prompt).toContain('costela-de-adão, banana-de-macaco');
    expect(prompt).toContain('português do Brasil');
    expect(prompt).toContain('apartamento');
    expect(prompt).toContain('25 caracteres');
    expect(CARE_GUIDE_PROMPT_VERSION).toBe(2);
    expect(writer.promptVersion).toBe(2);
    expect(writer.model).toBe('claude-sonnet-5-5');
  });

  it('asks Claude to keep the first known name as the common name', async () => {
    const { writer, sent } = writerAnswering(
      fixture('claude-care-guide-valid.json'),
    );

    await writer.write(monstera);

    expect(JSON.stringify(sent[0]?.body.messages)).toContain(
      'use o primeiro desses nomes, exatamente como está escrito',
    );
  });

  it('says there is no known name when the species has none', async () => {
    const { writer, sent } = writerAnswering(
      fixture('claude-care-guide-valid.json'),
    );

    await writer.write({
      scientificName: 'Pilea peperomioides',
      knownNames: [],
    });

    expect(JSON.stringify(sent[0]?.body.messages)).toContain('nenhum');
  });

  it('fails when the recorded care guide does not pass the Zod schema', async () => {
    const { writer } = writerAnswering(
      fixture('claude-care-guide-invalid.json'),
    );

    await expect(writer.write(monstera)).rejects.toThrow(
      CareGuideNotWrittenError,
    );
  });

  it('fails when Claude answers without calling the tool', async () => {
    const { writer } = writerAnswering(
      fixture('claude-care-guide-no-tool.json'),
    );

    await expect(writer.write(monstera)).rejects.toThrow(/no care guide/);
  });

  it('fails when Claude refuses', async () => {
    const { writer } = writerAnswering(
      fixture('claude-care-guide-refusal.json'),
    );

    await expect(writer.write(monstera)).rejects.toThrow(/refused/);
  });

  it('fails when the answer is cut off', async () => {
    const { writer } = writerAnswering({
      ...fixture('claude-care-guide-invalid.json'),
      stop_reason: 'max_tokens',
    });

    await expect(writer.write(monstera)).rejects.toThrow(/max_tokens/);
  });

  it('fails when the API answers an error', async () => {
    const { writer } = writerAnswering(
      {
        type: 'error',
        error: { type: 'overloaded_error', message: 'Overloaded' },
      },
      529,
    );

    await expect(writer.write(monstera)).rejects.toThrow(
      CareGuideNotWrittenError,
    );
  });
});
