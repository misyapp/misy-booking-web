import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

/// Graphe du réseau de transport pour le calcul d'itinéraire
class TransportGraph {
  final Map<String, TransportNode> nodes = {};
  final List<TransportEdge> edges = [];
  final Map<String, List<TransportEdge>> adjacencyList = {};
  final Map<String, String> _lineDirections = {}; // lineNumber -> terminus

  void buildFromLines(List<TransportLineGroup> lineGroups) {
    nodes.clear();
    edges.clear();
    adjacencyList.clear();
    _lineDirections.clear();

    // Première passe : créer tous les noeuds et noter les terminus
    for (final group in lineGroups) {
      for (final line in group.lines) {
        // Le terminus est le dernier arrêt de la ligne
        if (line.stops.isNotEmpty) {
          _lineDirections['${group.lineNumber}_${line.isRetour ? 'retour' : 'aller'}'] =
              line.stops.last.name;
        }

        for (final stop in line.stops) {
          final nodeId = _normalizeStopId(stop.name, stop.position);

          if (nodes.containsKey(nodeId)) {
            if (!nodes[nodeId]!.lineNumbers.contains(group.lineNumber)) {
              nodes[nodeId]!.lineNumbers.add(group.lineNumber);
            }
          } else {
            nodes[nodeId] = TransportNode(
              id: nodeId,
              name: stop.name,
              position: stop.position,
              lineNumbers: [group.lineNumber],
            );
          }
        }
      }
    }

    // Deuxième passe : créer les arêtes avec direction et tracé réel
    for (final group in lineGroups) {
      for (final line in group.lines) {
        final direction = line.stops.isNotEmpty ? line.stops.last.name : null;
        final lineCoordinates = line.coordinates;

        for (int i = 0; i < line.stops.length - 1; i++) {
          final fromStop = line.stops[i];
          final toStop = line.stops[i + 1];

          final fromId = _normalizeStopId(fromStop.name, fromStop.position);
          final toId = _normalizeStopId(toStop.name, toStop.position);

          final fromNode = nodes[fromId]!;
          final toNode = nodes[toId]!;

          final distance = _calculateDistance(fromNode.position, toNode.position);
          final travelTime = _estimateTravelTime(distance, group.transportType);

          // Extraire la portion du tracé entre les deux arrêts
          final pathSegment = _extractPathSegment(
            lineCoordinates,
            fromStop.position,
            toStop.position,
          );

          final edge = TransportEdge(
            from: fromNode,
            to: toNode,
            lineNumber: group.lineNumber,
            transportType: group.transportType,
            distance: distance,
            travelTimeMinutes: travelTime,
            direction: direction,
            pathCoordinates: pathSegment,
          );

          edges.add(edge);
          adjacencyList.putIfAbsent(fromId, () => []).add(edge);
        }
      }
    }

    // Troisième passe : connexions piétonnes entre arrêts proches
    _addWalkingConnections();
  }

  void _addWalkingConnections() {
    final nodeList = nodes.values.toList();
    const maxWalkingDistance = 0.4; // 400 mètres

    for (int i = 0; i < nodeList.length; i++) {
      for (int j = i + 1; j < nodeList.length; j++) {
        final node1 = nodeList[i];
        final node2 = nodeList[j];

        if (node1.id == node2.id) continue;

        final distance = _calculateDistance(node1.position, node2.position);

        if (distance <= maxWalkingDistance) {
          final commonLines = node1.lineNumbers
              .where((l) => node2.lineNumbers.contains(l))
              .toList();

          if (commonLines.isEmpty) {
            final walkTime = _estimateWalkingTime(distance);

            final walkEdge = TransportEdge(
              from: node1,
              to: node2,
              lineNumber: 'WALK',
              transportType: TransportType.bus,
              distance: distance,
              travelTimeMinutes: walkTime,
              isWalking: true,
            );
            edges.add(walkEdge);
            adjacencyList.putIfAbsent(node1.id, () => []).add(walkEdge);

            final reverseWalkEdge = TransportEdge(
              from: node2,
              to: node1,
              lineNumber: 'WALK',
              transportType: TransportType.bus,
              distance: distance,
              travelTimeMinutes: walkTime,
              isWalking: true,
            );
            edges.add(reverseWalkEdge);
            adjacencyList.putIfAbsent(node2.id, () => []).add(reverseWalkEdge);
          }
        }
      }
    }
  }

  String _normalizeStopId(String name, LatLng position) {
    final latRounded = (position.latitude * 10000).round();
    final lngRounded = (position.longitude * 10000).round();
    return '${name.toLowerCase().replaceAll(' ', '_')}_${latRounded}_$lngRounded';
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371;
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(from.latitude)) *
            math.cos(_toRadians(to.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180;

  int _estimateTravelTime(double distanceKm, TransportType type) {
    double speed;
    switch (type) {
      case TransportType.bus:
        speed = 15;
      case TransportType.urbanTrain:
        speed = 30;
      case TransportType.telepherique:
        speed = 20;
    }
    return math.max(1, (distanceKm / speed * 60).ceil());
  }

  /// Extrait la portion du tracé entre deux positions (arrêts)
  List<LatLng> _extractPathSegment(List<LatLng> lineCoordinates, LatLng from, LatLng to) {
    if (lineCoordinates.isEmpty) {
      return [from, to]; // Fallback: ligne droite
    }

    // Trouver l'index le plus proche pour le point de départ
    int fromIndex = _findNearestCoordinateIndex(lineCoordinates, from);
    // Trouver l'index le plus proche pour le point d'arrivée
    int toIndex = _findNearestCoordinateIndex(lineCoordinates, to);

    // S'assurer que fromIndex < toIndex (sinon inverser)
    if (fromIndex > toIndex) {
      final temp = fromIndex;
      fromIndex = toIndex;
      toIndex = temp;
    }

    // Extraire le segment (inclure les deux extrémités)
    if (fromIndex == toIndex) {
      return [from, to]; // Même point, retourner ligne droite
    }

    final segment = lineCoordinates.sublist(fromIndex, toIndex + 1);

    // S'assurer que le segment commence et finit exactement aux arrêts
    if (segment.isNotEmpty) {
      final result = <LatLng>[from];
      // Ajouter les points intermédiaires (éviter les doublons proches)
      for (int i = 1; i < segment.length - 1; i++) {
        result.add(segment[i]);
      }
      result.add(to);
      return result;
    }

    return [from, to];
  }

  /// Trouve l'index de la coordonnée la plus proche d'une position donnée
  int _findNearestCoordinateIndex(List<LatLng> coordinates, LatLng target) {
    int nearestIndex = 0;
    double nearestDistance = double.infinity;

    for (int i = 0; i < coordinates.length; i++) {
      final distance = _calculateDistance(coordinates[i], target);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  int _estimateWalkingTime(double distanceKm) {
    // Vitesse de marche: 4.5 km/h = 75m/min
    return math.max(1, (distanceKm * 1000 / 75).ceil());
  }

  /// Trouve les arrêts les plus proches d'une position (jusqu'à N arrêts)
  List<TransportNode> findNearestStops(LatLng position, {int maxStops = 3, double maxDistanceKm = 2.0}) {
    final stopsWithDistance = <MapEntry<TransportNode, double>>[];

    for (final node in nodes.values) {
      final distance = _calculateDistance(position, node.position);
      if (distance <= maxDistanceKm) {
        stopsWithDistance.add(MapEntry(node, distance));
      }
    }

    stopsWithDistance.sort((a, b) => a.value.compareTo(b.value));
    return stopsWithDistance.take(maxStops).map((e) => e.key).toList();
  }

  TransportNode? findNearestStop(LatLng position, {double maxDistanceKm = 2.0}) {
    final stops = findNearestStops(position, maxStops: 1, maxDistanceKm: maxDistanceKm);
    return stops.isNotEmpty ? stops.first : null;
  }

  /// Temps de marche maximum autorisé (en minutes)
  static const int maxWalkingTimeMinutes = 60;

  /// Trouve plusieurs itinéraires style IDF Mobilités
  List<TransportRoute> findRoutes(LatLng origin, LatLng destination, {int maxRoutes = 4}) {
    // Distance max: 4.5km = ~60min de marche à 75m/min
    final originStops = findNearestStops(origin, maxStops: 3, maxDistanceKm: 4.5);
    final destStops = findNearestStops(destination, maxStops: 3, maxDistanceKm: 4.5);

    if (originStops.isEmpty || destStops.isEmpty) {
      return [];
    }

    final routes = <TransportRoute>[];
    final seenSignatures = <String>{};

    // Essayer différentes combinaisons d'arrêts de départ/arrivée
    for (final startNode in originStops) {
      for (final endNode in destStops) {
        // Stratégie 1: Plus rapide
        final fastRoute = _findRouteWithCriteria(
          origin, destination, startNode, endNode,
          transferPenalty: 2,
        );
        if (fastRoute != null && _isWalkingTimeAcceptable(fastRoute)) {
          final sig = _getRouteSignature(fastRoute);
          if (!seenSignatures.contains(sig)) {
            seenSignatures.add(sig);
            routes.add(fastRoute);
          }
        }

        // Stratégie 2: Moins de correspondances
        final directRoute = _findRouteWithCriteria(
          origin, destination, startNode, endNode,
          transferPenalty: 25,
        );
        if (directRoute != null && _isWalkingTimeAcceptable(directRoute)) {
          final sig = _getRouteSignature(directRoute);
          if (!seenSignatures.contains(sig)) {
            seenSignatures.add(sig);
            routes.add(directRoute);
          }
        }
      }
    }

    // Trier par durée totale
    routes.sort((a, b) => a.totalDurationMinutes.compareTo(b.totalDurationMinutes));

    return routes.take(maxRoutes).toList();
  }

  /// Vérifie si le temps de marche total d'un itinéraire est acceptable (< 60 min)
  bool _isWalkingTimeAcceptable(TransportRoute route) {
    // Vérifier le temps de marche total
    if (route.walkingTimeMinutes > maxWalkingTimeMinutes) {
      return false;
    }

    // Vérifier aussi chaque étape de marche individuellement (max 30 min par étape)
    for (final step in route.steps) {
      if (step.isWalking && step.durationMinutes > 30) {
        return false;
      }
    }

    return true;
  }

  String _getRouteSignature(TransportRoute route) {
    return route.steps
        .where((s) => s.type == RouteStepType.transport)
        .map((s) => '${s.lineNumber}:${s.startStop?.id}-${s.endStop?.id}')
        .join('|');
  }

  TransportRoute? _findRouteWithCriteria(
    LatLng origin,
    LatLng destination,
    TransportNode startNode,
    TransportNode endNode, {
    required double transferPenalty,
  }) {
    if (startNode.id == endNode.id) return null;

    final distances = <String, double>{};
    final previous = <String, _PathInfo?>{};
    final visited = <String>{};
    final queue = <String>[];

    for (final nodeId in nodes.keys) {
      distances[nodeId] = double.infinity;
      previous[nodeId] = null;
    }
    distances[startNode.id] = 0;
    queue.add(startNode.id);

    while (queue.isNotEmpty) {
      queue.sort((a, b) => distances[a]!.compareTo(distances[b]!));
      final currentId = queue.removeAt(0);

      if (visited.contains(currentId)) continue;
      visited.add(currentId);

      if (currentId == endNode.id) break;

      final edgesList = adjacencyList[currentId] ?? [];
      for (final edge in edgesList) {
        final neighborId = edge.to.id;
        if (visited.contains(neighborId)) continue;

        double cost = edge.travelTimeMinutes.toDouble();

        final prevInfo = previous[currentId];
        if (prevInfo != null && prevInfo.lineNumber != edge.lineNumber && !edge.isWalking) {
          cost += transferPenalty;
        }

        final newDist = distances[currentId]! + cost;
        if (newDist < distances[neighborId]!) {
          distances[neighborId] = newDist;
          previous[neighborId] = _PathInfo(
            previousNodeId: currentId,
            edge: edge,
            lineNumber: edge.lineNumber,
          );
          if (!queue.contains(neighborId)) {
            queue.add(neighborId);
          }
        }
      }
    }

    if (previous[endNode.id] == null) {
      return null;
    }

    return _buildRouteIDF(origin, destination, startNode, endNode, previous);
  }

  /// Construit un itinéraire style IDF Mobilités
  TransportRoute? _buildRouteIDF(
    LatLng origin,
    LatLng destination,
    TransportNode startNode,
    TransportNode endNode,
    Map<String, _PathInfo?> previous,
  ) {
    final path = <_PathInfo>[];
    String? currentId = endNode.id;

    while (previous[currentId] != null) {
      path.insert(0, previous[currentId]!);
      currentId = previous[currentId]!.previousNodeId;
    }

    if (path.isEmpty) return null;

    final steps = <RouteStep>[];
    int totalWalkingTime = 0;
    int totalWalkingMeters = 0;
    int totalTransportTime = 0;

    // 1. Étape de marche vers le premier arrêt
    final walkToStopDistance = _calculateDistance(origin, startNode.position);
    final walkToStopTime = _estimateWalkingTime(walkToStopDistance);
    final walkToStopMeters = (walkToStopDistance * 1000).round();

    if (walkToStopMeters > 50) { // Seulement si > 50m
      steps.add(RouteStep(
        type: RouteStepType.walkToStop,
        startStop: startNode,
        durationMinutes: walkToStopTime,
        distanceKm: walkToStopDistance,
        distanceMeters: walkToStopMeters,
        walkStartPosition: origin,
        walkEndPosition: startNode.position,
      ));
      totalWalkingTime += walkToStopTime;
      totalWalkingMeters += walkToStopMeters;
    }

    // 2. Étapes de transport et correspondances
    String? currentLine;
    TransportNode? stepStart;
    final intermediateStops = <TransportNode>[];
    final stepPathCoordinates = <LatLng>[]; // Accumule les coordonnées du tracé
    double stepDistance = 0;
    int stepDuration = 0;
    TransportType? stepType;
    String? stepDirection;

    for (int i = 0; i < path.length; i++) {
      final info = path[i];
      final edge = info.edge;

      if (edge.isWalking) {
        // Terminer l'étape transport en cours
        if (stepStart != null && currentLine != null) {
          steps.add(RouteStep(
            type: RouteStepType.transport,
            startStop: stepStart,
            endStop: nodes[info.previousNodeId],
            lineNumber: currentLine,
            lineName: _getLineName(currentLine),
            transportType: stepType,
            intermediateStops: List.from(intermediateStops),
            durationMinutes: stepDuration,
            distanceKm: stepDistance,
            direction: stepDirection,
            pathCoordinates: List.from(stepPathCoordinates),
          ));
          totalTransportTime += stepDuration;
        }

        // Ajouter l'étape de marche (correspondance)
        final walkMeters = (edge.distance * 1000).round();
        steps.add(RouteStep(
          type: RouteStepType.walkTransfer,
          startStop: nodes[info.previousNodeId],
          endStop: edge.to,
          durationMinutes: edge.travelTimeMinutes,
          distanceKm: edge.distance,
          distanceMeters: walkMeters,
          walkStartPosition: nodes[info.previousNodeId]?.position,
          walkEndPosition: edge.to.position,
        ));
        totalWalkingTime += edge.travelTimeMinutes;
        totalWalkingMeters += walkMeters;

        // Reset pour la prochaine étape transport
        currentLine = null;
        stepStart = null;
        intermediateStops.clear();
        stepPathCoordinates.clear();
        stepDistance = 0;
        stepDuration = 0;
      } else {
        if (currentLine == null || currentLine != edge.lineNumber) {
          // Terminer l'étape transport précédente
          if (stepStart != null && currentLine != null) {
            steps.add(RouteStep(
              type: RouteStepType.transport,
              startStop: stepStart,
              endStop: nodes[info.previousNodeId],
              lineNumber: currentLine,
              lineName: _getLineName(currentLine),
              transportType: stepType,
              intermediateStops: List.from(intermediateStops),
              durationMinutes: stepDuration,
              distanceKm: stepDistance,
              direction: stepDirection,
              pathCoordinates: List.from(stepPathCoordinates),
            ));
            totalTransportTime += stepDuration;
          }

          // Nouvelle étape transport
          currentLine = edge.lineNumber;
          stepStart = nodes[info.previousNodeId];
          intermediateStops.clear();
          stepPathCoordinates.clear();
          // Ajouter les coordonnées du premier edge
          if (edge.pathCoordinates.isNotEmpty) {
            stepPathCoordinates.addAll(edge.pathCoordinates);
          } else {
            stepPathCoordinates.add(edge.from.position);
            stepPathCoordinates.add(edge.to.position);
          }
          stepDistance = edge.distance;
          stepDuration = edge.travelTimeMinutes;
          stepType = edge.transportType;
          stepDirection = edge.direction;
        } else {
          intermediateStops.add(nodes[info.previousNodeId]!);
          // Ajouter les coordonnées de cet edge (éviter le doublon du premier point)
          if (edge.pathCoordinates.isNotEmpty) {
            // Ajouter à partir du 2ème point pour éviter le doublon
            stepPathCoordinates.addAll(edge.pathCoordinates.skip(1));
          } else {
            stepPathCoordinates.add(edge.to.position);
          }
          stepDistance += edge.distance;
          stepDuration += edge.travelTimeMinutes;
        }

        // Dernière étape
        if (i == path.length - 1 && currentLine != null && stepStart != null) {
          steps.add(RouteStep(
            type: RouteStepType.transport,
            startStop: stepStart,
            endStop: edge.to,
            lineNumber: currentLine,
            lineName: _getLineName(currentLine),
            transportType: stepType,
            intermediateStops: List.from(intermediateStops),
            durationMinutes: stepDuration,
            distanceKm: stepDistance,
            direction: stepDirection,
            pathCoordinates: List.from(stepPathCoordinates),
          ));
          totalTransportTime += stepDuration;
        }
      }
    }

    // 3. Étape de marche depuis le dernier arrêt vers la destination
    final walkFromStopDistance = _calculateDistance(endNode.position, destination);
    final walkFromStopTime = _estimateWalkingTime(walkFromStopDistance);
    final walkFromStopMeters = (walkFromStopDistance * 1000).round();

    if (walkFromStopMeters > 50) { // Seulement si > 50m
      steps.add(RouteStep(
        type: RouteStepType.walkFromStop,
        startStop: endNode,
        durationMinutes: walkFromStopTime,
        distanceKm: walkFromStopDistance,
        distanceMeters: walkFromStopMeters,
        walkStartPosition: endNode.position,
        walkEndPosition: destination,
      ));
      totalWalkingTime += walkFromStopTime;
      totalWalkingMeters += walkFromStopMeters;
    }

    final totalDuration = totalWalkingTime + totalTransportTime;
    final totalDistance = steps.fold(0.0, (sum, s) => sum + s.distanceKm);
    final transfers = steps.where((s) => s.type == RouteStepType.transport).length - 1;

    final now = DateTime.now();

    return TransportRoute(
      steps: steps,
      totalDurationMinutes: totalDuration,
      totalDistanceKm: totalDistance,
      numberOfTransfers: math.max(0, transfers),
      origin: origin,
      destination: destination,
      walkingTimeMinutes: totalWalkingTime,
      walkingDistanceMeters: totalWalkingMeters,
      transportTimeMinutes: totalTransportTime,
      departureTime: now,
      arrivalTime: now.add(Duration(minutes: totalDuration)),
    );
  }

  String _getLineName(String lineNumber) {
    if (lineNumber == 'WALK') return 'Marche';
    if (lineNumber.contains('TRAIN') || lineNumber.contains('TCE')) return 'Train TCE';
    if (lineNumber.contains('TELEPHERIQUE')) return 'Téléphérique';
    return 'Ligne $lineNumber';
  }

  // Méthodes de compatibilité
  TransportRoute? findRoute(LatLng origin, LatLng destination) {
    final routes = findRoutes(origin, destination, maxRoutes: 1);
    return routes.isNotEmpty ? routes.first : null;
  }

  List<TransportRoute> findMultipleRoutes(LatLng origin, LatLng destination, {int maxRoutes = 5}) {
    return findRoutes(origin, destination, maxRoutes: maxRoutes);
  }
}

class _PathInfo {
  final String previousNodeId;
  final TransportEdge edge;
  final String lineNumber;

  _PathInfo({
    required this.previousNodeId,
    required this.edge,
    required this.lineNumber,
  });
}
