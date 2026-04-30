import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_config.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_network.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_pareto.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_query.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_route_builder.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_traceback.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_types.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';

/// Représente un noeud dans le graphe du réseau de transport
class TransportNode {
  final String id;
  final String name;
  final LatLng position;
  final List<String> lineNumbers;

  TransportNode({
    required this.id,
    required this.name,
    required this.position,
    required this.lineNumbers,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransportNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Représente une connexion entre deux noeuds
class TransportEdge {
  final TransportNode from;
  final TransportNode to;
  final String lineNumber;
  final TransportType transportType;
  final double distance;
  final int travelTimeMinutes;
  final bool isWalking;
  final String? direction; // Direction/Terminus de la ligne
  final List<LatLng> pathCoordinates; // Coordonnées du tracé réel

  TransportEdge({
    required this.from,
    required this.to,
    required this.lineNumber,
    required this.transportType,
    required this.distance,
    required this.travelTimeMinutes,
    this.isWalking = false,
    this.direction,
    this.pathCoordinates = const [],
  });
}

/// Type d'étape dans un itinéraire (style IDF Mobilités)
enum RouteStepType {
  walkToStop,      // Marche depuis l'origine vers le premier arrêt
  walkFromStop,    // Marche depuis le dernier arrêt vers la destination
  walkTransfer,    // Marche entre deux arrêts (correspondance)
  transport,       // Trajet en transport en commun
}

/// Représente une étape d'un itinéraire (style IDF Mobilités)
class RouteStep {
  final RouteStepType type;
  final TransportNode? startStop;
  final TransportNode? endStop;
  final String? lineNumber;
  final String? lineName;
  final TransportType? transportType;
  final List<TransportNode> intermediateStops;
  final int durationMinutes;
  final double distanceKm;
  final int distanceMeters;
  final String? direction; // Direction/Terminus
  final LatLng? walkStartPosition; // Pour les étapes de marche
  final LatLng? walkEndPosition;
  final List<LatLng> pathCoordinates; // Coordonnées du tracé réel pour cette étape

  RouteStep({
    required this.type,
    this.startStop,
    this.endStop,
    this.lineNumber,
    this.lineName,
    this.transportType,
    this.intermediateStops = const [],
    required this.durationMinutes,
    this.distanceKm = 0,
    this.distanceMeters = 0,
    this.direction,
    this.walkStartPosition,
    this.walkEndPosition,
    this.pathCoordinates = const [],
  });

  /// Nombre d'arrêts pour cette étape (uniquement pour transport)
  int get numberOfStops => intermediateStops.length + 1;

  /// Est-ce une étape de marche ?
  bool get isWalking => type == RouteStepType.walkToStop ||
                        type == RouteStepType.walkFromStop ||
                        type == RouteStepType.walkTransfer;

  /// Description de l'étape pour l'affichage
  String get description {
    switch (type) {
      case RouteStepType.walkToStop:
        return 'Marcher vers ${startStop?.name ?? "l\'arrêt"}';
      case RouteStepType.walkFromStop:
        return 'Marcher vers votre destination';
      case RouteStepType.walkTransfer:
        return 'Marcher vers ${endStop?.name ?? "l\'arrêt"}';
      case RouteStepType.transport:
        return '${lineName ?? lineNumber} direction ${direction ?? endStop?.name}';
    }
  }
}

/// Représente un itinéraire complet (style IDF Mobilités)
class TransportRoute {
  final List<RouteStep> steps;
  final int totalDurationMinutes;
  final double totalDistanceKm;
  final int numberOfTransfers;
  final LatLng origin;
  final LatLng destination;
  final int walkingTimeMinutes;
  final int walkingDistanceMeters;
  final int transportTimeMinutes;
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  TransportRoute({
    required this.steps,
    required this.totalDurationMinutes,
    required this.totalDistanceKm,
    required this.numberOfTransfers,
    required this.origin,
    required this.destination,
    required this.walkingTimeMinutes,
    required this.walkingDistanceMeters,
    required this.transportTimeMinutes,
    this.departureTime,
    this.arrivalTime,
  });

  /// Obtient toutes les coordonnées du trajet pour l'affichage
  List<LatLng> get allCoordinates {
    final coords = <LatLng>[];
    coords.add(origin);

    for (final step in steps) {
      if (step.isWalking) {
        if (step.walkStartPosition != null) coords.add(step.walkStartPosition!);
        if (step.walkEndPosition != null) coords.add(step.walkEndPosition!);
      } else {
        if (step.startStop != null) coords.add(step.startStop!.position);
        for (final stop in step.intermediateStops) {
          coords.add(stop.position);
        }
        if (step.endStop != null) coords.add(step.endStop!.position);
      }
    }

    coords.add(destination);
    return coords;
  }

  /// Liste des lignes utilisées (sans doublons)
  List<String> get usedLines {
    return steps
        .where((s) => s.type == RouteStepType.transport && s.lineNumber != null)
        .map((s) => s.lineNumber!)
        .toSet()
        .toList();
  }
}

/// Façade publique du moteur de routage. Délègue à RAPTOR
/// (`RaptorNetwork` + `RaptorQuery`) — algo de référence pour le routage
/// transit (Delling/Pajor/Werneck Microsoft Research 2012).
///
/// Conserve la signature historique (`buildFromLines`, `findRoute`,
/// `findMultipleRoutes`, `findNearestStop`, `findNearestStops`) pour ne
/// pas casser l'UI.
class TransportGraph {
  RaptorNetwork? _network;

  /// Compat : map id→TransportNode équivalente à l'ancien TransportGraph.
  /// Construite paresseusement depuis le RaptorNetwork pour ne pas
  /// allouer si pas demandée.
  Map<String, TransportNode> get nodes {
    final net = _network;
    if (net == null) return const {};
    final cached = _cachedNodes;
    if (cached != null) return cached;
    final m = <String, TransportNode>{};
    for (final s in net.stops) {
      final n = _toNode(s);
      m[n.id] = n;
    }
    return _cachedNodes = m;
  }

  Map<String, TransportNode>? _cachedNodes;

  /// Compat : liste plate des edges. Reconstruite paresseusement à partir
  /// des routes RAPTOR (consécutifs stops dans une route → edge transport)
  /// + footpaths → edges piéton. Conservé uniquement pour le logger
  /// `transport_lines_service.dart` qui veut juste le `length`.
  List<TransportEdge> get edges {
    final net = _network;
    if (net == null) return const [];
    final cached = _cachedEdges;
    if (cached != null) return cached;
    final list = <TransportEdge>[];
    final nodesMap = nodes;
    for (final r in net.routes) {
      for (var i = 0; i < r.stops.length - 1; i++) {
        final fromIdx = r.stops[i];
        final toIdx = r.stops[i + 1];
        list.add(TransportEdge(
          from: nodesMap['stop_$fromIdx']!,
          to: nodesMap['stop_$toIdx']!,
          lineNumber: r.lineNumber,
          transportType: r.transportType,
          distance: 0,
          travelTimeMinutes: r.travelMin[i],
          direction: r.directionLabel,
        ));
      }
    }
    for (var s = 0; s < net.footpaths.length; s++) {
      for (final fp in net.footpaths[s]) {
        if (fp.toStopIdx <= s) continue; // dédup
        list.add(TransportEdge(
          from: nodesMap['stop_$s']!,
          to: nodesMap['stop_${fp.toStopIdx}']!,
          lineNumber: 'WALK',
          transportType: TransportType.bus,
          distance: fp.distanceMeters / 1000.0,
          travelTimeMinutes: fp.durationMin,
          isWalking: true,
        ));
      }
    }
    return _cachedEdges = list;
  }

  List<TransportEdge>? _cachedEdges;

  /// Construit le réseau RAPTOR à partir des lignes du bundle. Effectue :
  ///   - Clustering Union-Find des arrêts (même nom OU proximité ≤ 50m).
  ///   - Construction des routes aller + retour (séparées).
  ///   - Index inverse stop→routes.
  ///   - Pre-compute des footpaths (transferts piéton ≤ 400m).
  void buildFromLines(List<TransportLineGroup> lineGroups) {
    _network = RaptorNetworkBuilder.build(lineGroups);
    _cachedNodes = null;
    _cachedEdges = null;
  }

  /// Cherche le 1er stop accessible à pied depuis [position].
  TransportNode? findNearestStop(LatLng position,
      {double maxDistanceKm = 2.0}) {
    final stops = findNearestStops(position,
        maxStops: 1, maxDistanceKm: maxDistanceKm);
    return stops.isNotEmpty ? stops.first : null;
  }

  /// Liste des stops les plus proches (jusqu'à [maxStops]) à ≤ [maxDistanceKm].
  List<TransportNode> findNearestStops(LatLng position,
      {int maxStops = 3, double maxDistanceKm = 2.0}) {
    final net = _network;
    if (net == null) return const [];
    final maxKm = maxDistanceKm;
    final ranked = <MapEntry<RaptorStop, double>>[];
    net.spatialIndex.forEachNearby(position.latitude, position.longitude,
        (stopIdx) {
      final s = net.stops[stopIdx];
      final distKm =
          _haversineMeters(position, s.position) / 1000.0;
      if (distKm <= maxKm) {
        ranked.add(MapEntry(s, distKm));
      }
    });
    // Si la grille n'a renvoyé aucun stop dans le rayon, élargit en
    // scannant tous les stops (cas frontière de cellule). Coût O(N) mais
    // extrêmement rare.
    if (ranked.isEmpty) {
      for (final s in net.stops) {
        final distKm = _haversineMeters(position, s.position) / 1000.0;
        if (distKm <= maxKm) {
          ranked.add(MapEntry(s, distKm));
        }
      }
    }
    ranked.sort((a, b) => a.value.compareTo(b.value));
    return ranked.take(maxStops).map((e) => _toNode(e.key)).toList();
  }

  /// Itinéraire optimal (le plus rapide). `null` si aucun chemin trouvé.
  TransportRoute? findRoute(LatLng origin, LatLng destination) {
    final routes = findMultipleRoutes(origin, destination, maxRoutes: 1);
    return routes.isEmpty ? null : routes.first;
  }

  /// Plusieurs alternatives Pareto-optimales (rapide / peu de
  /// correspondances / peu de marche). Trié par totalDurationMinutes.
  List<TransportRoute> findMultipleRoutes(LatLng origin, LatLng destination,
      {int maxRoutes = 5}) {
    final net = _network;
    if (net == null) return const [];

    // 1. Stops d'accès (origin) et de sortie (destination).
    final originRanked = _rankNearby(net, origin);
    final destRanked = _rankNearby(net, destination);
    if (originRanked.isEmpty || destRanked.isEmpty) return const [];

    // 2. Filtre les stops d'accès dont le walk dépasse maxSingleWalkMin
    //    SAUF s'il s'agit du seul candidat possible. Sécurise la recherche.
    final accessTimes = <int>[];
    final accessStopIdxs = <int>[];
    for (final entry in originRanked) {
      final t = math.max(1,
          (entry.value / RaptorConfig.walkSpeedKmh * 60.0).ceil());
      if (t <= RaptorConfig.maxSingleWalkMin) {
        accessStopIdxs.add(entry.key.idx);
        accessTimes.add(t);
      }
    }
    if (accessStopIdxs.isEmpty) {
      // Fallback : un seul stop (le plus proche).
      final s = originRanked.first.key;
      final t = math.max(1,
          (originRanked.first.value / RaptorConfig.walkSpeedKmh * 60.0)
              .ceil());
      accessStopIdxs.add(s.idx);
      accessTimes.add(t);
    }

    // 3. Pour chaque destStop candidate, lance une query RAPTOR (en
    //    pratique 1 seule suffit car la query produit une matrice
    //    stops×K et on lit le destStop voulu). On boucle sur destinations
    //    candidates pour ne pas forcer une seule sortie.
    final allJourneys = <RaptorJourney>[];
    final query = RaptorQuery(net: net);
    final queryResult = query.run(
      originStopIdxs: accessStopIdxs,
      originAccessTimeMin: accessTimes,
      destStopIdx: destRanked.first.key.idx,
    );

    for (final destEntry in destRanked) {
      final destS = destEntry.key;
      final egressKm = destEntry.value;
      final egressMin = math.max(
          1, (egressKm / RaptorConfig.walkSpeedKmh * 60.0).ceil());
      if (egressMin > RaptorConfig.maxSingleWalkMin) continue;
      final journeys = RaptorTraceback.traceAll(
        net: net,
        result: queryResult,
        destStopIdx: destS.idx,
        originStopIdxs: accessStopIdxs.toSet(),
      );
      // Ajoute le egress au total du journey (déjà compté dans arr[k]
      // côté query : non, l'access l'est mais pas l'egress car la query
      // s'arrête au destStop). On l'incorpore lors du buildRoute() final.
      // Ici on garde les journeys tels quels et on les enrichit dans le
      // builder.
      for (final j in journeys) {
        // On rajoute egressMin au totalMinutes pour le tri Pareto.
        allJourneys.add(RaptorJourney(
          legs: j.legs,
          totalMinutes: j.totalMinutes + egressMin,
          transfers: j.transfers,
          walkMinutes: j.walkMinutes + egressMin,
          rideMinutes: j.rideMinutes,
          boardingRound: j.boardingRound,
        ));
      }
    }

    if (allJourneys.isEmpty) return const [];

    // 4. Pareto + diversification.
    final filtered = RaptorPareto.filter(allJourneys, net, topN: maxRoutes);

    // 5. Build TransportRoute pour chaque journey retenue.
    final result = <TransportRoute>[];
    for (final j in filtered) {
      result.add(RaptorRouteBuilder.build(
        origin: origin,
        destination: destination,
        journey: j,
        net: net,
      ));
    }
    result.sort(
        (a, b) => a.totalDurationMinutes.compareTo(b.totalDurationMinutes));
    return result;
  }

  // ─── Helpers privés ───────────────────────────────────────────────

  List<MapEntry<RaptorStop, double>> _rankNearby(
      RaptorNetwork net, LatLng position) {
    final ranked = <MapEntry<RaptorStop, double>>[];
    net.spatialIndex.forEachNearby(position.latitude, position.longitude,
        (stopIdx) {
      final s = net.stops[stopIdx];
      final distKm = _haversineMeters(position, s.position) / 1000.0;
      if (distKm <= RaptorConfig.accessKm) {
        ranked.add(MapEntry(s, distKm));
      }
    });
    if (ranked.isEmpty) {
      for (final s in net.stops) {
        final distKm = _haversineMeters(position, s.position) / 1000.0;
        if (distKm <= RaptorConfig.accessKm) {
          ranked.add(MapEntry(s, distKm));
        }
      }
    }
    ranked.sort((a, b) => a.value.compareTo(b.value));
    return ranked.take(3).toList();
  }

  TransportNode _toNode(RaptorStop s) => TransportNode(
        id: 'stop_${s.idx}',
        name: s.name,
        position: s.position,
        lineNumbers: List.of(s.lineNumbers),
      );

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
}
