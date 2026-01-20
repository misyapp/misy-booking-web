import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';

/// Représente un noeud dans le graphe du réseau de transport
class TransportNode {
  final String id;
  final String name;
  final LatLng position;
  final List<String> lineNumbers; // Lignes passant par ce noeud

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
  final double distance; // en km
  final int travelTimeMinutes;
  final bool isWalking; // Connexion à pied entre arrêts proches

  TransportEdge({
    required this.from,
    required this.to,
    required this.lineNumber,
    required this.transportType,
    required this.distance,
    required this.travelTimeMinutes,
    this.isWalking = false,
  });
}

/// Représente une étape d'un itinéraire
class RouteStep {
  final TransportNode startStop;
  final TransportNode endStop;
  final String lineNumber;
  final String lineName;
  final TransportType transportType;
  final List<TransportNode> intermediateStops;
  final int durationMinutes;
  final double distance;
  final bool isWalking;
  final String direction;

  RouteStep({
    required this.startStop,
    required this.endStop,
    required this.lineNumber,
    required this.lineName,
    required this.transportType,
    required this.intermediateStops,
    required this.durationMinutes,
    required this.distance,
    this.isWalking = false,
    this.direction = '',
  });

  int get numberOfStops => intermediateStops.length + 1;
}

/// Représente un itinéraire complet
class TransportRoute {
  final List<RouteStep> steps;
  final int totalDurationMinutes;
  final double totalDistance;
  final int numberOfTransfers;
  final LatLng origin;
  final LatLng destination;

  TransportRoute({
    required this.steps,
    required this.totalDurationMinutes,
    required this.totalDistance,
    required this.numberOfTransfers,
    required this.origin,
    required this.destination,
  });

  /// Calcule le temps total de marche
  int get walkingTimeMinutes {
    return steps
        .where((s) => s.isWalking)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  /// Obtient toutes les coordonnées du trajet pour l'affichage
  List<LatLng> get allCoordinates {
    final coords = <LatLng>[];
    for (final step in steps) {
      coords.add(step.startStop.position);
      for (final stop in step.intermediateStops) {
        coords.add(stop.position);
      }
      coords.add(step.endStop.position);
    }
    return coords;
  }
}

/// Graphe du réseau de transport pour le calcul d'itinéraire
class TransportGraph {
  final Map<String, TransportNode> nodes = {};
  final List<TransportEdge> edges = [];
  final Map<String, List<TransportEdge>> adjacencyList = {};

  /// Construit le graphe à partir des lignes de transport
  void buildFromLines(List<TransportLineGroup> lineGroups) {
    nodes.clear();
    edges.clear();
    adjacencyList.clear();

    // Première passe : créer tous les noeuds
    for (final group in lineGroups) {
      for (final line in group.lines) {
        for (final stop in line.stops) {
          final nodeId = _normalizeStopId(stop.name, stop.position);

          if (nodes.containsKey(nodeId)) {
            // Ajouter la ligne à ce noeud existant
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

    // Deuxième passe : créer les arêtes (connexions entre arrêts consécutifs)
    for (final group in lineGroups) {
      for (final line in group.lines) {
        for (int i = 0; i < line.stops.length - 1; i++) {
          final fromStop = line.stops[i];
          final toStop = line.stops[i + 1];

          final fromId = _normalizeStopId(fromStop.name, fromStop.position);
          final toId = _normalizeStopId(toStop.name, toStop.position);

          final fromNode = nodes[fromId]!;
          final toNode = nodes[toId]!;

          final distance = _calculateDistance(fromNode.position, toNode.position);
          final travelTime = _estimateTravelTime(distance, group.transportType);

          final edge = TransportEdge(
            from: fromNode,
            to: toNode,
            lineNumber: group.lineNumber,
            transportType: group.transportType,
            distance: distance,
            travelTimeMinutes: travelTime,
          );

          edges.add(edge);
          adjacencyList.putIfAbsent(fromId, () => []).add(edge);

          // Ajouter l'arête inverse (bi-directionnel)
          final reverseEdge = TransportEdge(
            from: toNode,
            to: fromNode,
            lineNumber: group.lineNumber,
            transportType: group.transportType,
            distance: distance,
            travelTimeMinutes: travelTime,
          );
          edges.add(reverseEdge);
          adjacencyList.putIfAbsent(toId, () => []).add(reverseEdge);
        }
      }
    }

    // Troisième passe : ajouter des connexions piétonnes entre arrêts proches (< 300m)
    _addWalkingConnections();
  }

  /// Ajoute des connexions piétonnes entre arrêts proches de lignes différentes
  void _addWalkingConnections() {
    final nodeList = nodes.values.toList();
    const maxWalkingDistance = 0.3; // 300 mètres

    for (int i = 0; i < nodeList.length; i++) {
      for (int j = i + 1; j < nodeList.length; j++) {
        final node1 = nodeList[i];
        final node2 = nodeList[j];

        // Ne pas créer de connexion piétonne si même noeud ou mêmes lignes
        if (node1.id == node2.id) continue;

        final distance = _calculateDistance(node1.position, node2.position);

        if (distance <= maxWalkingDistance) {
          // Vérifier qu'ils ne sont pas déjà connectés par la même ligne
          final commonLines = node1.lineNumbers
              .where((l) => node2.lineNumbers.contains(l))
              .toList();

          if (commonLines.isEmpty) {
            // Vitesse de marche réaliste: 50m/min = 3km/h
            // (tient compte des feux, traversées, terrain)
            final walkTime = (distance * 1000 / 50).ceil();

            final walkEdge = TransportEdge(
              from: node1,
              to: node2,
              lineNumber: 'WALK',
              transportType: TransportType.bus, // Placeholder
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

  /// Normalise l'ID d'un arrêt basé sur son nom et sa position
  String _normalizeStopId(String name, LatLng position) {
    // Arrondir les coordonnées pour grouper les arrêts très proches
    final latRounded = (position.latitude * 10000).round();
    final lngRounded = (position.longitude * 10000).round();
    return '${name.toLowerCase().replaceAll(' ', '_')}_${latRounded}_$lngRounded';
  }

  /// Calcule la distance entre deux points en km
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

  /// Estime le temps de trajet selon le type de transport
  int _estimateTravelTime(double distanceKm, TransportType type) {
    // Vitesses moyennes en km/h
    double speed;
    switch (type) {
      case TransportType.bus:
        speed = 15; // Bus urbain avec arrêts
      case TransportType.urbanTrain:
        speed = 30; // Train urbain
      case TransportType.telepherique:
        speed = 20; // Téléphérique
    }
    return math.max(1, (distanceKm / speed * 60).ceil());
  }

  /// Trouve l'arrêt le plus proche d'une position donnée
  TransportNode? findNearestStop(LatLng position, {double maxDistanceKm = 3.0}) {
    TransportNode? nearest;
    double minDistance = double.infinity;

    for (final node in nodes.values) {
      final distance = _calculateDistance(position, node.position);
      if (distance < minDistance && distance <= maxDistanceKm) {
        minDistance = distance;
        nearest = node;
      }
    }

    return nearest;
  }

  /// Trouve un itinéraire entre deux positions
  TransportRoute? findRoute(LatLng origin, LatLng destination) {
    final startNode = findNearestStop(origin, maxDistanceKm: 3.0);
    final endNode = findNearestStop(destination, maxDistanceKm: 3.0);

    print('findRoute: origin=$origin, destination=$destination');
    print('startNode: ${startNode?.name} (${startNode?.position})');
    print('endNode: ${endNode?.name} (${endNode?.position})');

    if (startNode == null || endNode == null) {
      if (startNode == null) print('No stop found near origin within 3km');
      if (endNode == null) print('No stop found near destination within 3km');
      return null;
    }

    // Algorithme de Dijkstra
    final distances = <String, double>{};
    final previous = <String, _PathInfo?>{};
    final visited = <String>{};
    final queue = <String>[];

    // Initialisation
    for (final nodeId in nodes.keys) {
      distances[nodeId] = double.infinity;
      previous[nodeId] = null;
    }
    distances[startNode.id] = 0;
    queue.add(startNode.id);

    while (queue.isNotEmpty) {
      // Trouver le noeud avec la plus petite distance
      queue.sort((a, b) => distances[a]!.compareTo(distances[b]!));
      final currentId = queue.removeAt(0);

      if (visited.contains(currentId)) continue;
      visited.add(currentId);

      if (currentId == endNode.id) break;

      // Explorer les voisins
      final edges = adjacencyList[currentId] ?? [];
      for (final edge in edges) {
        final neighborId = edge.to.id;
        if (visited.contains(neighborId)) continue;

        // Coût = temps de trajet + pénalité de correspondance
        double cost = edge.travelTimeMinutes.toDouble();

        // Ajouter une pénalité de correspondance si on change de ligne
        final prevInfo = previous[currentId];
        if (prevInfo != null && prevInfo.lineNumber != edge.lineNumber && !edge.isWalking) {
          cost += 5; // 5 minutes de pénalité pour un changement
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

    // Reconstruire le chemin
    if (previous[endNode.id] == null) {
      return null;
    }

    return _buildRoute(origin, destination, startNode, endNode, previous);
  }

  /// Construit l'itinéraire à partir du chemin trouvé
  TransportRoute? _buildRoute(
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

    // Grouper les segments par ligne pour créer les étapes
    final steps = <RouteStep>[];
    String? currentLine;
    TransportNode? stepStart;
    final intermediateStops = <TransportNode>[];
    double stepDistance = 0;
    int stepDuration = 0;
    TransportType? stepType;
    bool stepIsWalking = false;

    for (int i = 0; i < path.length; i++) {
      final info = path[i];
      final edge = info.edge;

      if (currentLine == null || currentLine != edge.lineNumber) {
        // Nouvelle étape
        if (stepStart != null) {
          steps.add(RouteStep(
            startStop: stepStart,
            endStop: nodes[info.previousNodeId]!,
            lineNumber: currentLine!,
            lineName: _getLineName(currentLine),
            transportType: stepType!,
            intermediateStops: List.from(intermediateStops),
            durationMinutes: stepDuration,
            distance: stepDistance,
            isWalking: stepIsWalking,
            direction: edge.to.name,
          ));
        }

        currentLine = edge.lineNumber;
        stepStart = nodes[info.previousNodeId];
        intermediateStops.clear();
        stepDistance = edge.distance;
        stepDuration = edge.travelTimeMinutes;
        stepType = edge.transportType;
        stepIsWalking = edge.isWalking;
      } else {
        intermediateStops.add(nodes[info.previousNodeId]!);
        stepDistance += edge.distance;
        stepDuration += edge.travelTimeMinutes;
      }

      // Dernière étape
      if (i == path.length - 1) {
        steps.add(RouteStep(
          startStop: stepStart!,
          endStop: edge.to,
          lineNumber: currentLine!,
          lineName: _getLineName(currentLine),
          transportType: stepType!,
          intermediateStops: List.from(intermediateStops),
          durationMinutes: stepDuration,
          distance: stepDistance,
          isWalking: stepIsWalking,
          direction: edge.to.name,
        ));
      }
    }

    final totalDuration = steps.fold(0, (sum, s) => sum + s.durationMinutes);
    final totalDistance = steps.fold(0.0, (sum, s) => sum + s.distance);
    final transfers = steps.where((s) => !s.isWalking).length - 1;

    return TransportRoute(
      steps: steps,
      totalDurationMinutes: totalDuration,
      totalDistance: totalDistance,
      numberOfTransfers: math.max(0, transfers),
      origin: origin,
      destination: destination,
    );
  }

  String _getLineName(String lineNumber) {
    if (lineNumber == 'WALK') return 'Marche';
    if (lineNumber.contains('TRAIN') || lineNumber.contains('TCE')) return 'Train TCE';
    if (lineNumber.contains('TELEPHERIQUE')) return 'Téléphérique Orange';
    return 'Ligne $lineNumber';
  }
}

/// Information sur le chemin pour Dijkstra
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
