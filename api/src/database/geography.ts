import { type SQL, sql } from 'drizzle-orm';
import type { LatLng } from '../profile/donation-grid';

/** [point] as a PostGIS geography, for distances in meters on the spheroid. */
export function geographyOf({ lat, lng }: LatLng): SQL {
  return sql`ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography`;
}
