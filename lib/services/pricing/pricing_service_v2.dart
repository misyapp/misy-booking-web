import 'dart:math' as math;

import '../../functions/print_function.dart';
import '../../models/pricing/price_calculation.dart';
import '../../models/pricing/pricing_config_v2.dart';
import '../../models/pricing/promo_code.dart';
import 'pricing_service.dart';
import 'pricing_config_service.dart';

/// Service de calcul de prix selon le nouveau système de tarification Misy 2.0
/// 
/// Implémente tous les algorithmes définis dans les spécifications :
/// - Prix plancher pour distances < 3km
/// - Prix linéaire pour 3-15km
/// - Majoration courses longues (>15km) avec multiplicateur 1.2
/// - Majoration embouteillages ×1.4 sur créneaux 7h-9h59 et 16h-18h59 (Lun-Ven)
/// - Surcoûts réservation par catégorie
/// - Arrondis au multiple de 500 MGA le plus proche
/// - Support des codes promotionnels
/// 
/// Exemple d'usage :    
/// ```dart
/// final service = PricingServiceV2();
/// 
/// final result = await service.calculatePrice(
///   vehicleCategory: 'classic',
///   distance: 10.0,
///   requestTime: DateTime(2025, 1, 6, 17, 30), // Lundi 17h30 (embouteillages)
///   isScheduled: true, // Course programmée
/// );
/// 
/// print(result.formattedFinalPrice); // "43500 MGA"
/// print(result.formattedBreakdown);  // Détail complet
/// ```
class PricingServiceV2 implements IPricingService, ICacheablePricingService, IValidatablePricingService {
  /// Cache de la configuration pour éviter les appels répétés à Firestore
  PricingConfigV2? _cachedConfig;
  DateTime? _configCacheExpiry;
  
  /// Durée de cache de la configuration (5 minutes)
  static const Duration _configCacheDuration = Duration(minutes: 5);
  
  /// Statistiques de cache pour monitoring
  int _cacheHits = 0;
  int _cacheMisses = 0;
  DateTime? _lastCacheUpdate;
  
  @override
  String get version => "v2.0";
  
  @override
  String get displayName => "Pricing Service V2 (Misy 2.0)";
  
  @override
  Future<PriceCalculation> calculatePrice({
    required String vehicleCategory,
    required double distance,
    required DateTime requestTime,
    required bool isScheduled,
    PromoCode? promoCode,
    bool isAirportPickup = false,
    bool isAirportDrop = false,
  }) async {
    try {
      myCustomPrintStatement(
        'PricingServiceV2: Début calcul - $vehicleCategory, ${distance}km, programmé: $isScheduled',
        showPrint: true,
      );
      
      // 1. Validation des paramètres d'entrée
      final validationResult = await validatePricingParams(
        vehicleCategory: vehicleCategory,
        distance: distance,
        requestTime: requestTime,
        isScheduled: isScheduled,
        promoCode: promoCode,
      );
      
      if (!validationResult.isValid) {
        throw PricingServiceException(
          'Paramètres invalides: ${validationResult.errorMessage}',
          PricingServiceErrorCodes.validationError,
          context: {
            'vehicleCategory': vehicleCategory,
            'distance': distance,
            'requestTime': requestTime.toIso8601String(),
            'isScheduled': isScheduled,
            'errors': validationResult.errors,
          },
        );
      }
      
      // 2. Récupération de la configuration
      final config = await _getConfig();
      
      // 3. Calcul du prix de base selon la distance
      final basePrice = _calculateBasePrice(vehicleCategory, distance, config);
      myCustomPrintStatement('Prix de base calculé: ${basePrice.toStringAsFixed(0)} MGA');
      
      // 4. Application majoration embouteillages si applicable
      final trafficSurcharge = _applyTrafficSurcharge(basePrice, requestTime, config);
      if (trafficSurcharge > 0) {
        myCustomPrintStatement('Majoration embouteillages: +${trafficSurcharge.toStringAsFixed(0)} MGA');
      }
      
      // 5. Application surcoût réservation si applicable
      final reservationSurcharge = _applyReservationSurcharge(
        basePrice + trafficSurcharge,
        vehicleCategory,
        isScheduled,
        config
      );
      if (reservationSurcharge > 0) {
        myCustomPrintStatement('Surcoût réservation: +${reservationSurcharge.toStringAsFixed(0)} MGA');
      }

      // 6. Prix avant application du code promo
      final priceBeforePromo = basePrice + trafficSurcharge + reservationSurcharge;
      
      // 8. Application code promo si fourni
      final promoDiscount = _applyPromoCode(priceBeforePromo, promoCode, vehicleCategory);
      if (promoDiscount > 0) {
        myCustomPrintStatement('Réduction promo: -${promoDiscount.toStringAsFixed(0)} MGA');
      }

      // 9. Prix avant arrondi
      final priceBeforeRounding = priceBeforePromo - promoDiscount;

      // 10. Arrondi final
      final finalPrice = _roundPrice(priceBeforeRounding, config);

      myCustomPrintStatement('Prix final: ${finalPrice.toStringAsFixed(0)} MGA');

      // 11. Création du résultat avec breakdown détaillé
      final result = PriceCalculation.v2(
        vehicleCategory: vehicleCategory,
        distance: distance,
        isScheduled: isScheduled,
        basePrice: basePrice,
        trafficSurcharge: trafficSurcharge,
        reservationSurcharge: reservationSurcharge,
        promoDiscount: promoDiscount,
        finalPrice: finalPrice,
        additionalBreakdown: {
          'priceBeforeRounding': priceBeforeRounding,
          'roundingDifference': finalPrice - priceBeforeRounding,
          'configVersion': config.version,
          'isTrafficTime': config.isTrafficTime(requestTime),
          'formula': _getFormulaType(distance, config),
          'calculation': _getCalculationDetails(vehicleCategory, distance, config),
        },
      );
      
      // Validation finale du résultat
      if (!result.isValid()) {
        throw PricingServiceException(
          'Résultat de calcul invalide',
          PricingServiceErrorCodes.calculationError,
          context: result.toJson(),
        );
      }
      
      return result;
      
    } catch (e) {
      myCustomPrintStatement('Erreur dans PricingServiceV2.calculatePrice: $e', showPrint: true);
      
      if (e is PricingServiceException) {
        rethrow;
      }
      
      throw PricingServiceException(
        'Erreur de calcul de prix: ${e.toString()}',
        PricingServiceErrorCodes.calculationError,
        cause: e is Exception ? e : null,
        context: {
          'vehicleCategory': vehicleCategory,
          'distance': distance,
          'requestTime': requestTime.toIso8601String(),
          'isScheduled': isScheduled,
        },
      );
    }
  }
  
  /// Calcule le prix de base selon la distance et la catégorie
  /// 
  /// Applique la formule définie dans les spécifications :
  /// - Distance < 3km : Prix plancher
  /// - 3km ≤ Distance < 15km : Prix linéaire (prix/km × distance)  
  /// - Distance ≥ 15km : Prix normal + majoration courses longues
  double _calculateBasePrice(String category, double distance, PricingConfigV2 config) {
    final floorPrice = config.getFloorPrice(category);
    final pricePerKm = config.getPricePerKm(category);
    
    // Cas 1: Distance < seuil prix plancher (3 km par défaut)
    if (distance < config.floorPriceThreshold) {
      return floorPrice;
    }
    
    // Cas 2: Distance normale (3-15 km par défaut)
    if (distance < config.longTripThreshold) {
      return pricePerKm * distance;
    }
    
    // Cas 3: Course longue (> 15 km par défaut)
    // Prix normal pour les premiers 15km + majoration sur l'excédent
    final normalDistance = config.longTripThreshold;
    final extraDistance = distance - normalDistance;
    final normalPrice = pricePerKm * normalDistance;
    final extraPrice = extraDistance * pricePerKm * config.longTripMultiplier;
    
    return normalPrice + extraPrice;
  }
  
  /// Applique la majoration embouteillages si applicable
  /// 
  /// Vérifie si le moment de la demande correspond à un créneau
  /// d'embouteillages configuré et applique le multiplicateur.
  /// 
  /// Retourne le montant de la majoration (pas le prix total)
  double _applyTrafficSurcharge(double basePrice, DateTime requestTime, PricingConfigV2 config) {
    if (config.isTrafficTime(requestTime)) {
      // Retourner seulement la majoration (multiplicateur - 1)
      return basePrice * (config.trafficMultiplier - 1);
    }
    return 0.0;
  }
  
  /// Applique le surcoût de réservation si applicable
  ///
  /// Ajoute le surcoût fixe selon la catégorie pour les courses programmées
  double _applyReservationSurcharge(
    double currentPrice,
    String category,
    bool isScheduled,
    PricingConfigV2 config
  ) {
    if (!isScheduled) {
      return 0.0; // Course immédiate, pas de surcoût
    }

    return config.getReservationSurcharge(category);
  }

  /// Applique la réduction d'un code promo si valide
  /// 
  /// Calcule et applique la réduction selon le type de code promo.
  /// La réduction ne peut pas être supérieure au prix de base.
  double _applyPromoCode(double currentPrice, PromoCode? promoCode, String vehicleCategory) {
    if (promoCode == null) {
      return 0.0;
    }
    
    if (!promoCode.isValid(currentPrice, vehicleCategory)) {
      myCustomPrintStatement('Code promo invalide: ${promoCode.code}');
      return 0.0;
    }
    
    final discount = promoCode.calculateDiscount(currentPrice, vehicleCategory);
    
    // S'assurer que la réduction ne dépasse pas le prix
    return math.min(discount, currentPrice);
  }
  
  /// Arrondit le prix selon la configuration
  /// 
  /// Par défaut, arrondit au multiple de 500 MGA le plus proche
  double _roundPrice(double price, PricingConfigV2 config) {
    if (!config.enableRounding) {
      return price;
    }
    
    final step = config.roundingStep.toDouble();
    return (price / step).round() * step;
  }
  
  /// Détermine le type de formule utilisé selon la distance
  String _getFormulaType(double distance, PricingConfigV2 config) {
    if (distance < config.floorPriceThreshold) {
      return 'floor_price';
    } else if (distance < config.longTripThreshold) {
      return 'linear';
    } else {
      return 'long_trip';
    }
  }
  
  /// Génère les détails de calcul pour le breakdown
  Map<String, dynamic> _getCalculationDetails(String category, double distance, PricingConfigV2 config) {
    return {
      'floorPrice': config.getFloorPrice(category),
      'pricePerKm': config.getPricePerKm(category),
      'floorPriceThreshold': config.floorPriceThreshold,
      'longTripThreshold': config.longTripThreshold,
      'longTripMultiplier': config.longTripMultiplier,
      'trafficMultiplier': config.trafficMultiplier,
      'reservationSurcharge': config.getReservationSurcharge(category),
      'roundingStep': config.roundingStep,
    };
  }
  
  /// Récupère la configuration avec mise en cache
  Future<PricingConfigV2> _getConfig() async {
    // Vérifier si le cache est encore valide
    if (_cachedConfig != null && 
        _configCacheExpiry != null && 
        DateTime.now().isBefore(_configCacheExpiry!)) {
      _cacheHits++;
      return _cachedConfig!;
    }
    
    // Cache expiré ou inexistant, récupérer depuis Firestore
    _cacheMisses++;
    _cachedConfig = await PricingConfigService.getConfig();
    _configCacheExpiry = DateTime.now().add(_configCacheDuration);
    _lastCacheUpdate = DateTime.now();
    
    myCustomPrintStatement('Configuration mise en cache: ${_cachedConfig!.summary}');
    
    return _cachedConfig!;
  }
  
  @override
  Future<bool> isHealthy() async {
    try {
      // Tenter de récupérer la configuration
      final config = await _getConfig();
      
      // Vérifier que la configuration est valide
      if (!config.isValid()) {
        myCustomPrintStatement('PricingServiceV2: Configuration invalide');
        return false;
      }
      
      // Test rapide de calcul avec paramètres par défaut
      final testResult = await calculatePrice(
        vehicleCategory: 'classic',
        distance: 5.0,
        requestTime: DateTime.now(),
        isScheduled: false,
      );
      
      return testResult.isValid();
      
    } catch (e) {
      myCustomPrintStatement('PricingServiceV2: Health check failed - $e');
      return false;
    }
  }
  
  @override
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      final config = await _getConfig();
      
      return {
        'service': {
          'name': displayName,
          'version': version,
          'healthy': await isHealthy(),
        },
        'configuration': {
          'version': config.version,
          'enabled': config.enableNewPricingSystem,
          'valid': config.isValid(),
          'categories': config.supportedCategories.length,
          'trafficPeriods': config.trafficPeriods.length,
        },
        'cache': getCacheStats(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'service': {
          'name': displayName,
          'version': version,
          'healthy': false,
          'error': e.toString(),
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  @override
  Future<void> clearCache() async {
    _cachedConfig = null;
    _configCacheExpiry = null;
    myCustomPrintStatement('PricingServiceV2: Cache vidé');
  }
  
  @override
  Future<void> warmupCache() async {
    await _getConfig();
    myCustomPrintStatement('PricingServiceV2: Cache préchauffé');
  }
  
  @override
  Map<String, dynamic> getCacheStats() {
    return {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hitRate': _cacheHits + _cacheMisses > 0 
          ? _cacheHits / (_cacheHits + _cacheMisses) 
          : 0.0,
      'lastUpdate': _lastCacheUpdate?.toIso8601String(),
      'cacheExpiry': _configCacheExpiry?.toIso8601String(),
      'isCached': _cachedConfig != null,
    };
  }
  
  @override
  Future<ValidationResult> validatePricingParams({
    required String vehicleCategory,
    required double distance,
    required DateTime requestTime,
    required bool isScheduled,
    PromoCode? promoCode,
  }) async {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Validation catégorie véhicule
    final validCategories = ['taxi_moto', 'classic', 'confort', '4x4', 'van'];
    if (!validCategories.contains(vehicleCategory)) {
      errors.add('Catégorie de véhicule invalide: $vehicleCategory');
    }
    
    // Validation distance
    if (distance <= 0) {
      errors.add('La distance doit être positive');
    } else if (distance > 200) {
      warnings.add('Distance très importante: ${distance}km');
    }
    
    // Validation date/heure
    final now = DateTime.now();
    if (requestTime.isBefore(now.subtract(Duration(hours: 1)))) {
      errors.add('La date de demande ne peut pas être dans le passé');
    } else if (requestTime.isAfter(now.add(Duration(days: 30)))) {
      errors.add('La date de demande ne peut pas être si éloignée dans le futur');  
    }
    
    // Validation course programmée
    if (isScheduled && requestTime.isBefore(now.add(Duration(minutes: 5)))) {
      errors.add('Une course programmée doit être au moins 5 minutes dans le futur');
    }
    
    // Validation code promo si fourni
    if (promoCode != null) {
      if (promoCode.code.isEmpty) {
        errors.add('Code promo vide');
      } else if (promoCode.isExpired) {
        errors.add('Code promo expiré');
      } else if (promoCode.isMaxUsesReached) {
        errors.add('Code promo: limite d\'utilisation atteinte');
      }
      
      // Vérifier la validité pour cette catégorie (sans prix car on ne l'a pas encore)
      if (promoCode.validCategories != null && 
          !promoCode.validCategories!.contains(vehicleCategory)) {
        errors.add('Code promo non valide pour cette catégorie de véhicule');
      }
    }
    
    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors, warnings);
    }
    
    if (warnings.isNotEmpty) {
      return ValidationResult.successWithWarnings(warnings);
    }
    
    return ValidationResult.success;
  }
}