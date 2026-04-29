import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

/// Résultat de l'analyse géométrique d'une ligne (aller + retour).
///
/// Trois cas :
/// 1. Aller et retour quasi identiques → on n'affiche que `singleSegments`
///    (= aller, sans flèches puisque l'autre direction emprunte le même
///    couloir).
/// 2. Lignes complètement différentes (rare en pratique) → `commonSegments`
///    vide, `allerOnly` et `retourOnly` couvrent tout, flèches sur les deux.
/// 3. Lignes circulaires (cas typique d'un boucle qui contourne un quartier)
///    → `commonSegments` non vide pour le tronc commun, `allerOnly` et
///    `retourOnly` pour les boucles divergentes, flèches sur les boucles.
class LineGeometry {
  final bool isUnified;
  final List<List<LatLng>> singleSegments; // si isUnified
  final List<List<LatLng>> commonSegments;
  final List<List<LatLng>> allerOnly;
  final List<List<LatLng>> retourOnly;

  const LineGeometry._({
    required this.isUnified,
    required this.singleSegments,
    required this.commonSegments,
    required this.allerOnly,
    required this.retourOnly,
  });

  factory LineGeometry.unified(List<LatLng> path) => LineGeometry._(
        isUnified: true,
        singleSegments: [if (path.length >= 2) path],
        commonSegments: const [],
        allerOnly: const [],
        retourOnly: const [],
      );

  factory LineGeometry.split({
    required List<List<LatLng>> common,
    required List<List<LatLng>> allerOnly,
    required List<List<LatLng>> retourOnly,
  }) =>
      LineGeometry._(
        isUnified: false,
        singleSegments: const [],
        commonSegments: common,
        allerOnly: allerOnly,
        retourOnly: retourOnly,
      );
}

class LineGeometryAnalyzer {
  /// Distance max sous laquelle 2 points sont considérés "même couloir".
  /// 50m couvre les boulevards à 2 voies séparées sans assimiler des rues
  /// vraiment distinctes.
  static const double _commonThresholdMeters = 50.0;

  /// Si plus de 85% des deux directions sont communes, on traite comme une
  /// ligne unique (= les divergences résiduelles sont du bruit OSRM).
  static const double _unifiedThreshold = 0.85;

  /// Longueur minimale d'un run pour être rendu (évite les petits artefacts).
  static const int _minRunPoints = 2;

  static LineGeometry analyze(List<LatLng>? aller, List<LatLng>? retour) {
    final a = aller ?? const <LatLng>[];
    final r = retour ?? const <LatLng>[];

    if (a.length < 2 && r.length < 2) {
      return LineGeometry.unified(const []);
    }
    if (a.length < 2) return LineGeometry.unified(r);
    if (r.length < 2) return LineGeometry.unified(a);

    final allerCommon = _commonMask(a, r);
    final retourCommon = _commonMask(r, a);

    final allerRatio = _ratio(allerCommon);
    final retourRatio = _ratio(retourCommon);

    if (allerRatio >= _unifiedThreshold && retourRatio >= _unifiedThreshold) {
      return LineGeometry.unified(a);
    }

    final common = _runs(a, allerCommon, true);
    final allerDivergent = _runs(a, allerCommon, false);
    final retourDivergent = _runs(r, retourCommon, false);

    return LineGeometry.split(
      common: common,
      allerOnly: allerDivergent,
      retourOnly: retourDivergent,
    );
  }

  /// Pour chaque point de [path], renvoie `true` si le point est à <50m
  /// de n'importe quel point de [other]. Préfilter par bounding box pour
  /// limiter le coût brute force (utile sur 50+ points par direction).
  static List<bool> _commonMask(List<LatLng> path, List<LatLng> other) {
    if (other.isEmpty) {
      return List<bool>.filled(path.length, false);
    }
    final result = List<bool>.filled(path.length, false);
    for (var i = 0; i < path.length; i++) {
      final p = path[i];
      var minMeters = double.infinity;
      for (final q in other) {
        // Pré-filtre rapide : delta lat/lng en degrés (~ 1° ≈ 111 km).
        // Évite Haversine pour les points clairement éloignés.
        final dLatDeg = (p.latitude - q.latitude).abs();
        if (dLatDeg > 0.001) continue; // > ~110m d'écart en lat
        final d = _haversineMeters(p, q);
        if (d < minMeters) minMeters = d;
        if (minMeters <= _commonThresholdMeters) break;
      }
      result[i] = minMeters <= _commonThresholdMeters;
    }
    return result;
  }

  static double _ratio(List<bool> mask) {
    if (mask.isEmpty) return 0;
    final commonCount = mask.where((c) => c).length;
    return commonCount / mask.length;
  }

  /// Extrait les runs consécutifs où mask[i] == [wantValue], filtrés par
  /// taille min. Retourne la liste de sous-paths à rendre.
  static List<List<LatLng>> _runs(
    List<LatLng> path,
    List<bool> mask,
    bool wantValue,
  ) {
    final runs = <List<LatLng>>[];
    List<LatLng>? current;
    for (var i = 0; i < path.length; i++) {
      if (mask[i] == wantValue) {
        current ??= <LatLng>[];
        current.add(path[i]);
      } else if (current != null) {
        if (current.length >= _minRunPoints) runs.add(current);
        current = null;
      }
    }
    if (current != null && current.length >= _minRunPoints) runs.add(current);
    return runs;
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0; // mètres
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  /// Bearing en degrés (0 = nord, 90 = est) du point [a] vers [b].
  /// Utilisé pour orienter les markers flèches.
  static double bearingDegrees(LatLng a, LatLng b) {
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return ((math.atan2(y, x) * 180 / math.pi) + 360) % 360;
  }

  /// Calcule des points "guides flèches" pour un sous-segment divergent :
  /// pour chaque sous-séquence de 4 points consécutifs, retourne le 2e
  /// point (= bonne approximation du tiers du segment) avec sa direction.
  /// Au moins 1 flèche par run, max 1 toutes les 6 vertices pour éviter le
  /// clutter.
  static List<({LatLng position, double bearing})> arrowGuidesFor(
    List<LatLng> divergentSegment,
  ) {
    if (divergentSegment.length < 2) return const [];
    final guides = <({LatLng position, double bearing})>[];

    if (divergentSegment.length <= 6) {
      // Petit run : 1 seule flèche au milieu.
      final midIdx = divergentSegment.length ~/ 2;
      final from = divergentSegment[(midIdx - 1).clamp(0, midIdx)];
      final to = divergentSegment[midIdx];
      guides.add((position: to, bearing: bearingDegrees(from, to)));
      return guides;
    }

    // Run plus long : flèches espacées tous les 6 points.
    for (var i = 3; i < divergentSegment.length; i += 6) {
      final from = divergentSegment[i - 1];
      final to = divergentSegment[i];
      guides.add((position: to, bearing: bearingDegrees(from, to)));
    }
    return guides;
  }
}
