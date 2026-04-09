import * as turf from '@turf/turf';
import type { LngLat, Stop, Waypoint, RouteSegment } from '../types';

/** Project a point onto the nearest position on a LineString */
export function snapToLine(
  point: LngLat,
  routeCoords: [number, number][]
): { snapped: LngLat; lineFraction: number; distance: number } {
  if (routeCoords.length < 2) {
    return { snapped: point, lineFraction: 0, distance: Infinity };
  }

  const line = turf.lineString(routeCoords);
  const pt = turf.point([point.lng, point.lat]);
  const snapped = turf.nearestPointOnLine(line, pt);

  const totalLength = turf.length(line, { units: 'meters' });
  const sliced = turf.lineSlice(
    turf.point(routeCoords[0]),
    snapped,
    line
  );
  const distanceAlong = turf.length(sliced, { units: 'meters' });
  const lineFraction = totalLength > 0 ? distanceAlong / totalLength : 0;

  return {
    snapped: {
      lng: snapped.geometry.coordinates[0],
      lat: snapped.geometry.coordinates[1],
    },
    lineFraction: Math.round(lineFraction * 10000) / 10000,
    distance: (snapped.properties.dist ?? 0) * 1000,
  };
}

/** Order stops by their line_fraction and assign order numbers */
export function orderStopsByFraction(stops: Stop[]): Stop[] {
  return [...stops]
    .sort((a, b) => a.lineFraction - b.lineFraction)
    .map((stop, i) => ({ ...stop, order: i + 1 }));
}

/** Find which segment a click is nearest to, returns the waypoint index AFTER which to insert */
export function findInsertionIndex(
  clickPoint: LngLat,
  segments: RouteSegment[]
): number {
  let minDist = Infinity;
  let bestIndex = 0;

  for (let i = 0; i < segments.length; i++) {
    if (segments[i].coordinates.length < 2) continue;
    const segLine = turf.lineString(segments[i].coordinates);
    const pt = turf.point([clickPoint.lng, clickPoint.lat]);
    const nearest = turf.nearestPointOnLine(segLine, pt);
    const dist = nearest.properties.dist ?? Infinity;
    if (dist < minDist) {
      minDist = dist;
      bestIndex = i;
    }
  }

  return bestIndex;
}

/** Concatenate all segment coordinates into a single route */
export function buildFullRoute(segments: RouteSegment[]): [number, number][] {
  if (segments.length === 0) return [];

  const coords: [number, number][] = [];
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i].coordinates;
    // Skip the first point of subsequent segments (it's the same as the last of the previous)
    const start = i === 0 ? 0 : 1;
    for (let j = start; j < seg.length; j++) {
      coords.push(seg[j]);
    }
  }
  return coords;
}

/** Calculate total distance of a route in meters */
export function calculateRouteDistance(routeCoords: [number, number][]): number {
  if (routeCoords.length < 2) return 0;
  const line = turf.lineString(routeCoords);
  return turf.length(line, { units: 'meters' });
}

/** Sub-sample a dense LineString into waypoints every ~500m */
export function subsampleWaypoints(coords: [number, number][]): Waypoint[] {
  if (coords.length === 0) return [];
  if (coords.length <= 3) {
    return coords.map((c, i) => ({
      id: crypto.randomUUID(),
      lngLat: { lng: c[0], lat: c[1] },
      index: i,
    }));
  }

  const line = turf.lineString(coords);
  const totalLength = turf.length(line, { units: 'meters' });
  const INTERVAL = 500;

  const points: Waypoint[] = [];
  points.push({
    id: crypto.randomUUID(),
    lngLat: { lng: coords[0][0], lat: coords[0][1] },
    index: 0,
  });

  for (let d = INTERVAL; d < totalLength; d += INTERVAL) {
    const pt = turf.along(line, d, { units: 'meters' });
    points.push({
      id: crypto.randomUUID(),
      lngLat: { lng: pt.geometry.coordinates[0], lat: pt.geometry.coordinates[1] },
      index: points.length,
    });
  }

  const last = coords[coords.length - 1];
  points.push({
    id: crypto.randomUUID(),
    lngLat: { lng: last[0], lat: last[1] },
    index: points.length,
  });

  return points;
}
