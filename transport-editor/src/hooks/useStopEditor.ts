import { useCallback } from 'react';
import { useEditorStore } from '../store/editorStore';
import { snapToLine } from '../utils/geo';
import type { LngLat, Stop } from '../types';

export function useStopEditor() {
  const store = useEditorStore();

  /** Add a stop snapped to the route at the clicked position */
  const addStop = useCallback(
    (clickLngLat: LngLat) => {
      const routeCoords = store.getFullRoute();
      if (routeCoords.length < 2) return;

      const { snapped, lineFraction, distance } = snapToLine(clickLngLat, routeCoords);

      // Ignore clicks too far from the route (200m)
      if (distance > 200) return;

      const newStop: Stop = {
        id: crypto.randomUUID(),
        lngLat: snapped,
        name: `Arrêt ${store.stops.length + 1}`,
        order: 0,
        lineFraction,
      };

      store.addStop(newStop);
    },
    [store]
  );

  /** Move a stop, re-projecting it onto the route */
  const moveStop = useCallback(
    (id: string, newLngLat: LngLat) => {
      const routeCoords = store.getFullRoute();
      if (routeCoords.length < 2) return;

      const { snapped, lineFraction } = snapToLine(newLngLat, routeCoords);
      store.moveStop(id, snapped, lineFraction);
    },
    [store]
  );

  const deleteStop = useCallback(
    (id: string) => {
      store.deleteStop(id);
    },
    [store]
  );

  const renameStop = useCallback(
    (id: string, name: string) => {
      store.renameStop(id, name);
    },
    [store]
  );

  const selectStop = useCallback(
    (id: string | null) => {
      store.setSelectedStopId(id);
    },
    [store]
  );

  return { addStop, moveStop, deleteStop, renameStop, selectStop };
}
