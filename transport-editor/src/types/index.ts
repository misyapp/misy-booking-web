export interface LngLat {
  lng: number;
  lat: number;
}

export interface Waypoint {
  id: string;
  lngLat: LngLat;
  index: number;
}

export interface Stop {
  id: string;
  lngLat: LngLat;
  name: string;
  order: number;
  lineFraction: number;
}

export interface RouteSegment {
  fromWaypointId: string;
  toWaypointId: string;
  coordinates: [number, number][];
  isFallback?: boolean;
}

export interface LineData {
  lineName: string;
  lineColor: string;
  direction: string;
  updatedAt: string;
}

export type EditorMode = 'route' | 'stops';
