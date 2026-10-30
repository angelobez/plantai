import { z } from 'zod';
import {
  type CandidateImage,
  IdentificationServiceUnavailableError,
  PlantIdentifier,
  type RawCandidate,
} from './plant-identifier';

const IDENTIFY_URL = 'https://my-api.plantnet.org/v2/identify/all';

/** How many candidates the app shows. */
const CANDIDATES = 3;

const TIMEOUT_MS = 10_000;

/** Only the parts of the answer the API reads. */
const identifyResponseSchema = z.object({
  results: z.array(
    z.object({
      score: z.number().min(0).max(1),
      species: z.object({
        scientificNameWithoutAuthor: z.string().min(1),
        commonNames: z.array(z.string()).default([]),
      }),
      // Pl@ntNet sends the key as a string; a number is accepted too.
      gbif: z
        .object({ id: z.union([z.string(), z.number()]) })
        .nullish()
        .transform((gbif) => (gbif ? gbifKeyOf(gbif.id) : null)),
      images: z
        .array(
          z.object({
            author: z.string(),
            license: z.string(),
            url: z.object({ o: z.url(), m: z.url() }),
          }),
        )
        .default([]),
    }),
  ),
});

/** The 404 body Pl@ntNet answers when the photo matches no species. */
const speciesNotFoundSchema = z.object({
  message: z.literal('Species not found'),
});

function gbifKeyOf(id: string | number): number | null {
  const key = Number(id);
  return Number.isInteger(key) && key > 0 ? key : null;
}

/** `cc-by-sa` as the credit shows it: `CC BY-SA`. */
function licenseName(license: string): string {
  return license.replace(/^cc-/i, 'CC ').toUpperCase();
}

export interface PlantNetOptions {
  /** `PLANTNET_API_KEY`. */
  apiKey: string;
  /** Injected in tests; the global `fetch` otherwise. */
  fetch?: typeof fetch;
}

/**
 * {@link PlantIdentifier} over Pl@ntNet's API, called as in
 * docs/research/teste-plantnet.md: the `all` flora, Portuguese names, 3
 * results and `organs=auto`, plus the related images for the credits.
 */
export class PlantNetIdentifier extends PlantIdentifier {
  private readonly fetch: typeof fetch;

  constructor(private readonly options: PlantNetOptions) {
    super();
    this.fetch = options.fetch ?? fetch;
  }

  async identify(photo: Buffer): Promise<RawCandidate[]> {
    const { status, body } = await this.post(photo);
    if (status === 404 && speciesNotFoundSchema.safeParse(body).success) {
      return [];
    }
    if (status !== 200) {
      throw new IdentificationServiceUnavailableError(
        `Pl@ntNet answered ${String(status)}`,
      );
    }

    const parsed = identifyResponseSchema.safeParse(body);
    if (!parsed.success) {
      throw new IdentificationServiceUnavailableError(
        `Pl@ntNet answered an unexpected body: ${parsed.error.message}`,
      );
    }
    return parsed.data.results.slice(0, CANDIDATES).map((result) => ({
      scientificName: result.species.scientificNameWithoutAuthor,
      commonNames: result.species.commonNames,
      score: result.score,
      gbifKey: result.gbif,
      images: result.images.map((image): CandidateImage => ({
        url: image.url.m,
        author: image.author,
        license: licenseName(image.license),
        sourceUrl: image.url.o,
      })),
    }));
  }

  /** The status and the parsed JSON body; any failure means unavailable. */
  private async post(
    photo: Buffer,
  ): Promise<{ status: number; body: unknown }> {
    const url = new URL(IDENTIFY_URL);
    url.search = new URLSearchParams({
      'api-key': this.options.apiKey,
      lang: 'pt',
      'nb-results': String(CANDIDATES),
      'include-related-images': 'true',
    }).toString();
    const form = new FormData();
    form.append(
      'images',
      new Blob([new Uint8Array(photo)], { type: 'image/jpeg' }),
      'photo.jpg',
    );
    form.append('organs', 'auto');

    try {
      const response = await this.fetch(url, {
        method: 'POST',
        headers: { Accept: 'application/json' },
        body: form,
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      return { status: response.status, body: await response.json() };
    } catch (error) {
      // The URL carries the key, so only the error's name goes on.
      const reason = error instanceof Error ? error.name : 'unknown error';
      throw new IdentificationServiceUnavailableError(
        `Pl@ntNet could not be reached: ${reason}`,
      );
    }
  }
}
