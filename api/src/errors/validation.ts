import { createZodValidationPipe } from 'nestjs-zod';
import { ZodError } from 'zod';
import { DomainError } from './domain-error';

/** Turns Zod issues into the `errors[]` of a `VALIDATION_FAILED` problem. */
export function validationFailed(error: ZodError): DomainError {
  return new DomainError('VALIDATION_FAILED', {
    cause: error,
    errors: error.issues.map((issue) => ({
      path: issue.path.map(String).join('.'),
      message: issue.message,
    })),
  });
}

/** A `VALIDATION_FAILED` about one field, [path], found past the schema. */
export function invalidField(
  path: string,
  message: string,
  cause?: unknown,
): DomainError {
  return new DomainError('VALIDATION_FAILED', {
    cause,
    errors: [{ path, message }],
  });
}

/**
 * Global pipe: every parameter typed with a `createZodDto` class is validated
 * against its schema, and a rejection answers `400 VALIDATION_FAILED`.
 */
export const ZodValidationPipe = createZodValidationPipe({
  createValidationException: (error) =>
    error instanceof ZodError
      ? validationFailed(error)
      : new DomainError('VALIDATION_FAILED', { cause: error }),
});
