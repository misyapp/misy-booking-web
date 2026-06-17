import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';

/// Pont d'état de connexion book.misy.app → misy.app via un cookie posé sur
/// le domaine parent `.misy.app`. Le cookie ne contient QUE le prénom (UI),
/// jamais de jeton : il sert uniquement à basculer le header du site vitrine.
class MisySessionBridge {
  static const String _cookieName = 'misy_session';
  static bool _started = false;

  /// Synchronise l'état Firebase → cookie (login / logout). Idempotent.
  static void start() {
    if (_started) return;
    _started = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null || user.isAnonymous) {
        _clear();
      } else {
        _write(_firstName(user));
      }
    });

    // Le prénom n'est disponible qu'une fois le profil Firestore chargé :
    // on rafraîchit le cookie quand `userData` se peuple.
    userData.addListener(() {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null && !u.isAnonymous) _write(_firstName(u));
    });
  }

  /// Traite le deep-link `?logout=1` (déclenché depuis le menu compte de
  /// misy.app) : déconnexion Firebase puis retour sur le site vitrine.
  /// À appeler tôt au boot, après l'init Firebase. Retourne `true` si une
  /// déconnexion a été déclenchée (la page redirige alors vers misy.app et
  /// le reste du boot doit être court-circuité).
  static Future<bool> handleLogoutDeepLink() async {
    if (Uri.base.queryParameters['logout'] != '1') return false;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // On efface le cookie et on redirige même si le signOut échoue.
    }
    _clear();
    html.window.location.href = 'https://misy.app/';
    return true;
  }

  static String _firstName(User user) {
    final n = userData.value?.firstName;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    final d = user.displayName;
    if (d != null && d.trim().isNotEmpty) return d.trim().split(' ').first;
    return '';
  }

  static void _write(String name) {
    html.document.cookie = '$_cookieName=${Uri.encodeComponent(name)}; '
        'domain=.misy.app; path=/; max-age=2592000; samesite=Lax; secure';
  }

  static void _clear() {
    html.document.cookie = '$_cookieName=; '
        'domain=.misy.app; path=/; max-age=0; samesite=Lax; secure';
  }
}
