import {
  type CandidateImage,
  IdentificationServiceUnavailableError,
  type PlantIdentifier,
  type RawCandidate,
} from '../../src/identifications/plant-identifier';

/**
 * Stands in for Pl@ntNet: answers whatever a test put in {@link next}, no
 * candidates by default. Keeps every photo it was sent.
 */
export class FakePlantIdentifier implements PlantIdentifier {
  /** The candidates the next calls answer, best first. */
  next: RawCandidate[] = [];

  /** While true, every call fails as if Pl@ntNet were down. */
  failing = false;

  /** The bytes of every photo it was asked about, oldest first. */
  readonly photos: Buffer[] = [];

  /** Makes the next calls answer [candidates]. */
  answers(...candidates: RawCandidate[]): this {
    this.next = candidates;
    return this;
  }

  identify(photo: Buffer): Promise<RawCandidate[]> {
    this.photos.push(Buffer.from(photo));
    if (this.failing) {
      return Promise.reject(
        new IdentificationServiceUnavailableError('The fake Pl@ntNet is down'),
      );
    }
    return Promise.resolve(structuredClone(this.next));
  }
}

let images = 0;

/** A Pl@ntNet image with a unique URL and its credit. */
export function candidateImage(
  overrides: Partial<CandidateImage> = {},
): CandidateImage {
  images += 1;
  return {
    url: `https://bs.plantnet.org/image/m/${String(images)}`,
    author: 'Ana Ribeiro',
    license: 'CC BY-SA',
    sourceUrl: `https://bs.plantnet.org/image/o/${String(images)}`,
    ...overrides,
  };
}

/** A recognizable candidate: score 0.8, linked to GBIF, with one image. */
export function rawCandidate(
  overrides: Partial<RawCandidate> = {},
): RawCandidate {
  return {
    scientificName: 'Epipremnum aureum',
    commonNames: ['Jibóia', 'Jiboia verde'],
    score: 0.8,
    gbifKey: 2868323,
    images: [candidateImage()],
    ...overrides,
  };
}
