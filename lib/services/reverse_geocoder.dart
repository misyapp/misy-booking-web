// ============================================================================
// Reverse Geocoder — service unifié misy_booking_web
//
// Levier F (audit GCP 2026-05-04). Cascade par étape (step) configurable
// depuis le dashboard `/admin/settings`. Permet à l'admin de basculer
// chaque step entre Google Geocoding (qualité max, payant) et Nominatim
// self-hosted (gratuit, qualité OSM).
//
// Source de config : Firestore `setting/geocoding_config` avec map `steps`
// dont chaque entrée = { first, fallback } ∈ { "google", "nominatim", "none" }.
//
// Cascade interne :
//   0. Cache RAM résultats (clé lat/lng arrondi 5 décimales, cap 200)
//   1. Si first != "none" → tenter ce provider, normalize, return
//   2. Si fallback != "none" ET fallback != first → tenter, normalize, return
//   3. Safety net : Nominatim public (nominatim.openstreetmap.org)
//   4. Fallback texte "Position GPS (lat, lng)"
//
// Normalisation : peu importe Google ou Nominatim, retourne un format
// 2-3 segments unifié pour rendre la bascule invisible côté UX.
// ============================================================================

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/services/location.dart';

class _GeocodingConfig {
  final bool enabled;
  final String nominatimUrl;
  final String nominatimBearerToken;
  final Map<String, Map<String, String>> steps;

  const _GeocodingConfig({
    required this.enabled,
    required this.nominatimUrl,
    required this.nominatimBearerToken,
    required this.steps,
  });

  static const _GeocodingConfig defaults = _GeocodingConfig(
    enabled: true,
    nominatimUrl: 'https://nominatim.misy.app',
    nominatimBearerToken: '',
    steps: {},
  );

  Map<String, String> stepConfig(String step) {
    return steps[step] ?? const {'first': 'google', 'fallback': 'nominatim'};
  }

  factory _GeocodingConfig.fromFirestore(Map<String, dynamic> data) {
    final stepsRaw = (data['steps'] ?? {}) as Map<String, dynamic>;
    final stepsOut = <String, Map<String, String>>{};
    stepsRaw.forEach((key, value) {
      if (value is Map) {
        stepsOut[key] = {
          'first': (value['first'] ?? 'google').toString(),
          'fallback': (value['fallback'] ?? 'nominatim').toString(),
        };
      }
    });
    return _GeocodingConfig(
      enabled: data['enabled'] ?? true,
      nominatimUrl: (data['nominatimUrl'] ?? 'https://nominatim.misy.app').toString(),
      nominatimBearerToken: (data['nominatimBearerToken'] ?? '').toString(),
      steps: stepsOut,
    );
  }
}

class ReverseGeocoder {
  ReverseGeocoder._();
  static final ReverseGeocoder instance = ReverseGeocoder._();

  // Cache résultats (lat/lng → adresse normalisée)
  final Map<String, String> _resultCache = {};
  static const int _resultCacheMaxSize = 200;

  // Cache config Firestore (TTL 60s)
  _GeocodingConfig _cachedConfig = _GeocodingConfig.defaults;
  DateTime _configFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _configTTL = Duration(seconds: 60);

  String _resultKey(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';

  Future<_GeocodingConfig> _getConfig() async {
    final now = DateTime.now();
    if (now.difference(_configFetchedAt) < _configTTL) {
      return _cachedConfig;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('setting')
          .doc('geocoding_config')
          .get(const GetOptions(source: Source.serverAndCache));
      if (snap.exists && snap.data() != null) {
        _cachedConfig = _GeocodingConfig.fromFirestore(snap.data()!);
      } else {
        _cachedConfig = _GeocodingConfig.defaults;
      }
    } catch (e) {
      myCustomPrintStatement('[ReverseGeocoder] config fetch failed (using defaults): $e');
      _cachedConfig = _GeocodingConfig.defaults;
    }
    _configFetchedAt = now;
    return _cachedConfig;
  }

  /// Reverse geocode lat/lng → adresse formatée pour affichage UI.
  ///
  /// [step] : ID de l'étape user (`web.mapClick`, `web.pickupSelect`,
  /// `web.dropSelect`). Lu dans la config Firestore pour décider la cascade.
  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
    required String step,
  }) async {
    final cacheKey = _resultKey(latitude, longitude);
    final cached = _resultCache[cacheKey];
    if (cached != null) return cached;

    final config = await _getConfig();

    String? resolved;

    if (config.enabled) {
      final stepCfg = config.stepConfig(step);
      final first = stepCfg['first'] ?? 'google';
      final fallback = stepCfg['fallback'] ?? 'nominatim';

      // Slot 1 : first
      if (first != 'none') {
        resolved = await _tryProvider(first, latitude, longitude, config, step);
      }

      // Slot 2 : fallback (différent du first)
      if (resolved == null && fallback != 'none' && fallback != first) {
        resolved = await _tryProvider(fallback, latitude, longitude, config, step);
      }
    }

    // Safety net : Nominatim public OSM (sans token, gratuit)
    resolved ??= await _tryNominatim(
      latitude,
      longitude,
      'https://nominatim.openstreetmap.org',
      bearerToken: '',
      label: 'OSM-public',
    );

    // Fallback ultime : texte coords
    resolved ??= 'Position GPS (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';

    // Cap cache
    if (_resultCache.length >= _resultCacheMaxSize) {
      _resultCache.remove(_resultCache.keys.first);
    }
    _resultCache[cacheKey] = resolved;

    return resolved;
  }

  Future<String?> _tryProvider(
    String provider,
    double lat,
    double lng,
    _GeocodingConfig config,
    String step,
  ) async {
    if (provider == 'google') {
      return _tryGoogle(lat, lng, step);
    } else if (provider == 'nominatim') {
      return _tryNominatim(
        lat,
        lng,
        config.nominatimUrl,
        bearerToken: config.nominatimBearerToken,
        label: 'self-hosted',
      );
    }
    return null;
  }

  Future<String?> _tryGoogle(double lat, double lng, String step) async {
    try {
      final raw = await getAddressWithPlusCodeByLatLng(latitude: lat, longitude: lng);
      final results = raw['results'];
      if (results is List && results.isNotEmpty) {
        final first = results[0] as Map<String, dynamic>;
        myCustomPrintStatement('[ReverseGeocoder] step=$step → Google ✓');
        return _normalizeGoogle(first);
      }
    } catch (e) {
      myCustomPrintStatement('[ReverseGeocoder] step=$step → Google failed: $e');
    }
    return null;
  }

  Future<String?> _tryNominatim(
    double lat,
    double lng,
    String baseUrl, {
    required String bearerToken,
    required String label,
  }) async {
    if (baseUrl.trim().isEmpty) return null;
    final cleaned = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse(
        '$cleaned/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=1&accept-language=fr');
    try {
      final headers = <String, String>{
        'User-Agent': 'Misy-Booking-Web/1.0 (admin@misyapp.com)',
        'Accept-Language': 'fr',
      };
      if (bearerToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $bearerToken';
      }
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        myCustomPrintStatement('[ReverseGeocoder] Nominatim $label ✓');
        return _normalizeNominatim(data);
      }
      myCustomPrintStatement('[ReverseGeocoder] Nominatim $label HTTP ${resp.statusCode}');
    } catch (e) {
      myCustomPrintStatement('[ReverseGeocoder] Nominatim $label err: $e');
    }
    return null;
  }

  /// Normalise une réponse Google Geocoding en string 2-3 segments propre.
  String _normalizeGoogle(Map<String, dynamic> result) {
    String formatted = (result['formatted_address'] ?? '').toString();
    formatted = removeGooglePlusCode(formatted);
    formatted = _removeCountrySuffix(formatted);

    // Enrichir avec neighborhood si trouvé
    final components = (result['address_components'] ?? []) as List;
    for (final c in components) {
      final m = c as Map<String, dynamic>;
      final types = (m['types'] ?? []) as List;
      if (types.contains('neighborhood') || types.contains('administrative_area_level_4')) {
        final hood = (m['long_name'] ?? '').toString();
        if (hood.isNotEmpty && !formatted.startsWith(hood)) {
          formatted = '$hood, $formatted';
        }
        break;
      }
    }
    return formatted.trim();
  }

  /// Normalise une réponse Nominatim en string 2-3 segments compacts.
  ///
  /// Évite la verbosité de `display_name` (5+ segments) : on prend
  /// `name` (POI ou locality) + `neighbourhood` ou `suburb` + `city`.
  String _normalizeNominatim(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString();
    final addr = (data['address'] ?? {}) as Map<String, dynamic>;
    final neighbourhood = (addr['neighbourhood'] ?? '').toString();
    final suburb = (addr['suburb'] ?? '').toString();
    final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? '').toString();

    final parts = <String>[];
    if (name.isNotEmpty && name != neighbourhood && name != suburb && name != city) {
      parts.add(name);
    }
    if (neighbourhood.isNotEmpty) {
      parts.add(neighbourhood);
    } else if (suburb.isNotEmpty) {
      parts.add(suburb);
    }
    if (city.isNotEmpty && !parts.contains(city)) {
      parts.add(city);
    }

    if (parts.isEmpty) {
      // Fallback display_name nettoyé si pas d'address structurée
      final display = (data['display_name'] ?? '').toString();
      return _removeCountrySuffix(display);
    }
    return parts.join(', ');
  }

  String _removeCountrySuffix(String address) {
    return address
        .replaceAll(RegExp(r',\s*Madagascar\s*$'), '')
        .trim();
  }
}
