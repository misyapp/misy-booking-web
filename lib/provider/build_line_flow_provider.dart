import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_ride_hailing_app/services/transport_osrm_service.dart';

enum BuildLineStep { origin, destination, stops, refine, review }

/// Un arrêt saisi par l'user dans le flow.
class FlowStop {
  String name;
  LatLng position;
  final String? osmId;

  FlowStop({required this.name, required this.position, this.osmId});

  FlowStop copy() => FlowStop(name: name, position: position, osmId: osmId);
}

/// Un waypoint intermédiaire (entre 2 arrêts) où le bus passe sans s'arrêter.
class FlowWaypoint {
  LatLng position;
  /// Index de l'arrêt APRÈS lequel ce waypoint est inséré dans la séquence
  /// [origin, stop0, stop1, ..., stopN, destination]. -1 = entre origin et stop0.
  int afterStopIndex;

  FlowWaypoint({required this.position, required this.afterStopIndex});

  FlowWaypoint copy() =>
      FlowWaypoint(position: position, afterStopIndex: afterStopIndex);
}

/// Snapshot immutable de l'état du flow, pour le stack undo.
class _FlowSnapshot {
  final BuildLineStep step;
  final LatLng? origin;
  final String? originName;
  final LatLng? destination;
  final String? destinationName;
  final List<FlowStop> stops;
  final List<FlowWaypoint> waypoints;
  final List<List<double>> routeCoords;
  final bool routeDirty;

  _FlowSnapshot({
    required this.step,
    required this.origin,
    required this.originName,
    required this.destination,
    required this.destinationName,
    required this.stops,
    required this.waypoints,
    required this.routeCoords,
    required this.routeDirty,
  });
}

/// State machine du sub-flow "Construire la ligne" (4 sous-étapes).
///
/// Indépendant de TransportEditorProvider : il représente une session de
/// construction (ou modification-reconstruction) d'une direction de ligne.
class BuildLineFlowProvider extends ChangeNotifier {
  BuildLineStep _step = BuildLineStep.origin;
  BuildLineStep get step => _step;

  LatLng? _origin;
  String? _originName;
  LatLng? _destination;
  String? _destinationName;

  final List<FlowStop> _stops = [];
  final List<FlowWaypoint> _waypoints = [];

  List<List<double>> _routeCoords = const []; // [lng, lat]
  bool _isRouting = false;
  String? _error;

  /// True dès qu'une mutation structurelle a été faite depuis le dernier
  /// `_recompute` réussi. Utilisé par l'étape review pour bloquer "Terminer"
  /// tant que la route affichée ne reflète pas les modifications.
  bool _routeDirty = false;
  bool get isRouteDirty => _routeDirty;

  // Undo stack : snapshots immutables pris AVANT chaque mutation
  final List<_FlowSnapshot> _undoStack = [];
  static const int _maxUndo = 50;

  bool get canUndo => _undoStack.isNotEmpty;

  LatLng? get origin => _origin;
  String? get originName => _originName;
  LatLng? get destination => _destination;
  String? get destinationName => _destinationName;
  List<FlowStop> get stops => List.unmodifiable(_stops);
  List<FlowWaypoint> get waypoints => List.unmodifiable(_waypoints);
  List<List<double>> get routeCoords => _routeCoords;
  bool get isRouting => _isRouting;
  String? get error => _error;

  bool get hasRoute => _routeCoords.isNotEmpty;

  bool get canGoNext {
    switch (_step) {
      case BuildLineStep.origin:
        return _origin != null;
      case BuildLineStep.destination:
        return _destination != null;
      case BuildLineStep.stops:
        return _stops.length >= 2 && hasRoute;
      case BuildLineStep.refine:
        return hasRoute;
      case BuildLineStep.review:
        // Terminer reste actif même si dirty : `_onFinish` tente un dernier
        // recompute, et si OSRM échoue, demande confirmation à l'user
        // (sinon on bloque l'user en cas d'OSRM down).
        return hasRoute && _stops.length >= 2;
    }
  }

  void _pushSnapshot() {
    _undoStack.add(_FlowSnapshot(
      step: _step,
      origin: _origin,
      originName: _originName,
      destination: _destination,
      destinationName: _destinationName,
      stops: _stops.map((s) => s.copy()).toList(),
      waypoints: _waypoints.map((w) => w.copy()).toList(),
      routeCoords: List<List<double>>.from(_routeCoords),
      routeDirty: _routeDirty,
    ));
    if (_undoStack.length > _maxUndo) {
      _undoStack.removeAt(0);
    }
  }

  /// Annule la dernière mutation. Retourne false si rien à annuler.
  bool undo() {
    if (_undoStack.isEmpty) return false;
    final s = _undoStack.removeLast();
    _step = s.step;
    _origin = s.origin;
    _originName = s.originName;
    _destination = s.destination;
    _destinationName = s.destinationName;
    _stops
      ..clear()
      ..addAll(s.stops);
    _waypoints
      ..clear()
      ..addAll(s.waypoints);
    _routeCoords = s.routeCoords;
    _routeDirty = s.routeDirty;
    _error = null;
    notifyListeners();
    return true;
  }

  void setStep(BuildLineStep s) {
    if (s == _step) return;
    _pushSnapshot();
    _step = s;
    _error = null;
    notifyListeners();
  }

  void setOrigin(LatLng pos, {String? name}) {
    _pushSnapshot();
    _origin = pos;
    if (name != null) _originName = name;
    _routeDirty = true;
    notifyListeners();
  }

  void setDestination(LatLng pos, {String? name}) {
    _pushSnapshot();
    _destination = pos;
    if (name != null) _destinationName = name;
    _routeDirty = true;
    notifyListeners();
  }

  Future<bool> recomputeInitialRoute() async {
    if (_origin == null || _destination == null) return false;
    return _recompute([_origin!, _destination!]);
  }

  Future<bool> recomputeFullRoute() async {
    if (_origin == null || _destination == null) return false;
    // Séquence OSRM : origin → [waypoints -1] → stop[0] → [waypoints 0] →
    // stop[1] → [waypoints 1] → ... → stop[N] → [waypoints N] → destination.
    final seq = <LatLng>[_origin!];
    // Waypoints avant le premier arrêt (afterStopIndex == -1)
    for (final w in _waypoints.where((w) => w.afterStopIndex == -1)) {
      seq.add(w.position);
    }
    for (int i = 0; i < _stops.length; i++) {
      seq.add(_stops[i].position);
      for (final w in _waypoints.where((w) => w.afterStopIndex == i)) {
        seq.add(w.position);
      }
    }
    seq.add(_destination!);
    return _recompute(seq);
  }

  Future<bool> _recompute(List<LatLng> seq) async {
    _pushSnapshot();
    _isRouting = true;
    _error = null;
    notifyListeners();
    try {
      final coords = await TransportOsrmService.instance.routeDriving(seq);
      if (coords == null) {
        _error = 'OSRM n\'a pas pu calculer le tracé';
        return false;
      }
      _routeCoords = coords;
      _routeDirty = false;
      return true;
    } finally {
      _isRouting = false;
      notifyListeners();
    }
  }

  void addStop(LatLng pos, String name, {String? osmId}) {
    _pushSnapshot();
    _stops.add(FlowStop(name: name, position: pos, osmId: osmId));
    _routeDirty = true;
    notifyListeners();
  }

  /// Insère un arrêt à la position donnée dans la liste. Les arrêts qui
  /// suivaient sont décalés (leur numéro UI augmente de 1, gratuitement via
  /// l'index). Les waypoints dont l'`afterStopIndex >= index` sont incrémentés
  /// de 1 pour rester attachés au même stop logique après décalage.
  ///
  /// Utilisé par l'étape review pour "insérer un arrêt entre 2 arrêts
  /// existants" sans refaire tout le flow.
  void insertStopAt(int index, LatLng pos, String name, {String? osmId}) {
    final safeIdx = index.clamp(0, _stops.length);
    _pushSnapshot();
    _stops.insert(safeIdx, FlowStop(name: name, position: pos, osmId: osmId));
    for (final w in _waypoints) {
      if (w.afterStopIndex >= safeIdx) w.afterStopIndex++;
    }
    _routeDirty = true;
    notifyListeners();
  }

  /// Trouve le segment le plus proche de [pos] dans la séquence
  /// `[origin, stop₀, …, stopₙ, destination]` et insère l'arrêt au bon index.
  /// Retourne l'index auquel l'arrêt a été inséré (pratique pour un snackbar
  /// "arrêt inséré à la position N").
  int insertStopAtClosestSegment(LatLng pos, String name, {String? osmId}) {
    final sequence = <LatLng>[
      if (_origin != null) _origin!,
      ..._stops.map((s) => s.position),
      if (_destination != null) _destination!,
    ];
    // Fallback : si pas encore d'origin/destination, append à la fin.
    if (sequence.length < 2) {
      addStop(pos, name, osmId: osmId);
      return _stops.length - 1;
    }
    int bestSegment = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < sequence.length - 1; i++) {
      final d = _pointToSegmentDist(pos, sequence[i], sequence[i + 1]);
      if (d < bestDist) {
        bestDist = d;
        bestSegment = i;
      }
    }
    // Le segment `k` (0-indexé) va entre `sequence[k]` et `sequence[k+1]`.
    // Comme sequence[0] est origin, sequence[1] est stops[0], etc., insérer
    // au segment `k` = insérer à l'index `k` dans `_stops`.
    insertStopAt(bestSegment, pos, name, osmId: osmId);
    return bestSegment;
  }

  void removeStop(int index) {
    if (index < 0 || index >= _stops.length) return;
    _pushSnapshot();
    _stops.removeAt(index);
    // Les waypoints qui étaient après ce stop : on réindexe
    for (final w in _waypoints) {
      if (w.afterStopIndex > index) w.afterStopIndex--;
      if (w.afterStopIndex >= _stops.length) {
        w.afterStopIndex = _stops.length - 1;
      }
    }
    _routeDirty = true;
    notifyListeners();
  }

  void renameStop(int index, String name) {
    if (index < 0 || index >= _stops.length) return;
    _pushSnapshot();
    _stops[index].name = name;
    // Pas de dirty : le nom ne change pas la géométrie de la route.
    notifyListeners();
  }

  void moveStop(int index, LatLng pos) {
    if (index < 0 || index >= _stops.length) return;
    _pushSnapshot();
    _stops[index].position = pos;
    _routeDirty = true;
    notifyListeners();
  }

  void reorderStops(int oldIdx, int newIdx) {
    if (oldIdx < 0 || oldIdx >= _stops.length) return;
    if (newIdx > _stops.length) newIdx = _stops.length;
    _pushSnapshot();
    final s = _stops.removeAt(oldIdx);
    _stops.insert(newIdx > oldIdx ? newIdx - 1 : newIdx, s);
    _routeDirty = true;
    notifyListeners();
  }

  /// Déplace l'arrêt à `currentIdx` pour qu'il finisse à l'index `desiredIdx`
  /// (les deux 0-based). Variante "ergonomique" de [reorderStops] qui prend
  /// directement la position finale visée plutôt que la sémantique Flutter
  /// onReorder. No-op si la position est inchangée ou hors bornes.
  void setStopOrder(int currentIdx, int desiredIdx) {
    if (currentIdx < 0 || currentIdx >= _stops.length) return;
    final clamped = desiredIdx.clamp(0, _stops.length - 1);
    if (clamped == currentIdx) return;
    final reorderIdx = clamped > currentIdx ? clamped + 1 : clamped;
    reorderStops(currentIdx, reorderIdx);
  }

  /// Ajoute un waypoint en l'insérant dans le segment (arrêt A → arrêt B)
  /// le plus proche géographiquement.
  void addWaypoint(LatLng pos) {
    int closestIdx = -1; // -1 = entre origin et stop[0]
    double closestDist = double.infinity;

    final sequence = <LatLng>[
      if (_origin != null) _origin!,
      ..._stops.map((s) => s.position),
      if (_destination != null) _destination!,
    ];

    for (int i = 0; i < sequence.length - 1; i++) {
      final d = _pointToSegmentDist(pos, sequence[i], sequence[i + 1]);
      if (d < closestDist) {
        closestDist = d;
        closestIdx = i - 1; // i=0 → afterStopIndex=-1 (entre origin et stop0)
      }
    }

    _pushSnapshot();
    _waypoints.add(FlowWaypoint(position: pos, afterStopIndex: closestIdx));
    _routeDirty = true;
    notifyListeners();
  }

  void removeWaypoint(int index) {
    if (index < 0 || index >= _waypoints.length) return;
    _pushSnapshot();
    _waypoints.removeAt(index);
    _routeDirty = true;
    notifyListeners();
  }

  void moveWaypoint(int index, LatLng pos) {
    if (index < 0 || index >= _waypoints.length) return;
    _pushSnapshot();
    _waypoints[index].position = pos;
    _routeDirty = true;
    notifyListeners();
  }

  /// Distance approximative point → segment (en degrés² ; on compare pas en m).
  double _pointToSegmentDist(LatLng p, LatLng a, LatLng b) {
    final px = p.longitude, py = p.latitude;
    final ax = a.longitude, ay = a.latitude;
    final bx = b.longitude, by = b.latitude;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) {
      final ddx = px - ax, ddy = py - ay;
      return ddx * ddx + ddy * ddy;
    }
    var t = ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    final ex = px - cx, ey = py - cy;
    return ex * ex + ey * ey;
  }

  /// Construit le FeatureCollection final pour Firestore (hydraté côté app,
  /// sérialisé en JSON string côté storage par le service).
  Map<String, dynamic> buildFeatureCollection({
    required String lineNumber,
    required String direction,
  }) {
    final features = <Map<String, dynamic>>[];

    if (_routeCoords.isNotEmpty) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': _routeCoords,
        },
        'properties': {
          'kind': 'route',
          'source': 'misy-editor-build-flow',
        },
      });
    }

    // Stops + origin + destination comme Features Point type=stop
    int order = 0;
    if (_origin != null) {
      features.add(_stopFeature(_origin!, _originName ?? 'Terminus départ',
          role: 'origin', order: order++));
    }
    for (final s in _stops) {
      features.add(_stopFeature(
        s.position,
        s.name,
        order: order++,
        osmId: s.osmId,
      ));
    }
    if (_destination != null) {
      features.add(_stopFeature(
          _destination!, _destinationName ?? 'Terminus arrivée',
          role: 'destination', order: order++));
    }

    // Waypoints (intermédiaires, type=waypoint)
    for (final w in _waypoints) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [w.position.longitude, w.position.latitude],
        },
        'properties': {
          'type': 'waypoint',
          'after_stop': w.afterStopIndex,
        },
      });
    }

    final numStops = 2 + _stops.length; // origin + arrêts + destination

    return {
      'type': 'FeatureCollection',
      'properties': {
        'line': lineNumber,
        'direction': direction,
        'source': 'misy-editor-build-flow',
        'num_stops': numStops,
        'num_waypoints': _waypoints.length,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
      'features': features,
    };
  }

  Map<String, dynamic> _stopFeature(
    LatLng pos,
    String name, {
    required int order,
    String? role,
    String? osmId,
  }) {
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [pos.longitude, pos.latitude],
      },
      'properties': {
        'type': 'stop',
        'name': name,
        'order': order,
        if (role != null) 'role': role,
        if (osmId != null) 'osm_id': osmId,
      },
    };
  }

  void reset() {
    _step = BuildLineStep.origin;
    _origin = null;
    _originName = null;
    _destination = null;
    _destinationName = null;
    _stops.clear();
    _waypoints.clear();
    _routeCoords = const [];
    _isRouting = false;
    _error = null;
    _routeDirty = false;
    notifyListeners();
  }

  /// Charge le state depuis un FeatureCollection existant (inverse de
  /// [toFeatureCollection]). Utilisé pour le mode "Modifier (sans tout refaire)" :
  /// on hydrate origin/destination/stops/waypoints/route, on positionne
  /// `_routeDirty=false` (la route reflète déjà les arrêts), et on saute
  /// directement à [startStep] (typiquement [BuildLineStep.review]).
  ///
  /// Le format attendu suit celui produit par [_stopFeature] :
  ///   - LineString → routeCoords
  ///   - Point properties.role='origin' → origin
  ///   - Point properties.role='destination' → destination
  ///   - Point properties.type='stop' (sans role) → stop régulier
  ///   - Point properties.type='waypoint' + after_stop → waypoint
  void hydrateFromFeatureCollection({
    required Map<String, dynamic> fc,
    BuildLineStep startStep = BuildLineStep.review,
  }) {
    // Reset complet d'abord pour partir d'un état propre, sans pousser de
    // snapshot (on ne veut pas que cette hydration soit "annulable").
    _origin = null;
    _originName = null;
    _destination = null;
    _destinationName = null;
    _stops.clear();
    _waypoints.clear();
    _routeCoords = const [];
    _undoStack.clear();
    _error = null;

    final features = fc['features'] as List? ?? const [];

    // Stops intermédiaires : on collecte d'abord par order pour préserver l'ordre.
    final intermediates = <({int order, FlowStop stop})>[];
    final waypointEntries = <FlowWaypoint>[];

    for (final f in features) {
      final geom = f['geometry'] as Map?;
      if (geom == null) continue;
      final props = (f['properties'] as Map?) ?? const {};

      if (geom['type'] == 'LineString') {
        final coords = geom['coordinates'] as List? ?? const [];
        _routeCoords = [
          for (final c in coords)
            <double>[(c[0] as num).toDouble(), (c[1] as num).toDouble()],
        ];
      } else if (geom['type'] == 'Point') {
        final c = geom['coordinates'] as List;
        final pos = LatLng(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        );
        final pType = props['type'] as String?;
        final role = props['role'] as String?;
        final name = (props['name'] as String?)?.trim() ?? '';
        final osmId = props['osm_id'] as String?;

        if (pType == 'waypoint') {
          final after = (props['after_stop'] as num?)?.toInt() ?? -1;
          waypointEntries.add(
              FlowWaypoint(position: pos, afterStopIndex: after));
        } else if (role == 'origin') {
          _origin = pos;
          _originName = name.isEmpty ? null : name;
        } else if (role == 'destination') {
          _destination = pos;
          _destinationName = name.isEmpty ? null : name;
        } else {
          // stop régulier
          final order = (props['order'] as num?)?.toInt() ?? 999;
          intermediates.add((
            order: order,
            stop: FlowStop(name: name, position: pos, osmId: osmId),
          ));
        }
      }
    }

    intermediates.sort((a, b) => a.order.compareTo(b.order));
    _stops.addAll(intermediates.map((e) => e.stop));
    _waypoints.addAll(waypointEntries);

    _step = startStep;
    // Le tracé existe déjà et reflète les arrêts → pas dirty.
    _routeDirty = false;
    notifyListeners();
  }
}
