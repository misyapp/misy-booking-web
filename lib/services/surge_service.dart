import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Une cellule hexagonale en surge (miroir d'un doc `surge_state`).
class _SurgeCell {
  final String hexId;
  final double multiplier;
  final int demand;
  final List<List<double>> boundary; // [[lat,lng], ...]
  final int updatedAtMs; // fraîcheur : 0 si absent → considéré périmé
  _SurgeCell(this.hexId, this.multiplier, this.demand, this.boundary, this.updatedAtMs);
}

/// Une cellule est valide au devis si elle a été rafraîchie il y a < 5 min.
const int _kSurgeFreshnessMs = 300000;

/// Surge pricing — accès statique côté riderapp.
///
/// - écoute la collection `surge_state` (uniquement les cellules actives, peu
///   nombreuses) pour connaître le multiplicateur d'un point de départ ;
/// - lit `setting/surge_config` (flags + frais d'approche) ;
/// - expose des getters SYNCHRONES consommés par [PricingProvider].
///
/// Le prix reste calculé côté client ; la Cloud Function `computeSurgeState`
/// produit l'état, et `onBookingCreated` re-valide le multiplicateur appliqué.
class SurgeService {
  SurgeService._();

  // ── Config (setting/surge_config) ─────────────────────────────────────────
  static bool riderApplyEnabled = false;
  static bool approachEnabled = false;
  static num approachRatePerKm = 0;
  static num approachCap = 0;
  static num approachDriverShare = 1.0;
  static String? peripheralZoneId;
  static List<List<double>>? _peripheralPolygon; // [[lat,lng], ...]

  // ── État temps réel ───────────────────────────────────────────────────────
  static List<_SurgeCell> _activeCells = <_SurgeCell>[];
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _cfgSub;

  // ── Valeurs calculées pour le pickup courant (lues par le pricing) ────────
  static double currentSurgeMultiplier = 1.0;
  static String? currentSurgeHexId;
  static int currentSurgeDemand = 0;
  static double currentApproachAmount = 0; // Ar, fondu dans le prix affiché
  static double currentApproachDistKm = 0;

  // Valeurs réellement appliquées au dernier devis (audit booking, anti-drift).
  static double quotedMultiplier = 1.0;
  static double quotedApproachAmount = 0;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// À appeler une fois au démarrage de l'app.
  static void init() {
    _listenConfig();
    _listenSurgeState();
  }

  static void _listenSurgeState() {
    _sub?.cancel();
    _sub = _db.collection('surge_state').snapshots().listen((snap) {
      final cells = <_SurgeCell>[];
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final doc in snap.docs) {
        final d = doc.data();
        final mult = (d['multiplier'] as num?)?.toDouble() ?? 1.0;
        // On garde surge (>1) ET prix bas (<1) ; seul le neutre est ignoré.
        if ((mult - 1.0).abs() <= 0.0001) continue;
        // Fraîcheur : on exige un updatedAt Timestamp valide et récent (CF vivante).
        final ts = d['updatedAt'];
        final int updatedAtMs = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
        if (updatedAtMs == 0 || nowMs - updatedAtMs > _kSurgeFreshnessMs) continue;
        final rawBoundary = d['boundary'];
        if (rawBoundary is! List || rawBoundary.length < 3) continue;
        final boundary = <List<double>>[];
        for (final p in rawBoundary) {
          if (p is Map && p['lat'] is num && p['lng'] is num) {
            boundary.add([(p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()]);
          }
        }
        if (boundary.length < 3) continue;
        cells.add(_SurgeCell(
          (d['hexId'] as String?) ?? doc.id,
          mult,
          (d['demand'] as num?)?.toInt() ?? 0,
          boundary,
          updatedAtMs,
        ));
      }
      _activeCells = cells;
    }, onError: (_) {/* silencieux : pas de surge en cas d'erreur */});
  }

  static void _listenConfig() {
    _cfgSub?.cancel();
    _cfgSub = _db
        .collection('setting')
        .doc('surge_config')
        .snapshots()
        .listen((snap) async {
      final d = snap.data() ?? <String, dynamic>{};
      riderApplyEnabled = d['riderApplyEnabled'] == true && d['enabled'] == true;
      final approach = (d['approach'] as Map?) ?? const {};
      approachEnabled = approach['enabled'] == true && d['enabled'] == true;
      approachRatePerKm = (approach['ratePerKm'] as num?) ?? 0;
      approachCap = (approach['cap'] as num?) ?? 0;
      approachDriverShare = (approach['driverShare'] as num?) ?? 1.0;
      final newZoneId = approach['peripheralZoneId'] as String?;
      if (newZoneId != peripheralZoneId) {
        peripheralZoneId = newZoneId;
        await _loadPeripheralPolygon();
      }
    }, onError: (_) {});
  }

  static Future<void> _loadPeripheralPolygon() async {
    _peripheralPolygon = null;
    final id = peripheralZoneId;
    if (id == null || id.isEmpty) return;
    try {
      final doc = await _db.collection('geo_zones').doc(id).get();
      final poly = doc.data()?['polygon'];
      if (poly is List) {
        final pts = <List<double>>[];
        for (final p in poly) {
          if (p is Map && p['lat'] is num && p['lng'] is num) {
            pts.add([(p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()]);
          }
        }
        if (pts.length >= 3) _peripheralPolygon = pts;
      }
    } catch (_) {}
  }

  /// Recalcule surge + frais d'approche pour un point de départ.
  /// Appelé au même endroit que la résolution de zone (pickup connu).
  static void updateForPickup(double lat, double lng) {
    if (!riderApplyEnabled) {
      _resetPickup();
      return;
    }
    final cell = _cellForPoint(lat, lng);
    currentSurgeMultiplier = cell?.multiplier ?? 1.0;
    currentSurgeHexId = cell?.hexId;
    currentSurgeDemand = cell?.demand ?? 0;
    // Approche : asynchrone (requête chauffeurs) — ne bloque pas le devis.
    unawaited(_computeApproach(lat, lng));
  }

  static void _resetPickup() {
    currentSurgeMultiplier = 1.0;
    currentSurgeHexId = null;
    currentSurgeDemand = 0;
    currentApproachAmount = 0;
    currentApproachDistKm = 0;
  }

  static _SurgeCell? _cellForPoint(double lat, double lng) {
    // Re-vérifie la fraîcheur AU DEVIS (CF arrêtée → pas de surge fantôme).
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final c in _activeCells) {
      if (nowMs - c.updatedAtMs > _kSurgeFreshnessMs) continue;
      if (_pointInPolygon(lat, lng, c.boundary)) return c;
    }
    return null;
  }

  static Future<void> _computeApproach(double lat, double lng) async {
    currentApproachAmount = 0;
    currentApproachDistKm = 0;
    if (!approachEnabled ||
        approachRatePerKm <= 0 ||
        _peripheralPolygon == null) {
      return;
    }
    if (!_pointInPolygon(lat, lng, _peripheralPolygon!)) return;
    final dist = await _nearestOnlineDriverKm(lat, lng);
    if (dist == null) return;
    currentApproachDistKm = dist;
    var amt = dist * approachRatePerKm.toDouble();
    if (approachCap > 0) amt = math.min(amt, approachCap.toDouble());
    currentApproachAmount = amt;
  }

  /// Distance (km) du chauffeur en ligne le plus proche du pickup.
  static Future<double?> _nearestOnlineDriverKm(double lat, double lng) async {
    try {
      final snap = await _db
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .limit(1000)
          .get();
      double best = double.infinity;
      for (final doc in snap.docs) {
        final u = doc.data();
        final dLat = (u['currentLat'] as num?)?.toDouble();
        final dLng = (u['currentLng'] as num?)?.toDouble();
        if (dLat == null || dLng == null) continue;
        final d = _haversineKm(lat, lng, dLat, dLng);
        if (d < best) best = d;
      }
      return best.isFinite ? best : null;
    } catch (_) {
      return null;
    }
  }

  // ── Géométrie ─────────────────────────────────────────────────────────────
  static bool _pointInPolygon(double lat, double lng, List<List<double>> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final yi = poly[i][0], xi = poly[i][1];
      final yj = poly[j][0], xj = poly[j][1];
      final intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // pi/180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  static void dispose() {
    _sub?.cancel();
    _cfgSub?.cancel();
    _sub = null;
    _cfgSub = null;
  }
}
