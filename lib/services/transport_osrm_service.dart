import 'dart:convert';
import 'dart:math' as math;

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

  /// OSRM public limite à ~25 waypoints par requête. Au-delà, on chunke.
  static const int _maxWaypointsPerRequest = 25;

  /// Route driving entre une liste ordonnée de points.
  /// [waypoints] en LatLng (lat,lng). Renvoie coords en [lng, lat].
  ///
  /// Pour > 25 waypoints, split en sous-requêtes qui partagent un waypoint
  /// de jointure (p. ex. [0..24], [24..48], ...) et concatène les geometries.
  Future<List<List<double>>?> routeDriving(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;

    if (waypoints.length <= _maxWaypointsPerRequest) {
      return _routeSegment(waypoints);
    }

    // Chunking : chunks overlapping sur 1 waypoint (le dernier de l'un = le
    // premier du suivant) pour éviter les discontinuités.
    final merged = <List<double>>[];
    int start = 0;
    while (start < waypoints.length - 1) {
      final end = math.min(start + _maxWaypointsPerRequest, waypoints.length);
      final chunk = waypoints.sublist(start, end);
      final seg = await _routeSegment(chunk);
      if (seg == null) return null;
      if (merged.isEmpty) {
        merged.addAll(seg);
      } else {
        // Skip le premier point du nouveau chunk (= dernier du précédent)
        merged.addAll(seg.length > 1 ? seg.sublist(1) : seg);
      }
      if (end >= waypoints.length) break;
      start = end - 1;
    }
    return merged.isEmpty ? null : merged;
  }

  /// Tracé piéton entre 2 points. Renvoie geometry [lng,lat] + durée en
  /// secondes calculée à **vitesse de marche** (4.5 km/h ≈ 1.25 m/s),
  /// indépendamment du profil OSRM utilisé.
  ///
  /// Important : router.project-osrm.org ne déploie en pratique que le
  /// profil `car`. Même quand on lui demande `/walking/...`, il répond
  /// avec une durée pertinente pour la voiture (≈ 24 km/h). On ne fait
  /// donc JAMAIS confiance à `route.duration` retourné par OSRM pour ce
  /// usage : on prend uniquement la geometry (qui suit les rues, ok pour
  /// la marche) puis on recalcule la durée à partir de la longueur réelle.
  /// Cache mémoire (a→b → résultat). La clé arrondit les coords à 5 décimales
  /// (~1.1m) pour que des appels équivalents partagent le résultat sans
  /// repayer un round-trip HTTP. Vide à la fermeture de l'onglet.
  static final Map<String, ({
    List<List<double>> geometry,
    double durationSec,
    double distanceMeters
  })> _footCache = {};

  Future<({
    List<List<double>> geometry,
    double durationSec,
    double distanceMeters
  })?> routeFoot(LatLng a, LatLng b) async {
    final coords = '${a.longitude},${a.latitude};${b.longitude},${b.latitude}';
    const walkSpeedMps = 1.25; // 4.5 km/h, vitesse de marche standard
    final cacheKey =
        '${a.latitude.toStringAsFixed(5)},${a.longitude.toStringAsFixed(5)}|'
        '${b.latitude.toStringAsFixed(5)},${b.longitude.toStringAsFixed(5)}';
    final cached = _footCache[cacheKey];
    if (cached != null) return cached;

    // 1. Essai profils piétons (geometry seule), sinon driving en fallback.
    //    On essaie OSRM public puis le proxy book.misy.app pour chaque
    //    profil. CRITIQUE : le proxy ignore les query params qui ne sont
    //    PAS dans `path=` ; on doit donc URL-encode l'URL entière (path +
    //    query string OSRM) dans la valeur de `path`. Sans ça, OSRM ne
    //    voit pas `geometries=geojson` et renvoie une polyline encodée
    //    qui causait des overflows int32 dans le decoder Dart-JS.
    List<List<double>>? geom;
    for (final profile in const ['walking', 'foot']) {
      final innerPath =
          '/route/v1/$profile/$coords?overview=full&geometries=geojson';
      final urls = <Uri>[
        Uri.parse('$_publicBase$innerPath'),
        Uri.parse('$_proxyBase?path=${Uri.encodeComponent(innerPath)}'),
      ];
      for (final url in urls) {
        try {
          final resp =
              await http.get(url).timeout(const Duration(seconds: 5));
          if (resp.statusCode == 200) {
            geom = _parseGeometry(resp.body);
            if (geom != null && geom.isNotEmpty) break;
          }
        } catch (e) {
          myCustomPrintStatement('OSRM $profile ${url.host} KO: $e');
        }
      }
      if (geom != null && geom.isNotEmpty) break;
    }
    geom ??= await _routeSegment([a, b]);
    if (geom == null || geom.isEmpty) return null;

    final distMeters = _polylineLengthMeters(geom);
    // Sanity check : la geometry retournée doit avoir une longueur cumulée
    // cohérente avec la distance géodésique a→b. Si elle est > 5× la ligne
    // droite, la polyline est probablement corrompue (decoder bug,
    // endpoint qui retourne du noise, etc.) → fallback ligne droite à
    // vitesse de marche pour rester dans des valeurs réalistes.
    final straightMeters = _haversine(a, b);
    if (distMeters > 5 * straightMeters && straightMeters > 50) {
      myCustomPrintStatement(
          'OSRM geometry suspecte (${distMeters.toInt()}m vs straight ${straightMeters.toInt()}m), fallback ligne droite');
      final fallback = (
        geometry: <List<double>>[
          [a.longitude, a.latitude],
          [b.longitude, b.latitude],
        ],
        durationSec: straightMeters / walkSpeedMps,
        distanceMeters: straightMeters,
      );
      _footCache[cacheKey] = fallback;
      return fallback;
    }
    final result = (
      geometry: geom,
      durationSec: distMeters / walkSpeedMps,
      distanceMeters: distMeters,
    );
    _footCache[cacheKey] = result;
    return result;
  }

  static double _haversine(LatLng a, LatLng b) {
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

  double _polylineLengthMeters(List<List<double>> coords) {
    if (coords.length < 2) return 0;
    const earthR = 6371000.0;
    double total = 0;
    for (var i = 1; i < coords.length; i++) {
      final lng1 = coords[i - 1][0] * math.pi / 180.0;
      final lat1 = coords[i - 1][1] * math.pi / 180.0;
      final lng2 = coords[i][0] * math.pi / 180.0;
      final lat2 = coords[i][1] * math.pi / 180.0;
      final dLat = lat2 - lat1;
      final dLng = lng2 - lng1;
      final h = math.pow(math.sin(dLat / 2), 2).toDouble() +
          math.cos(lat1) *
              math.cos(lat2) *
              math.pow(math.sin(dLng / 2), 2).toDouble();
      total += earthR * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    }
    return total;
  }

  Future<List<List<double>>?> _routeSegment(List<LatLng> waypoints) async {
    final coordsPart = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    // CRITIQUE : on URL-encode l'URL OSRM (path + query) DANS le paramètre
    // `path=` du proxy. Sans ça, le proxy n'utilise que la portion `path=`
    // et le query string `&geometries=geojson&overview=full` est ignoré,
    // OSRM renvoie alors une polyline encodée par défaut.
    final innerPath =
        '/route/v1/driving/$coordsPart?overview=full&geometries=geojson&continue_straight=true';
    final urls = <Uri>[
      Uri.parse('$_publicBase$innerPath'),
      Uri.parse('$_proxyBase?path=${Uri.encodeComponent(innerPath)}'),
    ];
    for (final url in urls) {
      try {
        final resp =
            await http.get(url).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final parsed = _parseGeometry(resp.body);
          if (parsed != null) return parsed;
        }
        myCustomPrintStatement('OSRM ${url.host} HTTP ${resp.statusCode}');
      } catch (e) {
        myCustomPrintStatement('OSRM ${url.host} KO: $e');
      }
    }
    return null;
  }

  List<List<double>>? _parseGeometry(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final geom = (routes.first as Map<String, dynamic>)['geometry'];
      // OSRM peut renvoyer la geometry en GeoJSON (objet) si l'API a bien
      // accepté `geometries=geojson`, ou en polyline encodé (string) si le
      // proxy ne forward pas le query param. On gère les 2 cas.
      if (geom is Map) {
        final coords = geom['coordinates'] as List;
        return coords
            .map((c) => [
                  (c[0] as num).toDouble(),
                  (c[1] as num).toDouble(),
                ])
            .toList();
      }
      if (geom is String) {
        return _decodePolyline(geom, precision: 5);
      }
      return null;
    } catch (e) {
      myCustomPrintStatement('OSRM parse KO: $e');
      return null;
    }
  }

  /// Décode un polyline encodé Google/OSRM (precision 5 par défaut).
  /// Renvoie la liste de coordonnées au format `[lng, lat]` (GeoJSON-like).
  ///
  /// Algo standard : chaque coord est encodée comme delta Int sur 5 bits
  /// par chunk + bit de continuation. Cf. OSRM docs (`geometries=polyline`
  /// vs `polyline6`).
  static List<List<double>> _decodePolyline(String str, {int precision = 5}) {
    final factor = math.pow(10, precision).toDouble();
    final coords = <List<double>>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    final len = str.length;
    while (index < len) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = str.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        byte = str.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      coords.add([lng / factor, lat / factor]);
    }
    return coords;
  }
}
