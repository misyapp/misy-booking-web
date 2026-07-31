import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';

/// VITRINE « chauffeurs proches » — chauffeurs HORS LIGNE affichés sur la carte, à leur
/// dernière position connue, en complément des chauffeurs réellement en ligne.
///
/// POURQUOI : les balayages auto-offline déconnectent les chauffeurs faussement en ligne.
/// Au 30/07/2026 il ne restait que ~22 chauffeurs en ligne sur 5 020 → carte quasi vide à
/// l'ouverture de book.misy.app, ce qui décourage le visiteur avant même qu'il commande.
///
/// POURQUOI PAS FIRESTORE : retirer le filtre `isOnline == true` du listener ferait passer
/// chaque ouverture du site de ~22 à 5 020 documents lus (~200 $/mois). La vitrine est donc
/// servie par le dashboard (`GET /api/public/nearby-drivers`), qui la calcule à partir du
/// miroir annuaire déjà présent sur son disque → 0 lecture Firestore côté client.
///
/// INTERRUPTEUR : le dashboard répond `disabled: true` (liste vide) si la géozone du point
/// n'a pas coché « Chauffeurs vitrine hors ligne » (/admin/geo-zones). Rien à gérer ici :
/// une liste vide se comporte exactement comme une vitrine indisponible.
///
/// GARANTIES : fail-open (toute erreur ⇒ liste vide, la carte reste celle d'avant), un seul
/// appel réseau par zone/TTL, jamais de blocage de l'UI.
class NearbyShowcaseService {
  static const String _endpoint = 'https://misy-app.com/api/public/nearby-drivers';

  /// Durée de validité du cache mémoire. Les chauffeurs hors ligne ne bougent pas :
  /// inutile de réinterroger souvent.
  static const Duration _ttl = Duration(minutes: 10);

  /// Au-delà de ce déplacement du point de référence, le cache n'est plus pertinent.
  static const double _maxRefDriftKm = 2.0;

  /// Après un échec réseau, on ne réessaie pas avant ce délai (évite de marteler).
  static const Duration _failureBackoff = Duration(minutes: 2);

  static const Duration _timeout = Duration(seconds: 6);

  static List<ShowcaseDriver> _cache = const [];
  static DateTime? _cachedAt;
  static double? _refLat;
  static double? _refLng;
  static int _cachedLimit = 0;
  static DateTime? _lastFailureAt;
  static Future<bool>? _inFlight;

  /// Vitrine en cache pour ce point de référence, sans aucun appel réseau.
  /// Renvoie une liste vide si le cache est absent, périmé ou trop loin.
  static List<ShowcaseDriver> cached(double refLat, double refLng) {
    if (_cache.isEmpty || _cachedAt == null) return const [];
    if (DateTime.now().difference(_cachedAt!) > _ttl) return const [];
    if (!_isNearCachedRef(refLat, refLng)) return const [];
    return _cache;
  }

  /// Récupère la vitrine si nécessaire. Renvoie `true` si le cache a CHANGÉ (donc s'il
  /// faut redessiner), `false` s'il était déjà bon ou si l'appel a échoué.
  ///
  /// Ne lève jamais : l'appelant peut l'ignorer sans `try`.
  static Future<bool> prefetch({
    required double lat,
    required double lng,
    int limit = 8,
  }) {
    // Cache encore valable ET assez fourni → rien à faire.
    if (_cachedAt != null &&
        DateTime.now().difference(_cachedAt!) <= _ttl &&
        _isNearCachedRef(lat, lng) &&
        _cachedLimit >= limit) {
      return Future.value(false);
    }

    // Un appel est déjà en vol : on se greffe dessus au lieu d'en lancer un second.
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    if (_lastFailureAt != null &&
        DateTime.now().difference(_lastFailureAt!) < _failureBackoff) {
      return Future.value(false);
    }

    final future = _fetch(lat, lng, limit).whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  static Future<bool> _fetch(double lat, double lng, int limit) async {
    try {
      final uri = Uri.parse('$_endpoint?lat=$lat&lng=$lng&limit=$limit');
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) {
        _lastFailureAt = DateTime.now();
        myCustomPrintStatement('🚗 Vitrine chauffeurs : HTTP ${res.statusCode}');
        return false;
      }

      final body = jsonDecode(res.body);
      final rawList =
          (body is Map && body['drivers'] is List) ? body['drivers'] as List : const [];
      final parsed = <ShowcaseDriver>[];
      for (final raw in rawList) {
        if (raw is! Map) continue;
        final d = ShowcaseDriver.fromJson(raw);
        if (d != null) parsed.add(d);
      }

      _cache = parsed;
      _cachedAt = DateTime.now();
      _refLat = lat;
      _refLng = lng;
      _cachedLimit = limit;
      _lastFailureAt = null;
      myCustomPrintStatement('🚗 Vitrine chauffeurs : ${parsed.length} positions hors ligne');
      return parsed.isNotEmpty;
    } catch (e) {
      // Fail-open : réseau coupé, serveur down, JSON inattendu… la carte garde
      // simplement les chauffeurs en ligne, exactement comme avant cette feature.
      _lastFailureAt = DateTime.now();
      myCustomPrintStatement('🚗 Vitrine chauffeurs indisponible : $e');
      return false;
    }
  }

  static bool _isNearCachedRef(double lat, double lng) {
    if (_refLat == null || _refLng == null) return false;
    // Approximation plate suffisante à cette échelle (1° lat ≈ 111 km).
    final dLat = (lat - _refLat!) * 111.0;
    final dLng = (lng - _refLng!) * 111.0;
    return (dLat * dLat + dLng * dLng) <= (_maxRefDriftKm * _maxRefDriftKm);
  }

  /// Vide le cache (changement de compte, déconnexion, tests).
  static void reset() {
    _cache = const [];
    _cachedAt = null;
    _refLat = null;
    _refLng = null;
    _cachedLimit = 0;
    _lastFailureAt = null;
  }
}

/// Un chauffeur de la vitrine : position approximative + catégorie + photo.
/// Aucune donnée nominative ne transite (ni nom, ni téléphone, ni id Firestore).
class ShowcaseDriver {
  /// Clé opaque stable, utilisée comme id de marker (préfixée pour ne jamais
  /// entrer en collision avec un id de chauffeur Firestore).
  final String key;
  final double lat;
  final double lng;
  final String vehicleType;
  final String photo;

  const ShowcaseDriver({
    required this.key,
    required this.lat,
    required this.lng,
    required this.vehicleType,
    required this.photo,
  });

  static ShowcaseDriver? fromJson(Map raw) {
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    final vt = raw['vt']?.toString() ?? '';
    final k = raw['k']?.toString() ?? '';
    if (lat == null || lng == null || vt.isEmpty || k.isEmpty) return null;
    return ShowcaseDriver(
      key: 'showcase_$k',
      lat: lat,
      lng: lng,
      vehicleType: vt,
      photo: raw['photo']?.toString() ?? '',
    );
  }

  /// Chauffeur synthétique pour réutiliser tel quel le pipeline de markers
  /// (icône par catégorie, animation). `isOnline: false` est volontaire : aucun
  /// code métier ne doit le confondre avec un chauffeur joignable.
  ///
  /// ⚠️ Contrairement à la riderapp, `DriverModal` a ici des champs NON nullables
  /// (`email`, `verified`, `isBlocked`, `profileImage`, `fullName`…) : il faut tous
  /// les fournir, sinon `fromJson` lève un TypeError sur un null.
  DriverModal toDriverModal() => DriverModal.fromJson({
        'id': key,
        'currentLat': lat,
        'currentLng': lng,
        'vehicleType': vehicleType,
        'profileImage': photo,
        'isOnline': false,
        'isCustomer': false,
        'verified': true,
        'isBlocked': false,
        'email': '',
        'name': '',
      });
}