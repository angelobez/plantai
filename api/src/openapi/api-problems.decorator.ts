import { applyDecorators } from '@nestjs/common';
import {
  ApiExtraModels,
  ApiHeader,
  ApiResponse,
  getSchemaPath,
} from '@nestjs/swagger';
import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import { ERROR_STATUS, type ErrorCode } from '../errors/domain-error';

/** The `application/problem+json` body every error answers with (RFC 9457). */
export const problemDetailsSchema = z.object({
  type: z.literal('about:blank'),
  title: z.string(),
  status: z.int(),
  code: z.string().describe('Stable error code; the app shows the message'),
  errors: z
    .array(z.object({ path: z.string(), message: z.string() }))
    .optional()
    .describe('Per-field details, only for VALIDATION_FAILED'),
});

class ProblemDetails extends createZodDto(problemDetailsSchema) {}

/**
 * Codes any route may answer, whatever it does: a bad or outdated
 * `X-App-Version`, and the unmapped-error fallback.
 */
const SHARED_CODES = [
  'VALIDATION_FAILED',
  'APP_UPDATE_REQUIRED',
  'INTERNAL_ERROR',
] as const satisfies readonly ErrorCode[];

/**
 * Documents the errors of a route in the OpenAPI: one `problem+json` response
 * per status, listing its codes, plus the shared ones and the optional
 * `X-App-Version` header. Every route uses it, naming only its own codes.
 *
 * @example @ApiProblems('INVALID_CREDENTIALS', 'TOO_MANY_REQUESTS')
 */
export function ApiProblems(...codes: ErrorCode[]): MethodDecorator {
  const byStatus = new Map<number, ErrorCode[]>();
  for (const code of new Set([...codes, ...SHARED_CODES])) {
    const status = ERROR_STATUS[code];
    byStatus.set(status, [...(byStatus.get(status) ?? []), code]);
  }

  const responses = [...byStatus]
    .sort(([a], [b]) => a - b)
    .map(([status, statusCodes]) =>
      ApiResponse({
        status,
        description: statusCodes.join(', '),
        content: {
          'application/problem+json': {
            schema: {
              allOf: [
                { $ref: getSchemaPath(ProblemDetails) },
                {
                  type: 'object',
                  properties: { code: { type: 'string', enum: statusCodes } },
                },
              ],
            },
          },
        },
      }),
    );

  return applyDecorators(
    ApiExtraModels(ProblemDetails),
    ApiHeader({
      name: 'X-App-Version',
      required: false,
      description:
        'Semantic version of the app; older than MIN_APP_VERSION answers 426',
    }),
    ...responses,
  );
}
