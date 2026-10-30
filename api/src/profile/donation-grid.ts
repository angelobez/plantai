/** A point in decimal degrees (WGS 84). */
export interface LatLng {
  lat: number;
  lng: number;
}

/** About 1 km of latitude, in degrees. */
const LAT_STEP = 1 / 111.32;

/**
 * The center of the ~1 km grid cell holding `point` (ADR 0002). Rows of
 * latitude have a fixed step of 1/111.32 degree; inside a row, the longitude
 * step is that same step divided by the cosine of the row's center latitude,
 * so a cell is about 1 km wide in both directions at any latitude. Pure and
 * deterministic: two points in the same cell get exactly the same center.
 */
export function cellCenter({ lat, lng }: LatLng): LatLng {
  const row = Math.floor(lat / LAT_STEP);
  const centerLat = Math.min(90, Math.max(-90, (row + 0.5) * LAT_STEP));
  const lngStep = LAT_STEP / Math.cos((centerLat * Math.PI) / 180);
  const column = Math.floor(lng / lngStep);
  return { lat: centerLat, lng: wrapLongitude((column + 0.5) * lngStep) };
}

/** Brings a longitude past ±180 (cells near the antimeridian) back in range. */
function wrapLongitude(lng: number): number {
  if (lng > 180) return lng - 360;
  if (lng < -180) return lng + 360;
  return lng;
}
