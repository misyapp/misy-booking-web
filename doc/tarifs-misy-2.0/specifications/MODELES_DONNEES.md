# Modèles de Données - Tarifs Misy 2.0

## 🎯 Vue d'ensemble

Ce document détaille tous les modèles de données nécessaires pour le nouveau système de tarification, avec leurs structures, validations et utilisations.

## 📋 Modèles Principaux

### 1. PricingConfigV2

**Fichier** : `lib/models/pricing/pricing_config_v2.dart`  
**Utilisation** : Configuration centralisée du système de tarification

```dart
class PricingConfigV2 {
  // Identification
  final String version;                    // "2.0"
  final bool enableNewPricingSystem;       // Flag de migration
  
  // Prix de base par catégorie
  final Map<String, double> floorPrices;   // Prix plancher par véhicule
  final Map<String, double> pricePerKm;    // Prix au kilomètre par véhicule
  final double floorPriceThreshold;        // Seuil max prix plancher (3.0 km)
  
  // Configuration embouteillages
  final double trafficMultiplier;          // 1.4
  final List<TrafficPeriod> trafficPeriods;
  
  // Configuration courses longues
  final double longTripThreshold;          // 15.0 km
  final double longTripMultiplier;         // 1.2
  
  // Configuration réservation
  final Map<String, double> reservationSurcharge;
  final int reservationAdvanceMinutes;     // 10 minutes
  
  // Système d'arrondis
  final bool enableRounding;               // true
  final int roundingStep;                  // 500 MGA
  
  const PricingConfigV2({
    required this.version,
    required this.enableNewPricingSystem,
    required this.floorPrices,
    required this.pricePerKm,
    required this.floorPriceThreshold,
    required this.trafficMultiplier,
    required this.trafficPeriods,
    required this.longTripThreshold,
    required this.longTripMultiplier,
    required this.reservationSurcharge,
    required this.reservationAdvanceMinutes,
    required this.enableRounding,
    required this.roundingStep,
  });
  
  // Factory pour valeurs par défaut
  factory PricingConfigV2.defaultConfig() {
    return PricingConfigV2(
      version: "2.0",
      enableNewPricingSystem: false,
      floorPrices: {
        'taxi_moto': 6000.0,
        'classic': 8000.0,
        'confort': 11000.0,
        '4x4': 13000.0,
        'van': 15000.0,
      },
      pricePerKm: {
        'taxi_moto': 2000.0,
        'classic': 2750.0,
        'confort': 3850.0,
        '4x4': 4500.0,
        'van': 5000.0,
      },
      floorPriceThreshold: 3.0,
      trafficMultiplier: 1.4,
      trafficPeriods: [
        TrafficPeriod(
          startTime: TimeOfDay(hour: 7, minute: 0),
          endTime: TimeOfDay(hour: 9, minute: 59),
          daysOfWeek: [1, 2, 3, 4, 5], // Lun-Ven
        ),
        TrafficPeriod(
          startTime: TimeOfDay(hour: 16, minute: 0),
          endTime: TimeOfDay(hour: 18, minute: 59),
          daysOfWeek: [1, 2, 3, 4, 5], // Lun-Ven
        ),
      ],
      longTripThreshold: 15.0,
      longTripMultiplier: 1.2,
      reservationSurcharge: {
        'taxi_moto': 3600.0,
        'classic': 5000.0,
        'confort': 7000.0,
        '4x4': 8200.0,
        'van': 9100.0,
      },
      reservationAdvanceMinutes: 10,
      enableRounding: true,
      roundingStep: 500,
    );
  }
  
  // Sérialisation JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'enableNewPricingSystem': enableNewPricingSystem,
      'floorPrices': floorPrices,
      'pricePerKm': pricePerKm,
      'floorPriceThreshold': floorPriceThreshold,
      'trafficMultiplier': trafficMultiplier,
      'trafficPeriods': trafficPeriods.map((p) => p.toJson()).toList(),
      'longTripThreshold': longTripThreshold,
      'longTripMultiplier': longTripMultiplier,
      'reservationSurcharge': reservationSurcharge,
      'reservationAdvanceMinutes': reservationAdvanceMinutes,
      'enableRounding': enableRounding,
      'roundingStep': roundingStep,
    };
  }
  
  factory PricingConfigV2.fromJson(Map<String, dynamic> json) {
    return PricingConfigV2(
      version: json['version'] ?? "2.0",
      enableNewPricingSystem: json['enableNewPricingSystem'] ?? false,
      floorPrices: Map<String, double>.from(json['floorPrices'] ?? {}),
      pricePerKm: Map<String, double>.from(json['pricePerKm'] ?? {}),
      floorPriceThreshold: (json['floorPriceThreshold'] ?? 3.0).toDouble(),
      trafficMultiplier: (json['trafficMultiplier'] ?? 1.4).toDouble(),
      trafficPeriods: (json['trafficPeriods'] as List<dynamic>?)
          ?.map((p) => TrafficPeriod.fromJson(p))
          .toList() ?? [],
      longTripThreshold: (json['longTripThreshold'] ?? 15.0).toDouble(),
      longTripMultiplier: (json['longTripMultiplier'] ?? 1.2).toDouble(),
      reservationSurcharge: Map<String, double>.from(json['reservationSurcharge'] ?? {}),
      reservationAdvanceMinutes: json['reservationAdvanceMinutes'] ?? 10,
      enableRounding: json['enableRounding'] ?? true,
      roundingStep: json['roundingStep'] ?? 500,
    );
  }
  
  // Validation
  bool isValid() {
    // Vérifier que toutes les catégories ont des prix
    final categories = ['taxi_moto', 'classic', 'confort', '4x4', 'van'];
    
    for (final category in categories) {
      if (!floorPrices.containsKey(category) || floorPrices[category]! <= 0) {
        return false;
      }
      if (!pricePerKm.containsKey(category) || pricePerKm[category]! <= 0) {
        return false;
      }
      if (!reservationSurcharge.containsKey(category) || reservationSurcharge[category]! < 0) {
        return false;
      }
    }
    
    // Vérifier les seuils et multiplicateurs
    if (floorPriceThreshold <= 0 || longTripThreshold <= floorPriceThreshold) {
      return false;
    }
    
    if (trafficMultiplier <= 1.0 || longTripMultiplier <= 1.0) {
      return false;
    }
    
    if (roundingStep <= 0) {
      return false;
    }
    
    return true;
  }
  
  // Copy with (pour modifications)
  PricingConfigV2 copyWith({
    String? version,
    bool? enableNewPricingSystem,
    Map<String, double>? floorPrices,
    Map<String, double>? pricePerKm,
    double? floorPriceThreshold,
    double? trafficMultiplier,
    List<TrafficPeriod>? trafficPeriods,
    double? longTripThreshold,
    double? longTripMultiplier,
    Map<String, double>? reservationSurcharge,
    int? reservationAdvanceMinutes,
    bool? enableRounding,
    int? roundingStep,
  }) {
    return PricingConfigV2(
      version: version ?? this.version,
      enableNewPricingSystem: enableNewPricingSystem ?? this.enableNewPricingSystem,
      floorPrices: floorPrices ?? this.floorPrices,
      pricePerKm: pricePerKm ?? this.pricePerKm,
      floorPriceThreshold: floorPriceThreshold ?? this.floorPriceThreshold,
      trafficMultiplier: trafficMultiplier ?? this.trafficMultiplier,
      trafficPeriods: trafficPeriods ?? this.trafficPeriods,
      longTripThreshold: longTripThreshold ?? this.longTripThreshold,
      longTripMultiplier: longTripMultiplier ?? this.longTripMultiplier,
      reservationSurcharge: reservationSurcharge ?? this.reservationSurcharge,
      reservationAdvanceMinutes: reservationAdvanceMinutes ?? this.reservationAdvanceMinutes,
      enableRounding: enableRounding ?? this.enableRounding,
      roundingStep: roundingStep ?? this.roundingStep,
    );
  }
}
```

### 2. TrafficPeriod

**Fichier** : `lib/models/pricing/traffic_period.dart`  
**Utilisation** : Définition des créneaux d'embouteillages

```dart
class TrafficPeriod {
  final TimeOfDay startTime;              // Heure de début (ex: 07:00)
  final TimeOfDay endTime;                // Heure de fin (ex: 09:59)
  final List<int> daysOfWeek;             // Jours de la semaine (1=Lundi, 7=Dimanche)
  
  const TrafficPeriod({
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
  });
  
  // Vérifie si une DateTime donnée est dans cette période d'embouteillage
  bool isTrafficTime(DateTime dateTime) {
    // Vérifier le jour de la semaine
    if (!daysOfWeek.contains(dateTime.weekday)) {
      return false;
    }\n    \n    // Vérifier l'heure\n    final currentTime = TimeOfDay.fromDateTime(dateTime);\n    \n    // Conversion en minutes pour comparaison plus facile\n    final currentMinutes = currentTime.hour * 60 + currentTime.minute;\n    final startMinutes = startTime.hour * 60 + startTime.minute;\n    final endMinutes = endTime.hour * 60 + endTime.minute;\n    \n    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;\n  }\n  \n  // Sérialisation JSON\n  Map<String, dynamic> toJson() {\n    return {\n      'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',\n      'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',\n      'daysOfWeek': daysOfWeek,\n    };\n  }\n  \n  factory TrafficPeriod.fromJson(Map<String, dynamic> json) {\n    return TrafficPeriod(\n      startTime: _parseTimeOfDay(json['startTime']),\n      endTime: _parseTimeOfDay(json['endTime']),\n      daysOfWeek: List<int>.from(json['daysOfWeek'] ?? []),\n    );\n  }\n  \n  static TimeOfDay _parseTimeOfDay(String timeString) {\n    final parts = timeString.split(':');\n    return TimeOfDay(\n      hour: int.parse(parts[0]),\n      minute: int.parse(parts[1]),\n    );\n  }\n  \n  @override\n  String toString() {\n    final daysNames = {\n      1: 'Lun', 2: 'Mar', 3: 'Mer', 4: 'Jeu', \n      5: 'Ven', 6: 'Sam', 7: 'Dim'\n    };\n    \n    final daysList = daysOfWeek.map((d) => daysNames[d]).join(', ');\n    \n    return '${startTime.format(null)} - ${endTime.format(null)} ($daysList)';\n  }\n}\n```\n\n### 3. PriceCalculation\n\n**Fichier** : `lib/models/pricing/price_calculation.dart`  \n**Utilisation** : Résultat détaillé d'un calcul de prix\n\n```dart\nclass PriceCalculation {\n  // Composants du calcul\n  final double basePrice;               // Prix de base selon distance\n  final double trafficSurcharge;        // Majoration embouteillages (0 si pas applicable)\n  final double reservationSurcharge;    // Surcoût réservation (0 si immédiat)\n  final double promoDiscount;           // Réduction promo (0 si pas de code)\n  final double finalPrice;              // Prix final arrondi\n  \n  // Métadonnées\n  final Map<String, dynamic> breakdown; // Détail des calculs (debug)\n  final String pricingVersion;          // \"v1.0\" ou \"v2.0\"\n  final DateTime calculatedAt;          // Timestamp du calcul\n  \n  // Informations du scénario\n  final String vehicleCategory;\n  final double distance;\n  final bool isScheduled;\n  \n  const PriceCalculation({\n    required this.basePrice,\n    required this.trafficSurcharge,\n    required this.reservationSurcharge,\n    required this.promoDiscount,\n    required this.finalPrice,\n    required this.breakdown,\n    required this.pricingVersion,\n    required this.calculatedAt,\n    required this.vehicleCategory,\n    required this.distance,\n    required this.isScheduled,\n  });\n  \n  // Factory pour créer un calcul V2\n  factory PriceCalculation.v2({\n    required String vehicleCategory,\n    required double distance,\n    required bool isScheduled,\n    required double basePrice,\n    required double trafficSurcharge,\n    required double reservationSurcharge,\n    required double promoDiscount,\n    required double finalPrice,\n    Map<String, dynamic>? additionalBreakdown,\n  }) {\n    final breakdown = {\n      'formula': distance < 3 ? 'floor_price' : distance < 15 ? 'linear' : 'long_trip',\n      'baseCalculation': {\n        'distance': distance,\n        'basePrice': basePrice,\n      },\n      'surcharges': {\n        'traffic': trafficSurcharge,\n        'reservation': reservationSurcharge,\n      },\n      'discounts': {\n        'promo': promoDiscount,\n      },\n      'rounding': {\n        'beforeRounding': basePrice + trafficSurcharge + reservationSurcharge - promoDiscount,\n        'afterRounding': finalPrice,\n      },\n      ...?additionalBreakdown,\n    };\n    \n    return PriceCalculation(\n      basePrice: basePrice,\n      trafficSurcharge: trafficSurcharge,\n      reservationSurcharge: reservationSurcharge,\n      promoDiscount: promoDiscount,\n      finalPrice: finalPrice,\n      breakdown: breakdown,\n      pricingVersion: \"v2.0\",\n      calculatedAt: DateTime.now(),\n      vehicleCategory: vehicleCategory,\n      distance: distance,\n      isScheduled: isScheduled,\n    );\n  }\n  \n  // Factory pour créer un calcul V1 (legacy)\n  factory PriceCalculation.v1({\n    required String vehicleCategory,\n    required double distance,\n    required bool isScheduled,\n    required double finalPrice,\n  }) {\n    return PriceCalculation(\n      basePrice: finalPrice,\n      trafficSurcharge: 0,\n      reservationSurcharge: 0,\n      promoDiscount: 0,\n      finalPrice: finalPrice,\n      breakdown: {\n        'legacyCalculation': true,\n        'note': 'Calculation performed by legacy system',\n      },\n      pricingVersion: \"v1.0\",\n      calculatedAt: DateTime.now(),\n      vehicleCategory: vehicleCategory,\n      distance: distance,\n      isScheduled: isScheduled,\n    );\n  }\n  \n  // Getters utiles\n  double get totalSurcharges => trafficSurcharge + reservationSurcharge;\n  double get netPrice => basePrice + totalSurcharges - promoDiscount;\n  bool get hasTrafficSurcharge => trafficSurcharge > 0;\n  bool get hasReservationSurcharge => reservationSurcharge > 0;\n  bool get hasPromoDiscount => promoDiscount > 0;\n  bool get isV2Calculation => pricingVersion == \"v2.0\";\n  \n  // Formatage pour affichage\n  String get formattedFinalPrice => '${finalPrice.toStringAsFixed(0)} MGA';\n  \n  String get formattedBreakdown {\n    if (!isV2Calculation) {\n      return 'Prix calculé : ${formattedFinalPrice}';\n    }\n    \n    var result = 'Prix de base : ${basePrice.toStringAsFixed(0)} MGA';\n    \n    if (hasTrafficSurcharge) {\n      result += '\\nMajoration embouteillages : +${trafficSurcharge.toStringAsFixed(0)} MGA';\n    }\n    \n    if (hasReservationSurcharge) {\n      result += '\\nSurcoût réservation : +${reservationSurcharge.toStringAsFixed(0)} MGA';\n    }\n    \n    if (hasPromoDiscount) {\n      result += '\\nRéduction promo : -${promoDiscount.toStringAsFixed(0)} MGA';\n    }\n    \n    result += '\\nPrix final : ${formattedFinalPrice}';\n    \n    return result;\n  }\n  \n  // Sérialisation JSON\n  Map<String, dynamic> toJson() {\n    return {\n      'basePrice': basePrice,\n      'trafficSurcharge': trafficSurcharge,\n      'reservationSurcharge': reservationSurcharge,\n      'promoDiscount': promoDiscount,\n      'finalPrice': finalPrice,\n      'breakdown': breakdown,\n      'pricingVersion': pricingVersion,\n      'calculatedAt': calculatedAt.toIso8601String(),\n      'vehicleCategory': vehicleCategory,\n      'distance': distance,\n      'isScheduled': isScheduled,\n    };\n  }\n  \n  factory PriceCalculation.fromJson(Map<String, dynamic> json) {\n    return PriceCalculation(\n      basePrice: (json['basePrice'] ?? 0.0).toDouble(),\n      trafficSurcharge: (json['trafficSurcharge'] ?? 0.0).toDouble(),\n      reservationSurcharge: (json['reservationSurcharge'] ?? 0.0).toDouble(),\n      promoDiscount: (json['promoDiscount'] ?? 0.0).toDouble(),\n      finalPrice: (json['finalPrice'] ?? 0.0).toDouble(),\n      breakdown: Map<String, dynamic>.from(json['breakdown'] ?? {}),\n      pricingVersion: json['pricingVersion'] ?? \"unknown\",\n      calculatedAt: DateTime.parse(json['calculatedAt']),\n      vehicleCategory: json['vehicleCategory'] ?? '',\n      distance: (json['distance'] ?? 0.0).toDouble(),\n      isScheduled: json['isScheduled'] ?? false,\n    );\n  }\n}\n```\n\n### 4. PricingScenario\n\n**Fichier** : `lib/models/pricing/pricing_scenario.dart`  \n**Utilisation** : Paramètres d'entrée pour le calcul de prix\n\n```dart\nclass PricingScenario {\n  final String vehicleCategory;         // taxi_moto, classic, confort, 4x4, van\n  final double distance;                // Distance en km\n  final DateTime requestTime;           // Moment de la demande\n  final bool isScheduled;               // Course programmée ou immédiate\n  final PromoCode? promoCode;           // Code promo éventuel\n  \n  const PricingScenario({\n    required this.vehicleCategory,\n    required this.distance,\n    required this.requestTime,\n    required this.isScheduled,\n    this.promoCode,\n  });\n  \n  // Getters utiles\n  bool get isWeekday => requestTime.weekday <= 5;\n  bool get isWeekend => !isWeekday;\n  int get hourOfDay => requestTime.hour;\n  bool get isNightTime => hourOfDay < 6 || hourOfDay > 22;\n  \n  // Validation\n  bool isValid() {\n    final validCategories = ['taxi_moto', 'classic', 'confort', '4x4', 'van'];\n    \n    return validCategories.contains(vehicleCategory) &&\n           distance > 0 &&\n           distance <= 100; // Limite raisonnable\n  }\n  \n  // Sérialisation\n  Map<String, dynamic> toJson() {\n    return {\n      'vehicleCategory': vehicleCategory,\n      'distance': distance,\n      'requestTime': requestTime.toIso8601String(),\n      'isScheduled': isScheduled,\n      'promoCode': promoCode?.toJson(),\n    };\n  }\n  \n  factory PricingScenario.fromJson(Map<String, dynamic> json) {\n    return PricingScenario(\n      vehicleCategory: json['vehicleCategory'],\n      distance: (json['distance']).toDouble(),\n      requestTime: DateTime.parse(json['requestTime']),\n      isScheduled: json['isScheduled'],\n      promoCode: json['promoCode'] != null \n          ? PromoCode.fromJson(json['promoCode']) \n          : null,\n    );\n  }\n  \n  @override\n  String toString() {\n    return 'PricingScenario($vehicleCategory, ${distance}km, ${requestTime.toString().substring(0, 16)}, scheduled: $isScheduled)';\n  }\n}\n```\n\n### 5. PromoCode (si nécessaire)\n\n**Fichier** : `lib/models/pricing/promo_code.dart`  \n**Utilisation** : Gestion des codes promotionnels\n\n```dart\nclass PromoCode {\n  final String code;                    // Code promo (ex: \"WELCOME10\")\n  final PromoType type;                 // Pourcentage ou montant fixe\n  final double value;                   // Valeur de la réduction\n  final DateTime? validUntil;           // Date d'expiration\n  final double? minAmount;              // Montant minimum pour appliquer\n  final List<String>? validCategories;  // Catégories autorisées\n  \n  const PromoCode({\n    required this.code,\n    required this.type,\n    required this.value,\n    this.validUntil,\n    this.minAmount,\n    this.validCategories,\n  });\n  \n  // Calcule la réduction pour un prix donné\n  double calculateDiscount(double basePrice, String vehicleCategory) {\n    // Vérifier validité\n    if (!isValid(basePrice, vehicleCategory)) {\n      return 0.0;\n    }\n    \n    switch (type) {\n      case PromoType.percentage:\n        return basePrice * (value / 100);\n      case PromoType.fixedAmount:\n        return value;\n    }\n  }\n  \n  // Vérifie si le code peut être appliqué\n  bool isValid(double basePrice, String vehicleCategory) {\n    // Vérifier expiration\n    if (validUntil != null && DateTime.now().isAfter(validUntil!)) {\n      return false;\n    }\n    \n    // Vérifier montant minimum\n    if (minAmount != null && basePrice < minAmount!) {\n      return false;\n    }\n    \n    // Vérifier catégorie autorisée\n    if (validCategories != null && !validCategories!.contains(vehicleCategory)) {\n      return false;\n    }\n    \n    return true;\n  }\n  \n  Map<String, dynamic> toJson() {\n    return {\n      'code': code,\n      'type': type.toString().split('.').last,\n      'value': value,\n      'validUntil': validUntil?.toIso8601String(),\n      'minAmount': minAmount,\n      'validCategories': validCategories,\n    };\n  }\n  \n  factory PromoCode.fromJson(Map<String, dynamic> json) {\n    return PromoCode(\n      code: json['code'],\n      type: PromoType.values.firstWhere(\n        (e) => e.toString().split('.').last == json['type']\n      ),\n      value: (json['value']).toDouble(),\n      validUntil: json['validUntil'] != null \n          ? DateTime.parse(json['validUntil']) \n          : null,\n      minAmount: json['minAmount']?.toDouble(),\n      validCategories: json['validCategories'] != null \n          ? List<String>.from(json['validCategories']) \n          : null,\n    );\n  }\n}\n\nenum PromoType {\n  percentage,   // Réduction en pourcentage\n  fixedAmount,  // Réduction en montant fixe\n}\n```\n\n## 📊 Relations entre Modèles\n\n```\nPricingConfigV2\n├── TrafficPeriod[] (périodes d'embouteillages)\n└── utilisé par PricingServiceV2\n\nPricingScenario\n├── PromoCode? (optionnel)\n└── paramètres → PricingServiceV2 → PriceCalculation\n\nPriceCalculation\n├── contient tous les détails du calcul\n└── utilisé par TripProvider pour affichage\n```\n\n## ⚠️ Points d'Attention\n\n### Validation des Données\n- Tous les modèles ont des méthodes `isValid()`\n- Validation côté client ET serveur\n- Fallback vers valeurs par défaut\n\n### Performance\n- Sérialisation JSON optimisée\n- Cache des configurations\n- Pas de calculs inutiles\n\n### Compatibilité\n- Support des versions V1 et V2\n- Migration transparente\n- Pas de breaking changes\n\n## 🧪 Tests Requis\n\n### Tests Unitaires\n```dart\n// Exemple de test pour PricingConfigV2\ntest('PricingConfigV2 validation', () {\n  final config = PricingConfigV2.defaultConfig();\n  expect(config.isValid(), isTrue);\n  \n  final invalidConfig = config.copyWith(floorPriceThreshold: -1);\n  expect(invalidConfig.isValid(), isFalse);\n});\n\n// Test pour TrafficPeriod\ntest('TrafficPeriod detection', () {\n  final period = TrafficPeriod(\n    startTime: TimeOfDay(hour: 7, minute: 0),\n    endTime: TimeOfDay(hour: 9, minute: 59),\n    daysOfWeek: [1, 2, 3, 4, 5],\n  );\n  \n  final mondayMorning = DateTime(2025, 1, 6, 8, 30); // Lundi 8h30\n  expect(period.isTrafficTime(mondayMorning), isTrue);\n  \n  final sundayMorning = DateTime(2025, 1, 5, 8, 30); // Dimanche 8h30\n  expect(period.isTrafficTime(sundayMorning), isFalse);\n});\n```\n\n### Tests d'Intégration\n- Sérialisation/désérialisation JSON\n- Interaction avec Firestore\n- Calculs de prix bout en bout\n\n---\n\n**Documentation mise à jour** : 28 juillet 2025  \n**Version** : 1.0