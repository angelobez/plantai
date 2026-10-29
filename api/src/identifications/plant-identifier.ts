/** One photo Pl@ntNet shows for a candidate, with its credit. */
export interface CandidateImage {
  /** The image to show (Pl@ntNet's medium size). */
  url: string;
  author: string;
  /** Such as `CC BY-SA`. */
  license: string;
  /** Where the credit links to (the original image). */
  sourceUrl: string;
}

/** A species the identifier proposes for a photo, as it answered it. */
export interface RawCandidate {
  /** Without author. */
  scientificName: string;
  /** In Portuguese, raw: they may be phrases, or another plant's name. */
  commonNames: string[];
  /** From 0 to 1; it does not separate right from wrong answers well. */
  score: number;
  /** Null when the identifier did not link the species to GBIF. */
  gbifKey: number | null;
  images: CandidateImage[];
}

/**
 * The identifier could not be asked: timeout, network failure, a 5xx or any
 * answer other than candidates or "species not found". The identification
 * does not count against the daily limit.
 */
export class IdentificationServiceUnavailableError extends Error {
  override readonly name = 'IdentificationServiceUnavailableError';
}

/**
 * The port for identifying the plant in a photo (Pl@ntNet). The real adapter
 * is {@link PlantNetIdentifier}; tests swap in a fake.
 *
 * An abstract class rather than an interface, so it doubles as the Nest
 * injection token.
 */
export abstract class PlantIdentifier {
  /**
   * Up to 3 candidates for the JPEG [photo], best first; none when the photo
   * shows no plant the identifier knows. Fails with
   * {@link IdentificationServiceUnavailableError}.
   */
  abstract identify(photo: Buffer): Promise<RawCandidate[]>;
}
