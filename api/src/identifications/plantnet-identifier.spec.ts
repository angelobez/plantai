import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { IdentificationServiceUnavailableError } from './plant-identifier';
import { PlantNetIdentifier } from './plantnet-identifier';

/** A recorded Pl@ntNet answer from `__fixtures__`, as the raw body. */
function fixtureBody(name: string): string {
  return readFileSync(join(__dirname, '__fixtures__', name), 'utf8');
}

type FetchCall = Parameters<typeof fetch>;

/** A `fetch` that answers [status] with [body], and keeps every call. */
function answering(status: number, body: string) {
  const calls: FetchCall[] = [];
  const fetch = (...call: FetchCall) => {
    calls.push(call);
    return Promise.resolve(
      new Response(body, {
        status,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
  };
  return { calls, fetch };
}

const photo = Buffer.from('jpeg bytes');

describe('PlantNetIdentifier', () => {
  it('posts the photo to /v2/identify/all with the agreed parameters', async () => {
    const { calls, fetch } = answering(
      200,
      fixtureBody('plantnet-identify-jiboia.json'),
    );

    await new PlantNetIdentifier({ apiKey: 'key-123', fetch }).identify(photo);

    const [url, init] = calls[0] ?? [];
    const sent = new URL(url as URL);
    expect(sent.origin + sent.pathname).toBe(
      'https://my-api.plantnet.org/v2/identify/all',
    );
    expect(Object.fromEntries(sent.searchParams)).toEqual({
      'api-key': 'key-123',
      lang: 'pt',
      'nb-results': '3',
      'include-related-images': 'true',
    });
    expect(init?.method).toBe('POST');
    expect(init?.signal).toBeInstanceOf(AbortSignal);
    const form = init?.body as FormData;
    expect(form.get('organs')).toBe('auto');
    const image = form.get('images') as Blob;
    expect(image.type).toBe('image/jpeg');
    expect(Buffer.from(await image.arrayBuffer())).toEqual(photo);
  });

  it('reads up to 3 candidates, best first, without authors', async () => {
    const { fetch } = answering(
      200,
      fixtureBody('plantnet-identify-jiboia.json'),
    );

    const candidates = await new PlantNetIdentifier({
      apiKey: 'key',
      fetch,
    }).identify(photo);

    expect(candidates).toEqual([
      {
        scientificName: 'Epipremnum aureum',
        commonNames: ['Jibóia', 'Jiboia verde', 'Hera do-diabo'],
        score: 0.8121,
        gbifKey: 2868323,
        images: [
          {
            url: 'https://bs.plantnet.org/image/m/4b2c3a1f0e9d8c7b6a5f4e3d2c1b0a99',
            author: 'Ana Ribeiro',
            license: 'CC BY-SA',
            sourceUrl:
              'https://bs.plantnet.org/image/o/4b2c3a1f0e9d8c7b6a5f4e3d2c1b0a99',
          },
          {
            url: 'https://bs.plantnet.org/image/m/9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d',
            author: 'Carlos Lima',
            license: 'CC BY',
            sourceUrl:
              'https://bs.plantnet.org/image/o/9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d',
          },
        ],
      },
      expect.objectContaining({
        scientificName: 'Epipremnum pinnatum',
        score: 0.1343,
        gbifKey: 2868325,
      }),
      {
        scientificName: 'Philodendron hederaceum',
        commonNames: ['Maria mole', 'Jibóia', 'Filodendro'],
        score: 0.0059,
        gbifKey: null,
        images: [],
      },
    ]);
  });

  it('answers no candidates when Pl@ntNet finds no species (404)', async () => {
    const { fetch } = answering(
      404,
      fixtureBody('plantnet-species-not-found.json'),
    );

    await expect(
      new PlantNetIdentifier({ apiKey: 'key', fetch }).identify(photo),
    ).resolves.toEqual([]);
  });

  it.each([
    ['a 5xx', 500, '{"statusCode":500,"error":"Internal Server Error"}'],
    ['a 401 (bad key)', 401, '{"statusCode":401,"message":"Invalid API key"}'],
    ['a 429 (quota)', 429, '{"statusCode":429,"message":"Too Many Requests"}'],
    ['another 404', 404, '{"statusCode":404,"message":"Unknown project"}'],
    ['an unexpected body', 200, '{"results":[{"score":"high"}]}'],
    ['a body that is not JSON', 200, '<html>maintenance</html>'],
  ])('fails as unavailable on %s', async (_case, status, body) => {
    const { fetch } = answering(status, body);

    await expect(
      new PlantNetIdentifier({ apiKey: 'key', fetch }).identify(photo),
    ).rejects.toBeInstanceOf(IdentificationServiceUnavailableError);
  });

  it.each([
    ['a timeout', new DOMException('The operation timed out', 'TimeoutError')],
    ['a network failure', new TypeError('fetch failed')],
  ])('fails as unavailable on %s', async (_case, error) => {
    const fetch = () => Promise.reject(error);

    await expect(
      new PlantNetIdentifier({ apiKey: 'key', fetch }).identify(photo),
    ).rejects.toBeInstanceOf(IdentificationServiceUnavailableError);
  });

  it('never puts the key in the error message', async () => {
    const { fetch } = answering(500, '{}');

    await expect(
      new PlantNetIdentifier({ apiKey: 'secret-key', fetch }).identify(photo),
    ).rejects.toThrow(/^(?!.*secret-key)/s);
  });
});
