import '../../contants/global_data.dart';
import '../../functions/print_function.dart';
import '../../modal/vehicle_modal.dart';
import '../../models/pricing/price_calculation.dart';
import '../../models/pricing/promo_code.dart';
import 'pricing_service.dart';

/// Wrapper du système de tarification legacy (V1)
/// 
/// Ce service encapsule l'ancien algorithme de calcul de prix
/// dans la nouvelle interface IPricingService pour maintenir
/// la compatibilité pendant la phase de migration.
/// 
/// L'ancien système utilise :
/// - Prix de base par véhicule
/// - Prix au kilomètre  
/// - Charge par minute
/// - Réduction par catégorie de véhicule
/// - Frais de programmation fixe
/// - Réduction spéciale taxi-moto
/// 
/// Formule legacy :
/// ```
/// Prix = (prix_km × distance + prix_base + temps × charge_minute) 
///        - réduction_véhicule - réduction_spéciale + frais_programmation
/// ```
/// 
/// Exemple d'usage :
/// ```dart
/// final service = PricingServiceLegacy();
/// 
/// final result = await service.calculatePrice(
///   vehicleCategory: 'classic',
///   distance: 8.5,
///   requestTime: DateTime.now(),
///   isScheduled: false,
/// );
/// 
/// print(result.formattedFinalPrice); // Prix calculé avec l'ancien système
/// ```
class PricingServiceLegacy implements IPricingService {
  @override
  String get version => "v1.0";
  
  @override 
  String get displayName => "Legacy Pricing Service (V1)";
  
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
        'PricingServiceLegacy: Calcul legacy - $vehicleCategory, ${distance}km, programmé: $isScheduled',
        showPrint: true,
      );
      
      // 1. Validation des paramètres
      await _validateParams(vehicleCategory, distance, requestTime, isScheduled);
      
      // 2. Récupérer les données du véhicule
      final vehicleData = _getVehicleData(vehicleCategory);
      if (vehicleData == null) {
        throw PricingServiceException(
          'Données véhicule non trouvées pour la catégorie: $vehicleCategory',
          PricingServiceErrorCodes.invalidCategory,
        );
      }
      
      // 3. Calcul selon l'ancien algorithme
      final basePrice = _calculateLegacyPrice(vehicleData, distance, isScheduled);
      
      // 4. Application code promo si fourni (selon l'ancien système)
      double finalPrice = basePrice;
      double promoDiscount = 0.0;
      
      if (promoCode != null && promoCode.isValid(basePrice, vehicleCategory)) {
        promoDiscount = _calculateLegacyPromoDiscount(basePrice, promoCode);
        finalPrice = basePrice - promoDiscount;
      }
      
      // S'assurer que le prix final n'est pas négatif
      if (finalPrice < 0) {
        finalPrice = 0;
      }
      
      myCustomPrintStatement('PricingServiceLegacy: Prix final calculé: ${finalPrice.toStringAsFixed(0)} MGA');
      
      // 5. Créer le résultat au format V1 
      return PriceCalculation.v1(
        vehicleCategory: vehicleCategory,
        distance: distance,
        isScheduled: isScheduled,
        finalPrice: finalPrice,
      ).copyWith(
        // Ajouter les informations supplémentaires pour la compatibilité
        breakdown: {
          'legacyCalculation': true,
          'vehicleData': {
            'basePrice': vehicleData.basePrice,
            'pricePerKm': vehicleData.price,
            'perMinCharge': vehicleData.perMinCharge,
            'discount': vehicleData.discount,
          },
          'components': {
            'baseCalculated': basePrice,
            'promoDiscount': promoDiscount,
            'finalPrice': finalPrice,
          },
          'note': 'Calculation performed by legacy pricing system (TripProvider.calculatePrice)',
        },
      );
      
    } catch (e) {
      myCustomPrintStatement('Erreur dans PricingServiceLegacy.calculatePrice: $e', showPrint: true);
      
      if (e is PricingServiceException) {
        rethrow;
      }
      
      throw PricingServiceException(
        'Erreur de calcul legacy: ${e.toString()}',
        PricingServiceErrorCodes.calculationError,
        cause: e is Exception ? e : null,
        context: {
          'vehicleCategory': vehicleCategory,
          'distance': distance,
          'isScheduled': isScheduled,
        },
      );
    }
  }
  
  /// Calcule le prix selon l'ancien algorithme du TripProvider
  /// 
  /// Reproduit la logique de TripProvider.calculatePrice() ligne par ligne
  double _calculateLegacyPrice(VehicleModal vehicleData, double distance, bool isScheduled) {
    // Estimation du temps basée sur la distance (comme dans l'ancien système)
    // Vitesse moyenne estimée : 30 km/h en ville
    final estimatedTimeMinutes = (distance / 30.0) * 60.0;
    
    // Reproduction exacte de la formule legacy
    var baseCalculation = (vehicleData.price * distance) +
                         vehicleData.basePrice +
                         (estimatedTimeMinutes * vehicleData.perMinCharge);
    
    // Application de la réduction par véhicule
    var afterVehicleDiscount = baseCalculation - 
                              (baseCalculation * (vehicleData.discount / 100));
    
    // Application de la réduction spéciale taxi-moto si applicable
    var afterSpecialDiscount = afterVehicleDiscount - 
                              _getSpecialTaxiDiscount(vehicleData);
    
    // S'assurer que le prix n'est pas négatif après réductions
    if (afterSpecialDiscount < 0) {
      afterSpecialDiscount = 0;
    }
    
    // Ajouter les frais de programmation si applicable
    var finalPrice = afterSpecialDiscount + 
                    (isScheduled ? globalSettings.scheduleRideServiceFee : 0);
    
    myCustomPrintStatement('Legacy calculation: base=$baseCalculation, après réductions=$afterSpecialDiscount, final=$finalPrice');
    
    return finalPrice;
  }
  
  /// Calcule la réduction spéciale taxi-moto selon l'ancien système
  double _getSpecialTaxiDiscount(VehicleModal vehicleData) {
    // ID spécial hardcodé dans l'ancien système pour taxi-moto
    const String specialTaxiId = "02b2988097254a04859a";
    
    if (vehicleData.id == specialTaxiId &&
        userData.value != null &&
        userData.value!.extraDiscount > 0 &&
        globalSettings.enableTaxiExtraDiscount) {
      return userData.value!.extraDiscount;
    }
    
    return 0.0;
  }
  
  /// Calcule la réduction promo selon l'ancien système
  double _calculateLegacyPromoDiscount(double basePrice, PromoCode promoCode) {
    // L'ancien système utilise un système de pourcentage avec plafond
    // Simuler cela en convertissant notre PromoCode vers l'ancien format
    
    double discountPercent = 0.0;
    double maxDiscount = basePrice; // Par défaut, pas de plafond
    
    if (promoCode.type == PromoType.percentage) {
      discountPercent = promoCode.value;
      // Pour les codes pourcentage, utiliser un plafond raisonnable
      maxDiscount = basePrice * 0.5; // Max 50% du prix
    } else if (promoCode.type == PromoType.fixedAmount) {
      // Convertir montant fixe en pourcentage équivalent
      discountPercent = (promoCode.value / basePrice) * 100;
      maxDiscount = promoCode.value;
    }
    
    final calculatedDiscount = (basePrice * discountPercent) / 100;
    
    // Appliquer le plafond comme dans l'ancien système
    return calculatedDiscount < maxDiscount ? calculatedDiscount : maxDiscount;
  }
  
  /// Récupère les données du véhicule depuis les globals
  VehicleModal? _getVehicleData(String vehicleCategory) {
    // Chercher dans la liste des véhicules globaux
    for (final vehicle in vehicleListModal) {
      if (_matchesCategory(vehicle, vehicleCategory)) {
        return vehicle;
      }
    }
    
    myCustomPrintStatement('PricingServiceLegacy: Véhicule non trouvé pour catégorie: $vehicleCategory');
    return null;
  }
  
  /// Matche une catégorie string avec un VehicleModal
  bool _matchesCategory(VehicleModal vehicle, String category) {
    // Mapping entre les nouvelles catégories et les anciennes
    final categoryMappings = {
      'taxi_moto': ['taxi-moto', 'moto', 'taxi moto'],
      'classic': ['classic', 'classique', 'standard'],
      'confort': ['confort', 'comfort', 'premium'],
      '4x4': ['4x4', '4wd', 'suv'],
      'van': ['van', 'minibus', 'fourgon'],
    };
    
    final possibleNames = categoryMappings[category] ?? [category];
    final vehicleName = vehicle.name.toLowerCase();
    
    return possibleNames.any((name) => vehicleName.contains(name.toLowerCase()));
  }
  
  /// Validation des paramètres d'entrée
  Future<void> _validateParams(String vehicleCategory, double distance, DateTime requestTime, bool isScheduled) async {
    if (distance <= 0) {
      throw PricingServiceException(
        'Distance invalide: $distance',
        PricingServiceErrorCodes.invalidDistance,
      );
    }
    
    if (distance > 200) {
      throw PricingServiceException(
        'Distance trop importante: $distance km',
        PricingServiceErrorCodes.invalidDistance,
      );
    }
    
    final validCategories = ['taxi_moto', 'classic', 'confort', '4x4', 'van'];
    if (!validCategories.contains(vehicleCategory)) {
      throw PricingServiceException(
        'Catégorie invalide: $vehicleCategory',
        PricingServiceErrorCodes.invalidCategory,
      );
    }
  }
  
  @override
  Future<bool> isHealthy() async {
    try {
      // Vérifier que les données globales sont disponibles
      if (vehicleListModal.isEmpty) {
        myCustomPrintStatement('PricingServiceLegacy: Aucune donnée véhicule disponible');
        return false;
      }
      
      // Test rapide de calcul
      final testResult = await calculatePrice(
        vehicleCategory: 'classic',
        distance: 5.0,
        requestTime: DateTime.now(),
        isScheduled: false,
      );
      
      return testResult.isValid();
      
    } catch (e) {
      myCustomPrintStatement('PricingServiceLegacy: Health check failed - $e');
      return false;
    }
  }
  
  @override
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    return {
      'service': {
        'name': displayName,
        'version': version,
        'healthy': await isHealthy(),
      },
      'dependencies': {
        'vehicleListModal': vehicleListModal.length,
        'globalSettings': globalSettings.toString(),
        'userData': userData.value != null,
      },
      'supportedCategories': ['taxi_moto', 'classic', 'confort', '4x4', 'van'],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}