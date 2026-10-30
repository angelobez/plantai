import {
  applyDecorators,
  createParamDecorator,
  type ExecutionContext,
} from '@nestjs/common';
import { ApiHeader } from '@nestjs/swagger';
import type { Request } from 'express';
import { DomainError } from '../errors/domain-error';
import { invalidField } from '../errors/validation';
import type { LatLng } from '../profile/donation-grid';

/** The header with the searcher's approximate location. */
export const SEARCH_LOCATION_HEADER = 'X-Search-Location';

/** `<lat>,<lng>` in decimal degrees, spaces allowed around the comma. */
const FORMAT = /^\s*(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$/;

/**
 * Reads the searcher's location from `X-Search-Location: <lat>,<lng>`
 * (docs/spec/modelo-de-dados-e-api.md, "Localização de quem procura").
 * Missing: `LOCATION_REQUIRED`; out of format or range: `VALIDATION_FAILED`
 * on the header. The point is used as is (it is never stored) and never
 * echoed back, not even in the error message; the request logger already
 * redacts the header.
 */
export function parseSearchLocation(raw: string | undefined): LatLng {
  if (raw === undefined) throw new DomainError('LOCATION_REQUIRED');

  const match = FORMAT.exec(raw);
  const lat = Number(match?.[1]);
  const lng = Number(match?.[2]);
  if (!match || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    throw invalidField(
      SEARCH_LOCATION_HEADER,
      'must be "<lat>,<lng>" in decimal degrees, within -90..90 and -180..180',
    );
  }
  return { lat, lng };
}

/**
 * The searcher's location, parsed from `X-Search-Location` by
 * {@link parseSearchLocation}. Pair it with {@link ApiSearchLocation}.
 */
export const SearchLocation = createParamDecorator(
  (_data: unknown, context: ExecutionContext): LatLng =>
    parseSearchLocation(
      context
        .switchToHttp()
        .getRequest<Request>()
        .header(SEARCH_LOCATION_HEADER),
    ),
);

/** Documents the required `X-Search-Location` header in the OpenAPI. */
export function ApiSearchLocation(): MethodDecorator {
  return applyDecorators(
    ApiHeader({
      name: SEARCH_LOCATION_HEADER,
      required: true,
      example: '-23.5874,-46.6345',
      description:
        'The searcher’s approximate location, "<lat>,<lng>" in decimal degrees; never stored nor logged. Missing: LOCATION_REQUIRED',
    }),
  );
}
