/// Capture des paramètres de deep-link au tout début de main(),
/// avant que `usePathUrlStrategy()` + le router Flutter ne nettoient l'URL.
///
/// Problème : par le temps que `home_screen_web.initState` tourne, `Uri.base`
/// et `window.location.href` sont déjà ramenés à `https://book.misy.app/`
/// (les query params sont strippés). Du coup `_readUrlParameters` ne voit rien.
///
/// Usage : `DeepLinkParams.capture()` doit être appelé en TOUTE PREMIÈRE
/// instruction de `main()` (avant `WidgetsFlutterBinding.ensureInitialized()`
/// si possible). Ensuite les écrans lisent `DeepLinkParams.params`.
class DeepLinkParams {
  static Map<String, String> _params = const {};
  static bool _captured = false;

  /// À appeler une fois au démarrage. No-op si déjà capturé (HMR-safe).
  static void capture() {
    if (_captured) return;
    _captured = true;
    try {
      _params = Map<String, String>.from(Uri.base.queryParameters);
      // ignore: avoid_print
      print('🔗 DeepLinkParams.capture: $_params');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ DeepLinkParams.capture failed: $e');
    }
  }

  /// Les params capturés au boot. Vide tant que capture() n'a pas été appelé,
  /// ou si l'URL n'avait pas de query-string.
  static Map<String, String> get params => _params;

  /// Consomme + vide. À utiliser quand le deep-link a été traité,
  /// pour éviter une re-application sur les navigations suivantes.
  static Map<String, String> consume() {
    final p = _params;
    _params = const {};
    return p;
  }

  /// Consomme une clé précise en laissant les autres intactes (ex. retirer
  /// `login`/`signup` une fois la page d'auth affichée, sans toucher aux
  /// éventuels params de pré-remplissage pickup/destination).
  static String? consumeKey(String key) {
    if (!_params.containsKey(key)) return null;
    final mutable = Map<String, String>.from(_params);
    final value = mutable.remove(key);
    _params = mutable;
    return value;
  }
}
