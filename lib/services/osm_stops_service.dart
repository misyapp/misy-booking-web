import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// Arrêt de bus OSM pré-bundlé (source : Overpass, rayon 40 km autour de Tana).
class OsmStop {
  final String id;
  final String name;
  final LatLng position;
  final Map<String, String> tags;

  OsmStop({
    required this.id,
    required this.name,
    required this.position,
    required this.tags,
  });

  factory OsmStop.fromJson(Map<String, dynamic> j) => OsmStop(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        position: LatLng(
          (j['lat'] as num).toDouble(),
          (j['lng'] as num).toDouble(),
        ),
        tags: ((j['tags'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );

  bool get hasName => name.isNotEmpty;
  String get displayName => hasName ? name : 'Arrêt sans nom';
}

/// Singleton qui expose la liste des arrêts OSM pour l'éditeur terrain.
///
/// Chargé au démarrage via `rootBundle.loadString('assets/osm_bus_stops_tana.json')`.
/// La liste est statique (régénérée à la main via `scripts/fetch_osm_bus_stops.py`).
class OsmStopsService {
  OsmStopsService._();
  static final OsmStopsService instance = OsmStopsService._();

  bool _loaded = false;
  List<OsmStop> _all = const [];

  bool get isLoaded => _loaded;
  int get count => _all.length;
  List<OsmStop> get all => _all;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/osm_bus_stops_tana.json');
      final doc = json.decode(raw) as Map<String, dynamic>;
      final list = (doc['stops'] as List).cast<Map<String, dynamic>>();
      _all = list.map(OsmStop.fromJson).toList(growable: false);
      _loaded = true;
    } catch (e) {
      // Pas bloquant : l'éditeur fonctionnera sans suggestions OSM.
      _all = const [];
      _loaded = true;
    }
  }

  /// Recherche case-insensitive par contains sur le nom.
  /// Limite [max] résultats, triés par prefix-match puis alphabétique.
  List<OsmStop> searchByName(String query, {int max = 30}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final prefix = <OsmStop>[];
    final contains = <OsmStop>[];
    for (final s in _all) {
      if (!s.hasName) continue;
      final n = s.name.toLowerCase();
      if (n.startsWith(q)) {
        prefix.add(s);
      } else if (n.contains(q)) {
        contains.add(s);
      }
      if (prefix.length >= max) break;
    }
    prefix.sort((a, b) => a.name.compareTo(b.name));
    contains.sort((a, b) => a.name.compareTo(b.name));
    final out = [...prefix, ...contains];
    return out.length <= max ? out : out.sublist(0, max);
  }

  /// Arrêts à ≤ [radiusKm] du centre.
  List<OsmStop> nearby(LatLng center, {double radiusKm = 40}) {
    final r2 = radiusKm * radiusKm;
    final out = <OsmStop>[];
    for (final s in _all) {
      final d = _haversineKm(center, s.position);
      if (d * d <= r2) out.add(s);
    }
    return out;
  }

  /// Arrêts visibles dans une bbox (latMin, latMax, lngMin, lngMax).
  List<OsmStop> inBounds({
    required double latMin,
    required double latMax,
    required double lngMin,
    required double lngMax,
  }) {
    final out = <OsmStop>[];
    for (final s in _all) {
      final lat = s.position.latitude;
      final lng = s.position.longitude;
      if (lat >= latMin && lat <= latMax && lng >= lngMin && lng <= lngMax) {
        out.add(s);
      }
    }
    return out;
  }

  static double _haversineKm(LatLng a, LatLng b) {
    const rKm = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * rKm * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
