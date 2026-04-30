import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_config.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_types.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';

/// Construction du `RaptorNetwork` à partir des `TransportLineGroup`
/// chargés depuis le bundle. Effectue :
///   1. Clustering Union-Find des arrêts (même nom OU proximité).
///   2. Construction des routes RAPTOR (aller + retour comme 2 routes).
///   3. Index inverse stop → routes le desservant.
///   4. Footpaths (transferts piéton ≤ 400m) via grille spatiale.
class RaptorNetworkBuilder {
  RaptorNetworkBuilder._();

  /// Construit le réseau. Coût attendu : O(N²) ≤ 100ms sur 1000 stops
  /// grâce à la grille spatiale.
  static RaptorNetwork build(List<TransportLineGroup> groups) {
    // 1. Collecte de tous les arrêts bruts.
    final raw = <_RawStop>[];
    for (final group in groups) {
      for (final line in group.lines) {
        for (final stop in line.stops) {
          raw.add(_RawStop(
            name: stop.name.trim(),
            nameNorm: _normalizeName(stop.name),
            position: stop.position,
            lineNumber: group.lineNumber,
          ));
        }
      }
    }

    // 2. Clustering Union-Find.
    //    Union si (même nom normalisé ET ≤ 300m) OU (≤ 50m sans nom).
    //    Grille spatiale (cellules 500m) pour ne pas exploser O(N²).
    final dsu = _DSU(raw.length);
    final cell = <int, List<int>>{};
    int cellKey(double lat, double lng) {
      final cx = (lat / RaptorSpatialIndex.cellSizeDeg).floor();
      final cy = (lng / RaptorSpatialIndex.cellSizeDeg).floor();
      return ((cx + 0x100000) << 21) | (cy + 0x100000);
    }

    for (var i = 0; i < raw.length; i++) {
      cell
          .putIfAbsent(
              cellKey(raw[i].position.latitude, raw[i].position.longitude),
              () => <int>[])
          .add(i);
    }

    for (var i = 0; i < raw.length; i++) {
      final a = raw[i];
      final cx = (a.position.latitude / RaptorSpatialIndex.cellSizeDeg)
          .floor();
      final cy = (a.position.longitude / RaptorSpatialIndex.cellSizeDeg)
          .floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final key =
              ((cx + dx + 0x100000) << 21) | (cy + dy + 0x100000);
          final cellList = cell[key];
          if (cellList == null) continue;
          for (final j in cellList) {
            if (j <= i) continue;
            final b = raw[j];
            final distM = _haversineMeters(a.position, b.position);
            final sameName = a.nameNorm.isNotEmpty &&
                b.nameNorm == a.nameNorm;
            final shouldUnion =
                (sameName && distM <= RaptorConfig.sameNameClusterMaxMeters) ||
                    (distM <= RaptorConfig.geometricClusterMaxMeters);
            if (shouldUnion) dsu.union(i, j);
          }
        }
      }
    }

    // 3. Composantes connexes → liste de RaptorStop.
    final components = <int, List<int>>{};
    for (var i = 0; i < raw.length; i++) {
      components.putIfAbsent(dsu.find(i), () => <int>[]).add(i);
    }

    final stops = <RaptorStop>[];
    final rawIdxToStopIdx = List<int>.filled(raw.length, -1);
    var stopIdx = 0;
    for (final entry in components.entries) {
      final members = entry.value;
      // Centroïde + nom canonique (le plus fréquent, fallback non-vide).
      double sumLat = 0;
      double sumLng = 0;
      final nameCounts = <String, int>{};
      final lineSet = <String>{};
      for (final m in members) {
        sumLat += raw[m].position.latitude;
        sumLng += raw[m].position.longitude;
        if (raw[m].name.isNotEmpty) {
          nameCounts.update(raw[m].name, (v) => v + 1, ifAbsent: () => 1);
        }
        lineSet.add(raw[m].lineNumber);
      }
      String canonicalName = '';
      var bestCount = 0;
      nameCounts.forEach((n, c) {
        if (c > bestCount ||
            (c == bestCount && n.length > canonicalName.length)) {
          bestCount = c;
          canonicalName = n;
        }
      });
      final centroid = LatLng(sumLat / members.length, sumLng / members.length);
      stops.add(RaptorStop(
        idx: stopIdx,
        name: canonicalName,
        position: centroid,
        lineNumbers: lineSet.toList()..sort(_compareLineNumber),
      ));
      for (final m in members) {
        rawIdxToStopIdx[m] = stopIdx;
      }
      stopIdx++;
    }

    // 4. Construction des RaptorRoute (aller + retour comme 2 routes).
    //    On itère les lignes dans l'ordre où raw[] a été rempli pour
    //    pouvoir mapper line.stops[i] vers raw_idx, puis vers stop_idx.
    final routes = <RaptorRoute>[];
    var rawCursor = 0;
    var routeIdx = 0;
    for (final group in groups) {
      for (final line in group.lines) {
        if (line.stops.length < 2) {
          rawCursor += line.stops.length;
          continue;
        }
        final stopsSeq = <int>[];
        final travelMin = <int>[];
        // Mappe chaque stop de la ligne vers son cluster.
        // Note : on dédoublonne si 2 stops consécutifs tombent sur le même
        // cluster (cas aller/retour via le même cluster, peu fréquent).
        int? prevStopIdx;
        LatLng? prevPos;
        for (var k = 0; k < line.stops.length; k++) {
          final cur = rawIdxToStopIdx[rawCursor + k];
          if (cur == prevStopIdx) continue; // skip duplicat consécutif
          stopsSeq.add(cur);
          if (prevPos != null) {
            final distKm =
                _haversineMeters(prevPos, line.stops[k].position) / 1000.0;
            travelMin.add(_ceilMin(
                distKm / RaptorConfig.busSpeedKmh * 60.0));
          }
          prevStopIdx = cur;
          prevPos = line.stops[k].position;
        }
        rawCursor += line.stops.length;

        if (stopsSeq.length < 2) {
          continue;
        }

        routes.add(RaptorRoute(
          idx: routeIdx,
          lineNumber: group.lineNumber,
          isRetour: line.isRetour,
          transportType: group.transportType,
          stops: stopsSeq,
          travelMin: travelMin,
          headwayMin: RaptorConfig.defaultHeadwayMin,
          shape: line.coordinates,
          directionLabel: line.stops.isNotEmpty
              ? line.stops.last.name.trim()
              : null,
        ));
        routeIdx++;
      }
    }

    // 5. Index inverse : stopToRoutes[stopIdx] = liste des entries.
    final stopToRoutes =
        List<List<RaptorRouteEntry>>.generate(stops.length, (_) => []);
    for (final r in routes) {
      for (var p = 0; p < r.stops.length; p++) {
        stopToRoutes[r.stops[p]].add(RaptorRouteEntry(r.idx, p));
      }
    }

    // 6. Footpaths : pour chaque pair (i,j) à ≤ 400m, créer un transfert.
    //    Grille spatiale identique au clustering, élargie aux 9 cellules
    //    voisines (cellule 500m, suffisant pour rayon 400m).
    final footpaths =
        List<List<RaptorFootpath>>.generate(stops.length, (_) => []);
    final stopCell = <int, List<int>>{};
    for (final s in stops) {
      stopCell
          .putIfAbsent(
              cellKey(s.position.latitude, s.position.longitude),
              () => <int>[])
          .add(s.idx);
    }
    for (final s in stops) {
      final cx = (s.position.latitude / RaptorSpatialIndex.cellSizeDeg)
          .floor();
      final cy = (s.position.longitude / RaptorSpatialIndex.cellSizeDeg)
          .floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final key =
              ((cx + dx + 0x100000) << 21) | (cy + dy + 0x100000);
          final list = stopCell[key];
          if (list == null) continue;
          for (final tIdx in list) {
            if (tIdx == s.idx) continue;
            final t = stops[tIdx];
            final distM = _haversineMeters(s.position, t.position);
            if (distM > RaptorConfig.footpathRadiusMeters) continue;
            final distKm = distM / 1000.0;
            final dur =
                _ceilMin(distKm / RaptorConfig.walkSpeedKmh * 60.0);
            footpaths[s.idx].add(RaptorFootpath(
              toStopIdx: tIdx,
              durationMin: dur,
              distanceMeters: distM.round(),
            ));
          }
        }
      }
    }

    return RaptorNetwork(
      stops: stops,
      routes: routes,
      stopToRoutes: stopToRoutes,
      footpaths: footpaths,
      spatialIndex: RaptorSpatialIndex.build(stops),
    );
  }

  static String _normalizeName(String s) {
    var t = s.trim().toLowerCase();
    if (t.isEmpty) return t;
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'í': 'i',
      'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final buf = StringBuffer();
    for (final r in t.runes) {
      final ch = String.fromCharCode(r);
      buf.write(accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static int _compareLineNumber(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final h = math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.cos(lat1) *
            math.cos(lat2) *
            math.pow(math.sin(dLng / 2), 2).toDouble();
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static int _ceilMin(double minutes) {
    if (minutes <= 0) return 1;
    return math.max(1, minutes.ceil());
  }
}

class _RawStop {
  final String name;
  final String nameNorm;
  final LatLng position;
  final String lineNumber;
  const _RawStop({
    required this.name,
    required this.nameNorm,
    required this.position,
    required this.lineNumber,
  });
}

/// Disjoint Set Union (Union-Find) avec union par taille + path compression.
/// O(α(n)) amortizé par opération.
class _DSU {
  final List<int> _parent;
  final List<int> _size;
  _DSU(int n)
      : _parent = List.generate(n, (i) => i),
        _size = List.filled(n, 1);

  int find(int x) {
    while (_parent[x] != x) {
      _parent[x] = _parent[_parent[x]]; // path halving
      x = _parent[x];
    }
    return x;
  }

  void union(int a, int b) {
    var ra = find(a);
    var rb = find(b);
    if (ra == rb) return;
    if (_size[ra] < _size[rb]) {
      final t = ra;
      ra = rb;
      rb = t;
    }
    _parent[rb] = ra;
    _size[ra] += _size[rb];
  }
}
