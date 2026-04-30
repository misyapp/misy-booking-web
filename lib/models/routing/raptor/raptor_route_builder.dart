import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_config.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_types.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';

/// Convertit un `RaptorJourney` en `TransportRoute` consommable par
/// l'UI existante (timeline, rendu carte). Réutilise les types publics
/// de `route_planner.dart` sans rien y changer.
class RaptorRouteBuilder {
  RaptorRouteBuilder._();

  static TransportRoute build({
    required LatLng origin,
    required LatLng destination,
    required RaptorJourney journey,
    required RaptorNetwork net,
  }) {
    final steps = <RouteStep>[];
    var totalWalkMin = 0;
    var totalWalkM = 0;
    var totalRideMin = 0;
    double totalDistKm = 0;

    // Mappe RaptorStop → TransportNode éphémère (réutilisable car id stable).
    TransportNode toNode(int stopIdx) {
      final s = net.stops[stopIdx];
      return TransportNode(
        id: 'stop_$stopIdx',
        name: s.name,
        position: s.position,
        lineNumbers: List.of(s.lineNumbers),
      );
    }

    // 1. Walk to first stop si > 50m (depuis origin → 1er boarding stop ou
    //    1er walk leg).
    final firstLeg = journey.legs.first;
    final firstStopIdx = firstLeg is RaptorRideLeg
        ? firstLeg.boardStopIdx
        : (firstLeg as RaptorWalkLeg).fromStopIdx;
    final firstStopPos = net.stops[firstStopIdx].position;
    final accessKm = _haversineMeters(origin, firstStopPos) / 1000.0;
    final accessM = (accessKm * 1000).round();
    if (accessM > 50) {
      final accessMin = math.max(
          1, (accessKm / RaptorConfig.walkSpeedKmh * 60.0).ceil());
      steps.add(RouteStep(
        type: RouteStepType.walkToStop,
        startStop: toNode(firstStopIdx),
        durationMinutes: accessMin,
        distanceKm: accessKm,
        distanceMeters: accessM,
        walkStartPosition: origin,
        walkEndPosition: firstStopPos,
      ));
      totalWalkMin += accessMin;
      totalWalkM += accessM;
      totalDistKm += accessKm;
    }

    // 2. Pour chaque leg du journey.
    for (var i = 0; i < journey.legs.length; i++) {
      final leg = journey.legs[i];
      if (leg is RaptorRideLeg) {
        final route = net.routes[leg.routeIdx];
        // Intermediate stops = stops entre boardStopOrder+1 et alightStopOrder-1.
        final intermediates = <TransportNode>[];
        for (var p = leg.boardStopOrder + 1; p < leg.alightStopOrder; p++) {
          intermediates.add(toNode(route.stops[p]));
        }
        // Path coordinates : extraction du shape de la ligne entre
        // boardStop.position et alightStop.position.
        final boardPos = net.stops[leg.boardStopIdx].position;
        final alightPos = net.stops[leg.alightStopIdx].position;
        final path = _extractPathSegment(route.shape, boardPos, alightPos);
        // Distance = somme des travelMin / busSpeed (approximation propre).
        var distKm = 0.0;
        for (var p = leg.boardStopOrder; p < leg.alightStopOrder; p++) {
          distKm += route.travelMin[p] / 60.0 * RaptorConfig.busSpeedKmh;
        }
        final dur = leg.durationMin + leg.waitMin;
        steps.add(RouteStep(
          type: RouteStepType.transport,
          startStop: toNode(leg.boardStopIdx),
          endStop: toNode(leg.alightStopIdx),
          lineNumber: route.lineNumber,
          lineName: _lineDisplayName(route),
          transportType: route.transportType,
          intermediateStops: intermediates,
          durationMinutes: dur,
          distanceKm: distKm,
          direction: route.directionLabel,
          pathCoordinates: path,
        ));
        totalRideMin += dur;
        totalDistKm += distKm;
      } else if (leg is RaptorWalkLeg) {
        steps.add(RouteStep(
          type: RouteStepType.walkTransfer,
          startStop: toNode(leg.fromStopIdx),
          endStop: toNode(leg.toStopIdx),
          durationMinutes: leg.durationMin,
          distanceKm: leg.distanceMeters / 1000.0,
          distanceMeters: leg.distanceMeters,
          walkStartPosition: net.stops[leg.fromStopIdx].position,
          walkEndPosition: net.stops[leg.toStopIdx].position,
        ));
        totalWalkMin += leg.durationMin;
        totalWalkM += leg.distanceMeters;
        totalDistKm += leg.distanceMeters / 1000.0;
      }
    }

    // 3. Walk from last stop si > 50m.
    final lastLeg = journey.legs.last;
    final lastStopIdx = lastLeg is RaptorRideLeg
        ? lastLeg.alightStopIdx
        : (lastLeg as RaptorWalkLeg).toStopIdx;
    final lastStopPos = net.stops[lastStopIdx].position;
    final egressKm = _haversineMeters(lastStopPos, destination) / 1000.0;
    final egressM = (egressKm * 1000).round();
    if (egressM > 50) {
      final egressMin = math.max(
          1, (egressKm / RaptorConfig.walkSpeedKmh * 60.0).ceil());
      steps.add(RouteStep(
        type: RouteStepType.walkFromStop,
        startStop: toNode(lastStopIdx),
        durationMinutes: egressMin,
        distanceKm: egressKm,
        distanceMeters: egressM,
        walkStartPosition: lastStopPos,
        walkEndPosition: destination,
      ));
      totalWalkMin += egressMin;
      totalWalkM += egressM;
      totalDistKm += egressKm;
    }

    return TransportRoute(
      steps: steps,
      totalDurationMinutes: totalWalkMin + totalRideMin,
      totalDistanceKm: totalDistKm,
      numberOfTransfers: journey.transfers,
      origin: origin,
      destination: destination,
      walkingTimeMinutes: totalWalkMin,
      walkingDistanceMeters: totalWalkM,
      transportTimeMinutes: totalRideMin,
      departureTime: DateTime.now(),
      arrivalTime: DateTime.now()
          .add(Duration(minutes: totalWalkMin + totalRideMin)),
    );
  }

  static String _lineDisplayName(RaptorRoute r) {
    switch (r.transportType) {
      case TransportType.urbanTrain:
        return 'Train TCE';
      case TransportType.telepherique:
        return 'Téléphérique Orange';
      case TransportType.bus:
        return 'Ligne ${r.lineNumber}';
    }
  }

  /// Extrait la portion de polyline entre 2 positions, en snappant chaque
  /// extrémité au point le plus proche du shape.
  static List<LatLng> _extractPathSegment(
      List<LatLng> shape, LatLng from, LatLng to) {
    if (shape.length < 2) return [from, to];
    final i = _nearestIndex(shape, from);
    final j = _nearestIndex(shape, to);
    final lo = math.min(i, j);
    final hi = math.max(i, j);
    if (lo == hi) return [shape[lo]];
    return shape.sublist(lo, hi + 1);
  }

  static int _nearestIndex(List<LatLng> pts, LatLng target) {
    var best = 0;
    var bestSq = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final dLat = pts[i].latitude - target.latitude;
      final dLng = pts[i].longitude - target.longitude;
      final sq = dLat * dLat + dLng * dLng;
      if (sq < bestSq) {
        bestSq = sq;
        best = i;
      }
    }
    return best;
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
}
