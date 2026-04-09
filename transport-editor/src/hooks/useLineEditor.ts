import { useCallback } from 'react';
import { useEditorStore } from '../store/editorStore';
import { useOSRM } from './useOSRM';
import type { LngLat, Waypoint } from '../types';

export function useLineEditor() {
  const store = useEditorStore();
  const { routeSegment, debouncedRoute } = useOSRM();

  /** Add a waypoint at the end of the route */
  const addWaypoint = useCallback(
    async (lngLat: LngLat) => {
      const newWp: Waypoint = {
        id: crypto.randomUUID(),
        lngLat,
        index: store.waypoints.length,
      };

      const prevWp =
        store.waypoints.length > 0
          ? store.waypoints[store.waypoints.length - 1]
          : null;

      store.addWaypoint(newWp);

      if (prevWp) {
        store.setRoutingLoading(true);
        store.setRoutingError(null);
        try {
          const result = await routeSegment(prevWp.lngLat, lngLat);
          if (result) {
            store.setSegment(prevWp.id, newWp.id, result.coordinates);
          }
        } catch {
          // Fallback: straight line
          store.setSegment(
            prevWp.id,
            newWp.id,
            [
              [prevWp.lngLat.lng, prevWp.lngLat.lat],
              [lngLat.lng, lngLat.lat],
            ],
            true
          );
          store.setRoutingError('OSRM indisponible — ligne droite affichée');
        } finally {
          store.setRoutingLoading(false);
        }
      }
    },
    [store, routeSegment]
  );

  /** Insert a waypoint between existing ones */
  const insertWaypoint = useCallback(
    async (lngLat: LngLat, afterIndex: number) => {
      const newWp: Waypoint = {
        id: crypto.randomUUID(),
        lngLat,
        index: afterIndex + 1,
      };

      const prevWp = store.waypoints[afterIndex];
      const nextWp = store.waypoints[afterIndex + 1];
      if (!prevWp || !nextWp) return;

      store.insertWaypoint(newWp, afterIndex);
      store.setRoutingLoading(true);
      store.setRoutingError(null);

      try {
        const [seg1, seg2] = await Promise.all([
          routeSegment(prevWp.lngLat, lngLat),
          routeSegment(lngLat, nextWp.lngLat),
        ]);
        if (seg1) store.setSegment(prevWp.id, newWp.id, seg1.coordinates);
        if (seg2) store.setSegment(newWp.id, nextWp.id, seg2.coordinates);
      } catch {
        store.setSegment(
          prevWp.id,
          newWp.id,
          [
            [prevWp.lngLat.lng, prevWp.lngLat.lat],
            [lngLat.lng, lngLat.lat],
          ],
          true
        );
        store.setSegment(
          newWp.id,
          nextWp.id,
          [
            [lngLat.lng, lngLat.lat],
            [nextWp.lngLat.lng, nextWp.lngLat.lat],
          ],
          true
        );
        store.setRoutingError('OSRM indisponible — ligne droite affichée');
      } finally {
        store.setRoutingLoading(false);
      }
    },
    [store, routeSegment]
  );

  /** Move a waypoint (debounced OSRM calls for drag) */
  const moveWaypoint = useCallback(
    (id: string, lngLat: LngLat) => {
      store.moveWaypoint(id, lngLat);

      const idx = store.waypoints.findIndex((w) => w.id === id);
      if (idx < 0) return;

      const prevWp = idx > 0 ? store.waypoints[idx - 1] : null;
      const nextWp = idx < store.waypoints.length - 1 ? store.waypoints[idx + 1] : null;

      if (prevWp) {
        debouncedRoute(
          `seg_${prevWp.id}_${id}`,
          prevWp.lngLat,
          lngLat,
          (result) => store.setSegment(prevWp.id, id, result.coordinates),
          () => store.setRoutingError('OSRM indisponible')
        );
      }
      if (nextWp) {
        debouncedRoute(
          `seg_${id}_${nextWp.id}`,
          lngLat,
          nextWp.lngLat,
          (result) => store.setSegment(id, nextWp.id, result.coordinates),
          () => store.setRoutingError('OSRM indisponible')
        );
      }
    },
    [store, debouncedRoute]
  );

  /** Delete a waypoint and reconnect adjacent ones */
  const deleteWaypoint = useCallback(
    async (id: string) => {
      const idx = store.waypoints.findIndex((w) => w.id === id);
      if (idx < 0) return;

      const prevWp = idx > 0 ? store.waypoints[idx - 1] : null;
      const nextWp = idx < store.waypoints.length - 1 ? store.waypoints[idx + 1] : null;

      store.deleteWaypoint(id);

      // Reconnect prev → next if both exist
      if (prevWp && nextWp) {
        store.setRoutingLoading(true);
        try {
          const result = await routeSegment(prevWp.lngLat, nextWp.lngLat);
          if (result) {
            store.setSegment(prevWp.id, nextWp.id, result.coordinates);
          }
        } catch {
          store.setSegment(
            prevWp.id,
            nextWp.id,
            [
              [prevWp.lngLat.lng, prevWp.lngLat.lat],
              [nextWp.lngLat.lng, nextWp.lngLat.lat],
            ],
            true
          );
          store.setRoutingError('OSRM indisponible — ligne droite affichée');
        } finally {
          store.setRoutingLoading(false);
        }
      }
    },
    [store, routeSegment]
  );

  return { addWaypoint, insertWaypoint, moveWaypoint, deleteWaypoint };
}
