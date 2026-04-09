import { useEffect, useRef, useCallback } from 'react';
import maplibregl from 'maplibre-gl';
import { useEditorStore } from '../store/editorStore';
import { useLineEditor } from '../hooks/useLineEditor';
import { useStopEditor } from '../hooks/useStopEditor';
import { findInsertionIndex, buildFullRoute } from '../utils/geo';
import type { LngLat } from '../types';

const MAP_STYLE = 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';
const CENTER: [number, number] = [47.52, -18.91];
const ZOOM = 13;

export function MapEditor() {
  const mapContainer = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const isDraggingRef = useRef(false);
  const draggedIdRef = useRef<string | null>(null);
  const dragTypeRef = useRef<'waypoint' | 'stop' | null>(null);

  const mode = useEditorStore((s) => s.mode);
  const waypoints = useEditorStore((s) => s.waypoints);
  const segments = useEditorStore((s) => s.segments);
  const stops = useEditorStore((s) => s.stops);
  const lineColor = useEditorStore((s) => s.lineData.lineColor);
  const isRoutingLoading = useEditorStore((s) => s.isRoutingLoading);
  const routingError = useEditorStore((s) => s.routingError);
  const setRoutingError = useEditorStore((s) => s.setRoutingError);

  const { addWaypoint, insertWaypoint, moveWaypoint, deleteWaypoint } = useLineEditor();
  const { addStop, moveStop, deleteStop } = useStopEditor();

  // ---- Initialize map ----
  useEffect(() => {
    if (!mapContainer.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: mapContainer.current,
      style: MAP_STYLE,
      center: CENTER,
      zoom: ZOOM,
    });

    map.addControl(new maplibregl.NavigationControl(), 'bottom-right');

    map.on('load', () => {
      // Route source + layers (border + fill)
      map.addSource('route', {
        type: 'geojson',
        data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [] }, properties: {} },
      });
      map.addLayer({
        id: 'route-border',
        type: 'line',
        source: 'route',
        paint: {
          'line-color': '#000000',
          'line-width': 10,
          'line-opacity': 0.15,
        },
      });
      map.addLayer({
        id: 'route-line',
        type: 'line',
        source: 'route',
        paint: {
          'line-color': '#e74c3c',
          'line-width': 6,
          'line-opacity': 0.9,
        },
        layout: { 'line-cap': 'round', 'line-join': 'round' },
      });

      // Waypoint source + layers
      map.addSource('waypoints', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      });
      map.addLayer({
        id: 'waypoints-circle',
        type: 'circle',
        source: 'waypoints',
        paint: {
          'circle-radius': 8,
          'circle-color': '#ffffff',
          'circle-stroke-color': '#e74c3c',
          'circle-stroke-width': 3,
        },
      });
      map.addLayer({
        id: 'waypoints-label',
        type: 'symbol',
        source: 'waypoints',
        layout: {
          'text-field': ['get', 'label'],
          'text-size': 10,
          'text-font': ['Open Sans Bold'],
          'text-allow-overlap': true,
        },
        paint: { 'text-color': '#333333' },
      });

      // Stop source + layers
      map.addSource('stops', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      });
      map.addLayer({
        id: 'stops-circle',
        type: 'circle',
        source: 'stops',
        paint: {
          'circle-radius': 6,
          'circle-color': '#3498db',
          'circle-stroke-color': '#ffffff',
          'circle-stroke-width': 2,
        },
      });
      map.addLayer({
        id: 'stops-label',
        type: 'symbol',
        source: 'stops',
        layout: {
          'text-field': ['get', 'name'],
          'text-size': 11,
          'text-font': ['Open Sans Regular'],
          'text-offset': [0, 1.5],
          'text-allow-overlap': false,
        },
        paint: {
          'text-color': '#2c3e50',
          'text-halo-color': '#ffffff',
          'text-halo-width': 1.5,
        },
      });
    });

    mapRef.current = map;
    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // ---- Update route layer ----
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.getSource('route')) return;

    const orderedSegments = waypoints
      .slice(0, -1)
      .map((w, i) => {
        const nextW = waypoints[i + 1];
        return segments.find(
          (s) => s.fromWaypointId === w.id && s.toWaypointId === nextW.id
        );
      })
      .filter((s) => s !== undefined);

    const fullRoute = buildFullRoute(orderedSegments);

    (map.getSource('route') as maplibregl.GeoJSONSource).setData({
      type: 'Feature',
      geometry: {
        type: 'LineString',
        coordinates: fullRoute.length >= 2 ? fullRoute : [],
      },
      properties: {},
    });
  }, [segments, waypoints]);

  // ---- Update route color ----
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.getLayer('route-line')) return;
    map.setPaintProperty('route-line', 'line-color', lineColor);
    map.setPaintProperty('waypoints-circle', 'circle-stroke-color', lineColor);
  }, [lineColor]);

  // ---- Update waypoint layer ----
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.getSource('waypoints')) return;

    (map.getSource('waypoints') as maplibregl.GeoJSONSource).setData({
      type: 'FeatureCollection',
      features: waypoints.map((w, i) => ({
        type: 'Feature' as const,
        geometry: {
          type: 'Point' as const,
          coordinates: [w.lngLat.lng, w.lngLat.lat],
        },
        properties: { id: w.id, label: `${i + 1}`, index: i },
      })),
    });
  }, [waypoints]);

  // ---- Update stop layer ----
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.getSource('stops')) return;

    (map.getSource('stops') as maplibregl.GeoJSONSource).setData({
      type: 'FeatureCollection',
      features: stops.map((s) => ({
        type: 'Feature' as const,
        geometry: {
          type: 'Point' as const,
          coordinates: [s.lngLat.lng, s.lngLat.lat],
        },
        properties: { id: s.id, name: s.name, order: s.order },
      })),
    });
  }, [stops]);

  // ---- Cursor ----
  useEffect(() => {
    const canvas = mapRef.current?.getCanvas();
    if (!canvas) return;
    canvas.style.cursor = 'crosshair';
  }, [mode]);

  // ---- Map click handler ----
  const handleMapClick = useCallback(
    (e: maplibregl.MapMouseEvent) => {
      if (isDraggingRef.current) return;
      const map = mapRef.current;
      if (!map) return;

      const lngLat: LngLat = { lng: e.lngLat.lng, lat: e.lngLat.lat };

      // Check if clicking on a waypoint (don't add new one)
      const wpFeatures = map.queryRenderedFeatures(e.point, {
        layers: ['waypoints-circle'],
      });
      if (wpFeatures.length > 0) return;

      // Check if clicking on a stop
      const stopFeatures = map.queryRenderedFeatures(e.point, {
        layers: ['stops-circle'],
      });
      if (stopFeatures.length > 0) {
        const stopId = stopFeatures[0].properties?.id;
        if (stopId) useEditorStore.getState().setSelectedStopId(stopId);
        return;
      }

      if (mode === 'route') {
        // Check if clicking on the route line (insert waypoint)
        const routeFeatures = map.queryRenderedFeatures(e.point, {
          layers: ['route-line'],
        });
        if (routeFeatures.length > 0 && segments.length > 0) {
          const idx = findInsertionIndex(lngLat, segments);
          insertWaypoint(lngLat, idx);
        } else {
          addWaypoint(lngLat);
        }
      } else if (mode === 'stops') {
        addStop(lngLat);
      }
    },
    [mode, segments, addWaypoint, insertWaypoint, addStop]
  );

  // ---- Context menu (right-click delete) ----
  const handleContextMenu = useCallback(
    (e: maplibregl.MapMouseEvent) => {
      e.preventDefault();
      const map = mapRef.current;
      if (!map) return;

      const wpFeatures = map.queryRenderedFeatures(e.point, {
        layers: ['waypoints-circle'],
      });
      if (wpFeatures.length > 0) {
        const wpId = wpFeatures[0].properties?.id;
        if (wpId) deleteWaypoint(wpId);
        return;
      }

      const stopFeatures = map.queryRenderedFeatures(e.point, {
        layers: ['stops-circle'],
      });
      if (stopFeatures.length > 0) {
        const stopId = stopFeatures[0].properties?.id;
        if (stopId) deleteStop(stopId);
      }
    },
    [deleteWaypoint, deleteStop]
  );

  // ---- Drag interactions ----
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const onMouseDown = (e: maplibregl.MapMouseEvent) => {
      // Check waypoints first
      let features = map.queryRenderedFeatures(e.point, {
        layers: ['waypoints-circle'],
      });
      if (features.length > 0) {
        isDraggingRef.current = true;
        draggedIdRef.current = features[0].properties?.id ?? null;
        dragTypeRef.current = 'waypoint';
        map.getCanvas().style.cursor = 'grabbing';
        map.dragPan.disable();
        return;
      }

      // Check stops
      features = map.queryRenderedFeatures(e.point, {
        layers: ['stops-circle'],
      });
      if (features.length > 0) {
        isDraggingRef.current = true;
        draggedIdRef.current = features[0].properties?.id ?? null;
        dragTypeRef.current = 'stop';
        map.getCanvas().style.cursor = 'grabbing';
        map.dragPan.disable();
        return;
      }
    };

    const onMouseMove = (e: maplibregl.MapMouseEvent) => {
      if (!isDraggingRef.current || !draggedIdRef.current) {
        // Hover cursors
        const wpFeats = map.queryRenderedFeatures(e.point, { layers: ['waypoints-circle'] });
        const stopFeats = map.queryRenderedFeatures(e.point, { layers: ['stops-circle'] });
        if (wpFeats.length > 0 || stopFeats.length > 0) {
          map.getCanvas().style.cursor = 'grab';
        } else {
          map.getCanvas().style.cursor = 'crosshair';
        }
        return;
      }

      const lngLat: LngLat = { lng: e.lngLat.lng, lat: e.lngLat.lat };
      if (dragTypeRef.current === 'waypoint') {
        moveWaypoint(draggedIdRef.current, lngLat);
      } else if (dragTypeRef.current === 'stop') {
        moveStop(draggedIdRef.current, lngLat);
      }
    };

    const onMouseUp = () => {
      if (isDraggingRef.current) {
        isDraggingRef.current = false;
        draggedIdRef.current = null;
        dragTypeRef.current = null;
        map.dragPan.enable();
        map.getCanvas().style.cursor = 'crosshair';
      }
    };

    map.on('mousedown', onMouseDown);
    map.on('mousemove', onMouseMove);
    map.on('mouseup', onMouseUp);

    return () => {
      map.off('mousedown', onMouseDown);
      map.off('mousemove', onMouseMove);
      map.off('mouseup', onMouseUp);
    };
  }, [moveWaypoint, moveStop]);

  // ---- Click & contextmenu events ----
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    map.on('click', handleMapClick);
    map.on('contextmenu', handleContextMenu);

    return () => {
      map.off('click', handleMapClick);
      map.off('contextmenu', handleContextMenu);
    };
  }, [handleMapClick, handleContextMenu]);

  return (
    <div style={{ flex: 1, position: 'relative' }}>
      <div ref={mapContainer} style={{ width: '100%', height: '100%' }} />

      {/* Loading indicator */}
      {isRoutingLoading && (
        <div className="map-status loading">Calcul du tracé…</div>
      )}

      {/* Error banner */}
      {routingError && (
        <div className="map-status error" onClick={() => setRoutingError(null)}>
          ⚠ {routingError} (cliquez pour fermer)
        </div>
      )}
    </div>
  );
}
