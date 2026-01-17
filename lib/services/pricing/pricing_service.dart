import '../../models/pricing/price_calculation.dart';
import '../../models/pricing/promo_code.dart';

/// Interface commune pour tous les services de calcul de prix
/// 
/// Cette interface permet de maintenir la compatibilité entre
/// l'ancien système de tarification (V1) et le nouveau système (V2)
/// en exposant une API unifiée.
/// 
/// Les implémentations concrètes sont :
/// - [PricingServiceLegacy] : Encapsule l'ancien système
/// - [PricingServiceV2] : Nouveau système avec toutes les fonctionnalités
/// 
/// Exemple d'usage :
/// ```dart
/// // Obtention du service via le sélecteur
/// final service = await PricingSystemSelector.getPricingService();
/// 
/// // Calcul du prix
/// final result = await service.calculatePrice(
///   vehicleCategory: 'classic',
///   distance: 8.5,
///   requestTime: DateTime.now(),
///   isScheduled: false,
/// );
/// 
/// print(result.formattedFinalPrice); // "23000 MGA"
/// ```
abstract class IPricingService {
  /// Calcule le prix d'une course selon les paramètres fournis
  /// 
  /// Cette méthode est le point d'entrée principal pour tous les calculs
  /// de prix. Elle doit être implémentée par tous les services de tarification.
  /// 
  /// [vehicleCategory] Catégorie du véhicule demandé
  ///   Valeurs possibles : 'taxi_moto', 'classic', 'confort', '4x4', 'van'
  /// 
  /// [distance] Distance du trajet en kilomètres
  ///   Doit être positive et raisonnable (< 200km)
  /// 
  /// [requestTime] Moment de la demande de course
  ///   Utilisé pour détecter les créneaux d'embouteillages et
  ///   valider les courses programmées
  /// 
  /// [isScheduled] True si la course est programmée à l'avance
  ///   Détermine l'application du surcoût de réservation
  /// 
  /// [promoCode] Code promotionnel optionnel à appliquer
  ///   Si fourni, la réduction sera calculée et appliquée
  ///
  /// [isAirportPickup] True si le point de départ est un aéroport
  ///   Détermine l'application des frais d'aéroport
  ///
  /// [isAirportDrop] True si la destination est un aéroport
  ///   Détermine l'application des frais d'aéroport
  ///
  /// Retourne un [PriceCalculation] contenant :
  /// - Le prix final calculé
  /// - Le détail de tous les composants (base, majorations, réductions)
  /// - Les métadonnées de traçabilité
  ///
  /// Lève une [ArgumentError] si les paramètres sont invalides
  /// Lève une [ServiceException] en cas d'erreur de calcul
  Future<PriceCalculation> calculatePrice({
    required String vehicleCategory,
    required double distance,
    required DateTime requestTime,
    required bool isScheduled,
    PromoCode? promoCode,
    bool isAirportPickup = false,
    bool isAirportDrop = false,
  });
  
  /// Version du service de tarification
  /// 
  /// Permet d'identifier quel système a été utilisé pour le calcul :
  /// - "v1.0" : Ancien système (legacy)
  /// - "v2.0" : Nouveau système
  String get version;
  
  /// Nom d'affichage du service
  /// 
  /// Utilisé pour les logs et le debug
  String get displayName;
  
  /// Vérifie si le service est disponible et opérationnel
  /// 
  /// Peut effectuer des vérifications de santé comme :
  /// - Accès à la configuration
  /// - Validation des paramètres système
  /// - Test de connectivité si nécessaire
  /// 
  /// Retourne true si le service peut être utilisé
  Future<bool> isHealthy();
  
  /// Obtient des informations de diagnostic sur le service
  /// 
  /// Retourne un Map contenant des informations utiles pour le debug :
  /// - Version du service
  /// - État de la configuration
  /// - Dernière mise à jour
  /// - Métriques de performance
  Future<Map<String, dynamic>> getDiagnosticInfo();
}

/// Interface optionnelle pour les services supportant la mise en cache
/// 
/// Les services implémentant cette interface peuvent optimiser leurs
/// performances en cachant les configurations et résultats.
abstract class ICacheablePricingService extends IPricingService {
  /// Vide le cache du service
  /// 
  /// Force le rechargement de la configuration lors du prochain calcul
  Future<void> clearCache();
  
  /// Précharge le cache avec les données nécessaires
  /// 
  /// Peut être appelé au démarrage de l'application pour améliorer
  /// les performances du premier calcul
  Future<void> warmupCache();
  
  /// Obtient des statistiques sur l'utilisation du cache
  /// 
  /// Retourne des métriques comme :
  /// - Nombre de hits/miss
  /// - Taille du cache
  /// - Dernière mise à jour
  Map<String, dynamic> getCacheStats();
}

/// Interface optionnelle pour les services supportant la validation avancée
/// 
/// Permet d'effectuer des vérifications supplémentaires sur les paramètres
/// avant le calcul effectif du prix.
abstract class IValidatablePricingService extends IPricingService {
  /// Valide les paramètres d'un calcul de prix
  /// 
  /// Effectue une validation complète des paramètres sans calculer le prix.
  /// Utile pour valider les données utilisateur avant soumission.
  /// 
  /// [vehicleCategory] Catégorie à valider
  /// [distance] Distance à valider  
  /// [requestTime] Date/heure à valider
  /// [isScheduled] Type de course à valider
  /// [promoCode] Code promo à valider (optionnel)
  /// 
  /// Retourne un [ValidationResult] avec le statut et les erreurs
  Future<ValidationResult> validatePricingParams({
    required String vehicleCategory,
    required double distance,
    required DateTime requestTime,
    required bool isScheduled,
    PromoCode? promoCode,
  });
}

/// Résultat d'une validation de paramètres
class ValidationResult {
  /// True si tous les paramètres sont valides
  final bool isValid;
  
  /// Liste des erreurs de validation (vide si isValid = true)
  final List<String> errors;
  
  /// Avertissements non-bloquants
  final List<String> warnings;
  
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
  
  /// Validation réussie sans erreur ni avertissement
  static const ValidationResult success = ValidationResult(isValid: true);
  
  /// Factory pour une validation échouée
  factory ValidationResult.failure(List<String> errors, [List<String>? warnings]) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
    );
  }
  
  /// Factory pour une validation réussie avec avertissements
  factory ValidationResult.successWithWarnings(List<String> warnings) {
    return ValidationResult(
      isValid: true,
      warnings: warnings,
    );
  }
  
  /// True s'il y a des avertissements
  bool get hasWarnings => warnings.isNotEmpty;
  
  /// Message d'erreur combiné
  String get errorMessage => errors.join(', ');
  
  /// Message d'avertissement combiné
  String get warningMessage => warnings.join(', ');
  
  @override
  String toString() {
    if (isValid) {
      return hasWarnings 
          ? 'ValidationResult(valid with warnings: $warningMessage)'
          : 'ValidationResult(valid)';
    }
    return 'ValidationResult(invalid: $errorMessage)';
  }
}

/// Exception lancée par les services de tarification
class PricingServiceException implements Exception {
  /// Message d'erreur
  final String message;
  
  /// Code d'erreur pour identification programmatique
  final String code;
  
  /// Exception originale si applicable
  final Exception? cause;
  
  /// Données contextuelles pour le debug
  final Map<String, dynamic>? context;
  
  const PricingServiceException(
    this.message,
    this.code, {
    this.cause,
    this.context,
  });
  
  @override
  String toString() {
    var str = 'PricingServiceException($code): $message';
    if (cause != null) {
      str += '\nCaused by: $cause';
    }
    if (context != null && context!.isNotEmpty) {
      str += '\nContext: $context';
    }
    return str;
  }
}

/// Codes d'erreur standardisés pour les services de tarification
class PricingServiceErrorCodes {
  static const String invalidCategory = 'INVALID_CATEGORY';
  static const String invalidDistance = 'INVALID_DISTANCE';  
  static const String invalidTime = 'INVALID_TIME';
  static const String configurationError = 'CONFIGURATION_ERROR';
  static const String calculationError = 'CALCULATION_ERROR';
  static const String networkError = 'NETWORK_ERROR';
  static const String cacheError = 'CACHE_ERROR';
  static const String validationError = 'VALIDATION_ERROR';
  static const String serviceUnavailable = 'SERVICE_UNAVAILABLE';
  static const String promoCodeError = 'PROMO_CODE_ERROR';
}