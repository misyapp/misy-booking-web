/// Stub mobile / non-web : aucune opération (pas de cookie navigateur).
class MisySessionBridge {
  static void start() {}
  static Future<bool> handleLogoutDeepLink() async => false;
}
