import 'dart:async';
import 'dart:convert';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../functions/print_function.dart';
import 'routing/osrm_secure_client.dart';

/// Holds the decoded route coordinates alongside optional metadata.
class RouteInfo {
  RouteInfo({
    required this.coordinates,
    this.bounds,
    this.distanceMeters,
    this.durationSeconds,
  });

  /// Ordered list of points that describe the full route polyline.
  final List<LatLng> coordinates;

  /// Map bounds returned by the Google Directions API, if available.
  final LatLngBounds? bounds;

  /// Total distance in meters aggregated from each leg of the route.
  final double? distanceMeters;

  /// Total duration in seconds aggregated from each leg of the route.
  final double? durationSeconds;

  /// Convenience getter returning the total distance in kilometers if known.
  double? get distanceKm =>
      distanceMeters != null ? distanceMeters! / 1000.0 : null;

  /// Convenience getter returning the total travel time as a [Duration] if known.
  Duration? get duration => durationSeconds != null
      ? Duration(seconds: durationSeconds!.round())
      : null;
}

/// Service responsible for fetching and decoding routes from the Directions API.
class RouteService {
  RouteService._();

  /// Fetches a route between [origin] and [destination], optionally going through [waypoints].
  static Future<RouteInfo> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    String travelMode = 'driving',
  }) async {
    final List<LatLng> orderedPoints = <LatLng>[
      origin,
      ...waypoints,
      destination,
    ];

    final String coordinates = orderedPoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');

    final Set<String> allowedProfiles = {'driving', 'walking', 'cycling'};
    final String requestedProfile = travelMode.toLowerCase();
    final String profile =
        allowedProfiles.contains(requestedProfile) ? requestedProfile : 'driving';

    final String queryParams = 'overview=full&geometries=polyline';

    // Construction du path pour OSRM (sans le domaine)
    final String path = '/route/v1/$profile/$coordinates';

    try {
      // Utilisation du client OSRM sécurisé avec HMAC
      // Gère automatiquement le fallback OSRM2 → OSRM1
      myCustomLogStatements('🧭 RouteService → Fetching route via OSRM Secure Client');
      final http.Response response = await OsrmSecureClient.secureGet(
        path: path,
        queryParams: queryParams,
        timeoutSeconds: 3,
      );

      if (response.statusCode == 200) {
        return _parseOsrmResponse(response.body);
      }
      throw Exception('OSRM returned status ${response.statusCode}');
    } on Exception catch (error) {
      myCustomLogStatements('❌ RouteService OSRM error: $error');
      rethrow;
    }

    // [DEPRECATED] Google Directions API - remplacé par OSRM2.misy.app
    // final params = <String, String>{
    //   'origin': '${origin.latitude},${origin.longitude}',
    //   'destination': '${destination.latitude},${destination.longitude}',
    //   'mode': travelMode,
    //   'key': googleMapApiKey,
    // };
    //
    // if (waypoints.isNotEmpty) {
    //   params['waypoints'] =
    //       waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');
    // }
    //
    // final uri =
    //     Uri.https('maps.googleapis.com', '/maps/api/directions/json', params);
    // myCustomLogStatements('🧭 RouteService → GET $uri');
    //
    // late http.Response response;
    // try {
    //   response = await http.get(uri);
    // } on Exception catch (error) {
    //   myCustomLogStatements('❌ RouteService network error: $error');
    //   rethrow;
    // }
    //
    // if (response.statusCode != 200) {
    //   myCustomLogStatements(
    //       '❌ RouteService bad status: ${response.statusCode} -> ${response.body}');
    //   throw Exception('Failed to fetch route: HTTP ${response.statusCode}');
    // }
    //
    // final Map<String, dynamic> data = jsonDecode(response.body);
    // final status = data['status'] as String?;
    //
    // if (status != 'OK') {
    //   myCustomLogStatements(
    //       '❌ RouteService API status not OK: $status ${data['error_message'] ?? ''}');
    //   throw Exception('Directions API error: $status');
    // }
    //
    // final routes = data['routes'] as List<dynamic>? ?? [];
    // if (routes.isEmpty) {
    //      myCustomLogStatements('❌ RouteService no routes found in response');
    //      throw Exception('No routes found');
    // }
    //
    // final primaryRoute = routes.first as Map<String, dynamic>;
    // final overviewPolyline = primaryRoute['overview_polyline'] as Map?;
    // final encodedPoints = overviewPolyline?['points'] as String?;
    // if (encodedPoints == null || encodedPoints.isEmpty) {
    //   myCustomLogStatements('❌ RouteService missing overview polyline');
    //   throw Exception('Route polyline missing from response');
    // }
    //
    // final polylinePoints =
    //     PolylinePoints().decodePolyline(encodedPoints).map((point) {
    //   return LatLng(point.latitude, point.longitude);
    // }).toList();
    //
    // if (polylinePoints.isEmpty) {
    //   myCustomLogStatements('❌ RouteService decoded 0 polyline points');
    //   throw Exception('Failed to decode route polyline');
    // }
    //
    // final boundsJson = primaryRoute['bounds'] as Map<String, dynamic>?;
    // LatLngBounds? bounds;
    // if (boundsJson != null) {
    //   final northeast = boundsJson['northeast'] as Map<String, dynamic>?;
    //   final southwest = boundsJson['southwest'] as Map<String, dynamic>?;
    //   if (northeast != null && southwest != null) {
    //     bounds = LatLngBounds(
    //       northeast: LatLng(
    //         (northeast['lat'] as num).toDouble(),
    //         (northeast['lng'] as num).toDouble(),
    //       ),
    //       southwest: LatLng(
    //         (southwest['lat'] as num).toDouble(),
    //         (southwest['lng'] as num).toDouble(),
    //       ),
    //     );
    //   }
    // }
    //
    // double? totalDistanceMeters;
    // double? totalDurationSeconds;
    //
    // final legs = primaryRoute['legs'] as List<dynamic>?;
    // if (legs != null && legs.isNotEmpty) {
    //   double distance = 0;
    //   double duration = 0;
    //
    //   for (final leg in legs) {
    //     final distanceValue =
    //         ((leg as Map)['distance']?['value'] as num?)?.toDouble();
    //     final durationValue = (leg['duration']?['value'] as num?)?.toDouble();
    //
    //     if (distanceValue != null) {
    //       distance += distanceValue;
    //     }
    //     if (durationValue != null) {
    //       duration += durationValue;
    //     }
    //   }
    //
    //   totalDistanceMeters = distance > 0 ? distance : null;
    //   totalDurationSeconds = duration > 0 ? duration : null;
    // }
    //
    // myCustomLogStatements(
    //     '✅ RouteService decoded ${polylinePoints.length} points (distance: ${totalDistanceMeters ?? 'n/a'} m)');
    //
    // return RouteInfo(
    //   coordinates: polylinePoints,
    //   bounds: bounds,
    //   distanceMeters: totalDistanceMeters,
    //   durationSeconds: totalDurationSeconds,
    // );
  }

  static RouteInfo _parseOsrmResponse(String body) {
    final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
    final String? code = data['code'] as String?;

    if (code != null && code != 'Ok') {
      myCustomLogStatements(
          '❌ RouteService OSRM response code not OK: $code ${data['message'] ?? ''}');
      throw Exception('OSRM error: $code');
    }

    final List<dynamic> routes = data['routes'] as List<dynamic>? ?? <dynamic>[];
    if (routes.isEmpty) {
      myCustomLogStatements('❌ RouteService no routes found in OSRM response');
      throw Exception('No routes found');
    }

    final Map<String, dynamic> primaryRoute =
        routes.first as Map<String, dynamic>;
    final String? encodedGeometry = primaryRoute['geometry'] as String?;

    if (encodedGeometry == null || encodedGeometry.isEmpty) {
      myCustomLogStatements('❌ RouteService missing OSRM geometry');
      throw Exception('Route geometry missing from response');
    }

    final List<LatLng> polylinePoints =
        PolylinePoints().decodePolyline(encodedGeometry).map((point) {
      return LatLng(point.latitude, point.longitude);
    }).toList();

    if (polylinePoints.isEmpty) {
      myCustomLogStatements('❌ RouteService decoded 0 OSRM polyline points');
      throw Exception('Failed to decode route polyline');
    }

    final double? distanceMeters =
        (primaryRoute['distance'] as num?)?.toDouble();
    final double? durationSeconds =
        (primaryRoute['duration'] as num?)?.toDouble();

    myCustomLogStatements(
        '✅ RouteService decoded ${polylinePoints.length} points (distance: ${distanceMeters ?? 'n/a'} m)');

    return RouteInfo(
      coordinates: polylinePoints,
      bounds: null,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }
}
