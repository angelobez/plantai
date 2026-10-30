import {
  type CallHandler,
  type ExecutionContext,
  Injectable,
  type NestInterceptor,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import multer, { MulterError } from 'multer';
import type { Observable } from 'rxjs';
import type { DomainError } from '../errors/domain-error';
import { invalidField } from '../errors/validation';

/** The multipart field that carries the photo. */
export const PHOTO_FIELD = 'file';

/** The Lambda request ceiling (ADR 0004); the app sends well under 1 MB. */
export const MAX_PHOTO_BYTES = 6 * 1024 * 1024;

const parseUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_PHOTO_BYTES, files: 1 },
}).single(PHOTO_FIELD);

/** A `VALIDATION_FAILED` about the photo field. */
export function invalidPhoto(message: string, cause?: unknown): DomainError {
  return invalidField(PHOTO_FIELD, message, cause);
}

function toDomainError(error: unknown): DomainError {
  if (error instanceof MulterError) {
    return invalidPhoto(
      error.code === 'LIMIT_FILE_SIZE'
        ? 'file is larger than 6 MB'
        : `unexpected multipart content (${error.code})`,
      error,
    );
  }
  return invalidPhoto('malformed multipart body', error);
}

/**
 * Reads the multipart body into memory and puts the photo at
 * `request.file`, for `@UploadedFile()`. It runs after the guard, so a
 * request without a session is refused before its body is read.
 *
 * Every problem with the upload answers `VALIDATION_FAILED` on the
 * {@link PHOTO_FIELD} path: Nest's own `FileInterceptor` would answer `413`
 * for a file that is too big, which the API has no code for.
 */
@Injectable()
export class PhotoUploadInterceptor implements NestInterceptor {
  async intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<unknown>> {
    const http = context.switchToHttp();
    await new Promise<void>((resolve, reject) => {
      parseUpload(
        http.getRequest<Request>(),
        http.getResponse<Response>(),
        (error: unknown) => {
          if (error) reject(toDomainError(error));
          else resolve();
        },
      );
    });
    return next.handle();
  }
}
