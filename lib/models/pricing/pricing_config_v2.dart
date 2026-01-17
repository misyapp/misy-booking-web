import 'package:flutter/material.dart';
import 'traffic_period.dart';

/// Configuration centralisée du nouveau système de tarification Misy 2.0
/// 
/// Ce modèle contient tous les paramètres nécessaires au calcul des prix :
/// - Prix plancher et prix au kilomètre par catégorie de véhicule
/// - Configuration des majorations (embouteillages, courses longues)
/// - Surcoûts de réservation
/// - Paramètres d'arrondi
/// - Flag de migration pour basculer entre ancien et nouveau système
/// 
/// Exemple d'usage :
/// ```dart
/// final config = PricingConfigV2.defaultConfig();
/// print(config.floorPrices['classic']); // 8000.0
/// print(config.isValid()); // true
/// ```
class PricingConfigV2 {
  /// Version du système de tarification ("2.0")
  final String version;
  
  /// Flag de migration : active le nouveau système si true
  /// IMPORTANT: Doit rester false initialement pour éviter les régressions
  final bool enableNewPricingSystem;
  
  /// Prix plancher par catégorie de véhicule (MGA)
  /// Appliqué pour les distances < floorPriceThreshold
  final Map<String, double> floorPrices;
  
  /// Prix au kilomètre par catégorie de véhicule (MGA/km)
  final Map<String, double> pricePerKm;
  
  /// Seuil maximum pour l'application du prix plancher (km)
  /// Par défaut : 3.0 km
  final double floorPriceThreshold;
  
  /// Multiplicateur pour majoration embouteillages
  /// Par défaut : 1.4 (soit +40%)
  final double trafficMultiplier;
  
  /// Périodes d'embouteillages où s'applique la majoration
  final List<TrafficPeriod> trafficPeriods;
  
  /// Seuil pour considérer une course comme "longue" (km)
  /// Par défaut : 15.0 km
  final double longTripThreshold;
  
  /// Multiplicateur pour courses longues (> longTripThreshold)
  /// Par défaut : 1.2 (soit +20% sur la distance excédentaire)
  final double longTripMultiplier;
  
  /// Surcoût fixe de réservation par catégorie (MGA)
  /// Appliqué uniquement pour les courses programmées
  final Map<String, double> reservationSurcharge;

  /// Temps d'avance minimum pour considérer une course comme "programmée" (minutes)
  /// Par défaut : 10 minutes
  final int reservationAdvanceMinutes;
  
  /// Active/désactive le système d'arrondis
  /// Par défaut : true
  final bool enableRounding;
  
  /// Pas d'arrondi (MGA)
  /// Par défaut : 500 (arrondi au multiple de 500 MGA le plus proche)
  final int roundingStep;
  
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
  
  /// Factory créant la configuration par défaut selon les spécifications Misy 2.0
  /// 
  /// Utilise les tarifs définis dans les spécifications :
  /// - Prix plancher : Taxi-moto 6000, Classic 8000, Confort 11000, 4x4 13000, Van 15000
  /// - Prix/km : Taxi-moto 2000, Classic 2750, Confort 3850, 4x4 4500, Van 5000
  /// - Embouteillages : 7h-9h59 et 16h-18h59 (Lun-Ven), multiplicateur 1.4
  /// - Réservation : Taxi-moto 3600, Classic 5000, Confort 7000, 4x4 8200, Van 9100
  /// 
  /// IMPORTANT: enableNewPricingSystem est initialisé à false
  factory PricingConfigV2.defaultConfig() {
    return PricingConfigV2(
      version: "2.0",
      enableNewPricingSystem: false, // CRITICAL: Ne pas activer par défaut
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
        // Embouteillages du matin : 7h00 à 9h59, Lundi à Vendredi
        TrafficPeriod(
          startTime: TimeOfDay(hour: 7, minute: 0),
          endTime: TimeOfDay(hour: 9, minute: 59),
          daysOfWeek: [1, 2, 3, 4, 5], // Lun-Ven
        ),
        // Embouteillages du soir : 16h00 à 18h59, Lundi à Vendredi
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
  
  /// Sérialisation vers JSON pour stockage Firestore
  /// 
  /// Format compatible avec la structure Firestore définie dans les spécifications
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
  
  /// Désérialisation depuis JSON
  /// 
  /// Gère les cas où certains champs sont manquants en utilisant
  /// les valeurs par défaut pour maintenir la compatibilité.
  /// 
  /// [json] Map contenant les données JSON depuis Firestore
  factory PricingConfigV2.fromJson(Map<String, dynamic> json) {
    // Récupérer la configuration par défaut pour les fallbacks
    final defaultConfig = PricingConfigV2.defaultConfig();
    
    return PricingConfigV2(
      version: json['version'] ?? "2.0",
      enableNewPricingSystem: json['enableNewPricingSystem'] ?? false,
      floorPrices: _parseDoubleMap(json['floorPrices'], defaultConfig.floorPrices),
      pricePerKm: _parseDoubleMap(json['pricePerKm'], defaultConfig.pricePerKm),
      floorPriceThreshold: _parseDouble(json['floorPriceThreshold'], defaultConfig.floorPriceThreshold),
      trafficMultiplier: _parseDouble(json['trafficMultiplier'], defaultConfig.trafficMultiplier),
      trafficPeriods: _parseTrafficPeriods(json['trafficPeriods'], defaultConfig.trafficPeriods),
      longTripThreshold: _parseDouble(json['longTripThreshold'], defaultConfig.longTripThreshold),
      longTripMultiplier: _parseDouble(json['longTripMultiplier'], defaultConfig.longTripMultiplier),
      reservationSurcharge: _parseDoubleMap(json['reservationSurcharge'], defaultConfig.reservationSurcharge),
      reservationAdvanceMinutes: _parseInt(json['reservationAdvanceMinutes'], defaultConfig.reservationAdvanceMinutes),
      enableRounding: json['enableRounding'] ?? defaultConfig.enableRounding,
      roundingStep: _parseInt(json['roundingStep'], defaultConfig.roundingStep),
    );
  }
  
  /// Helper pour parser un Map<String, double> avec fallback
  static Map<String, double> _parseDoubleMap(dynamic value, Map<String, double> fallback) {
    if (value is Map) {
      final result = <String, double>{};
      value.forEach((key, val) {
        if (key is String && val != null) {
          result[key] = _parseDouble(val, fallback[key] ?? 0.0);
        }
      });
      
      // S'assurer que toutes les catégories requises sont présentes
      for (final category in ['taxi_moto', 'classic', 'confort', '4x4', 'van']) {
        if (!result.containsKey(category)) {
          result[category] = fallback[category] ?? 0.0;
        }
      }
      
      return result;
    }
    return Map.from(fallback);
  }
  
  /// Helper pour parser un double avec fallback
  static double _parseDouble(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }
  
  /// Helper pour parser un int avec fallback
  static int _parseInt(dynamic value, int fallback) {
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }
  
  /// Helper pour parser les périodes de trafic avec fallback
  static List<TrafficPeriod> _parseTrafficPeriods(dynamic value, List<TrafficPeriod> fallback) {
    if (value is List) {
      try {
        return value.map((p) => TrafficPeriod.fromJson(p)).toList();
      } catch (e) {
        // En cas d'erreur de parsing, utiliser le fallback
        return List.from(fallback);
      }
    }
    return List.from(fallback);
  }
  
  /// Validation complète de la configuration
  /// 
  /// Vérifie que tous les paramètres sont cohérents et valides :
  /// - Toutes les catégories de véhicules ont des prix positifs
  /// - Les seuils et multiplicateurs sont logiques
  /// - Les périodes de trafic sont valides
  /// - Les paramètres d'arrondi sont corrects
  bool isValid() {
    final categories = ['taxi_moto', 'classic', 'confort', '4x4', 'van'];
    
    // Vérifier que toutes les catégories ont des prix plancher valides
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
    
    // Vérifier la cohérence des seuils
    if (floorPriceThreshold <= 0 || longTripThreshold <= floorPriceThreshold) {
      return false;
    }
    
    // Vérifier les multiplicateurs
    // trafficMultiplier doit être > 1.0 (surcharge trafic)
    // longTripMultiplier peut être < 1.0 (réduction) ou > 1.0 (surcharge)
    if (trafficMultiplier <= 1.0 || longTripMultiplier <= 0) {
      return false;
    }
    
    // Vérifier les paramètres d'arrondi
    if (roundingStep <= 0) {
      return false;
    }
    
    // Vérifier le temps d'avance réservation
    if (reservationAdvanceMinutes < 0) {
      return false;
    }
    
    // Vérifier que toutes les périodes de trafic sont valides
    for (final period in trafficPeriods) {
      if (!period.isValid()) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Obtient le prix plancher pour une catégorie de véhicule
  /// 
  /// [category] Catégorie du véhicule
  /// Retourne le prix plancher ou 0 si la catégorie n'existe pas
  double getFloorPrice(String category) {
    return floorPrices[category] ?? 0.0;
  }
  
  /// Obtient le prix au kilomètre pour une catégorie de véhicule
  /// 
  /// [category] Catégorie du véhicule
  /// Retourne le prix/km ou 0 si la catégorie n'existe pas
  double getPricePerKm(String category) {
    return pricePerKm[category] ?? 0.0;
  }
  
  /// Obtient le surcoût de réservation pour une catégorie de véhicule
  ///
  /// [category] Catégorie du véhicule
  /// Retourne le surcoût ou 0 si la catégorie n'existe pas
  double getReservationSurcharge(String category) {
    return reservationSurcharge[category] ?? 0.0;
  }

  /// Vérifie si une DateTime est dans une période d'embouteillages
  /// 
  /// [dateTime] Date/heure à vérifier
  /// Retourne true si c'est une période d'embouteillages
  bool isTrafficTime(DateTime dateTime) {
    for (final period in trafficPeriods) {
      if (period.isTrafficTime(dateTime)) {
        return true;
      }
    }
    return false;
  }
  
  /// Liste des catégories de véhicules supportées
  List<String> get supportedCategories => ['taxi_moto', 'classic', 'confort', '4x4', 'van'];
  
  /// Vérifie si une catégorie de véhicule est supportée
  /// 
  /// [category] Catégorie à vérifier
  /// Retourne true si la catégorie est supportée
  bool isCategorySupported(String category) {
    return supportedCategories.contains(category);
  }
  
  /// Création d'une copie avec modifications
  /// 
  /// Permet de créer une nouvelle configuration en modifiant
  /// seulement certains paramètres. Utile pour les tests et
  /// les ajustements de configuration.
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
      floorPrices: floorPrices ?? Map.from(this.floorPrices),
      pricePerKm: pricePerKm ?? Map.from(this.pricePerKm),
      floorPriceThreshold: floorPriceThreshold ?? this.floorPriceThreshold,
      trafficMultiplier: trafficMultiplier ?? this.trafficMultiplier,
      trafficPeriods: trafficPeriods ?? List.from(this.trafficPeriods),
      longTripThreshold: longTripThreshold ?? this.longTripThreshold,
      longTripMultiplier: longTripMultiplier ?? this.longTripMultiplier,
      reservationSurcharge: reservationSurcharge ?? Map.from(this.reservationSurcharge),
      reservationAdvanceMinutes: reservationAdvanceMinutes ?? this.reservationAdvanceMinutes,
      enableRounding: enableRounding ?? this.enableRounding,
      roundingStep: roundingStep ?? this.roundingStep,
    );
  }
  
  /// Résumé de la configuration pour debug/logging
  /// 
  /// Génère un résumé lisible de la configuration incluant
  /// les informations principales sans détails sensibles.
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('PricingConfigV2 Summary:');
    buffer.writeln('- Version: $version');
    buffer.writeln('- System enabled: $enableNewPricingSystem');
    buffer.writeln('- Categories: ${supportedCategories.length}');
    buffer.writeln('- Floor price threshold: ${floorPriceThreshold}km');
    buffer.writeln('- Long trip threshold: ${longTripThreshold}km');
    buffer.writeln('- Traffic periods: ${trafficPeriods.length}');
    buffer.writeln('- Rounding enabled: $enableRounding (step: ${roundingStep} MGA)');
    buffer.writeln('- Valid: ${isValid()}');
    return buffer.toString();
  }
  
  @override
  String toString() {
    return 'PricingConfigV2(v$version, enabled: $enableNewPricingSystem, categories: ${supportedCategories.length})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is PricingConfigV2 &&
           other.version == version &&
           other.enableNewPricingSystem == enableNewPricingSystem &&
           _mapEquals(other.floorPrices, floorPrices) &&
           _mapEquals(other.pricePerKm, pricePerKm) &&
           other.floorPriceThreshold == floorPriceThreshold &&
           other.trafficMultiplier == trafficMultiplier &&
           _listEquals(other.trafficPeriods, trafficPeriods) &&
           other.longTripThreshold == longTripThreshold &&
           other.longTripMultiplier == longTripMultiplier &&
           _mapEquals(other.reservationSurcharge, reservationSurcharge) &&
           other.reservationAdvanceMinutes == reservationAdvanceMinutes &&
           other.enableRounding == enableRounding &&
           other.roundingStep == roundingStep;
  }
  
  @override
  int get hashCode {
    return version.hashCode ^
           enableNewPricingSystem.hashCode ^
           floorPrices.hashCode ^
           pricePerKm.hashCode ^
           floorPriceThreshold.hashCode ^
           trafficMultiplier.hashCode ^
           trafficPeriods.hashCode ^
           longTripThreshold.hashCode ^
           longTripMultiplier.hashCode ^
           reservationSurcharge.hashCode ^
           reservationAdvanceMinutes.hashCode ^
           enableRounding.hashCode ^
           roundingStep.hashCode;
  }
  
  /// Helper pour comparer des Map<String, double>
  bool _mapEquals(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
  
  /// Helper pour comparer des listes de TrafficPeriod
  bool _listEquals(List<TrafficPeriod> a, List<TrafficPeriod> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}