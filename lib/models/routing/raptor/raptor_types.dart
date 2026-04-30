import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';

/// Cluster d'arrêts canonique : tous les "Andoharanofotsy" (même nom OU
/// proximité ≤ 50m) forment 1 seul Stop dans le réseau RAPTOR.
class RaptorStop {
  /// Index dans `RaptorNetwork.stops`. Sert de clé partout.
  final int idx;

  /// Nom canonique (le plus fréquent dans le cluster).
  final String name;

  /// Centroïde du cluster (moyenne des positions).
  final LatLng position;

  /// Numéros de lignes desservant ce cluster (set, pour UI).
  final List<String> lineNumbers;

  const RaptorStop({
    required this.idx,
    required this.name,
    required this.position,
    required this.lineNumbers,
  });
}

/// Une "Route" RAPTOR = séquence ordonnée d'arrêts dans une direction.
/// Chaque ligne réelle (TransportLineGroup) génère 2 RaptorRoute :
/// l'aller et le retour. On NE FUSIONNE PAS aller+retour pour respecter
/// le sens du voyage (un voyageur ne peut pas remonter dans le mauvais
/// sens).
class RaptorRoute {
  final int idx;

  /// Numéro de ligne d'origine (ex "137", "187", "TRAIN_TCE").
  final String lineNumber;

  /// Faux pour l'aller, vrai pour le retour (utilisé pour exposer la
  /// direction dans la timeline).
  final bool isRetour;

  final TransportType transportType;

  /// Index Stop dans `RaptorNetwork.stops`, ordonnés dans le sens du voyage.
  final List<int> stops;

  /// `travelMin[i]` = minutes entre `stops[i]` et `stops[i+1]`.
  /// Longueur = stops.length - 1.
  final List<int> travelMin;

  /// Headway moyen (min) — wait time = headway/2 espérance.
  final double headwayMin;

  /// Coordonnées du tracé OSRM/GeoJSON pour rendu UI. Snapshot du
  /// `TransportLine.coordinates` d'origine.
  final List<LatLng> shape;

  /// Position du terminus (dernier stop) — affichée comme direction.
  final String? directionLabel;

  const RaptorRoute({
    required this.idx,
    required this.lineNumber,
    required this.isRetour,
    required this.transportType,
    required this.stops,
    required this.travelMin,
    required this.headwayMin,
    required this.shape,
    required this.directionLabel,
  });
}

/// Référence d'un stop dans une route : (routeIdx, position dans la route).
/// Utilisé pour `stopToRoutes[stopIdx] = List<RouteEntry>`.
class RaptorRouteEntry {
  final int routeIdx;
  final int stopOrder;
  const RaptorRouteEntry(this.routeIdx, this.stopOrder);
}

/// Footpath (transfert piéton) entre 2 stops à ≤ 400m.
class RaptorFootpath {
  final int toStopIdx;

  /// Durée en minutes (haversine_km / walkSpeed × 60, arrondi up, min 1).
  final int durationMin;

  /// Distance droite en mètres (UI affichage).
  final int distanceMeters;

  const RaptorFootpath({
    required this.toStopIdx,
    required this.durationMin,
    required this.distanceMeters,
  });
}

/// Réseau RAPTOR pré-calculé. Construit 1× par session via
/// `RaptorNetworkBuilder.build(linesGroups)`. Lecture seule ensuite.
class RaptorNetwork {
  final List<RaptorStop> stops;
  final List<RaptorRoute> routes;

  /// Pour chaque stopIdx : routes qui le desservent + position dans la route.
  final List<List<RaptorRouteEntry>> stopToRoutes;

  /// Pour chaque stopIdx : transferts piéton vers d'autres stops ≤ 400m.
  final List<List<RaptorFootpath>> footpaths;

  /// Index spatial pour `findNearestStops(latlng)`. Cellules ~500m.
  final RaptorSpatialIndex spatialIndex;

  const RaptorNetwork({
    required this.stops,
    required this.routes,
    required this.stopToRoutes,
    required this.footpaths,
    required this.spatialIndex,
  });
}

/// Grille spatiale pour la recherche d'arrêts proches en O(1) amortizé.
/// Les cellules font ~500m (cellSizeDeg = 0.005 ≈ 500m latitude).
class RaptorSpatialIndex {
  static const double cellSizeDeg = 0.005;

  final List<RaptorStop> stops;
  final Map<int, List<int>> _cells;

  RaptorSpatialIndex._(this.stops, this._cells);

  factory RaptorSpatialIndex.build(List<RaptorStop> stops) {
    final cells = <int, List<int>>{};
    for (final s in stops) {
      final key = _cellKey(s.position.latitude, s.position.longitude);
      cells.putIfAbsent(key, () => <int>[]).add(s.idx);
    }
    return RaptorSpatialIndex._(stops, cells);
  }

  static int _cellKey(double lat, double lng) {
    final cx = (lat / cellSizeDeg).floor();
    final cy = (lng / cellSizeDeg).floor();
    // Combine 2 ints en un int64 unique. (cx + 1<<20) << 21 | (cy + 1<<20)
    return ((cx + 0x100000) << 21) | (cy + 0x100000);
  }

  /// Itère sur les indices stops dans les 9 cellules autour de (lat,lng).
  /// Le caller filtre ensuite par distance précise.
  void forEachNearby(double lat, double lng, void Function(int stopIdx) visit) {
    final cx = (lat / cellSizeDeg).floor();
    final cy = (lng / cellSizeDeg).floor();
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final key =
            ((cx + dx + 0x100000) << 21) | (cy + dy + 0x100000);
        final list = _cells[key];
        if (list == null) continue;
        for (final idx in list) {
          visit(idx);
        }
      }
    }
  }
}

/// Backward-pointer pour la reconstruction du chemin : "j'ai atteint ce
/// stop au round k en montant à bord de routeIdx, embarqué en
/// boardStopIdx, descendu à alightStopIdx (= ce stop)".
class RaptorTripBack {
  final int routeIdx;
  final int boardStopIdx;
  final int boardStopOrder;
  final int alightStopOrder;
  const RaptorTripBack({
    required this.routeIdx,
    required this.boardStopIdx,
    required this.boardStopOrder,
    required this.alightStopOrder,
  });
}

/// Leg d'un journey RAPTOR avant conversion vers la timeline UI.
sealed class RaptorLeg {
  const RaptorLeg();
}

class RaptorRideLeg extends RaptorLeg {
  final int routeIdx;
  final int boardStopIdx;
  final int alightStopIdx;
  final int boardStopOrder;
  final int alightStopOrder;
  /// Durée embarquée (incluant le wait headway/2 implicite côté algo,
  /// mais on l'inclut explicitement ici pour que la timeline soit juste).
  final int durationMin;
  final int waitMin;
  const RaptorRideLeg({
    required this.routeIdx,
    required this.boardStopIdx,
    required this.alightStopIdx,
    required this.boardStopOrder,
    required this.alightStopOrder,
    required this.durationMin,
    required this.waitMin,
  });
}

class RaptorWalkLeg extends RaptorLeg {
  final int fromStopIdx;
  final int toStopIdx;
  final int durationMin;
  final int distanceMeters;
  const RaptorWalkLeg({
    required this.fromStopIdx,
    required this.toStopIdx,
    required this.durationMin,
    required this.distanceMeters,
  });
}

/// Trajet complet candidat avant conversion vers TransportRoute (UI).
class RaptorJourney {
  final List<RaptorLeg> legs;
  final int totalMinutes;
  final int transfers;
  final int walkMinutes;
  final int rideMinutes;
  /// Round k auquel cette journey est apparue (= nb de boardings).
  final int boardingRound;

  const RaptorJourney({
    required this.legs,
    required this.totalMinutes,
    required this.transfers,
    required this.walkMinutes,
    required this.rideMinutes,
    required this.boardingRound,
  });
}
