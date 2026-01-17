import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../functions/print_function.dart';
import 'routing/osrm_secure_client.dart';
import '../utils/snap_to_road.dart';

/// Résultat du snap d'un chauffeur sur la route
class DriverSnapResult {
  final String driverId;
  final LatLng snappedPosition; // Position sur la route
  final LatLng rawPosition; // Position GPS brute
  final double? bearing; // Direction sur la route (null si pas calculable)
  final double distanceFromRoad; // Distance entre GPS et route (mètres)
  final bool isSnapped; // true si snappé, false si position brute utilisée

  DriverSnapResult({
    required this.driverId,
    required this.snappedPosition,
    required this.rawPosition,
    this.bearing, // Nullable - null si pas de mouvement pour calculer
    required this.distanceFromRoad,
    required this.isSnapped,
  });
}

/// Service pour snapper les positions des chauffeurs sur les routes
/// Utilise OSRM Nearest API pour trouver le point le plus proche sur une route
class DriverSnapService {
  // Cache des dernières positions snappées par chauffeur
  static final Map<String, DriverSnapResult> _cache = {};

  // Cache des derniers bearings par chauffeur (pour interpolation fluide)
  static final Map<String, double> _lastBearings = {};

  /// Seuil maximum pour considérer un snap valide (en mètres)
  static const double maxSnapDistance = 100.0;

  /// Snappe une position de chauffeur sur la route la plus proche via OSRM Nearest
  /// Retourne la position snappée ou la position brute si le snap échoue
  static Future<DriverSnapResult> snapDriverPosition({
    required String driverId,
    required LatLng currentPosition,
    LatLng? previousPosition,
  }) async {
    try {
      // Appel OSRM Nearest API avec number=3 pour obtenir plusieurs nodes
      final path = '/nearest/v1/driving/${currentPosition.longitude},${currentPosition.latitude}';
      final response = await OsrmSecureClient.secureGet(
        path: path,
        queryParams: 'number=3',
        timeoutSeconds: 2,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['waypoints'] != null && data['waypoints'].isNotEmpty) {
          final waypoint = data['waypoints'][0];
          final snappedLat = waypoint['location'][1] as double;
          final snappedLng = waypoint['location'][0] as double;
          final distance = (waypoint['distance'] as num).toDouble();
          final snappedPosition = LatLng(snappedLat, snappedLng);

          // Si trop loin de la route, utiliser la position brute
          if (distance > maxSnapDistance) {
            if (kDebugMode) {
              myCustomPrintStatement('[SNAP] Driver $driverId too far from road: ${distance.toStringAsFixed(1)}m');
            }
            return _createRawResult(driverId, currentPosition, previousPosition);
          }

          // Calculer le bearing
          double? bearing;

          // 1. Si on a une position précédente avec mouvement significatif
          if (previousPosition != null) {
            final prevSnapped = _cache[driverId];
            LatLng fromPos;
            if (prevSnapped != null && prevSnapped.isSnapped) {
              fromPos = prevSnapped.snappedPosition;
            } else {
              fromPos = previousPosition;
            }

            final movementDistance = _calculateDistanceMeters(fromPos, snappedPosition);
            if (movementDistance > 5.0) {
              bearing = SnapToRoad.calculateBearing(fromPos, snappedPosition);
              _lastBearings[driverId] = bearing;
            } else {
              bearing = _lastBearings[driverId];
            }
          }

          // 2. Si pas de bearing calculé, essayer avec les autres waypoints
          if (bearing == null && data['waypoints'].length > 1) {
            // Utiliser le 2ème waypoint pour déterminer la direction de la route
            final waypoint2 = data['waypoints'][1];
            final lat2 = waypoint2['location'][1] as double;
            final lng2 = waypoint2['location'][0] as double;
            final pos2 = LatLng(lat2, lng2);

            // Calculer le bearing entre le point snappé et le 2ème waypoint
            final dist = _calculateDistanceMeters(snappedPosition, pos2);
            if (dist > 1.0) { // Au moins 1m de différence
              bearing = SnapToRoad.calculateBearing(snappedPosition, pos2);
              // Choix aléatoire entre cette direction et l'inverse (route bidirectionnelle)
              final random = math.Random(driverId.hashCode);
              if (random.nextBool()) {
                bearing = (bearing + 180) % 360;
              }
              _lastBearings[driverId] = bearing;
              if (kDebugMode) {
                myCustomPrintStatement('[SNAP] Driver $driverId: bearing from road nodes: ${bearing.toStringAsFixed(0)}°');
              }
            }
          }

          // 3. Fallback: utiliser le cache
          bearing ??= _lastBearings[driverId];

          final result = DriverSnapResult(
            driverId: driverId,
            snappedPosition: snappedPosition,
            rawPosition: currentPosition,
            bearing: bearing,
            distanceFromRoad: distance,
            isSnapped: true,
          );

          _cache[driverId] = result;

          if (kDebugMode) {
            myCustomPrintStatement('[SNAP] Driver $driverId snapped: ${distance.toStringAsFixed(1)}m from road, bearing: ${bearing?.toStringAsFixed(0) ?? "N/A"}°');
          }

          return result;
        }
      }

      // Fallback: utiliser la position brute
      return _createRawResult(driverId, currentPosition, previousPosition);
    } catch (e) {
      if (kDebugMode) {
        myCustomPrintStatement('[SNAP] Error snapping driver $driverId: $e');
      }
      return _createRawResult(driverId, currentPosition, previousPosition);
    }
  }

  /// Crée un résultat avec la position brute (quand le snap échoue)
  static DriverSnapResult _createRawResult(
    String driverId,
    LatLng currentPosition,
    LatLng? previousPosition,
  ) {
    double? bearing;
    if (previousPosition != null) {
      // Vérifier si le mouvement est significatif (> 5 mètres)
      final movementDistance = _calculateDistanceMeters(previousPosition, currentPosition);
      if (movementDistance > 5.0) {
        bearing = SnapToRoad.calculateBearing(previousPosition, currentPosition);
        _lastBearings[driverId] = bearing;
      } else {
        // Pas de mouvement significatif - garder le bearing précédent
        bearing = _lastBearings[driverId];
      }
    } else {
      // Utiliser le cache seulement si on en a un valide
      bearing = _lastBearings[driverId];
    }

    final result = DriverSnapResult(
      driverId: driverId,
      snappedPosition: currentPosition,
      rawPosition: currentPosition,
      bearing: bearing, // null si pas de mouvement pour calculer
      distanceFromRoad: 0,
      isSnapped: false,
    );

    _cache[driverId] = result;
    return result;
  }

  /// Calcule la distance entre deux points en mètres (Haversine)
  static double _calculateDistanceMeters(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // mètres

    final lat1 = p1.latitude * (math.pi / 180);
    final lat2 = p2.latitude * (math.pi / 180);
    final dLat = (p2.latitude - p1.latitude) * (math.pi / 180);
    final dLng = (p2.longitude - p1.longitude) * (math.pi / 180);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Snappe plusieurs chauffeurs en parallèle (optimisé)
  static Future<List<DriverSnapResult>> snapMultipleDrivers(
    List<Map<String, dynamic>> drivers,
  ) async {
    final futures = <Future<DriverSnapResult>>[];

    for (final driver in drivers) {
      final driverData = driver['driverData'];
      if (driverData.currentLat != null && driverData.currentLng != null) {
        final currentPos = LatLng(driverData.currentLat!, driverData.currentLng!);
        LatLng? previousPos;

        if (driverData.oldLat != null && driverData.oldLng != null) {
          previousPos = LatLng(driverData.oldLat!, driverData.oldLng!);
        }

        futures.add(snapDriverPosition(
          driverId: driverData.id,
          currentPosition: currentPos,
          previousPosition: previousPos,
        ));
      }
    }

    return Future.wait(futures);
  }

  /// Nettoie le cache pour un chauffeur (quand il n'est plus affiché)
  static void clearCache(String driverId) {
    _cache.remove(driverId);
    _lastBearings.remove(driverId);
  }

  /// Nettoie tout le cache
  static void clearAllCache() {
    _cache.clear();
    _lastBearings.clear();
  }

  /// Récupère le dernier résultat en cache pour un chauffeur
  static DriverSnapResult? getCachedResult(String driverId) {
    return _cache[driverId];
  }
}
