import '../../functions/print_function.dart';
import 'pricing_service.dart';
import 'pricing_service_v2.dart';
import 'pricing_service_legacy.dart';
import 'pricing_config_service.dart';

/// Sélecteur de système de tarification
/// 
/// Cette classe détermine quel service de tarification utiliser
/// selon la configuration Firestore. Elle permet une migration
/// progressive et contrôlée entre l'ancien et le nouveau système.
/// 
/// La logique de sélection :
/// 1. Récupère la configuration depuis Firestore
/// 2. Vérifie le flag `enableNewPricingSystem`
/// 3. Retourne le service approprié (V1 ou V2)
/// 4. Implémente un fallback vers V1 en cas d'erreur
/// 
/// Exemple d'usage :
/// ```dart
/// // Dans TripProvider ou toute autre classe nécessitant le calcul de prix
/// final pricingService = await PricingSystemSelector.getPricingService();
/// 
/// final result = await pricingService.calculatePrice(
///   vehicleCategory: 'classic',
///   distance: 8.5,
///   requestTime: DateTime.now(),
///   isScheduled: false,
/// );
/// 
/// print('Prix calculé avec ${pricingService.displayName}: ${result.formattedFinalPrice}');
/// ```
class PricingSystemSelector {
  /// Cache du service sélectionné pour éviter les appels répétés
  static IPricingService? _cachedService;
  static DateTime? _cacheExpiry;
  static bool? _lastKnownSystemState;
  
  /// Durée du cache du service sélectionné (2 minutes)
  static const Duration _serviceCacheDuration = Duration(minutes: 2);
  
  /// Statistiques pour monitoring
  static int _selectionCount = 0;
  static int _v1Selections = 0;
  static int _v2Selections = 0;
  static int _fallbackSelections = 0;
  
  /// Obtient le service de tarification approprié selon la configuration
  /// 
  /// Cette méthode est le point d'entrée principal pour obtenir
  /// le service de tarification. Elle gère automatiquement :
  /// - La sélection entre V1 et V2
  /// - Le cache du service sélectionné
  /// - Le fallback en cas d'erreur
  /// 
  /// Retourne une instance d'[IPricingService] (V1 ou V2)
  static Future<IPricingService> getPricingService() async {
    try {
      _selectionCount++;
      
      // Vérifier si le cache est encore valide
      if (_cachedService != null && 
          _cacheExpiry != null && 
          DateTime.now().isBefore(_cacheExpiry!)) {
        myCustomPrintStatement('PricingSystemSelector: Service récupéré du cache (${_cachedService!.displayName})');
        return _cachedService!;
      }
      
      myCustomPrintStatement('PricingSystemSelector: Sélection du système de tarification...');
      
      // Vérifier l'état du nouveau système
      final isNewSystemEnabled = await PricingConfigService.isNewPricingSystemEnabled();
      
      IPricingService selectedService;
      
      if (isNewSystemEnabled) {
        // Nouveau système activé
        myCustomPrintStatement('PricingSystemSelector: Nouveau système de tarification V2 sélectionné');
        selectedService = PricingServiceV2();
        _v2Selections++;
        
        // Vérifier que le service V2 est opérationnel
        if (!(await selectedService.isHealthy())) {
          myCustomPrintStatement(
            'PricingSystemSelector: Service V2 non opérationnel, fallback vers V1',
            showPrint: true,
          );
          selectedService = PricingServiceLegacy();
          _fallbackSelections++;
        }
      } else {
        // Ancien système (comportement par défaut)
        myCustomPrintStatement('PricingSystemSelector: Ancien système de tarification V1 sélectionné');
        selectedService = PricingServiceLegacy();
        _v1Selections++;
      }
      
      // Mettre en cache
      _cachedService = selectedService;
      _cacheExpiry = DateTime.now().add(_serviceCacheDuration);
      _lastKnownSystemState = isNewSystemEnabled;
      
      return selectedService;
      
    } catch (e) {
      myCustomPrintStatement(
        'PricingSystemSelector: Erreur lors de la sélection - $e. Fallback vers V1.',
        showPrint: true,
      );
      
      // En cas d'erreur, toujours utiliser l'ancien système (sécurité)
      _fallbackSelections++;
      final fallbackService = PricingServiceLegacy();
      
      // Mettre en cache le fallback pour éviter les erreurs répétées
      _cachedService = fallbackService;
      _cacheExpiry = DateTime.now().add(_serviceCacheDuration);
      
      return fallbackService;
    }
  }
  
  /// Force la sélection du nouveau système de tarification V2
  /// 
  /// Utilisé principalement pour les tests ou les cas spéciaux
  /// où on veut forcer l'utilisation du nouveau système
  /// indépendamment de la configuration Firestore.
  /// 
  /// ATTENTION: Ignore la configuration Firestore
  static IPricingService forceV2() {
    myCustomPrintStatement('PricingSystemSelector: Système V2 forcé');
    final service = PricingServiceV2();
    
    // Mettre en cache
    _cachedService = service;
    _cacheExpiry = DateTime.now().add(_serviceCacheDuration);
    
    return service;
  }
  
  /// Force la sélection de l'ancien système de tarification V1
  /// 
  /// Utilisé principalement pour les tests ou les cas spéciaux
  /// où on veut forcer l'utilisation de l'ancien système.
  /// 
  /// ATTENTION: Ignore la configuration Firestore
  static IPricingService forceV1() {
    myCustomPrintStatement('PricingSystemSelector: Système V1 forcé');
    final service = PricingServiceLegacy();
    
    // Mettre en cache
    _cachedService = service;
    _cacheExpiry = DateTime.now().add(_serviceCacheDuration);
    
    return service;
  }
  
  /// Invalide le cache et force une nouvelle sélection
  /// 
  /// Utilisé quand la configuration a changé et qu'on veut
  /// s'assurer que le prochain appel à getPricingService()
  /// récupère la configuration la plus récente.
  static void invalidateCache() {
    _cachedService = null;
    _cacheExpiry = null;
    _lastKnownSystemState = null;
    myCustomPrintStatement('PricingSystemSelector: Cache invalidé');
  }
  
  /// Vérifie quel système est actuellement sélectionné
  /// 
  /// Retourne une chaîne décrivant le système actuel :
  /// - "v1" pour l'ancien système
  /// - "v2" pour le nouveau système
  /// - "unknown" si aucun système n'est en cache
  static String getCurrentSystemVersion() {
    if (_cachedService == null) return "unknown";
    return _cachedService!.version == "v2.0" ? "v2" : "v1";
  }
  
  /// Vérifie si le nouveau système est actuellement sélectionné
  /// 
  /// Retourne true si le service en cache est V2
  static bool isUsingNewSystem() {
    return getCurrentSystemVersion() == "v2";
  }
  
  /// Vérifie si l'ancien système est actuellement sélectionné
  /// 
  /// Retourne true si le service en cache est V1
  static bool isUsingLegacySystem() {
    return getCurrentSystemVersion() == "v1";
  }
  
  /// Obtient des informations de diagnostic sur le sélecteur
  /// 
  /// Retourne des statistiques utiles pour le monitoring :
  /// - Système actuellement sélectionné
  /// - Statistiques de sélection
  /// - État du cache
  /// - Informations sur le service actuel
  static Future<Map<String, dynamic>> getDiagnosticInfo() async {
    final diagnosticInfo = <String, dynamic>{
      'selector': {
        'currentSystem': getCurrentSystemVersion(),
        'lastKnownSystemState': _lastKnownSystemState,
        'cacheExpiry': _cacheExpiry?.toIso8601String(),
        'isCacheValid': _cachedService != null && 
                       _cacheExpiry != null && 
                       DateTime.now().isBefore(_cacheExpiry!),
      },
      'statistics': {
        'totalSelections': _selectionCount,
        'v1Selections': _v1Selections,
        'v2Selections': _v2Selections,
        'fallbackSelections': _fallbackSelections,
        'v2AdoptionRate': _selectionCount > 0 
            ? _v2Selections / _selectionCount 
            : 0.0,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Ajouter les informations du service actuel si disponible
    if (_cachedService != null) {
      try {
        final serviceInfo = await _cachedService!.getDiagnosticInfo();
        diagnosticInfo['currentService'] = serviceInfo;
      } catch (e) {
        diagnosticInfo['currentService'] = {
          'error': 'Failed to get service diagnostic info: $e',
        };
      }
    }
    
    return diagnosticInfo;
  }
  
  /// Effectue un test de santé des deux systèmes
  /// 
  /// Vérifie que les services V1 et V2 sont opérationnels.
  /// Utile pour le monitoring et les alertes.
  /// 
  /// Retourne un Map avec l'état de santé de chaque système
  static Future<Map<String, dynamic>> healthCheck() async {
    final results = <String, dynamic>{};
    
    try {
      // Test du service V1
      final v1Service = PricingServiceLegacy();
      results['v1'] = {
        'healthy': await v1Service.isHealthy(),
        'version': v1Service.version,
        'displayName': v1Service.displayName,
      };
    } catch (e) {
      results['v1'] = {
        'healthy': false,
        'error': e.toString(),
      };
    }
    
    try {
      // Test du service V2
      final v2Service = PricingServiceV2();
      results['v2'] = {
        'healthy': await v2Service.isHealthy(),
        'version': v2Service.version,
        'displayName': v2Service.displayName,
      };
    } catch (e) {
      results['v2'] = {
        'healthy': false,
        'error': e.toString(),
      };
    }
    
    // Test de la configuration
    try {
      results['configuration'] = {
        'healthy': await PricingConfigService.healthCheck(),
        'newSystemEnabled': await PricingConfigService.isNewPricingSystemEnabled(),
      };
    } catch (e) {
      results['configuration'] = {
        'healthy': false,
        'error': e.toString(),
      };
    }
    
    // État global
    results['overall'] = {
      'healthy': (results['v1']['healthy'] as bool) && 
                (results['configuration']['healthy'] as bool),
      'recommendedSystem': (results['v2']['healthy'] as bool) ? 'v2' : 'v1',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    return results;
  }
  
  /// Réinitialise toutes les statistiques
  /// 
  /// Utilisé principalement pour les tests et le monitoring
  static void resetStatistics() {
    _selectionCount = 0;
    _v1Selections = 0;
    _v2Selections = 0;
    _fallbackSelections = 0;
    myCustomPrintStatement('PricingSystemSelector: Statistiques réinitialisées');
  }
  
  /// Précharge les services pour améliorer les performances
  /// 
  /// Initialise les caches des services et de la configuration
  /// pour accélérer les premiers calculs de prix.
  /// 
  /// Recommandé d'appeler au démarrage de l'application.
  static Future<void> warmup() async {
    try {
      myCustomPrintStatement('PricingSystemSelector: Préchauffage...');
      
      // Précharger la configuration
      await PricingConfigService.warmupCache();
      
      // Précharger le service sélectionné
      final service = await getPricingService();
      
      // Si c'est le service V2, précharger son cache aussi
      if (service is PricingServiceV2) {
        await service.warmupCache();
      }
      
      myCustomPrintStatement('PricingSystemSelector: Préchauffage terminé');
      
    } catch (e) {
      myCustomPrintStatement(
        'PricingSystemSelector: Erreur lors du préchauffage - $e',
        showPrint: true,
      );
    }
  }
}