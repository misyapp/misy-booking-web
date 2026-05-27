import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration multi-région des Cloud Functions HTTP (audit GCP 2026-05-14,
/// levier I). Lit `setting/cloud_functions_config` Firestore avec cache RAM 60s
/// pour permettre une bascule us-central1 → asia-east1 sans rebuild app.
///
/// Pendant la fenêtre d'adoption (~2-3 semaines après release), les fonctions
/// sont déployées en parallèle dans les 2 régions, et ce flag pilote laquelle
/// est appelée. Une fois adoption ≥ 80 %, l'admin bascule le flag
/// `setting/cloud_functions_config` côté Firestore → toutes les apps actives
/// switchent en < 60 s sans rebuild.
///
/// Structure du doc Firestore :
/// ```
/// setting/cloud_functions_config:
///   mainFunction:             "us-central1"  ou  "asia-east1"
///   sendNotificationFunction: "us-central1"  ou  "asia-east1"
///   updateSchedulerJob:       "us-central1"  ou  "asia-east1"
/// ```
class CloudFunctionsConfig {
  static const String _projectId = "misy-95336";

  static const Map<String, String> _defaults = {
    'mainFunction': 'us-central1',
    'sendNotificationFunction': 'us-central1',
    'updateSchedulerJob': 'us-central1',
  };

  static final Map<String, String> _cache = Map.from(_defaults);
  static DateTime _fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _ttl = Duration(seconds: 60);

  /// Retourne la région courante pour [functionName] (`mainFunction`,
  /// `sendNotificationFunction`, `updateSchedulerJob`). Fallback : us-central1.
  static Future<String> regionFor(String functionName) async {
    if (DateTime.now().difference(_fetchedAt) >= _ttl) {
      await _refresh();
    }
    return _cache[functionName] ?? _defaults[functionName] ?? 'us-central1';
  }

  /// URL HTTP complète de la Cloud Function [functionName] dans la région
  /// courante. Ex: `https://asia-east1-misy-95336.cloudfunctions.net/mainFunction`.
  static Future<String> urlFor(String functionName) async {
    final region = await regionFor(functionName);
    return 'https://$region-$_projectId.cloudfunctions.net/$functionName';
  }

  static Future<void> _refresh() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('setting')
          .doc('cloud_functions_config')
          .get(const GetOptions(source: Source.serverAndCache));
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        for (final key in _defaults.keys) {
          final val = (data[key] ?? _defaults[key]).toString();
          if (val == 'us-central1' || val == 'asia-east1') {
            _cache[key] = val;
          }
        }
      }
    } catch (e) {
      // Garde le cache existant (defaults au premier appel)
    }
    _fetchedAt = DateTime.now();
  }
}
