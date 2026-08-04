import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rider_ride_hailing_app/services/reverse_geocoder.dart';

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
/// Endpoint : **uniquement** notre instance `nominatim.misy.app`, via le token
/// de `setting/geocoding_config` (le même que celui déjà utilisé par
/// [ReverseGeocoder] côté web).
///
/// 🚫 On n'interroge JAMAIS `nominatim.openstreetmap.org` : la politique de la
/// fondation OSM interdit le trafic applicatif automatisé. Sans token, la
/// recherche renvoie une liste vide — l'appelant retombe sur ses propres
/// suggestions (arrêts, historique, tap sur la carte).
///
/// Viewbox large autour de Madagascar pour remonter les résultats locaux en
/// priorité (pas de `countrycodes` : notre instance est multi-région).
class NominatimService {
  NominatimService._();
  static final NominatimService instance = NominatimService._();

  // ViewBox biais Madagascar (lon_min, lat_min, lon_max, lat_max).
  static const String _viewbox = '43.2,-25.6,50.5,-11.9';

  Future<List<NominatimPlace>> search(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final ep = await ReverseGeocoder.instance.selfHostedNominatim();
    if (ep == null) {
      // ignore: avoid_print
      print('[Nominatim] pas de token privé → recherche désactivée '
          '(on ne tape jamais l\'instance publique OSM)');
      return const [];
    }
    final uri = Uri.parse('${ep.base}/search').replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'limit': '$limit',
      'viewbox': _viewbox,
      // bounded=0 : biais soft (ne pas exclure les résultats hors viewbox).
      'bounded': '0',
      'addressdetails': '0',
    });
    try {
      // Le Bearer déclenche un preflight OPTIONS — notre proxy y répond
      // correctement (contrairement à l'instance publique, qui renvoyait un
      // 302 vers /ui/search.html : c'est ce qui avait motivé l'absence de
      // headers ici à l'origine).
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer ${ep.token}',
      });
      if (resp.statusCode != 200) {
        // Log explicite en console DevTools pour diagnostic.
        // ignore: avoid_print
        print('[Nominatim] ${resp.statusCode}: ${resp.body}');
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
      // ignore: avoid_print
      print('[Nominatim] error: $e');
      return const [];
    }
  }

  String _firstComma(String s) {
    final i = s.indexOf(',');
    return (i > 0 ? s.substring(0, i) : s).trim();
  }
}
