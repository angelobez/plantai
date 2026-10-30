import type { ReferencePhotoDownloader } from '../../src/catalog/reference-photo-downloader';

/**
 * Stands in for Wikimedia: serves the bytes a test registered for each URL,
 * and fails like a missing file for any other. Keeps every URL it was asked.
 */
export class FakeReferencePhotoDownloader implements ReferencePhotoDownloader {
  private readonly files = new Map<string, Buffer>();

  /** Every URL passed to {@link download}, oldest first. */
  readonly downloaded: string[] = [];

  /** Makes [url] answer [bytes]. */
  serves(url: string, bytes: Buffer): this {
    this.files.set(url, bytes);
    return this;
  }

  /** Makes [url] fail, as if the file were gone. */
  forget(url: string): this {
    this.files.delete(url);
    return this;
  }

  download(url: string): Promise<Buffer> {
    this.downloaded.push(url);
    const bytes = this.files.get(url);
    return bytes
      ? Promise.resolve(Buffer.from(bytes))
      : Promise.reject(new Error(`HTTP 404 for ${url}`));
  }
}
