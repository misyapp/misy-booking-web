import 'package:cloud_firestore/cloud_firestore.dart';

import '../../functions/print_function.dart';
import '../../models/pricing/pricing_config_v2.dart';

/// Service de gestion de la configuration du système de tarification v2
/// 
/// Responsabilités :
/// - Récupération de la configuration depuis Firestore
/// - Mise à jour de la configuration (pour les administrateurs)
/// - Cache local avec expiration pour optimiser les performances
/// - Fallback vers configuration par défaut en cas d'erreur
/// - Validation des données récupérées
/// 
/// Structure Firestore :
/// Collection: `settings`
/// Document: `pricing_config_v2`
/// 
/// Exemple d'usage :
/// ```dart
/// // Récupération de la configuration
/// final config = await PricingConfigService.getConfig();
/// print('System enabled: ${config.enableNewPricingSystem}');
/// 
/// // Mise à jour de la configuration (admin seulement)
/// final newConfig = config.copyWith(enableNewPricingSystem: true);
/// await PricingConfigService.updateConfig(newConfig);
/// ```
class PricingConfigService {
  /// Collection Firestore pour les paramètres
  static final CollectionReference _settingsCollection =
      FirebaseFirestore.instance.collection('setting');
  
  /// Document spécifique pour la configuration de pricing v2
  static const String _configDocumentId = 'pricing_config_v2';
  
  /// Cache de la configuration
  static PricingConfigV2? _cachedConfig;
  static DateTime? _cacheExpiry;
  
  /// Durée de vie du cache (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  /// Statistiques pour monitoring
  static int _cacheHits = 0;
  static int _cacheMisses = 0;
  static DateTime? _lastFetchTime;
  static String? _lastFetchError;
  
  /// Récupère la configuration du système de tarification
  /// 
  /// Utilise un cache local pour optimiser les performances.
  /// En cas d'erreur, retourne la configuration par défaut.
  /// 
  /// Retourne une instance de [PricingConfigV2]
  /// 
  /// Lève [FirestoreConfigException] en cas d'erreur critique
  static Future<PricingConfigV2> getConfig() async {
    try {
      // Vérifier si le cache est encore valide
      if (_cachedConfig != null && 
          _cacheExpiry != null && 
          DateTime.now().isBefore(_cacheExpiry!)) {
        _cacheHits++;
        myCustomPrintStatement('PricingConfigService: Configuration récupérée du cache');
        return _cachedConfig!;
      }
      
      // Cache expiré ou inexistant, récupérer depuis Firestore
      _cacheMisses++;
      myCustomPrintStatement('PricingConfigService: Récupération depuis Firestore...');
      
      final docSnapshot = await _settingsCollection
          .doc(_configDocumentId)
          .get()
          .timeout(const Duration(seconds: 10));
      
      PricingConfigV2 config;
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        // Document existe, parser les données
        final data = docSnapshot.data() as Map<String, dynamic>;
        config = PricingConfigV2.fromJson(data);
        
        // Valider la configuration récupérée
        if (!config.isValid()) {
          myCustomPrintStatement(
            'PricingConfigService: Configuration Firestore invalide, utilisation de la configuration par défaut',
            showPrint: true,
          );
          config = PricingConfigV2.defaultConfig();
        } else {
          myCustomPrintStatement('PricingConfigService: Configuration Firestore valide récupérée');
        }
      } else {
        // Document n'existe pas, créer la configuration par défaut
        myCustomPrintStatement(
          'PricingConfigService: Document de configuration non trouvé, création de la configuration par défaut',
          showPrint: true,
        );
        config = PricingConfigV2.defaultConfig();
        
        // Sauvegarder la configuration par défaut dans Firestore
        await _createDefaultConfig(config);
      }
      
      // Mettre en cache
      _cachedConfig = config;
      _cacheExpiry = DateTime.now().add(_cacheDuration);
      _lastFetchTime = DateTime.now();
      _lastFetchError = null;
      
      myCustomPrintStatement('PricingConfigService: Configuration mise en cache');
      return config;
      
    } catch (e) {
      _lastFetchError = e.toString();
      _lastFetchTime = DateTime.now();
      
      myCustomPrintStatement(
        'PricingConfigService: Erreur lors de la récupération - $e',
        showPrint: true,
      );
      
      // Si on a une configuration en cache (même expirée), l'utiliser
      if (_cachedConfig != null) {
        myCustomPrintStatement(
          'PricingConfigService: Utilisation de la configuration en cache (expirée) en fallback',
          showPrint: true,
        );
        return _cachedConfig!;
      }
      
      // Dernière option : configuration par défaut
      myCustomPrintStatement(
        'PricingConfigService: Utilisation de la configuration par défaut en fallback',
        showPrint: true,
      );
      
      final defaultConfig = PricingConfigV2.defaultConfig();
      _cachedConfig = defaultConfig;
      return defaultConfig;
    }
  }
  
  /// Met à jour la configuration dans Firestore
  /// 
  /// ATTENTION: Cette méthode devrait être utilisée uniquement par
  /// les administrateurs système. Elle invalide le cache automatiquement.
  /// 
  /// [config] Nouvelle configuration à sauvegarder
  /// 
  /// Lève [FirestoreConfigException] en cas d'erreur
  static Future<void> updateConfig(PricingConfigV2 config) async {
    try {
      // Valider la configuration avant sauvegarde
      if (!config.isValid()) {
        throw FirestoreConfigException(
          'Configuration invalide: impossible de sauvegarder',
          'INVALID_CONFIG',
        );
      }
      
      myCustomPrintStatement('PricingConfigService: Mise à jour de la configuration...');
      
      // Sauvegarder dans Firestore
      await _settingsCollection
          .doc(_configDocumentId)
          .set(config.toJson())
          .timeout(const Duration(seconds: 10));
      
      // Invalider le cache pour forcer le rechargement
      await clearCache();
      
      myCustomPrintStatement('PricingConfigService: Configuration mise à jour avec succès');
      
    } catch (e) {
      myCustomPrintStatement(
        'PricingConfigService: Erreur lors de la mise à jour - $e',
        showPrint: true,
      );
      
      if (e is FirestoreConfigException) {
        rethrow;
      }
      
      throw FirestoreConfigException(
        'Erreur lors de la sauvegarde: ${e.toString()}',
        'SAVE_ERROR',
        cause: e,
      );
    }
  }
  
  /// Crée la configuration par défaut dans Firestore
  /// 
  /// Utilisé lors de la première initialisation ou si le document
  /// de configuration n'existe pas.
  static Future<void> _createDefaultConfig(PricingConfigV2 config) async {
    try {
      myCustomPrintStatement('PricingConfigService: Création de la configuration par défaut dans Firestore...');
      
      await _settingsCollection
          .doc(_configDocumentId)
          .set(config.toJson())
          .timeout(const Duration(seconds: 10));
      
      myCustomPrintStatement('PricingConfigService: Configuration par défaut créée avec succès');
      
    } catch (e) {
      // Ne pas lancer d'exception ici car ce n'est pas critique
      // La configuration par défaut fonctionne même sans être sauvegardée
      myCustomPrintStatement(
        'PricingConfigService: Impossible de créer la configuration par défaut dans Firestore - $e',
        showPrint: true,
      );
    }
  }
  
  /// Vide le cache de configuration
  /// 
  /// Force le rechargement depuis Firestore lors du prochain appel à getConfig()
  static Future<void> clearCache() async {
    _cachedConfig = null;
    _cacheExpiry = null;
    myCustomPrintStatement('PricingConfigService: Cache vidé');
  }
  
  /// Précharge la configuration dans le cache
  /// 
  /// Utile à appeler au démarrage de l'application pour améliorer
  /// les performances du premier calcul de prix
  static Future<void> warmupCache() async {
    await getConfig();
    myCustomPrintStatement('PricingConfigService: Cache préchauffé');
  }
  
  /// Vérifie si le nouveau système de tarification est activé
  /// 
  /// Méthode de convenance qui récupère la configuration et 
  /// retourne directement le flag d'activation.
  /// 
  /// Retourne false en cas d'erreur (fallback sécurisé)
  static Future<bool> isNewPricingSystemEnabled() async {
    try {
      final config = await getConfig();
      return config.enableNewPricingSystem;
    } catch (e) {
      myCustomPrintStatement(
        'PricingConfigService: Erreur lors de la vérification du flag - $e',
        showPrint: true,
      );
      return false; // Fallback sécurisé : utiliser l'ancien système
    }
  }
  
  /// Active ou désactive le nouveau système de tarification
  /// 
  /// Méthode de convenance pour basculer entre les systèmes
  /// sans avoir à manipuler toute la configuration.
  /// 
  /// [enabled] True pour activer le nouveau système, false pour l'ancien
  static Future<void> setNewPricingSystemEnabled(bool enabled) async {
    final config = await getConfig();
    final updatedConfig = config.copyWith(enableNewPricingSystem: enabled);
    await updateConfig(updatedConfig);
    
    myCustomPrintStatement(
      'PricingConfigService: Nouveau système ${enabled ? "activé" : "désactivé"}',
      showPrint: true,
    );
  }
  
  /// Obtient des statistiques sur l'utilisation du service
  /// 
  /// Retourne des métriques utiles pour le monitoring :
  /// - Statistiques de cache
  /// - Dernière récupération
  /// - Erreurs éventuelles
  static Map<String, dynamic> getStats() {
    return {
      'cache': {
        'hits': _cacheHits,
        'misses': _cacheMisses,
        'hitRate': _cacheHits + _cacheMisses > 0
            ? _cacheHits / (_cacheHits + _cacheMisses)
            : 0.0,
        'isCached': _cachedConfig != null,
        'expiry': _cacheExpiry?.toIso8601String(),
      },
      'firestore': {
        'lastFetchTime': _lastFetchTime?.toIso8601String(),
        'lastError': _lastFetchError,
        'collectionPath': _settingsCollection.path,
        'documentId': _configDocumentId,
      },
      'config': {
        'version': _cachedConfig?.version,
        'enabled': _cachedConfig?.enableNewPricingSystem,
        'valid': _cachedConfig?.isValid(),
      },
    };
  }
  
  /// Effectue un test de santé du service
  /// 
  /// Vérifie :
  /// - La connectivité à Firestore
  /// - La validité de la configuration
  /// - Le bon fonctionnement du cache
  /// 
  /// Retourne true si tout fonctionne correctement
  static Future<bool> healthCheck() async {
    try {
      // Tester la récupération de configuration
      final config = await getConfig();
      
      // Vérifier que la configuration est valide
      if (!config.isValid()) {
        myCustomPrintStatement('PricingConfigService: Health check failed - configuration invalide');
        return false;
      }
      
      // Tester l'accès à Firestore (sans modifier les données)
      await _settingsCollection
          .doc(_configDocumentId)
          .get()
          .timeout(const Duration(seconds: 5));
      
      myCustomPrintStatement('PricingConfigService: Health check réussi');
      return true;
      
    } catch (e) {
      myCustomPrintStatement('PricingConfigService: Health check failed - $e', showPrint: true);
      return false;
    }
  }
  
  /// Réinitialise les statistiques de cache
  /// 
  /// Utile pour le monitoring et les tests
  static void resetStats() {
    _cacheHits = 0;
    _cacheMisses = 0;
    _lastFetchTime = null;
    _lastFetchError = null;
  }
}

/// Exception spécifique pour les erreurs de configuration Firestore
class FirestoreConfigException implements Exception {
  /// Message d'erreur descriptif
  final String message;
  
  /// Code d'erreur pour identification programmatique
  final String code;
  
  /// Exception originale si applicable
  final dynamic cause;
  
  const FirestoreConfigException(this.message, this.code, {this.cause});
  
  @override
  String toString() {
    var str = 'FirestoreConfigException($code): $message';
    if (cause != null) {
      str += '\nCaused by: $cause';
    }
    return str;
  }
}

/// Codes d'erreur pour FirestoreConfigException
class FirestoreConfigErrorCodes {
  static const String invalidConfig = 'INVALID_CONFIG';
  static const String saveError = 'SAVE_ERROR';
  static const String fetchError = 'FETCH_ERROR';
  static const String networkError = 'NETWORK_ERROR';
  static const String permissionError = 'PERMISSION_ERROR';
  static const String timeoutError = 'TIMEOUT_ERROR';
}