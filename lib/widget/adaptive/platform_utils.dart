import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Utilitaires pour la détection de plateforme et l'adaptation UI
class PlatformUtils {
  /// Retourne true si on est sur iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Retourne true si on est sur Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Retourne true si on est sur le Web
  static bool get isWeb => kIsWeb;

  /// Retourne true si on doit utiliser le style Liquid Glass (iOS uniquement)
  static bool get useLiquidGlass => !kIsWeb && Platform.isIOS;

  /// Retourne true si on doit utiliser le style Material (Android ou Web)
  static bool get useMaterial => kIsWeb || Platform.isAndroid;
}
