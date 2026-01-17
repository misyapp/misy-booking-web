import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';

class FeatureToggleService {
  static FeatureToggleService? _instance;
  static FeatureToggleService get instance {
    _instance ??= FeatureToggleService._();
    return _instance!;
  }
  FeatureToggleService._();

  /// Vérifie si la fonctionnalité portefeuille numérique est activée
  /// Retourne false par défaut (masqué) pour plus de sécurité
  bool isDigitalWalletEnabled() {
    try {
      // Récupérer le contexte depuis la clé globale
      final context = MyGlobalKeys.navigatorKey.currentContext;
      if (context == null) {
        // Fallback sécurisé : masquer par défaut
        return false;
      }

      // Récupérer le provider des paramètres admin
      final adminProvider = Provider.of<AdminSettingsProvider>(context, listen: false);
      
      // Retourner la valeur du flag avec fallback false
      return adminProvider.defaultAppSettingModal.digitalWalletEnabled;
    } catch (e) {
      // En cas d'erreur, masquer par sécurité
      return false;
    }
  }

  /// Vérifie si le paiement par carte bancaire est activé
  /// Retourne false par défaut (masqué) pour plus de sécurité
  bool isCreditCardPaymentEnabled() {
    try {
      // Récupérer le contexte depuis la clé globale
      final context = MyGlobalKeys.navigatorKey.currentContext;
      if (context == null) {
        // Fallback sécurisé : masquer par défaut
        return false;
      }

      // Récupérer le provider des paramètres admin
      final adminProvider = Provider.of<AdminSettingsProvider>(context, listen: false);
      
      // Retourner la valeur du flag avec fallback false
      return adminProvider.defaultAppSettingModal.creditCardPaymentEnabled;
    } catch (e) {
      // En cas d'erreur, masquer par sécurité
      return false;
    }
  }

  /// Méthode utilitaire pour d'autres features futures
  bool isFeatureEnabled(String featureName) {
    switch (featureName) {
      case 'digitalWallet':
        return isDigitalWalletEnabled();
      case 'creditCardPayment':
        return isCreditCardPaymentEnabled();
      default:
        return false;
    }
  }
}