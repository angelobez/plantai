import { cellCenter, type LatLng } from './donation-grid';

/** Great-circle distance in km (haversine on a sphere of radius 6371 km). */
function distanceKm(a: LatLng, b: LatLng): number {
  const rad = (degrees: number) => (degrees * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

const LAT_STEP = 1 / 111.32;

describe('cellCenter', () => {
  it('is deterministic', () => {
    const point = { lat: -23.5874, lng: -46.6345 };

    expect(cellCenter(point)).toEqual(cellCenter({ ...point }));
  });

  it('gives the same center to points in the same cell', () => {
    const center = cellCenter({ lat: -23.5874, lng: -46.6345 });
    const nearby = [
      { lat: center.lat + LAT_STEP * 0.4, lng: center.lng },
      { lat: center.lat - LAT_STEP * 0.4, lng: center.lng },
      { lat: center.lat, lng: center.lng + LAT_STEP * 0.4 },
      { lat: center.lat + LAT_STEP * 0.3, lng: center.lng - LAT_STEP * 0.4 },
    ];

    for (const point of nearby) {
      expect(cellCenter(point)).toEqual(center);
    }
  });

  it('maps a center to itself', () => {
    const center = cellCenter({ lat: -30.0346, lng: -51.2177 });

    expect(cellCenter(center)).toEqual(center);
  });

  it.each([
    ['near the equator', { lat: 0.0123, lng: -49.9876 }],
    ['in São Paulo', { lat: -23.5874, lng: -46.6345 }],
    ['in the south of Brazil', { lat: -30.0346, lng: -51.2177 }],
    ['at the southern tip of Brazil', { lat: -33.7422, lng: -53.3732 }],
  ])('makes cells of about 1 km in both directions %s', (_case, point) => {
    const center = cellCenter(point);
    const north = cellCenter({ lat: center.lat + LAT_STEP, lng: center.lng });
    const east = cellCenter({
      lat: center.lat,
      lng: center.lng + LAT_STEP / Math.cos((center.lat * Math.PI) / 180),
    });

    // The row above has its own longitude step, so compare latitudes only.
    expect(distanceKm(center, { ...center, lat: north.lat })).toBeCloseTo(1, 1);
    expect(distanceKm(center, east)).toBeCloseTo(1, 1);
  });

  it.each([
    { lat: 0.0123, lng: -49.9876 },
    { lat: -0.0001, lng: 0.0001 },
    { lat: -23.5874, lng: -46.6345 },
    { lat: -23.58, lng: -46.63 },
    { lat: -30.0346, lng: -51.2177 },
    { lat: -33.7422, lng: -53.3732 },
    { lat: 5.2718, lng: -60.2104 },
  ])('puts the center less than 0.8 km from %p', (point) => {
    expect(distanceKm(point, cellCenter(point))).toBeLessThan(0.8);
  });

  it.each([
    { lat: 90, lng: 180 },
    { lat: -90, lng: -180 },
    { lat: 89.999, lng: 179.999 },
    { lat: 0, lng: 180 },
  ])('keeps the center a valid coordinate at %p', (point) => {
    const center = cellCenter(point);

    expect(Math.abs(center.lat)).toBeLessThanOrEqual(90);
    expect(Math.abs(center.lng)).toBeLessThanOrEqual(180);
  });
});
