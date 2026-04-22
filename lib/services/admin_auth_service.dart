import 'package:firebase_auth/firebase_auth.dart';

/// Lecture des custom claims `transport_editor` et `transport_admin` posés
/// via les scripts Node. Sert de gate pour l'éditeur terrain et pour l'UI
/// admin review. Un compte admin cumule les deux claims.
class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  bool? _cachedEditor;
  bool? _cachedAdmin;

  /// True si le user connecté a le claim `transport_editor=true`.
  /// [forceRefresh] relance un getIdTokenResult(true) — utile après un login
  /// qui vient d'être re-authentifié côté Auth.
  Future<bool> isTransportEditor({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedEditor != null) return _cachedEditor!;
    await _refresh(forceRefresh);
    return _cachedEditor ?? false;
  }

  /// True si le user connecté a le claim `transport_admin=true`.
  Future<bool> isTransportAdmin({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedAdmin != null) return _cachedAdmin!;
    await _refresh(forceRefresh);
    return _cachedAdmin ?? false;
  }

  Future<void> _refresh(bool forceRefresh) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cachedEditor = false;
      _cachedAdmin = false;
      return;
    }
    try {
      final token = await user.getIdTokenResult(forceRefresh);
      _cachedEditor = token.claims?['transport_editor'] == true;
      _cachedAdmin = token.claims?['transport_admin'] == true;
    } catch (_) {
      _cachedEditor = false;
      _cachedAdmin = false;
    }
  }

  /// Invalide le cache (logout, changement d'user).
  void invalidate() {
    _cachedEditor = null;
    _cachedAdmin = null;
  }

  /// Stream pratique pour UI réactive (listen aux auth state changes).
  Stream<bool> isTransportEditorStream() async* {
    await for (final user in FirebaseAuth.instance.authStateChanges()) {
      invalidate();
      if (user == null) {
        yield false;
        continue;
      }
      yield await isTransportEditor(forceRefresh: true);
    }
  }

  Stream<bool> isTransportAdminStream() async* {
    await for (final user in FirebaseAuth.instance.authStateChanges()) {
      invalidate();
      if (user == null) {
        yield false;
        continue;
      }
      yield await isTransportAdmin(forceRefresh: true);
    }
  }

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get currentEmail => FirebaseAuth.instance.currentUser?.email;
}
