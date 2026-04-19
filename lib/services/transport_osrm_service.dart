import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

/// Appel OSRM pour générer un tracé routier entre 2+ points (profil driving).
/// Renvoie les coordonnées en [lng, lat] (format GeoJSON natif).
///
/// Endpoint : OSRM public par défaut. Fallback possible vers le proxy
/// book.misy.app/osrm-proxy.php si le public rate-limit.
class TransportOsrmService {
  TransportOsrmService._();
  static final TransportOsrmService instance = TransportOsrmService._();

  static const String _publicBase = 'https://router.project-osrm.org';
  static const String _proxyBase = 'https://book.misy.app/osrm-proxy.php';

  /// Route driving entre une liste ordonnée de points.
  /// [waypoints] en LatLng (lat,lng). Renvoie coords en [lng, lat].
  Future<List<List<double>>?> routeDriving(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;

    final coordsPart = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    // 1. Essai OSRM public
    try {
      final url = Uri.parse(
        '$_publicBase/route/v1/driving/$coordsPart'
        '?overview=full&geometries=geojson&continue_straight=true',
      );
      final resp =
          await http.get(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final parsed = _parseGeometry(resp.body);
        if (parsed != null) return parsed;
      }
      myCustomPrintStatement('OSRM public HTTP ${resp.statusCode}');
    } catch (e) {
      myCustomPrintStatement('OSRM public KO: $e');
    }

    // 2. Fallback proxy
    try {
      final url = Uri.parse(
        '$_proxyBase?path=/route/v1/driving/$coordsPart'
        '&overview=full&geometries=geojson',
      );
      final resp =
          await http.get(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        return _parseGeometry(resp.body);
      }
      myCustomPrintStatement('OSRM proxy HTTP ${resp.statusCode}');
    } catch (e) {
      myCustomPrintStatement('OSRM proxy KO: $e');
    }

    return null;
  }

  List<List<double>>? _parseGeometry(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final geom = routes.first['geometry'] as Map<String, dynamic>;
      final coords = geom['coordinates'] as List;
      return coords
          .map((c) => [
                (c[0] as num).toDouble(),
                (c[1] as num).toDouble(),
              ])
          .toList();
    } catch (e) {
      myCustomPrintStatement('OSRM parse KO: $e');
      return null;
    }
  }
}
