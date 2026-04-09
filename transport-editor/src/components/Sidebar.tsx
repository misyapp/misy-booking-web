import { useState, useRef } from 'react';
import { useEditorStore } from '../store/editorStore';
import { useStopEditor } from '../hooks/useStopEditor';
import { useUndoRedo } from '../hooks/useUndoRedo';
import { importGeoJSON, exportGeoJSON, downloadGeoJSON } from '../utils/geojson';
import { buildFullRoute, calculateRouteDistance } from '../utils/geo';
import type { RouteSegment } from '../types';

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const mode = useEditorStore((s) => s.mode);
  const setMode = useEditorStore((s) => s.setMode);
  const lineData = useEditorStore((s) => s.lineData);
  const updateLineData = useEditorStore((s) => s.updateLineData);
  const waypoints = useEditorStore((s) => s.waypoints);
  const segments = useEditorStore((s) => s.segments);
  const stops = useEditorStore((s) => s.stops);
  const selectedStopId = useEditorStore((s) => s.selectedStopId);
  const importData = useEditorStore((s) => s.importData);
  const clearAll = useEditorStore((s) => s.clearAll);

  const { deleteStop, renameStop, selectStop } = useStopEditor();
  const { undo, redo } = useUndoRedo();

  // Compute stats
  const orderedSegments = waypoints
    .slice(0, -1)
    .map((w, i) => {
      const nextW = waypoints[i + 1];
      return segments.find(
        (s) => s.fromWaypointId === w.id && s.toWaypointId === nextW.id
      );
    })
    .filter((s): s is RouteSegment => s !== undefined);
  const fullRoute = buildFullRoute(orderedSegments);
  const totalDistance = calculateRouteDistance(fullRoute);

  const handleExport = () => {
    const data = exportGeoJSON(lineData, waypoints, stops, fullRoute);
    const filename = lineData.lineName.replace(/\s+/g, '_').toLowerCase() + '.geojson';
    downloadGeoJSON(data, filename);
  };

  const handleImport = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (ev) => {
      try {
        const geojson = JSON.parse(ev.target?.result as string);
        const result = importGeoJSON(geojson);

        // Build segments from waypoints + route coordinates
        const importSegments: RouteSegment[] = [];
        for (let i = 0; i < result.waypoints.length - 1; i++) {
          const from = result.waypoints[i];
          const to = result.waypoints[i + 1];
          // For imported files, use the full route coordinates split between waypoints
          // Simplified: create one segment with all route coords
          if (i === 0) {
            importSegments.push({
              fromWaypointId: from.id,
              toWaypointId: to.id,
              coordinates: result.routeCoordinates,
            });
          } else {
            // Additional segments are empty placeholders; the route is in segment 0
            importSegments.push({
              fromWaypointId: from.id,
              toWaypointId: to.id,
              coordinates: [],
            });
          }
        }

        // Better approach: put all coordinates in a single segment between first and last waypoint
        const singleSegment: RouteSegment[] =
          result.waypoints.length >= 2
            ? [
                {
                  fromWaypointId: result.waypoints[0].id,
                  toWaypointId: result.waypoints[result.waypoints.length - 1].id,
                  coordinates: result.routeCoordinates,
                },
              ]
            : [];

        importData(result.waypoints, result.stops, singleSegment, result.lineData);
      } catch (err) {
        alert('Erreur lors de l\'import: ' + (err as Error).message);
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  const handleClear = () => {
    if (confirm('Tout effacer ? Cette action est irréversible.')) {
      clearAll();
    }
  };

  if (collapsed) {
    return (
      <div className="sidebar collapsed">
        <button className="sidebar-toggle" onClick={() => setCollapsed(false)} title="Ouvrir le panneau">
          ▶
        </button>
      </div>
    );
  }

  return (
    <aside className="sidebar">
      <button className="sidebar-toggle" onClick={() => setCollapsed(true)} title="Fermer le panneau">
        ◀
      </button>

      <div className="sidebar-content">
        {/* Header */}
        <h1 className="sidebar-title">🚍 Éditeur Taxi Be</h1>

        {/* Line info */}
        <section className="section">
          <label className="section-label">Nom de la ligne</label>
          <input
            type="text"
            value={lineData.lineName}
            onChange={(e) => updateLineData({ lineName: e.target.value })}
            className="input"
          />
          <div style={{ display: 'flex', gap: 8, marginTop: 8, alignItems: 'center' }}>
            <label className="section-label" style={{ margin: 0 }}>Couleur</label>
            <input
              type="color"
              value={lineData.lineColor}
              onChange={(e) => updateLineData({ lineColor: e.target.value })}
              className="color-picker"
            />
            <span style={{ fontSize: 12, color: '#888' }}>{lineData.lineColor}</span>
          </div>
        </section>

        {/* Stats */}
        <section className="section stats-bar">
          <span>{(totalDistance / 1000).toFixed(1)} km</span>
          <span>{stops.length} arrêts</span>
          <span>{waypoints.length} pts</span>
        </section>

        {/* Mode selector */}
        <section className="section">
          <div className="mode-toggle">
            <button
              className={`mode-btn ${mode === 'route' ? 'active' : ''}`}
              onClick={() => setMode('route')}
            >
              ✏️ Tracé
            </button>
            <button
              className={`mode-btn ${mode === 'stops' ? 'active' : ''}`}
              onClick={() => setMode('stops')}
            >
              📍 Arrêts
            </button>
          </div>
          <div className="mode-hint">
            {mode === 'route'
              ? 'Cliquez sur la carte pour ajouter des points. Clic droit pour supprimer.'
              : 'Cliquez sur le tracé pour ajouter un arrêt. Clic droit pour supprimer.'}
          </div>
        </section>

        {/* Stop list */}
        <section className="section stop-list-section">
          <label className="section-label">Arrêts ({stops.length})</label>
          <div className="stop-list">
            {stops.length === 0 && (
              <div className="empty-state">Aucun arrêt. Passez en mode Arrêts pour en ajouter.</div>
            )}
            {stops.map((stop) => (
              <div
                key={stop.id}
                className={`stop-item ${selectedStopId === stop.id ? 'selected' : ''}`}
                onClick={() => selectStop(stop.id)}
              >
                <span className="stop-order">{stop.order}</span>
                <input
                  type="text"
                  value={stop.name}
                  onChange={(e) => renameStop(stop.id, e.target.value)}
                  className="stop-name-input"
                  onClick={(e) => e.stopPropagation()}
                />
                <button
                  className="stop-delete-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    deleteStop(stop.id);
                  }}
                  title="Supprimer"
                >
                  ×
                </button>
              </div>
            ))}
          </div>
        </section>

        {/* Actions */}
        <section className="section actions">
          <div style={{ display: 'flex', gap: 4 }}>
            <button className="action-btn" onClick={() => undo()} title="Annuler (Ctrl+Z)">
              ↩
            </button>
            <button className="action-btn" onClick={() => redo()} title="Refaire (Ctrl+Shift+Z)">
              ↪
            </button>
          </div>
          <button className="action-btn primary" onClick={handleExport}>
            Exporter GeoJSON
          </button>
          <button className="action-btn" onClick={handleImport}>
            Importer GeoJSON
          </button>
          <button className="action-btn danger" onClick={handleClear}>
            Tout effacer
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept=".geojson,.json"
            style={{ display: 'none' }}
            onChange={handleFileChange}
          />
        </section>
      </div>
    </aside>
  );
}
