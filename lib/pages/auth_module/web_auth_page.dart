import 'dart:async';
import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/web_auth_screen.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/utils/deep_link_params.dart';

/// Page d'auth **autonome et légère** pour le deep-link `?login=1|signup=1`
/// (CTA "Connexion"/"S'inscrire" de beta.misy.app).
///
/// Poussée directement par le splash, AVANT le `splashAuthentication` lourd
/// (login anonyme, settings Firestore, géozones, home + carte) : l'utilisateur
/// voit la carte d'auth dès que le moteur Flutter est chargé, au lieu d'un
/// écran blanc de plusieurs secondes.
///
/// Mécanique post-auth : un mini-listener local attend un **vrai** compte
/// (non anonyme, hors flow social en cours — les flows sociaux naviguent
/// eux-mêmes) puis arme le listener global `setAuthListener`, qui traite
/// l'utilisateur courant à l'abonnement (userModal, vérif phoneNo,
/// navigation Main/PhoneNumber). Un utilisateur DÉJÀ connecté qui ouvre
/// ?login=1 est ainsi redirigé vers la home automatiquement.
class WebAuthPage extends StatefulWidget {
  final WebAuthMode initialMode;
  const WebAuthPage({super.key, this.initialMode = WebAuthMode.login});

  @override
  State<WebAuthPage> createState() => _WebAuthPageState();
}

class _WebAuthPageState extends State<WebAuthPage> {
  StreamSubscription<User?>? _authSub;
  bool _delegated = false;

  @override
  void initState() {
    super.initState();

    // Deep-link traité : retirer login/signup pour que HomeScreenWeb ne
    // rouvre pas le dialog après navigation (les éventuels params
    // pickup/destination restent intacts).
    DeepLinkParams.consumeKey('login');
    DeepLinkParams.consumeKey('signup');

    // Firestore exige un utilisateur authentifié (règles) pour les requêtes
    // de la carte d'auth (vérif téléphone/email existants). Si aucune session
    // n'est restaurée, créer l'anonyme en arrière-plan — sans bloquer l'UI.
    if (FirebaseAuth.instance.currentUser == null) {
      FirebaseAuth.instance.signInAnonymously().then((cred) {
        myCustomPrintStatement(
            '🎭 WebAuthPage: anonyme de service créé ${cred.user?.uid}');
      }).catchError((e) {
        myCustomPrintStatement('⚠️ WebAuthPage: signInAnonymously: $e');
      });
    }

    // Settings réels (enableOTPVerification…) en arrière-plan : le chemin
    // rapide saute splashAuthentication, donc globalSettings est encore aux
    // valeurs par défaut. Le temps de remplir le formulaire, c'est chargé.
    FirestoreServices.getAndSetSettings();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (_delegated || !mounted) return;
      // On attend un vrai compte — l'anonyme de service ne compte pas.
      if (user == null || user.isAnonymous) return;
      // Les flows sociaux gèrent leur propre navigation (flags globaux).
      if (isGoogleSignInInProgress ||
          isFacebookSignInInProgress ||
          isAppleSignInInProgress) {
        return;
      }
      _delegated = true;
      _authSub?.cancel();
      // Délègue toute la suite au listener global : il traite immédiatement
      // l'utilisateur courant (userModal, phoneNo manquant → PhoneNumberScreen,
      // sinon MainNavigationScreen) et reste armé pour la session.
      myCustomPrintStatement(
          '✅ WebAuthPage: vrai compte détecté → délégation à setAuthListener');
      Provider.of<CustomAuthProvider>(context, listen: false)
          .setAuthListener(context);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWebPageBackground,
      body: WebAuthScreen(
        initialMode: widget.initialMode,
        // Croix = aller à la home complète (boot normal via reload — l'app
        // n'a pas encore fait son splashAuthentication sur ce chemin).
        onClose: () => html.window.location.assign('/'),
      ),
    );
  }
}
