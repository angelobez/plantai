import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

/**
 * The `:id` of a route that reads one resource. A value that is not a UUID
 * answers `VALIDATION_FAILED` before any query runs.
 */
export class IdParam extends createZodDto(z.object({ id: z.uuid() })) {}
