import 'package:firebase_auth/firebase_auth.dart';

/// Lecture du custom claim `transport_editor` posé via
/// `scripts/create_transport_editor_user.js`. Sert de gate unique pour
/// l'accès à l'éditeur terrain (/transport-editor).
class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  bool? _cached;

  /// True si le user connecté a le claim `transport_editor=true`.
  /// [forceRefresh] relance un getIdTokenResult(true) — utile après un login
  /// qui vient d'être re-authentifié côté Auth.
  Future<bool> isTransportEditor({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cached = false;
      return false;
    }

    try {
      final token = await user.getIdTokenResult(forceRefresh);
      final claim = token.claims?['transport_editor'];
      _cached = claim == true;
      return _cached!;
    } catch (_) {
      _cached = false;
      return false;
    }
  }

  /// Invalide le cache (logout, changement d'user).
  void invalidate() {
    _cached = null;
  }

  /// Stream pratique pour UI réactive (listen aux auth state changes).
  Stream<bool> isTransportEditorStream() async* {
    await for (final user in FirebaseAuth.instance.authStateChanges()) {
      _cached = null;
      if (user == null) {
        yield false;
        continue;
      }
      yield await isTransportEditor(forceRefresh: true);
    }
  }

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get currentEmail => FirebaseAuth.instance.currentUser?.email;
}
