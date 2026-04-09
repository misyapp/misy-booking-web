import type { LineData, Waypoint, Stop } from '../types';
import { snapToLine, orderStopsByFraction, subsampleWaypoints } from './geo';

export interface ImportResult {
  lineData: LineData;
  waypoints: Waypoint[];
  stops: Stop[];
  routeCoordinates: [number, number][];
}

/** Import a GeoJSON file (supports both Misy legacy and editor format) */
export function importGeoJSON(geojson: any): ImportResult {
  const props = geojson.properties || {};

  const lineData: LineData = {
    lineName: props.line_name || props.route_name || `Ligne ${props.line || 'Sans nom'}`,
    lineColor: props.line_color || '#e74c3c',
    direction: props.direction || '',
    updatedAt: props.updated_at || new Date().toISOString(),
  };

  // Handle Flutter color format "0xFF..."
  if (lineData.lineColor.startsWith('0x') || lineData.lineColor.startsWith('0X')) {
    lineData.lineColor = '#' + lineData.lineColor.replace(/^0x(FF)?/i, '');
  }

  // Find the route feature
  const features = geojson.features || [];
  const routeFeature = features.find(
    (f: any) => f.properties?.type === 'route' || f.geometry?.type === 'LineString'
  );
  const routeCoordinates: [number, number][] = routeFeature?.geometry?.coordinates || [];

  // Waypoints: use stored ones if available, otherwise sub-sample
  let waypoints: Waypoint[];
  if (routeFeature?.properties?.waypoints && routeFeature.properties.waypoints.length > 0) {
    waypoints = routeFeature.properties.waypoints.map(
      (coord: [number, number], i: number) => ({
        id: crypto.randomUUID(),
        lngLat: { lng: coord[0], lat: coord[1] },
        index: i,
      })
    );
  } else {
    waypoints = subsampleWaypoints(routeCoordinates);
  }

  // Import stops
  const stopFeatures = features.filter(
    (f: any) => f.properties?.type === 'stop' || (f.geometry?.type === 'Point' && f.properties?.name)
  );

  const stops: Stop[] = stopFeatures.map((f: any, i: number) => {
    const coords = f.geometry.coordinates;
    const lngLat = { lng: coords[0], lat: coords[1] };

    let lineFraction = f.properties.line_fraction;
    if (lineFraction === undefined && routeCoordinates.length >= 2) {
      lineFraction = snapToLine(lngLat, routeCoordinates).lineFraction;
    }

    return {
      id: crypto.randomUUID(),
      lngLat,
      name: f.properties.name || `Arrêt ${i + 1}`,
      order: f.properties.order || i + 1,
      lineFraction: lineFraction || 0,
    };
  });

  return {
    lineData,
    waypoints,
    stops: orderStopsByFraction(stops),
    routeCoordinates,
  };
}

/** Export editor state to GeoJSON */
export function exportGeoJSON(
  lineData: LineData,
  waypoints: Waypoint[],
  stops: Stop[],
  routeCoordinates: [number, number][]
): any {
  const orderedStops = orderStopsByFraction(stops);

  return {
    type: 'FeatureCollection',
    properties: {
      line_name: lineData.lineName,
      line_color: lineData.lineColor,
      direction: lineData.direction,
      updated_at: new Date().toISOString(),
      num_stops: orderedStops.length,
      num_coordinates: routeCoordinates.length,
      source: 'transport-editor',
    },
    features: [
      {
        type: 'Feature',
        geometry: {
          type: 'LineString',
          coordinates: routeCoordinates,
        },
        properties: {
          type: 'route',
          waypoints: waypoints.map((w) => [w.lngLat.lng, w.lngLat.lat]),
        },
      },
      ...orderedStops.map((stop) => ({
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [stop.lngLat.lng, stop.lngLat.lat],
        },
        properties: {
          type: 'stop',
          name: stop.name,
          order: stop.order,
          line_fraction: stop.lineFraction,
        },
      })),
    ],
  };
}

/** Download a GeoJSON object as a .geojson file */
export function downloadGeoJSON(data: any, filename: string) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
