import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

/// Représente une zone géographique avec des configurations spécifiques
/// pour les tarifs et le classement des catégories de véhicules
class GeoZone {
  final String id;
  final String name;
  final String description;
  final List<LatLng> polygon; // Points du polygone définissant la zone
  final bool isActive;
  final int priority; // Priorité si zones se chevauchent (plus élevé = prioritaire)
  final GeoZonePricing? pricing; // Configuration des tarifs (null = tarifs par défaut)
  final GeoZoneCategoryConfig? categoryConfig; // Configuration des catégories
  final GeoZoneCommissionConfig? commissionConfig; // Configuration des commissions
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GeoZone({
    required this.id,
    required this.name,
    required this.description,
    required this.polygon,
    this.isActive = true,
    this.priority = 0,
    this.pricing,
    this.categoryConfig,
    this.commissionConfig,
    this.createdAt,
    this.updatedAt,
  });

  factory GeoZone.fromFirestore(Map<String, dynamic> data, String id) {
    // DEBUG: Log de la structure brute
    myCustomPrintStatement('🗺️ === GeoZone.fromFirestore ===');
    myCustomPrintStatement('   Zone ID: $id, Name: ${data['name']}');
    myCustomPrintStatement('   isActive: ${data['isActive']}, priority: ${data['priority']}');
    myCustomPrintStatement('   polygon raw type: ${data['polygon']?.runtimeType}');

    // Parser les points du polygone avec support multiple formats
    List<LatLng> polygonPoints = [];
    if (data['polygon'] != null) {
      final polygonData = data['polygon'];
      myCustomPrintStatement('   polygon length: ${polygonData is List ? polygonData.length : 'N/A'}');

      if (polygonData is List && polygonData.isNotEmpty) {
        myCustomPrintStatement('   First point type: ${polygonData[0].runtimeType}');
        myCustomPrintStatement('   First point value: ${polygonData[0]}');
      }

      for (var point in data['polygon']) {
        double lat = 0.0;
        double lng = 0.0;

        // Format 1: GeoPoint natif de Firestore
        if (point is GeoPoint) {
          lat = point.latitude;
          lng = point.longitude;
          myCustomPrintStatement('   📍 Parsed GeoPoint: ($lat, $lng)');
        }
        // Format 2: Map avec lat/lng ou latitude/longitude
        else if (point is Map) {
          lat = (point['lat'] ?? point['latitude'] ?? point['_latitude'] ?? 0.0).toDouble();
          lng = (point['lng'] ?? point['longitude'] ?? point['_longitude'] ?? 0.0).toDouble();
          myCustomPrintStatement('   📍 Parsed Map: ($lat, $lng)');
        } else {
          myCustomPrintStatement('   ⚠️ Unknown point format: ${point.runtimeType}');
        }

        // Validation: ignorer les points invalides (0,0 peut être valide en théorie mais très improbable)
        if (lat != 0.0 || lng != 0.0) {
          polygonPoints.add(LatLng(lat, lng));
        } else {
          myCustomPrintStatement('   ❌ Invalid point skipped (0.0, 0.0)');
        }
      }
    }

    myCustomPrintStatement('   ✅ Total valid polygon points: ${polygonPoints.length}');

    return GeoZone(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      polygon: polygonPoints,
      isActive: data['isActive'] ?? true,
      priority: data['priority'] ?? 0,
      pricing: data['pricing'] != null
          ? GeoZonePricing.fromMap(data['pricing'])
          : null,
      categoryConfig: data['categoryConfig'] != null
          ? GeoZoneCategoryConfig.fromMap(data['categoryConfig'])
          : null,
      commissionConfig: data['commissionConfig'] != null
          ? GeoZoneCommissionConfig.fromMap(data['commissionConfig'])
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'polygon': polygon
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
      'isActive': isActive,
      'priority': priority,
      'pricing': pricing?.toMap(),
      'categoryConfig': categoryConfig?.toMap(),
      'commissionConfig': commissionConfig?.toMap(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Vérifie si un point (lat, lng) est à l'intérieur de cette zone
  /// Utilise l'algorithme Ray Casting (point-in-polygon)
  bool containsPoint(double latitude, double longitude) {
    myCustomPrintStatement('🎯 containsPoint("$name"): test ($latitude, $longitude)');

    if (polygon.isEmpty || polygon.length < 3) {
      myCustomPrintStatement('   ❌ Polygon invalide: ${polygon.length} points (min 3 requis)');
      return false;
    }

    // Calculer et logger les bounds du polygon
    final latitudes = polygon.map((p) => p.latitude).toList();
    final longitudes = polygon.map((p) => p.longitude).toList();
    final minLat = latitudes.reduce((a, b) => a < b ? a : b);
    final maxLat = latitudes.reduce((a, b) => a > b ? a : b);
    final minLng = longitudes.reduce((a, b) => a < b ? a : b);
    final maxLng = longitudes.reduce((a, b) => a > b ? a : b);

    myCustomPrintStatement('   📐 Polygon bounds: lat[$minLat - $maxLat], lng[$minLng - $maxLng]');

    // Pré-check rapide avec le bounding box
    if (latitude < minLat || latitude > maxLat || longitude < minLng || longitude > maxLng) {
      myCustomPrintStatement('   ❌ Point HORS bounding box');
      return false;
    }
    myCustomPrintStatement('   ✅ Point DANS bounding box, test ray casting...');

    // Utiliser un algorithme Ray Casting plus robuste
    bool inside = false;
    int n = polygon.length;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      // Vérifier si le rayon horizontal coupe le segment
      if (((yi > longitude) != (yj > longitude)) &&
          (latitude < (xj - xi) * (longitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }

    myCustomPrintStatement('   ${inside ? '✅' : '❌'} Ray casting result: $inside');
    return inside;
  }

  /// Crée une copie avec des modifications
  GeoZone copyWith({
    String? id,
    String? name,
    String? description,
    List<LatLng>? polygon,
    bool? isActive,
    int? priority,
    GeoZonePricing? pricing,
    GeoZoneCategoryConfig? categoryConfig,
    GeoZoneCommissionConfig? commissionConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GeoZone(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      polygon: polygon ?? this.polygon,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      pricing: pricing ?? this.pricing,
      categoryConfig: categoryConfig ?? this.categoryConfig,
      commissionConfig: commissionConfig ?? this.commissionConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Représente une période horaire avec son multiplicateur de trafic
class TrafficPeriod {
  final String id;
  final String name; // Ex: "Heure de pointe matin", "Nuit"
  final int startHour; // Heure de début (0-23)
  final int startMinute; // Minute de début (0-59)
  final int endHour; // Heure de fin (0-23)
  final int endMinute; // Minute de fin (0-59)
  final double multiplier; // Multiplicateur pour cette période
  final List<int>? daysOfWeek; // Jours applicables (1=lundi, 7=dimanche), null = tous les jours

  const TrafficPeriod({
    required this.id,
    required this.name,
    required this.startHour,
    this.startMinute = 0,
    required this.endHour,
    this.endMinute = 0,
    required this.multiplier,
    this.daysOfWeek,
  });

  factory TrafficPeriod.fromMap(Map<String, dynamic> map) {
    return TrafficPeriod(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      startHour: map['startHour'] ?? 0,
      startMinute: map['startMinute'] ?? 0,
      endHour: map['endHour'] ?? 0,
      endMinute: map['endMinute'] ?? 0,
      multiplier: (map['multiplier'] ?? 1.0).toDouble(),
      daysOfWeek: map['daysOfWeek'] != null
          ? List<int>.from(map['daysOfWeek'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'multiplier': multiplier,
      'daysOfWeek': daysOfWeek,
    };
  }

  /// Vérifie si cette période est active pour un moment donné
  bool isActiveAt(DateTime dateTime) {
    // Vérifier le jour de la semaine si spécifié
    if (daysOfWeek != null && !daysOfWeek!.contains(dateTime.weekday)) {
      return false;
    }

    final currentMinutes = dateTime.hour * 60 + dateTime.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // Gérer le cas où la période traverse minuit
    if (endMinutes < startMinutes) {
      // Ex: 22:00 - 06:00
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      // Ex: 07:00 - 09:00
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }
}

/// Configuration des tarifs pour une zone géographique
class GeoZonePricing {
  final double? basePriceMultiplier; // Multiplicateur du prix de base (1.0 = normal, 1.5 = +50%)
  final double? perKmMultiplier; // Multiplicateur du prix par km
  final double? perMinMultiplier; // Multiplicateur du prix par minute
  final double? minimumFare; // Tarif minimum dans cette zone
  final double? waitingTimeMultiplier; // Multiplicateur du temps d'attente
  final double? trafficMultiplier; // Multiplicateur global de trafic (appliqué en plus des périodes)
  final List<TrafficPeriod>? trafficPeriods; // Périodes horaires avec multiplicateurs spécifiques
  final Map<String, VehiclePricingOverride>? vehicleOverrides; // Tarifs spécifiques par catégorie

  const GeoZonePricing({
    this.basePriceMultiplier,
    this.perKmMultiplier,
    this.perMinMultiplier,
    this.minimumFare,
    this.waitingTimeMultiplier,
    this.trafficMultiplier,
    this.trafficPeriods,
    this.vehicleOverrides,
  });

  factory GeoZonePricing.fromMap(Map<String, dynamic> map) {
    Map<String, VehiclePricingOverride>? overrides;
    final vehicleOverridesData = map['vehicleOverrides'];

    if (vehicleOverridesData != null) {
      overrides = {};

      // Format 1: Map<String, dynamic> (format attendu)
      if (vehicleOverridesData is Map) {
        myCustomPrintStatement('   📦 vehicleOverrides: format Map détecté');
        (vehicleOverridesData as Map<String, dynamic>).forEach((key, value) {
          if (value is Map) {
            overrides![key] = VehiclePricingOverride.fromMap(Map<String, dynamic>.from(value));
          }
        });
      }
      // Format 2: List<dynamic> (format dashboard - ignorer si vide ou mal formé)
      else if (vehicleOverridesData is List) {
        myCustomPrintStatement('   📦 vehicleOverrides: format List détecté (${vehicleOverridesData.length} éléments) - ignoré');
        // Les listes vides ou mal formées sont ignorées
        // TODO: Adapter si le dashboard envoie un format List avec des données utiles
      }
      else {
        myCustomPrintStatement('   ⚠️ vehicleOverrides: format inconnu ${vehicleOverridesData.runtimeType}');
      }
    }

    // Parser les périodes de trafic
    List<TrafficPeriod>? trafficPeriods;
    final trafficPeriodsData = map['trafficPeriods'];
    if (trafficPeriodsData != null && trafficPeriodsData is List) {
      myCustomPrintStatement('   📊 trafficPeriods: ${trafficPeriodsData.length} périodes détectées');
      trafficPeriods = trafficPeriodsData
          .map((p) => TrafficPeriod.fromMap(Map<String, dynamic>.from(p)))
          .toList();
    }

    return GeoZonePricing(
      basePriceMultiplier: (map['basePriceMultiplier'] ?? 1.0).toDouble(),
      perKmMultiplier: (map['perKmMultiplier'] ?? 1.0).toDouble(),
      perMinMultiplier: (map['perMinMultiplier'] ?? 1.0).toDouble(),
      minimumFare: map['minimumFare']?.toDouble(),
      waitingTimeMultiplier: (map['waitingTimeMultiplier'] ?? 1.0).toDouble(),
      trafficMultiplier: map['trafficMultiplier']?.toDouble(),
      trafficPeriods: trafficPeriods,
      vehicleOverrides: overrides,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'basePriceMultiplier': basePriceMultiplier ?? 1.0,
      'perKmMultiplier': perKmMultiplier ?? 1.0,
      'perMinMultiplier': perMinMultiplier ?? 1.0,
      'minimumFare': minimumFare,
      'waitingTimeMultiplier': waitingTimeMultiplier ?? 1.0,
      'trafficMultiplier': trafficMultiplier,
      'trafficPeriods': trafficPeriods?.map((p) => p.toMap()).toList(),
      'vehicleOverrides': vehicleOverrides?.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }

  /// Obtient le multiplicateur de trafic actuel basé sur l'heure
  /// Retourne le multiplicateur de la période active, ou trafficMultiplier par défaut, ou 1.0
  double getCurrentTrafficMultiplier({DateTime? atTime}) {
    final now = atTime ?? DateTime.now();

    // Chercher une période active
    if (trafficPeriods != null && trafficPeriods!.isNotEmpty) {
      for (final period in trafficPeriods!) {
        if (period.isActiveAt(now)) {
          myCustomPrintStatement('   🚦 Période de trafic active: "${period.name}" (x${period.multiplier})');
          return period.multiplier;
        }
      }
    }

    // Sinon retourner le multiplicateur global ou 1.0
    return trafficMultiplier ?? 1.0;
  }

  /// Obtient la période de trafic active actuellement (si existe)
  TrafficPeriod? getActiveTrafficPeriod({DateTime? atTime}) {
    final now = atTime ?? DateTime.now();

    if (trafficPeriods == null || trafficPeriods!.isEmpty) return null;

    for (final period in trafficPeriods!) {
      if (period.isActiveAt(now)) {
        return period;
      }
    }
    return null;
  }

  /// Applique les multiplicateurs de cette zone à un prix de base
  double applyToBasePrice(double basePrice) {
    return basePrice * (basePriceMultiplier ?? 1.0);
  }

  double applyToPerKm(double perKm) {
    return perKm * (perKmMultiplier ?? 1.0);
  }

  double applyToPerMin(double perMin) {
    return perMin * (perMinMultiplier ?? 1.0);
  }

  double applyToWaitingTime(double waitingFee) {
    return waitingFee * (waitingTimeMultiplier ?? 1.0);
  }
}

/// Override de prix pour une catégorie de véhicule spécifique
class VehiclePricingOverride {
  final double? basePrice; // Prix de base fixe (remplace le prix par défaut)
  final double? perKmCharge; // Prix par km fixe
  final double? perMinCharge; // Prix par minute fixe
  final double? basePriceMultiplier; // Ou multiplicateur si pas de prix fixe
  final double? perKmMultiplier;
  final double? perMinMultiplier;

  const VehiclePricingOverride({
    this.basePrice,
    this.perKmCharge,
    this.perMinCharge,
    this.basePriceMultiplier,
    this.perKmMultiplier,
    this.perMinMultiplier,
  });

  factory VehiclePricingOverride.fromMap(Map<String, dynamic> map) {
    // DEBUG: Log parsing des overrides
    myCustomPrintStatement('   🔧 VehiclePricingOverride.fromMap: $map');
    myCustomPrintStatement('      basePrice raw: ${map['basePrice']} (${map['basePrice']?.runtimeType})');
    myCustomPrintStatement('      perKmCharge raw: ${map['perKmCharge']} (${map['perKmCharge']?.runtimeType})');
    return VehiclePricingOverride(
      basePrice: map['basePrice']?.toDouble(),
      perKmCharge: map['perKmCharge']?.toDouble(),
      perMinCharge: map['perMinCharge']?.toDouble(),
      basePriceMultiplier: map['basePriceMultiplier']?.toDouble(),
      perKmMultiplier: map['perKmMultiplier']?.toDouble(),
      perMinMultiplier: map['perMinMultiplier']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'basePrice': basePrice,
      'perKmCharge': perKmCharge,
      'perMinCharge': perMinCharge,
      'basePriceMultiplier': basePriceMultiplier,
      'perKmMultiplier': perKmMultiplier,
      'perMinMultiplier': perMinMultiplier,
    };
  }
}

/// Configuration des commissions pour une zone géographique
class GeoZoneCommissionConfig {
  /// Commission par défaut de la zone (en pourcentage, ex: 18.0 pour 18%)
  /// Null = utiliser globalSettings.adminCommission
  final double? defaultCommission;

  /// Overrides de commission par catégorie de véhicule
  /// Clés: ID de catégorie (ex: "classic", "confort") ou ID Firestore du véhicule
  final Map<String, CategoryCommissionOverride>? categoryOverrides;

  const GeoZoneCommissionConfig({
    this.defaultCommission,
    this.categoryOverrides,
  });

  factory GeoZoneCommissionConfig.fromMap(Map<String, dynamic> map) {
    Map<String, CategoryCommissionOverride>? overrides;
    final categoryOverridesData = map['categoryOverrides'];

    if (categoryOverridesData != null && categoryOverridesData is Map) {
      overrides = {};
      (categoryOverridesData as Map<String, dynamic>).forEach((key, value) {
        if (value is Map) {
          overrides![key] = CategoryCommissionOverride.fromMap(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    return GeoZoneCommissionConfig(
      defaultCommission: map['defaultCommission']?.toDouble(),
      categoryOverrides: overrides,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultCommission': defaultCommission,
      'categoryOverrides': categoryOverrides?.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }

  /// Obtient le taux de commission pour une catégorie donnée
  /// Retourne: categoryOverride -> defaultCommission -> null (utiliser global)
  double? getCommissionForCategory(String categoryId, {String? categoryName}) {
    // D'abord chercher par ID
    if (categoryOverrides != null) {
      final override = categoryOverrides![categoryId];
      if (override?.commission != null) {
        return override!.commission;
      }
      // Puis par nom de catégorie si fourni
      if (categoryName != null) {
        final overrideByName = categoryOverrides![categoryName];
        if (overrideByName?.commission != null) {
          return overrideByName!.commission;
        }
      }
    }
    // Fallback sur la commission par défaut de la zone
    return defaultCommission;
  }
}

/// Override de commission pour une catégorie spécifique
class CategoryCommissionOverride {
  /// Taux de commission (en pourcentage, ex: 18.0 pour 18%)
  final double? commission;

  /// Description optionnelle (pour l'admin dashboard)
  final String? description;

  const CategoryCommissionOverride({
    this.commission,
    this.description,
  });

  factory CategoryCommissionOverride.fromMap(Map<String, dynamic> map) {
    return CategoryCommissionOverride(
      commission: map['commission']?.toDouble(),
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commission': commission,
      'description': description,
    };
  }
}

/// Configuration du classement et de la disponibilité des catégories par zone
class GeoZoneCategoryConfig {
  final List<String>? categoryOrder; // Ordre des catégories (IDs) dans cette zone
  final List<String>? disabledCategories; // Catégories non disponibles dans cette zone
  final List<String>? featuredCategories; // Catégories mises en avant dans cette zone
  final String? defaultCategory; // Catégorie sélectionnée par défaut

  const GeoZoneCategoryConfig({
    this.categoryOrder,
    this.disabledCategories,
    this.featuredCategories,
    this.defaultCategory,
  });

  factory GeoZoneCategoryConfig.fromMap(Map<String, dynamic> map) {
    return GeoZoneCategoryConfig(
      categoryOrder: map['categoryOrder'] != null
          ? List<String>.from(map['categoryOrder'])
          : null,
      disabledCategories: map['disabledCategories'] != null
          ? List<String>.from(map['disabledCategories'])
          : null,
      featuredCategories: map['featuredCategories'] != null
          ? List<String>.from(map['featuredCategories'])
          : null,
      defaultCategory: map['defaultCategory'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryOrder': categoryOrder,
      'disabledCategories': disabledCategories,
      'featuredCategories': featuredCategories,
      'defaultCategory': defaultCategory,
    };
  }

  /// Vérifie si une catégorie est disponible dans cette zone
  bool isCategoryAvailable(String categoryId) {
    if (disabledCategories == null) return true;
    return !disabledCategories!.contains(categoryId);
  }

  /// Vérifie si une catégorie est mise en avant
  bool isCategoryFeatured(String categoryId) {
    if (featuredCategories == null) return false;
    return featuredCategories!.contains(categoryId);
  }
}
