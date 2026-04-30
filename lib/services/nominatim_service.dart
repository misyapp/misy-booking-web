import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/functions/print_function.dart';

/// Résultat d'une recherche Nominatim (OSM).
class NominatimPlace {
  final String displayName;
  final double lat;
  final double lon;
  final String shortName;

  const NominatimPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.shortName,
  });
}

/// Recherche / autocomplete de lieu via Nominatim (OSM) — utilisée par
/// l'éditeur terrain transport et par le calculateur d'itinéraire public.
///
/// Endpoint : Nominatim public OSM (sandbox). L'instance auto-hébergée
/// `nominatim.misy.app` est un proxy auth-protected sans token disponible
/// côté web pour l'instant ; on reste sur le public en attendant.
///
/// Respect de la Nominatim Usage Policy publique :
///   - max ~1 req/sec (debounce côté UI)
///   - User-Agent obligatoire identifiant l'app
///   - Pas d'abus volumétrique (ok pour une saisie interactive)
///
/// Biaisé Madagascar (`countrycodes=mg`) avec viewbox large autour de Tana
/// pour remonter les résultats locaux en priorité.
class NominatimService {
  NominatimService._();
  static final NominatimService instance = NominatimService._();

  static const String _endpoint =
      'https://nominatim.openstreetmap.org/search';
  static const String _userAgent =
      'Misy-Booking-Web/1.0 (https://book.misy.app; contact@misyapp.com)';

  // ViewBox biais Madagascar (lon_min, lat_min, lon_max, lat_max).
  static const String _viewbox = '43.2,-25.6,50.5,-11.9';

  Future<List<NominatimPlace>> search(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'limit': '$limit',
      'countrycodes': 'mg',
      'viewbox': _viewbox,
      // bounded=0 : biais soft (ne pas exclure les résultats hors viewbox).
      'bounded': '0',
      'addressdetails': '0',
    });
    try {
      final resp = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept-Language': 'fr',
      });
      if (resp.statusCode != 200) {
        myCustomPrintStatement('Nominatim ${resp.statusCode}: ${resp.body}');
        return const [];
      }
      final data = json.decode(resp.body) as List;
      return data.map((e) {
        final m = e as Map<String, dynamic>;
        final display = m['display_name']?.toString() ?? '';
        return NominatimPlace(
          displayName: display,
          lat: double.parse(m['lat'].toString()),
          lon: double.parse(m['lon'].toString()),
          shortName: _firstComma(display),
        );
      }).toList();
    } catch (e) {
      myCustomPrintStatement('Nominatim err: $e');
      return const [];
    }
  }

  String _firstComma(String s) {
    final i = s.indexOf(',');
    return (i > 0 ? s.substring(0, i) : s).trim();
  }
}
