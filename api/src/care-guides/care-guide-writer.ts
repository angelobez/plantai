import type { CareGuideContent } from './care-guide-content';

/** What the writer knows about the species. */
export interface CareGuideRequest {
  /** Without author. */
  scientificName: string;
  /** The common names the Catalog already has, primary first. */
  knownNames: string[];
}

export interface WrittenCareGuide {
  /** Already validated by `careGuideContentSchema`. */
  content: CareGuideContent;
  /** The model that wrote it (a fallback model, after a refusal). */
  model: string;
}

/** Claude could not write the care guide, or wrote an invalid one. */
export class CareGuideNotWrittenError extends Error {
  override readonly name = 'CareGuideNotWrittenError';
}

/**
 * The port for writing a species' care guide (Claude). The real adapter is
 * {@link ClaudeCareGuideWriter}; tests swap in a fake.
 *
 * An abstract class rather than an interface, so it doubles as the Nest
 * injection token.
 */
export abstract class CareGuideWriter {
  /** The model the care guide is asked of, kept while it is generated. */
  abstract readonly model: string;
  /** The version of the prompt, so the guides can be written again later. */
  abstract readonly promptVersion: number;

  /** Rejects with {@link CareGuideNotWrittenError}. */
  abstract write(request: CareGuideRequest): Promise<WrittenCareGuide>;
}
