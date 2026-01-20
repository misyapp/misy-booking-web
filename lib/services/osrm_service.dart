import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/functions/print_function.dart';

/// Service pour obtenir des itinéraires piétons via OSRM
class OsrmService {
  static const String _baseUrl = 'https://router.project-osrm.org';

  /// Obtient un itinéraire piéton entre deux points
  /// Retourne une liste de coordonnées pour le tracé
  static Future<OsrmWalkingRoute?> getWalkingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      // Format: /route/v1/foot/{lon1},{lat1};{lon2},{lat2}
      final url = Uri.parse(
        '$_baseUrl/route/v1/foot/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          // Convertir les coordonnées GeoJSON [lon, lat] en LatLng
          final points = coordinates.map<LatLng>((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          // Durée en secondes, distance en mètres
          final duration = (route['duration'] as num).toDouble();
          final distance = (route['distance'] as num).toDouble();

          return OsrmWalkingRoute(
            points: points,
            durationSeconds: duration,
            distanceMeters: distance,
          );
        }
      }

      myCustomPrintStatement('OSRM error: ${response.statusCode}');
      return null;
    } catch (e) {
      myCustomPrintStatement('OSRM request failed: $e');
      return null;
    }
  }

  /// Obtient plusieurs itinéraires piétons en parallèle
  static Future<List<OsrmWalkingRoute?>> getMultipleWalkingRoutes(
    List<(LatLng, LatLng)> originDestinationPairs,
  ) async {
    final futures = originDestinationPairs.map(
      (pair) => getWalkingRoute(pair.$1, pair.$2),
    );
    return Future.wait(futures);
  }
}

/// Représente un itinéraire piéton OSRM
class OsrmWalkingRoute {
  final List<LatLng> points;
  final double durationSeconds;
  final double distanceMeters;

  OsrmWalkingRoute({
    required this.points,
    required this.durationSeconds,
    required this.distanceMeters,
  });

  /// Durée en minutes
  int get durationMinutes => (durationSeconds / 60).ceil();

  /// Distance en kilomètres
  double get distanceKm => distanceMeters / 1000;
}
