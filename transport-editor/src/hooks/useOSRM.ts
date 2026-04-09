import { useCallback, useRef } from 'react';
import type { LngLat } from '../types';

const OSRM_BASE = 'https://osrm2.misy.app/route/v1/driving';

export interface OSRMResult {
  coordinates: [number, number][];
  distance: number;
}

export function useOSRM() {
  const abortControllers = useRef<Map<string, AbortController>>(new Map());
  const debounceTimers = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());

  const fetchRoute = useCallback(
    async (points: LngLat[], signal?: AbortSignal): Promise<OSRMResult | null> => {
      if (points.length < 2) return null;

      const coords = points.map((p) => `${p.lng},${p.lat}`).join(';');
      const url = `${OSRM_BASE}/${coords}?geometries=geojson&overview=full&steps=false`;

      const response = await fetch(url, { signal });
      if (!response.ok) throw new Error(`OSRM error: ${response.status}`);
      const data = await response.json();

      if (data.code !== 'Ok' || !data.routes?.[0]) {
        throw new Error(`OSRM routing failed: ${data.code}`);
      }

      return {
        coordinates: data.routes[0].geometry.coordinates,
        distance: data.routes[0].distance,
      };
    },
    []
  );

  const routeSegment = useCallback(
    async (from: LngLat, to: LngLat, signal?: AbortSignal): Promise<OSRMResult | null> => {
      return fetchRoute([from, to], signal);
    },
    [fetchRoute]
  );

  /** Debounced segment routing for drag operations */
  const debouncedRoute = useCallback(
    (
      key: string,
      from: LngLat,
      to: LngLat,
      onResult: (result: OSRMResult) => void,
      onError: (error: Error) => void
    ) => {
      // Clear previous timer and abort previous request for this key
      const prevTimer = debounceTimers.current.get(key);
      if (prevTimer) clearTimeout(prevTimer);
      const prevController = abortControllers.current.get(key);
      if (prevController) prevController.abort();

      debounceTimers.current.set(
        key,
        setTimeout(async () => {
          const controller = new AbortController();
          abortControllers.current.set(key, controller);
          try {
            const result = await routeSegment(from, to, controller.signal);
            if (result) onResult(result);
          } catch (e) {
            if ((e as Error).name !== 'AbortError') {
              onError(e as Error);
            }
          }
        }, 300)
      );
    },
    [routeSegment]
  );

  const cancelAll = useCallback(() => {
    debounceTimers.current.forEach((t) => clearTimeout(t));
    debounceTimers.current.clear();
    abortControllers.current.forEach((c) => c.abort());
    abortControllers.current.clear();
  }, []);

  return { fetchRoute, routeSegment, debouncedRoute, cancelAll };
}
