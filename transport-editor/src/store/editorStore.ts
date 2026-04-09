import { create } from 'zustand';
import { temporal } from 'zundo';
import type { EditorMode, LineData, Waypoint, Stop, RouteSegment, LngLat } from '../types';
import { orderStopsByFraction, buildFullRoute, calculateRouteDistance } from '../utils/geo';

interface EditorState {
  // Mode
  mode: EditorMode;
  setMode: (mode: EditorMode) => void;

  // Line metadata
  lineData: LineData;
  updateLineData: (data: Partial<LineData>) => void;

  // Waypoints
  waypoints: Waypoint[];
  addWaypoint: (waypoint: Waypoint) => void;
  insertWaypoint: (waypoint: Waypoint, afterIndex: number) => void;
  moveWaypoint: (id: string, lngLat: LngLat) => void;
  deleteWaypoint: (id: string) => void;

  // Route segments
  segments: RouteSegment[];
  setSegment: (fromId: string, toId: string, coords: [number, number][], isFallback?: boolean) => void;
  removeSegmentsForWaypoint: (waypointId: string) => void;

  // Stops
  stops: Stop[];
  addStop: (stop: Stop) => void;
  moveStop: (id: string, lngLat: LngLat, lineFraction: number) => void;
  deleteStop: (id: string) => void;
  renameStop: (id: string, name: string) => void;

  // UI state
  isRoutingLoading: boolean;
  routingError: string | null;
  selectedStopId: string | null;
  setRoutingLoading: (loading: boolean) => void;
  setRoutingError: (error: string | null) => void;
  setSelectedStopId: (id: string | null) => void;

  // Computed helpers
  getFullRoute: () => [number, number][];
  getTotalDistance: () => number;

  // Import/clear
  importData: (waypoints: Waypoint[], stops: Stop[], segments: RouteSegment[], lineData: LineData) => void;
  clearAll: () => void;
}

const defaultLineData: LineData = {
  lineName: 'Nouvelle ligne',
  lineColor: '#e74c3c',
  direction: '',
  updatedAt: new Date().toISOString(),
};

export const useEditorStore = create<EditorState>()(
  temporal(
    (set, get) => ({
      mode: 'route',
      setMode: (mode) => set({ mode }),

      lineData: { ...defaultLineData },
      updateLineData: (data) =>
        set((state) => ({ lineData: { ...state.lineData, ...data } })),

      waypoints: [],
      addWaypoint: (waypoint) =>
        set((state) => ({
          waypoints: [...state.waypoints, { ...waypoint, index: state.waypoints.length }],
        })),
      insertWaypoint: (waypoint, afterIndex) =>
        set((state) => {
          const newWaypoints = [...state.waypoints];
          newWaypoints.splice(afterIndex + 1, 0, waypoint);
          return {
            waypoints: newWaypoints.map((w, i) => ({ ...w, index: i })),
          };
        }),
      moveWaypoint: (id, lngLat) =>
        set((state) => ({
          waypoints: state.waypoints.map((w) =>
            w.id === id ? { ...w, lngLat } : w
          ),
        })),
      deleteWaypoint: (id) =>
        set((state) => ({
          waypoints: state.waypoints
            .filter((w) => w.id !== id)
            .map((w, i) => ({ ...w, index: i })),
          segments: state.segments.filter(
            (s) => s.fromWaypointId !== id && s.toWaypointId !== id
          ),
        })),

      segments: [],
      setSegment: (fromId, toId, coords, isFallback) =>
        set((state) => {
          const existing = state.segments.findIndex(
            (s) => s.fromWaypointId === fromId && s.toWaypointId === toId
          );
          const newSeg: RouteSegment = {
            fromWaypointId: fromId,
            toWaypointId: toId,
            coordinates: coords,
            isFallback,
          };
          if (existing >= 0) {
            const newSegments = [...state.segments];
            newSegments[existing] = newSeg;
            return { segments: newSegments };
          }
          return { segments: [...state.segments, newSeg] };
        }),
      removeSegmentsForWaypoint: (waypointId) =>
        set((state) => ({
          segments: state.segments.filter(
            (s) => s.fromWaypointId !== waypointId && s.toWaypointId !== waypointId
          ),
        })),

      stops: [],
      addStop: (stop) =>
        set((state) => ({
          stops: orderStopsByFraction([...state.stops, stop]),
        })),
      moveStop: (id, lngLat, lineFraction) =>
        set((state) => ({
          stops: orderStopsByFraction(
            state.stops.map((s) =>
              s.id === id ? { ...s, lngLat, lineFraction } : s
            )
          ),
        })),
      deleteStop: (id) =>
        set((state) => ({
          stops: orderStopsByFraction(state.stops.filter((s) => s.id !== id)),
          selectedStopId: state.selectedStopId === id ? null : state.selectedStopId,
        })),
      renameStop: (id, name) =>
        set((state) => ({
          stops: state.stops.map((s) => (s.id === id ? { ...s, name } : s)),
        })),

      isRoutingLoading: false,
      routingError: null,
      selectedStopId: null,
      setRoutingLoading: (loading) => set({ isRoutingLoading: loading }),
      setRoutingError: (error) => set({ routingError: error }),
      setSelectedStopId: (id) => set({ selectedStopId: id }),

      getFullRoute: () => {
        const { segments, waypoints } = get();
        // Order segments by waypoint order
        const orderedSegments = waypoints
          .slice(0, -1)
          .map((w, i) => {
            const nextW = waypoints[i + 1];
            return segments.find(
              (s) => s.fromWaypointId === w.id && s.toWaypointId === nextW.id
            );
          })
          .filter((s): s is RouteSegment => s !== undefined);
        return buildFullRoute(orderedSegments);
      },
      getTotalDistance: () => {
        const route = get().getFullRoute();
        return calculateRouteDistance(route);
      },

      importData: (waypoints, stops, segments, lineData) =>
        set({
          waypoints,
          stops: orderStopsByFraction(stops),
          segments,
          lineData,
          mode: 'route',
          selectedStopId: null,
          routingError: null,
        }),
      clearAll: () =>
        set({
          waypoints: [],
          stops: [],
          segments: [],
          lineData: { ...defaultLineData },
          mode: 'route',
          selectedStopId: null,
          routingError: null,
          isRoutingLoading: false,
        }),
    }),
    {
      limit: 50,
      partialize: (state) => {
        const { isRoutingLoading, routingError, selectedStopId, ...tracked } = state;
        return tracked;
      },
    }
  )
);

export const useTemporalStore = () => {
  return useEditorStore.temporal.getState();
};
