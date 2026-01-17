import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/geo_zone.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer les zones géographiques avec tarifs et catégories personnalisés
class GeoZoneService {
  static const String _cacheKey = 'GEO_ZONES_CACHE';
  static const String _lastUpdateKey = 'GEO_ZONES_LAST_UPDATE';
  static const int _cacheValidityMinutes = 60; // Cache valide 1 heure

  // 🔧 DEBUG: Mettre à true pour bypasser tous les caches pendant le debug
  // À REMETTRE À FALSE EN PRODUCTION!
  static const bool _debugBypassCache = true;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'geo_zones';

  // Cache mémoire pour accès rapide
  static List<GeoZone>? _memoryCache;
  static DateTime? _memoryCacheTime;

  // Zone courante (mise à jour par GeoZoneProvider)
  static GeoZone? _currentZone;

  /// Getter pour la zone courante (accès synchrone)
  static GeoZone? get currentZone => _currentZone;

  /// Setter pour la zone courante (appelé par GeoZoneProvider)
  static set currentZone(GeoZone? zone) {
    _currentZone = zone;
    myCustomPrintStatement('🗺️ GeoZoneService: Zone courante mise à jour: ${zone?.name ?? "NULL"}');
  }

  /// Obtient le taux de commission pour un véhicule dans la zone courante
  /// Utilise le cache statique pour accès synchrone
  ///
  /// [vehicleId] - ID Firestore du véhicule
  /// [categoryName] - Nom normalisé de la catégorie (ex: "classic", "confort")
  /// [globalDefault] - Taux de commission global par défaut
  ///
  /// Retourne un record avec le taux et la source pour l'audit trail
  static ({double rate, String source, String? zoneId, String? zoneName})
      getCommissionForVehicleSync({
    required String vehicleId,
    String? categoryName,
    required double globalDefault,
  }) {
    // Si aucune zone courante ou pas de config commission
    if (_currentZone?.commissionConfig == null) {
      return (
        rate: globalDefault,
        source: 'global_default',
        zoneId: null,
        zoneName: null,
      );
    }

    final config = _currentZone!.commissionConfig!;

    // Chercher par ID puis par nom de catégorie
    final zoneRate = config.getCommissionForCategory(
      vehicleId,
      categoryName: categoryName,
    );

    if (zoneRate != null) {
      // Déterminer si c'est un override de catégorie ou le défaut de zone
      final isOverride =
          config.categoryOverrides?.containsKey(vehicleId) == true ||
              (categoryName != null &&
                  config.categoryOverrides?.containsKey(categoryName) == true);

      return (
        rate: zoneRate,
        source: isOverride ? 'zone_category_override' : 'zone_default',
        zoneId: _currentZone!.id,
        zoneName: _currentZone!.name,
      );
    }

    // Fallback sur le global
    return (
      rate: globalDefault,
      source: 'global_default',
      zoneId: null,
      zoneName: null,
    );
  }

  /// Recherche synchrone de zone à partir du cache mémoire
  /// Retourne null si le cache n'est pas disponible
  static GeoZone? getZoneForLocationSync(double latitude, double longitude) {
    if (_memoryCache == null || _memoryCache!.isEmpty) {
      return null;
    }

    GeoZone? matchingZone;
    int highestPriority = -1;

    for (final zone in _memoryCache!) {
      if (zone.containsPoint(latitude, longitude)) {
        if (zone.priority > highestPriority) {
          matchingZone = zone;
          highestPriority = zone.priority;
        }
      }
    }

    return matchingZone;
  }

  /// Récupère toutes les zones actives depuis Firestore avec cache
  static Future<List<GeoZone>> getZones() async {
    myCustomPrintStatement('🗺️ === GeoZoneService.getZones() ===');
    myCustomPrintStatement('   _debugBypassCache: $_debugBypassCache');

    try {
      // 🔧 DEBUG: Bypass tous les caches si flag actif
      if (!_debugBypassCache) {
        // Vérifier le cache mémoire d'abord (le plus rapide)
        if (_isMemoryCacheValid()) {
          myCustomPrintStatement("   ✅ GeoZones chargées depuis le cache mémoire");
          return _memoryCache!;
        }

        // Vérifier le cache local
        final cachedZones = await _getCachedZones();
        if (cachedZones.isNotEmpty && await _isCacheValid()) {
          myCustomPrintStatement("   ✅ GeoZones chargées depuis le cache local");
          _memoryCache = cachedZones;
          _memoryCacheTime = DateTime.now();
          return cachedZones;
        }
      } else {
        myCustomPrintStatement('   ⚠️ DEBUG MODE: Cache bypassed!');
      }

      // Récupérer depuis Firestore
      myCustomPrintStatement("   📡 Récupération depuis Firestore collection '$_collectionName'");
      myCustomPrintStatement("   📡 Query: isActive=true, orderBy priority DESC");

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      myCustomPrintStatement("   📡 Firestore returned ${querySnapshot.docs.length} documents");

      // Log chaque document brut
      for (var doc in querySnapshot.docs) {
        myCustomPrintStatement('   --- Document ${doc.id} ---');
        myCustomPrintStatement('      Raw data keys: ${doc.data().keys.toList()}');
        myCustomPrintStatement('      isActive: ${doc.data()['isActive']}');
        myCustomPrintStatement('      priority: ${doc.data()['priority']}');
        myCustomPrintStatement('      polygon type: ${doc.data()['polygon']?.runtimeType}');
        if (doc.data()['polygon'] != null && doc.data()['polygon'] is List) {
          final polygonList = doc.data()['polygon'] as List;
          myCustomPrintStatement('      polygon length: ${polygonList.length}');
          if (polygonList.isNotEmpty) {
            myCustomPrintStatement('      first point type: ${polygonList[0].runtimeType}');
          }
        }
      }

      final zones = querySnapshot.docs
          .map((doc) => GeoZone.fromFirestore(doc.data(), doc.id))
          .toList();

      // Mettre en cache
      await _cacheZones(zones);
      _memoryCache = zones;
      _memoryCacheTime = DateTime.now();

      myCustomPrintStatement("   ✅ ${zones.length} GeoZones récupérées depuis Firestore");
      return zones;
    } catch (e, stack) {
      myCustomPrintStatement("   ❌ Erreur lors de la récupération des GeoZones: $e");
      myCustomPrintStatement("   Stack: $stack");

      // Fallback sur le cache même expiré
      final cachedZones = await _getCachedZones();
      if (cachedZones.isNotEmpty) {
        myCustomPrintStatement("   ⚠️ Utilisation du cache expiré comme fallback");
        return cachedZones;
      }

      return [];
    }
  }

  /// Trouve la zone applicable pour une position donnée
  /// Retourne la zone avec la plus haute priorité si plusieurs zones contiennent le point
  static Future<GeoZone?> getZoneForLocation(double latitude, double longitude) async {
    final zones = await getZones();

    myCustomPrintStatement('🔍 Recherche zone pour position: ($latitude, $longitude)');
    myCustomPrintStatement('   Nombre de zones disponibles: ${zones.length}');

    GeoZone? matchingZone;
    int highestPriority = -1;

    for (final zone in zones) {
      // Log détaillé du polygone pour debug
      myCustomPrintStatement('   📍 Test zone "${zone.name}" (priority: ${zone.priority}):');
      myCustomPrintStatement('      - Polygone: ${zone.polygon.length} points');
      if (zone.polygon.isNotEmpty) {
        myCustomPrintStatement('      - Bounds: lat[${zone.polygon.map((p) => p.latitude).reduce((a, b) => a < b ? a : b).toStringAsFixed(6)} - ${zone.polygon.map((p) => p.latitude).reduce((a, b) => a > b ? a : b).toStringAsFixed(6)}]');
        myCustomPrintStatement('                lng[${zone.polygon.map((p) => p.longitude).reduce((a, b) => a < b ? a : b).toStringAsFixed(6)} - ${zone.polygon.map((p) => p.longitude).reduce((a, b) => a > b ? a : b).toStringAsFixed(6)}]');
      }

      final isInZone = zone.containsPoint(latitude, longitude);
      myCustomPrintStatement('      - Position dans zone: $isInZone');

      if (isInZone) {
        if (zone.priority > highestPriority) {
          matchingZone = zone;
          highestPriority = zone.priority;
          myCustomPrintStatement('      ✅ Zone candidate (priorité plus haute)');
        }
      }
    }

    if (matchingZone != null) {
      myCustomPrintStatement(
          "✅ Zone trouvée pour ($latitude, $longitude): ${matchingZone.name}");
      myCustomPrintStatement(
          "   Pricing: baseMult=${matchingZone.pricing?.basePriceMultiplier}, kmMult=${matchingZone.pricing?.perKmMultiplier}");
      myCustomPrintStatement(
          "   Categories: disabled=${matchingZone.categoryConfig?.disabledCategories}");
    } else {
      myCustomPrintStatement(
          "⚠️ Aucune zone trouvée pour ($latitude, $longitude) - tarifs par défaut");
    }

    return matchingZone;
  }

  /// Trouve la zone applicable pour un trajet (basé sur le point de départ)
  /// Option: peut aussi prendre en compte la destination
  static Future<GeoZone?> getZoneForTrip({
    required double pickupLatitude,
    required double pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    bool usePickupZone = true, // Si false, utilise la zone de destination
  }) async {
    if (usePickupZone) {
      return await getZoneForLocation(pickupLatitude, pickupLongitude);
    } else if (dropoffLatitude != null && dropoffLongitude != null) {
      return await getZoneForLocation(dropoffLatitude, dropoffLongitude);
    }
    return await getZoneForLocation(pickupLatitude, pickupLongitude);
  }

  /// Stream pour écouter les changements en temps réel
  static Stream<List<GeoZone>> getZonesStream() {
    return _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .snapshots()
        .map((snapshot) {
      final zones = snapshot.docs
          .map((doc) => GeoZone.fromFirestore(doc.data(), doc.id))
          .toList();
      // Mettre à jour le cache mémoire
      _memoryCache = zones;
      _memoryCacheTime = DateTime.now();
      return zones;
    });
  }

  /// Met en cache les zones localement
  static Future<void> _cacheZones(List<GeoZone> zones) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = zones.map((z) => {
        'id': z.id,
        'name': z.name,
        'description': z.description,
        'polygon': z.polygon
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'isActive': z.isActive,
        'priority': z.priority,
        'pricing': z.pricing?.toMap(),
        'categoryConfig': z.categoryConfig?.toMap(),
        'commissionConfig': z.commissionConfig?.toMap(),
        'createdAt': z.createdAt?.toIso8601String(),
        'updatedAt': z.updatedAt?.toIso8601String(),
      }).toList();

      await prefs.setString(_cacheKey, json.encode(jsonList));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      myCustomPrintStatement("GeoZones mises en cache");
    } catch (e) {
      myCustomPrintStatement("Erreur lors de la mise en cache des GeoZones: $e");
    }
  }

  /// Récupère les zones depuis le cache local
  static Future<List<GeoZone>> _getCachedZones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);

      if (cachedData == null) return [];

      final List<dynamic> jsonList = json.decode(cachedData);
      return jsonList.map((data) {
        final mapData = Map<String, dynamic>.from(data);
        return GeoZone.fromFirestore(mapData, mapData['id'] ?? '');
      }).toList();
    } catch (e) {
      myCustomPrintStatement("Erreur lors de la lecture du cache GeoZones: $e");
      return [];
    }
  }

  /// Vérifie si le cache mémoire est valide
  static bool _isMemoryCacheValid() {
    if (_memoryCache == null || _memoryCacheTime == null) return false;
    final difference = DateTime.now().difference(_memoryCacheTime!);
    return difference.inMinutes < 5; // Cache mémoire valide 5 minutes
  }

  /// Vérifie si le cache local est encore valide
  static Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateString = prefs.getString(_lastUpdateKey);

      if (lastUpdateString == null) return false;

      final lastUpdate = DateTime.parse(lastUpdateString);
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);

      return difference.inMinutes < _cacheValidityMinutes;
    } catch (e) {
      myCustomPrintStatement("Erreur lors de la vérification du cache: $e");
      return false;
    }
  }

  /// Force le rafraîchissement du cache
  static Future<List<GeoZone>> refreshZones() async {
    try {
      // Vider les caches
      _memoryCache = null;
      _memoryCacheTime = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastUpdateKey);

      // Récupérer les nouvelles données
      return await getZones();
    } catch (e) {
      myCustomPrintStatement("Erreur lors du rafraîchissement des GeoZones: $e");
      return await _getCachedZones();
    }
  }

  /// Vide complètement le cache
  static Future<void> clearCache() async {
    try {
      _memoryCache = null;
      _memoryCacheTime = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastUpdateKey);
      myCustomPrintStatement("Cache des GeoZones vidé");
    } catch (e) {
      myCustomPrintStatement("Erreur lors du vidage du cache: $e");
    }
  }
}
