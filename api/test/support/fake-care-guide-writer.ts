import type { CareGuideContent } from '../../src/care-guides/care-guide-content';
import {
  CareGuideNotWrittenError,
  type CareGuideRequest,
  type CareGuideWriter,
  type WrittenCareGuide,
} from '../../src/care-guides/care-guide-writer';

/** A valid care guide; [overrides] for what a test cares about. */
export function careGuideContent(
  overrides: Partial<CareGuideContent> = {},
): CareGuideContent {
  return {
    commonName: 'planta de teste',
    watering: {
      summary: '1x por semana',
      details: 'Regue quando a terra de cima estiver seca.',
    },
    light: {
      summary: 'Meia-sombra',
      details: 'Muita claridade, sem sol direto.',
    },
    propagation: {
      summary: 'Estaca',
      details: 'Corte um pedaço do caule com um nó e deixe na água.',
    },
    ...overrides,
  };
}

/**
 * Stands in for Claude. By default every species gets {@link careGuideContent}
 * named after its first known name (the scientific one when it has none), so
 * the Catalog's names stay as they were; a test teaches other answers with
 * {@link writes}. Keeps every request it got.
 */
export class FakeCareGuideWriter implements CareGuideWriter {
  readonly model = 'fake-care-guide-model';
  readonly promptVersion = 1;

  /** Every request, oldest first. */
  readonly requests: CareGuideRequest[] = [];

  /** While true, every call fails as if Claude were down. */
  failing = false;

  /** The species whose guide fails, while every other one is written. */
  readonly failingFor = new Set<string>();

  /** When set, calls wait for it before answering. */
  gate: Promise<void> | undefined;

  /** How long each call takes, so calls made together overlap. */
  delayMs = 0;

  /** The most calls that were ever waiting for an answer at once. */
  maxConcurrent = 0;
  private inFlight = 0;

  private readonly answers = new Map<string, CareGuideContent>();

  /** Makes the guide of [scientificName] be [content]. */
  writes(scientificName: string, content: CareGuideContent): this {
    this.answers.set(scientificName, content);
    return this;
  }

  /** The scientific names it was asked about, oldest first. */
  get asked(): string[] {
    return this.requests.map((request) => request.scientificName);
  }

  async write(request: CareGuideRequest): Promise<WrittenCareGuide> {
    this.requests.push(request);
    this.inFlight += 1;
    this.maxConcurrent = Math.max(this.maxConcurrent, this.inFlight);
    try {
      await (this.gate ??
        new Promise((resolve) => setTimeout(resolve, this.delayMs)));
    } finally {
      this.inFlight -= 1;
    }
    if (this.failing || this.failingFor.has(request.scientificName)) {
      throw new CareGuideNotWrittenError('The fake Claude is down');
    }
    const content =
      this.answers.get(request.scientificName) ??
      careGuideContent({
        commonName: request.knownNames[0] ?? request.scientificName,
      });
    return { content, model: this.model };
  }
}
