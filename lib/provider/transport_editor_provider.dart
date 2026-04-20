import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_ride_hailing_app/models/transport_line_validation.dart';
import 'package:rider_ride_hailing_app/services/transport_editor_service.dart';
import 'package:rider_ride_hailing_app/services/transport_osrm_service.dart';

enum EditorMode { view, modifying, restarting }

/// Représente un arrêt en cours d'édition (avant persistance).
class EditableStop {
  String name;
  LatLng position;
  final String? stopId;

  EditableStop({
    required this.name,
    required this.position,
    this.stopId,
  });

  EditableStop copy() =>
      EditableStop(name: name, position: position, stopId: stopId);
}

/// Un snapshot immutable pour undo/redo.
class _Snapshot {
  final List<LatLng> vertices;
  final List<EditableStop> stops;
  _Snapshot(List<LatLng> v, List<EditableStop> s)
      : vertices = List.unmodifiable(v),
        stops = List.unmodifiable(s.map((e) => e.copy()));
}

class TransportEditorProvider extends ChangeNotifier {
  final TransportEditorService _service = TransportEditorService.instance;

  String? _lineNumber;
  String? get lineNumber => _lineNumber;

  Map<String, dynamic>? _editedDoc;
  Map<String, dynamic>? get editedDoc => _editedDoc;

  EditorStep _step = EditorStep.allerRoute;
  EditorStep get step => _step;

  EditorMode _mode = EditorMode.view;
  EditorMode get mode => _mode;

  // État en cours d'édition (propre à l'étape courante)
  List<LatLng> _vertices = [];
  List<EditableStop> _stops = [];
  List<LatLng> get vertices => List.unmodifiable(_vertices);
  List<EditableStop> get stops => List.unmodifiable(_stops);

  // Undo / redo
  final List<_Snapshot> _undoStack = [];
  final List<_Snapshot> _redoStack = [];
  static const int _maxUndo = 50;

  bool _loading = false;
  bool get isLoading => _loading;

  bool _saving = false;
  bool get isSaving => _saving;

  String? _error;
  String? get error => _error;

  // ─────────── Chargement ligne ───────────

  Future<void> loadLine(String lineNumber, {EditorStep? initialStep}) async {
    _loading = true;
    _error = null;
    _lineNumber = lineNumber;
    notifyListeners();
    try {
      _editedDoc = await _service.loadOrBootstrap(lineNumber);
      setStep(initialStep ?? EditorStep.allerRoute);
    } catch (e) {
      _error = 'Chargement ligne $lineNumber KO: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Change d'étape et recharge les listes de travail depuis le FC courant.
  void setStep(EditorStep step) {
    _step = step;
    _mode = EditorMode.view;
    _reloadWorkingFromDoc();
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  void _reloadWorkingFromDoc() {
    _vertices = [];
    _stops = [];
    final doc = _editedDoc;
    if (doc == null) return;
    final direction = _step.isAller ? 'aller' : 'retour';
    final dir = doc[direction] as Map<String, dynamic>?;
    final fc = dir?['feature_collection'] as Map<String, dynamic>?;
    if (fc == null) return;

    final ls = GeoJsonHelpers.extractLineString(fc);
    _vertices = ls.map((c) => LatLng(c[1], c[0])).toList();

    _stops = GeoJsonHelpers.extractStops(fc).map((f) {
      final g = f['geometry'] as Map<String, dynamic>;
      final coords = g['coordinates'] as List;
      final props = (f['properties'] as Map?) ?? {};
      return EditableStop(
        name: props['name']?.toString() ?? 'Arrêt',
        position: LatLng(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        ),
        stopId: props['stop_id']?.toString(),
      );
    }).toList();
  }

  // ─────────── Modes ───────────

  void setMode(EditorMode mode) {
    _mode = mode;
    if (mode == EditorMode.restarting) {
      _pushUndo();
      if (_step.isRoute) {
        _vertices = [];
      } else {
        _stops = [];
      }
    }
    notifyListeners();
  }

  bool get isEditing =>
      _mode == EditorMode.modifying || _mode == EditorMode.restarting;

  // ─────────── Undo / redo ───────────

  void _pushUndo() {
    _undoStack.add(_Snapshot(_vertices, _stops));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_Snapshot(_vertices, _stops));
    final s = _undoStack.removeLast();
    _vertices = List.of(s.vertices);
    _stops = s.stops.map((e) => e.copy()).toList();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_Snapshot(_vertices, _stops));
    final s = _redoStack.removeLast();
    _vertices = List.of(s.vertices);
    _stops = s.stops.map((e) => e.copy()).toList();
    notifyListeners();
  }

  // ─────────── Édition tracé ───────────

  void moveVertex(int index, LatLng newPos) {
    if (index < 0 || index >= _vertices.length) return;
    _pushUndo();
    _vertices[index] = newPos;
    notifyListeners();
  }

  /// Insère un vertex après [afterIndex]. Si null, append à la fin.
  void insertVertex(LatLng pos, {int? afterIndex}) {
    _pushUndo();
    if (afterIndex == null) {
      _vertices.add(pos);
    } else {
      _vertices.insert(afterIndex + 1, pos);
    }
    notifyListeners();
  }

  void removeVertex(int index) {
    if (index < 0 || index >= _vertices.length) return;
    if (_vertices.length <= 2) return; // garde un min de 2 points
    _pushUndo();
    _vertices.removeAt(index);
    notifyListeners();
  }

  Future<bool> autoRouteBetween(List<LatLng> waypoints) async {
    _pushUndo();
    notifyListeners();
    final coords = await TransportOsrmService.instance.routeDriving(waypoints);
    if (coords == null) return false;
    _vertices = coords.map((c) => LatLng(c[1], c[0])).toList();
    notifyListeners();
    return true;
  }

  // ─────────── Édition arrêts ───────────

  void moveStop(int index, LatLng newPos) {
    if (index < 0 || index >= _stops.length) return;
    _pushUndo();
    _stops[index].position = newPos;
    notifyListeners();
  }

  void addStop(LatLng pos, String name) {
    _pushUndo();
    _stops.add(EditableStop(name: name, position: pos));
    notifyListeners();
  }

  void removeStop(int index) {
    if (index < 0 || index >= _stops.length) return;
    _pushUndo();
    _stops.removeAt(index);
    notifyListeners();
  }

  void renameStop(int index, String name) {
    if (index < 0 || index >= _stops.length) return;
    _pushUndo();
    _stops[index].name = name;
    notifyListeners();
  }

  void reorderStops(int oldIdx, int newIdx) {
    if (oldIdx < 0 || oldIdx >= _stops.length) return;
    if (newIdx > _stops.length) newIdx = _stops.length;
    _pushUndo();
    final item = _stops.removeAt(oldIdx);
    _stops.insert(newIdx > oldIdx ? newIdx - 1 : newIdx, item);
    notifyListeners();
  }

  // ─────────── Persistance ───────────

  /// Valide l'étape telle quelle (aucune modif du doc Firestore).
  Future<bool> validateAsIs() async {
    final line = _lineNumber;
    if (line == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _service.markValidated(line, _step);
      _mode = EditorMode.view;
      return true;
    } catch (e) {
      _error = 'Validation KO: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Commit les modifs locales dans Firestore et sort du mode édition.
  Future<bool> commitEdit() async {
    final line = _lineNumber;
    final doc = _editedDoc;
    if (line == null || doc == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final direction = _step.isAller ? 'aller' : 'retour';
      final existing =
          (doc[direction] as Map?)?['feature_collection'] as Map<String, dynamic>? ??
              GeoJsonHelpers.emptyFeatureCollection(
                  lineNumber: line, direction: direction);

      int? vBefore, vAfter, sBefore, sAfter;
      Map<String, dynamic> updated;

      if (_step.isRoute) {
        vBefore = GeoJsonHelpers.extractLineString(existing).length;
        vAfter = _vertices.length;
        final coords = _vertices
            .map((p) => [p.longitude, p.latitude])
            .toList();
        updated = GeoJsonHelpers.replaceLineString(existing, coords);
      } else {
        sBefore = GeoJsonHelpers.extractStops(existing).length;
        sAfter = _stops.length;
        final stopFeatures = _stops
            .map((s) => GeoJsonHelpers.makeStopFeature(
                  lng: s.position.longitude,
                  lat: s.position.latitude,
                  name: s.name,
                  stopId: s.stopId,
                ))
            .toList();
        updated = GeoJsonHelpers.replaceStops(existing, stopFeatures);
        // MAJ num_stops dans properties root
        final props =
            Map<String, dynamic>.from(updated['properties'] as Map? ?? {});
        props['num_stops'] = _stops.length;
        updated['properties'] = props;
      }

      // Clone Firestore-safe (pas de Timestamp qui traînent)
      updated = json.decode(json.encode(updated));

      await _service.saveStepEdit(
        lineNumber: line,
        step: _step,
        updatedFeatureCollection: updated,
        verticesBefore: vBefore,
        verticesAfter: vAfter,
        stopsBefore: sBefore,
        stopsAfter: sAfter,
      );

      // Met à jour le cache local
      final dirMap =
          Map<String, dynamic>.from(doc[direction] as Map? ?? {});
      dirMap['feature_collection'] = updated;
      _editedDoc = Map<String, dynamic>.from(doc)..[direction] = dirMap;
      _mode = EditorMode.view;
      _undoStack.clear();
      _redoStack.clear();
      return true;
    } catch (e) {
      _error = 'Sauvegarde KO: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Remplace entièrement une direction (tracé + arrêts) avec le résultat
  /// du sub-flow "Construire la ligne". Marque automatiquement les 2 étapes
  /// de la direction à `modified`.
  Future<bool> commitReplaceDirection({
    required String direction, // 'aller' | 'retour'
    required Map<String, dynamic> featureCollection,
    int? numStops,
    int? numVertices,
  }) async {
    final line = _lineNumber;
    if (line == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _service.saveDirectionEdit(
        lineNumber: line,
        direction: direction,
        featureCollection: featureCollection,
        numStops: numStops,
        numVertices: numVertices,
      );
      // Met à jour le cache local
      final doc = _editedDoc ?? <String, dynamic>{};
      final dirMap = Map<String, dynamic>.from(doc[direction] as Map? ?? {});
      dirMap['feature_collection'] = featureCollection;
      _editedDoc = Map<String, dynamic>.from(doc)..[direction] = dirMap;
      _reloadWorkingFromDoc();
      _mode = EditorMode.view;
      return true;
    } catch (e) {
      _error = 'Sauvegarde direction KO: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void reset() {
    _lineNumber = null;
    _editedDoc = null;
    _step = EditorStep.allerRoute;
    _mode = EditorMode.view;
    _vertices = [];
    _stops = [];
    _undoStack.clear();
    _redoStack.clear();
    _error = null;
    notifyListeners();
  }
}
