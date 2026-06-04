import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/functions/print_function.dart';

/// Faisceaux LOOM pré-calculés de la vue réseau « toutes lignes »
/// (Transport en commun, book.misy.app).
///
/// Charge `web/transport_network/network_strands.json`, généré au build par
/// `tools/network/build_network_map.sh` (Firestore prod → bundle → misy2loom
/// → topo|loom → loom2strands). Chaque ligne y est une liste de runs
/// continus dont les points portent (vLat, vLng) = perpendiculaire unitaire
/// × facteur de slot — la sémantique de `_StrandPt` : le rendu existant
/// applique l'offset réel au zoom courant via `_applyStrandOffset`.
///
/// Derrière le flag compile-time `--dart-define=LOOM_NETWORK=true`.
/// Tout échec (flag off, fichier absent, HTTP ≠ 200, parse KO) → `false`
/// et le runtime retombe sur l'heuristique `_precomputeStrandRuns`
/// (aucune régression possible de la vue réseau).
class LoomNetworkService {
  LoomNetworkService._();

  static final LoomNetworkService instance = LoomNetworkService._();

  /// Flag d'activation du rendu LOOM (A/B avec l'heuristique runtime).
  static const bool flagEnabled = bool.fromEnvironment('LOOM_NETWORK');

  static const String _jsonPath = 'transport_network/network_strands.json';

  Future<bool>? _loadFuture;
  Map<String, List<LoomStrandRun>>? _runsByLine;

  /// Densité de corridor au-delà de laquelle les brins sont amincis
  /// (recopiée du `meta.denseK` du JSON ; 6 par défaut).
  int denseK = 6;

  /// Charge (une fois) le JSON des faisceaux. `true` = rendu LOOM dispo.
  Future<bool> ensureLoaded() {
    if (!flagEnabled) return Future.value(false);
    return _loadFuture ??= _load();
  }

  Future<bool> _load() async {
    try {
      final res = await http.get(Uri.base.resolve(_jsonPath));
      if (res.statusCode != 200) {
        myCustomPrintStatement(
            'LoomNetworkService: HTTP ${res.statusCode} pour $_jsonPath '
            '→ fallback heuristique');
        return false;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final meta = json['meta'] as Map<String, dynamic>? ?? const {};
      denseK = (meta['denseK'] as num?)?.toInt() ?? 6;
      final lines = json['lines'] as Map<String, dynamic>? ?? const {};
      final parsed = <String, List<LoomStrandRun>>{};
      lines.forEach((lineNumber, v) {
        final runs = (v as Map<String, dynamic>)['runs'] as List? ?? const [];
        parsed[lineNumber] = [
          for (final r in runs)
            LoomStrandRun(
              k: ((r as Map<String, dynamic>)['k'] as num?)?.toInt() ?? 1,
              pts: [
                for (final p in r['pts'] as List)
                  [
                    (p[0] as num).toDouble(), // lat
                    (p[1] as num).toDouble(), // lng
                    (p[2] as num).toDouble(), // vLat (× slot)
                    (p[3] as num).toDouble(), // vLng (× slot)
                  ],
              ],
            ),
        ];
      });
      _runsByLine = parsed;
      myCustomPrintStatement(
          'LoomNetworkService: ${parsed.length} lignes, corridor max '
          '${meta['maxCorridor']} (run ${meta['generated']})');
      return parsed.isNotEmpty;
    } catch (e) {
      myCustomPrintStatement(
          'LoomNetworkService: erreur chargement $_jsonPath: $e '
          '→ fallback heuristique');
      return false;
    }
  }

  /// Runs LOOM d'une ligne (clé = `line_number` exact du manifest),
  /// `null` si absente (→ fallback tracé brut côté rendu).
  List<LoomStrandRun>? runsFor(String lineNumber) => _runsByLine?[lineNumber];
}

/// Une pièce continue du tracé d'une ligne en vue réseau : points
/// `[lat, lng, vLat, vLng]` + densité max [k] du corridor traversé
/// (k > [LoomNetworkService.denseK] → brins amincis au rendu).
class LoomStrandRun {
  final int k;
  final List<List<double>> pts;

  const LoomStrandRun({required this.k, required this.pts});
}
