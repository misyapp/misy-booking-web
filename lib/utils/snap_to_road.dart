import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Résultat du snap-to-road
class SnappedPosition {
  final LatLng position;      // Position projetée sur la route
  final double bearing;       // Direction de la route à ce point
  final int segmentIndex;     // Index du segment sur lequel on est
  final double distanceFromRoute; // Distance entre la position GPS et la route

  SnappedPosition({
    required this.position,
    required this.bearing,
    required this.segmentIndex,
    required this.distanceFromRoute,
  });
}

/// Utilitaire pour projeter une position GPS sur un polyline (snap-to-road)
class SnapToRoad {
  /// Seuil maximum pour snapper (en mètres)
  /// Au-delà, on considère que le chauffeur est hors route
  static const double maxSnapDistance = 50.0;

  /// Projette une position GPS sur le polyline le plus proche
  /// Retourne null si la position est trop éloignée de la route
  static SnappedPosition? snapToPolyline(LatLng gpsPosition, List<LatLng> polyline) {
    if (polyline.length < 2) return null;

    double minDistance = double.infinity;
    LatLng? closestPoint;
    int closestSegmentIndex = 0;
    double segmentBearing = 0;

    // Parcourir tous les segments du polyline
    for (int i = 0; i < polyline.length - 1; i++) {
      final start = polyline[i];
      final end = polyline[i + 1];

      // Projeter le point GPS sur ce segment
      final projection = _projectPointOnSegment(gpsPosition, start, end);
      final distance = _haversineDistance(gpsPosition, projection);

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = projection;
        closestSegmentIndex = i;
        segmentBearing = calculateBearing(start, end);
      }
    }

    if (closestPoint == null || minDistance > maxSnapDistance) {
      return null;
    }

    return SnappedPosition(
      position: closestPoint,
      bearing: segmentBearing,
      segmentIndex: closestSegmentIndex,
      distanceFromRoute: minDistance,
    );
  }

  /// Projette un point sur un segment de ligne
  static LatLng _projectPointOnSegment(LatLng point, LatLng segStart, LatLng segEnd) {
    // Convertir en coordonnées cartésiennes locales (approximation pour petites distances)
    final dx = segEnd.longitude - segStart.longitude;
    final dy = segEnd.latitude - segStart.latitude;

    if (dx == 0 && dy == 0) {
      return segStart;
    }

    // Calculer le paramètre t de la projection
    final px = point.longitude - segStart.longitude;
    final py = point.latitude - segStart.latitude;

    final t = (px * dx + py * dy) / (dx * dx + dy * dy);

    // Limiter t entre 0 et 1 pour rester sur le segment
    final clampedT = t.clamp(0.0, 1.0);

    return LatLng(
      segStart.latitude + clampedT * dy,
      segStart.longitude + clampedT * dx,
    );
  }

  /// Calcule la distance entre deux points en mètres (formule Haversine)
  static double _haversineDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // mètres

    final lat1Rad = p1.latitude * (pi / 180);
    final lat2Rad = p2.latitude * (pi / 180);
    final deltaLat = (p2.latitude - p1.latitude) * (pi / 180);
    final deltaLng = (p2.longitude - p1.longitude) * (pi / 180);

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calcule le bearing (direction) entre deux points en degrés (public)
  static double calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (pi / 180);
    final lat2 = end.latitude * (pi / 180);
    final dLng = (end.longitude - start.longitude) * (pi / 180);

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    final bearing = atan2(y, x) * (180 / pi);
    return (bearing + 360) % 360;
  }

  /// Interpole entre deux positions pour un mouvement fluide
  static LatLng interpolate(LatLng from, LatLng to, double t) {
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  /// Interpole un bearing (angle) de manière fluide
  static double interpolateBearing(double from, double to, double t) {
    // Gérer le cas où on passe par 0/360 degrés
    double diff = to - from;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    double result = from + diff * t;
    return (result + 360) % 360;
  }

  /// Trouve le point le plus avancé sur le polyline depuis un index donné
  /// Utile pour éviter que le chauffeur "recule" sur la route
  static SnappedPosition? snapForward(
    LatLng gpsPosition,
    List<LatLng> polyline,
    int minSegmentIndex,
  ) {
    if (polyline.length < 2 || minSegmentIndex >= polyline.length - 1) {
      return null;
    }

    double minDistance = double.infinity;
    LatLng? closestPoint;
    int closestSegmentIndex = minSegmentIndex;
    double segmentBearing = 0;

    // Ne chercher que dans les segments à partir de minSegmentIndex
    // avec une marge de 2 segments en arrière pour les corrections GPS
    final startIndex = (minSegmentIndex - 2).clamp(0, polyline.length - 2);

    for (int i = startIndex; i < polyline.length - 1; i++) {
      final start = polyline[i];
      final end = polyline[i + 1];

      final projection = _projectPointOnSegment(gpsPosition, start, end);
      final distance = _haversineDistance(gpsPosition, projection);

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = projection;
        closestSegmentIndex = i;
        segmentBearing = calculateBearing(start, end);
      }
    }

    if (closestPoint == null || minDistance > maxSnapDistance) {
      return null;
    }

    return SnappedPosition(
      position: closestPoint,
      bearing: segmentBearing,
      segmentIndex: closestSegmentIndex,
      distanceFromRoute: minDistance,
    );
  }
}
