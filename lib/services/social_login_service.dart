import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/user_social_login_detail_modal.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/phone_number_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

class SocialLoginServices {
  /// Downstream commun aux connexions sociales WEB (book.misy.app) : crée ou
  /// met à jour le compte Firestore puis navigue. Sur le web, Google/Facebook
  /// passent par `signInWithPopup` (les plugins natifs ne marchent pas en
  /// navigateur) — ce helper reprend la logique d'origine à partir du
  /// `UserCredential` obtenu. Le chemin natif iOS/Android reste inchangé.
  Future<UserSocialLoginDeatilModal?> _finalizeWebSocialLogin(
    UserCredential authResult,
    String type,
    void Function(bool) setFlag,
  ) async {
    final user = authResult.user;
    if (user == null) {
      setFlag(false);
      hideLoading();
      return null;
    }

    final fullName = user.displayName ?? '';
    final userSnapshot = await FirestoreServices.users.doc(user.uid).get();
    final customAuthProvider = Provider.of<CustomAuthProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false);

    if (userSnapshot.exists == false) {
      final request = {
        'id': user.uid,
        'name': fullName,
        'lastName': fullName.isEmpty ? '' : fullName.split(" ").last,
        'firstName': fullName.isEmpty ? '' : fullName.split(" ").first,
        'email': user.email ?? '',
        "verified": true,
        "isBlocked": false,
        "accountDeleted": false,
        "isCustomer": true,
        'phoneNo': "",
        "countryName": "United States",
        'password': user.uid,
        'profileImage': user.photoURL ?? dummyUserImage,
      };
      await customAuthProvider.signup(
        MyGlobalKeys.navigatorKey.currentContext!,
        request,
        socialLogin: true,
      );
      await customAuthProvider.clearGuestDataOnly();
      customAuthProvider.currentUser = user;
      await customAuthProvider.getAndUpdateUserModal(showLoader: false);
      hideLoading();
      // Tout nouveau compte → renseigner le numéro de téléphone.
      pushAndRemoveUntil(
        context: MyGlobalKeys.navigatorKey.currentContext!,
        screen: const PhoneNumberScreen(),
      );
      setFlag(false);
    } else {
      await customAuthProvider.clearGuestDataOnly();
      customAuthProvider.currentUser = user;
      await customAuthProvider.getAndUpdateUserModal();
      hideLoading();
      final userPhoneNo = userData.value?.phoneNo;
      final hasPhoneNumber = userPhoneNo != null && userPhoneNo.isNotEmpty;
      pushAndRemoveUntil(
        context: MyGlobalKeys.navigatorKey.currentContext!,
        screen: hasPhoneNumber
            ? const MainNavigationScreen()
            : const PhoneNumberScreen(),
      );
      setFlag(false);
    }

    return UserSocialLoginDeatilModal(
      socialLoginId: user.uid,
      emailId: user.email ?? '',
      userName: user.displayName ?? '',
    );
  }

  Future<UserSocialLoginDeatilModal?> signInWithGoogle() async {
    showHomePageMenuNoti.value = true;
    final firebaseAuth = FirebaseAuth.instance;
    try {
      myCustomPrintStatement('🔵 Début connexion Google...');

      // Activer le flag pour bloquer les navigations du listener
      isGoogleSignInInProgress = true;
      myCustomPrintStatement('🚫 Google Sign-In en cours - navigation listener bloquée');

      // Sauvegarder l'état de l'utilisateur actuel AVANT la connexion Google
      final currentUser = firebaseAuth.currentUser;
      final wasAnonymous = currentUser?.isAnonymous ?? false;
      myCustomPrintStatement('🔍 État avant connexion: wasAnonymous=$wasAnonymous, currentUser=${currentUser?.uid}');

      // ⚡ FIX: Ne SE DÉCONNECTER que si c'est un utilisateur anonyme
      // Si l'utilisateur est déjà connecté avec un compte Google, on ne fait RIEN
      if (currentUser != null && wasAnonymous) {
        myCustomPrintStatement('🔄 Déconnexion de l\'utilisateur anonyme');
        await firebaseAuth.signOut();
        await Future.delayed(Duration(milliseconds: 300));
      } else if (currentUser != null && !wasAnonymous) {
        myCustomPrintStatement('ℹ️ Utilisateur déjà connecté - pas de déconnexion');
      }

      // Web (book.misy.app) : le plugin google_sign_in ne fonctionne pas en
      // navigateur (token null) → flux Firebase popup, comme Apple.
      if (kIsWeb) {
        final provider = GoogleAuthProvider()..addScope('email');
        final authResult = await firebaseAuth.signInWithPopup(provider);
        await showLoading();
        return await _finalizeWebSocialLogin(
            authResult, 'Google', (v) => isGoogleSignInInProgress = v);
      }

      GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: Platform.isIOS
              ? "1062917624003-hadjqukpk8cmpi4go5l0kq17l63fja55.apps.googleusercontent.com"
              : null);
      myCustomPrintStatement('🔵 GoogleSignIn instance créée');

      // ⚡ FIX: Déconnecter Google Sign-In pour forcer l'affichage du sélecteur de comptes
      // Cela permet à l'utilisateur de choisir parmi plusieurs comptes Google
      await googleSignIn.signOut();
      myCustomPrintStatement('🔄 Google Sign-In déconnecté pour afficher le sélecteur de comptes');

      GoogleSignInAccount? googleAccount = await googleSignIn.signIn();
      myCustomPrintStatement('🔵 Google Account sélectionné: $googleAccount');

      if (googleAccount != null) {
        // ⚡ FIX: Afficher le loading dès que l'utilisateur sélectionne son compte
        // pour donner un feedback visuel immédiat
        await showLoading();
        myCustomPrintStatement('⏳ Loading affiché après sélection du compte Google');

        myCustomPrintStatement('✅ Compte Google valide, récupération des credentials...');
        GoogleSignInAuthentication googleAuth =
            await googleAccount.authentication;

        // ⚡ FIX: GARDER le flag actif pendant tout le processus
        // Le listener reste bloqué jusqu'à ce que la navigation soit complète
        myCustomPrintStatement('🔒 Flag Google Sign-In reste actif pendant signInWithCredential');

        final authResult = await firebaseAuth.signInWithCredential(
          GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
            accessToken: googleAuth.accessToken,
          ),
        );

        // return _userFromFirebase(authResult.user);
        myCustomPrintStatement(
            'the user data is ${authResult.user!.providerData}');
        Map<String, dynamic> data = {
          'uid': authResult.user?.uid,
          'name': authResult.user?.displayName,
          'email': authResult.user?.email ?? '',
          'type': 'Google'
          // 'fname':authResult.additionalUserInfo.
        };

        myCustomPrintStatement('google login successfully-------------- $data');
        Map<String, dynamic> request = {
          'email': authResult.user?.email ?? '',
          'google_id': authResult.user?.uid
        };
        myCustomPrintStatement("request data is $request");
        final DocumentSnapshot userSnapshot =
            await FirestoreServices.users.doc(authResult.user?.uid).get();
        CustomAuthProvider customAuthProvider = Provider.of<CustomAuthProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);

        if (userSnapshot.exists == false) {
          // Nouveau utilisateur - créer le compte
          Map<String, dynamic> request = {
            'id': authResult.user?.uid,
            'name': authResult.user?.displayName,
            'lastName': authResult.user?.displayName!.split(" ").last,
            'firstName': authResult.user?.displayName!.split(" ").first,
            'email': authResult.user?.email,
            "verified": true,
            "isBlocked": false,
            "accountDeleted": false,
            "isCustomer": true,
            'phoneNo': "",
            "countryName": "United States",
            'password': authResult.user?.uid,
            'profileImage': authResult.user?.photoURL ?? dummyUserImage
          };

          await customAuthProvider.signup(
            MyGlobalKeys.navigatorKey.currentContext!,
            request,
            socialLogin: true,
          );

          // ⚡ Nettoyer uniquement les données invité (sans supprimer l'utilisateur Firebase)
          await customAuthProvider.clearGuestDataOnly();

          // ⚡ FIX CRITIQUE: Mettre à jour currentUser et charger userData.value AVANT navigation
          // Sans cela, userData.value est null sur PhoneNumberScreen et cause une erreur
          customAuthProvider.currentUser = authResult.user;
          await customAuthProvider.getAndUpdateUserModal(showLoader: false);
          myCustomPrintStatement('✅ userData.value initialisé pour nouveau compte: ${authResult.user?.uid}');

          hideLoading();

          // ⚡ Navigation SYSTÉMATIQUE vers PhoneNumberScreen pour TOUS les nouveaux comptes
          pushAndRemoveUntil(
            context: MyGlobalKeys.navigatorKey.currentContext!,
            screen: const PhoneNumberScreen(),
          );

          // ✅ Désactiver le flag APRÈS la navigation complète
          isGoogleSignInInProgress = false;
          myCustomPrintStatement("✅ Nouveau compte créé - Navigation SYSTÉMATIQUE vers PhoneNumberScreen - Flag désactivé");
        } else {
          // ⚡ FIX: Si l'utilisateur était déjà connecté avec ce compte,
          // Firebase ne déclenchera PAS authStateChanges(), donc on doit juste mettre à jour les données
          // ⚡ Nettoyer uniquement les données invité (sans supprimer l'utilisateur Firebase)
          await customAuthProvider.clearGuestDataOnly();

          // ⚡ FIX CRITIQUE: Mettre à jour currentUser AVANT d'appeler getAndUpdateUserModal()
          // Sans cela, getAndUpdateUserModal() essaie d'accéder à currentUser!.uid qui est null
          customAuthProvider.currentUser = authResult.user;
          myCustomPrintStatement('✅ currentUser mis à jour: ${authResult.user?.uid}');

          // 🔍 DEBUG: Vérifier les données Firestore AVANT getAndUpdateUserModal
          final firestoreDoc = await FirestoreServices.users.doc(authResult.user?.uid).get();
          if (firestoreDoc.exists) {
            final firestoreData = firestoreDoc.data() as Map<String, dynamic>;
            myCustomPrintStatement('🔍 DEBUG Firestore AVANT getAndUpdateUserModal:');
            myCustomPrintStatement('   - phoneNo: ${firestoreData['phoneNo']}');
            myCustomPrintStatement('   - countryCode: ${firestoreData['countryCode']}');
            myCustomPrintStatement('   - countryName: ${firestoreData['countryName']}');
          } else {
            myCustomPrintStatement('⚠️ DEBUG: Document Firestore n\'existe PAS pour ${authResult.user?.uid}');
          }

          // ⚡ FIX: Navigation directe SANS attendre le listener
          // Cela évite la double navigation qui cause le GlobalKey dupliqué
          await customAuthProvider.getAndUpdateUserModal();
          hideLoading();

          // 🔍 DEBUG: Vérifier userData.value APRÈS getAndUpdateUserModal
          myCustomPrintStatement('🔍 DEBUG userData.value APRÈS getAndUpdateUserModal:');
          myCustomPrintStatement('   - phoneNo: ${userData.value?.phoneNo}');
          myCustomPrintStatement('   - phone (raw): ${userData.value?.phone}');
          myCustomPrintStatement('   - countryCode: ${userData.value?.countryCode}');
          myCustomPrintStatement('   - countryName: ${userData.value?.countryName}');

          // ⚡ FIX: Vérifier si l'utilisateur a déjà un numéro de téléphone
          // Si phoneNo est vide/null → demander le numéro
          // Si phoneNo existe → navigation directe vers l'accueil
          final userPhoneNo = userData.value?.phoneNo;
          final bool hasPhoneNumber = userPhoneNo != null && userPhoneNo.isNotEmpty;

          if (hasPhoneNumber) {
            // ✅ Utilisateur existant avec numéro de téléphone → MainNavigationScreen
            myCustomPrintStatement("✅ Utilisateur existant avec numéro ($userPhoneNo) - Navigation vers MainNavigationScreen");
            pushAndRemoveUntil(
              context: MyGlobalKeys.navigatorKey.currentContext!,
              screen: const MainNavigationScreen(),
            );
          } else {
            // ⚠️ Utilisateur existant SANS numéro de téléphone → PhoneNumberScreen
            myCustomPrintStatement("⚠️ Utilisateur existant SANS numéro - Navigation vers PhoneNumberScreen");
            pushAndRemoveUntil(
              context: MyGlobalKeys.navigatorKey.currentContext!,
              screen: const PhoneNumberScreen(),
            );
          }

          // ✅ Désactiver le flag APRÈS la navigation complète
          isGoogleSignInInProgress = false;
          myCustomPrintStatement("✅ Navigation terminée - Flag désactivé");
        }

        return UserSocialLoginDeatilModal(
            socialLoginId: authResult.user!.uid,
            emailId: authResult.user!.email!,
            userName: authResult.user!.displayName!);
      } else {
        myCustomPrintStatement("⚠️ Connexion Google annulée par l'utilisateur ou compte null");
        isGoogleSignInInProgress = false; // ⚡ FIX: Réactiver en cas d'annulation
        hideLoading();
        return null;
      }
    } catch (e) {
      myCustomPrintStatement("❌ Error during Google sign-in: $e");
      isGoogleSignInInProgress = false; // Réactiver en cas d'erreur
      hideLoading();
      showSnackbar("Erreur lors de la connexion Google: ${e.toString()}");
      return null;
    }
  }

  Future<UserSocialLoginDeatilModal?> facebookLogin() async {
    showHomePageMenuNoti.value = true;
    final firebaseAuth = FirebaseAuth.instance;

    try {
      myCustomPrintStatement('🔵 Début connexion Facebook...');

      // Activer le flag pour bloquer les navigations du listener
      isFacebookSignInInProgress = true;
      myCustomPrintStatement('🚫 Facebook Sign-In en cours - navigation listener bloquée');

      // Sauvegarder l'état de l'utilisateur actuel AVANT la connexion Facebook
      final currentUser = firebaseAuth.currentUser;
      final wasAnonymous = currentUser?.isAnonymous ?? false;
      myCustomPrintStatement('🔍 État avant connexion: wasAnonymous=$wasAnonymous, currentUser=${currentUser?.uid}');

      // Déconnecter l'utilisateur anonyme si nécessaire
      if (currentUser != null && wasAnonymous) {
        myCustomPrintStatement('🔄 Déconnexion de l\'utilisateur anonyme');
        await firebaseAuth.signOut();
        await Future.delayed(Duration(milliseconds: 300));
      } else if (currentUser != null && !wasAnonymous) {
        myCustomPrintStatement('ℹ️ Utilisateur déjà connecté - pas de déconnexion');
      }

      // Web (book.misy.app) : flutter_facebook_auth exige le SDK JS (window.FB)
      // → flux Firebase popup à la place, comme Apple.
      if (kIsWeb) {
        final provider = FacebookAuthProvider()
          ..addScope('email')
          ..addScope('public_profile');
        final authResult = await firebaseAuth.signInWithPopup(provider);
        await showLoading();
        return await _finalizeWebSocialLogin(
            authResult, 'Facebook', (v) => isFacebookSignInInProgress = v);
      }

      // Create an instance of FacebookLogin
      final fb = FacebookAuth.instance;
      await fb.logOut();
      myCustomPrintStatement('🔄 Facebook Auth déconnecté pour forcer nouvelle authentification');

      final rawNonce = generateNonce();

      final res = await fb.login(
          loginTracking: LoginTracking.enabled,
          permissions: ["public_profile", "email"]);

      myCustomPrintStatement('🔵 Facebook login result: ${res.status}');

      // Check result status
      if (res.status == LoginStatus.success) {
        // ⚡ FIX: Afficher le loading dès que l'utilisateur se connecte avec Facebook
        // pour donner un feedback visuel immédiat
        await showLoading();
        myCustomPrintStatement('⏳ Loading affiché après connexion Facebook');

        final AccessToken? accessToken = res.accessToken;

        myCustomPrintStatement('✅ Token Facebook reçu: ${accessToken?.tokenString?.substring(0, 20)}...');
        myCustomPrintStatement('🔵 Token type: ${res.accessToken?.type}');

        late OAuthCredential credential;
        if (Platform.isIOS) {
          switch (res.accessToken!.type) {
            case AccessTokenType.classic:
              credential = FacebookAuthProvider.credential(
                accessToken!.tokenString!,
              );
              break;
            case AccessTokenType.limited:
              credential = OAuthCredential(
                providerId: 'facebook.com',
                signInMethod: 'oauth',
                idToken: accessToken!.tokenString,
                rawNonce: rawNonce,
              );
              break;
          }
        } else {
          credential = FacebookAuthProvider.credential(accessToken!.tokenString);
        }

        // ⚡ FIX: GARDER le flag actif pendant tout le processus
        // Le listener reste bloqué jusqu'à ce que la navigation soit complète
        myCustomPrintStatement('🔒 Flag Facebook Sign-In reste actif pendant signInWithCredential');

        // Sign in the user with Firebase
        final UserCredential userCredential =
            await firebaseAuth.signInWithCredential(credential);

        final profile = await fb.getUserData();
        myCustomPrintStatement("✅ Profil Facebook: ${profile['name']}");

        final DocumentSnapshot userSnapshot =
            await FirestoreServices.users.doc(userCredential.user?.uid).get();
        CustomAuthProvider customAuthProvider = Provider.of<CustomAuthProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);

        if (userSnapshot.exists == false) {
          // Nouveau utilisateur - créer le compte
          Map<String, dynamic> request = {
            'id': userCredential.user?.uid,
            'name': profile["name"] ?? userCredential.user?.displayName,
            'lastName': (profile["name"] ?? userCredential.user?.displayName ?? '').split(" ").last,
            'firstName': (profile["name"] ?? userCredential.user?.displayName ?? '').split(" ").first,
            'email': profile["email"] ?? userCredential.user?.email ?? '',
            "verified": true,
            "isBlocked": false,
            "accountDeleted": false,
            "isCustomer": true,
            'phoneNo': "",
            "countryName": "United States",
            'password': userCredential.user?.uid,
            'profileImage': userCredential.user?.photoURL ?? dummyUserImage
          };

          await customAuthProvider.signup(
            MyGlobalKeys.navigatorKey.currentContext!,
            request,
            socialLogin: true,
          );

          // ⚡ Nettoyer uniquement les données invité (sans supprimer l'utilisateur Firebase)
          await customAuthProvider.clearGuestDataOnly();

          // ⚡ FIX CRITIQUE: Mettre à jour currentUser et charger userData.value AVANT navigation
          // Sans cela, userData.value est null sur PhoneNumberScreen et cause une erreur
          customAuthProvider.currentUser = userCredential.user;
          await customAuthProvider.getAndUpdateUserModal(showLoader: false);
          myCustomPrintStatement('✅ userData.value initialisé pour nouveau compte: ${userCredential.user?.uid}');

          hideLoading();

          // ⚡ Navigation SYSTÉMATIQUE vers PhoneNumberScreen pour TOUS les nouveaux comptes
          pushAndRemoveUntil(
            context: MyGlobalKeys.navigatorKey.currentContext!,
            screen: const PhoneNumberScreen(),
          );

          // ✅ Désactiver le flag APRÈS la navigation complète
          isFacebookSignInInProgress = false;
          myCustomPrintStatement("✅ Nouveau compte créé - Navigation SYSTÉMATIQUE vers PhoneNumberScreen - Flag désactivé");
        } else {
          // ⚡ Nettoyer uniquement les données invité (sans supprimer l'utilisateur Firebase)
          await customAuthProvider.clearGuestDataOnly();

          // ⚡ FIX CRITIQUE: Mettre à jour currentUser AVANT d'appeler getAndUpdateUserModal()
          // Sans cela, getAndUpdateUserModal() essaie d'accéder à currentUser!.uid qui est null
          customAuthProvider.currentUser = userCredential.user;
          myCustomPrintStatement('✅ currentUser mis à jour: ${userCredential.user?.uid}');

          // 🔍 DEBUG: Vérifier les données Firestore AVANT getAndUpdateUserModal
          final firestoreDoc = await FirestoreServices.users.doc(userCredential.user?.uid).get();
          if (firestoreDoc.exists) {
            final firestoreData = firestoreDoc.data() as Map<String, dynamic>;
            myCustomPrintStatement('🔍 DEBUG Firestore AVANT getAndUpdateUserModal (Facebook):');
            myCustomPrintStatement('   - phoneNo: ${firestoreData['phoneNo']}');
            myCustomPrintStatement('   - countryCode: ${firestoreData['countryCode']}');
            myCustomPrintStatement('   - countryName: ${firestoreData['countryName']}');
          } else {
            myCustomPrintStatement('⚠️ DEBUG: Document Firestore n\'existe PAS pour ${userCredential.user?.uid}');
          }

          // ⚡ FIX: Navigation directe SANS attendre le listener
          // Cela évite la double navigation qui cause le GlobalKey dupliqué
          await customAuthProvider.getAndUpdateUserModal();
          hideLoading();

          // 🔍 DEBUG: Vérifier userData.value APRÈS getAndUpdateUserModal
          myCustomPrintStatement('🔍 DEBUG userData.value APRÈS getAndUpdateUserModal (Facebook):');
          myCustomPrintStatement('   - phoneNo: ${userData.value?.phoneNo}');
          myCustomPrintStatement('   - phone (raw): ${userData.value?.phone}');
          myCustomPrintStatement('   - countryCode: ${userData.value?.countryCode}');
          myCustomPrintStatement('   - countryName: ${userData.value?.countryName}');

          // ⚡ FIX: Vérifier si l'utilisateur a déjà un numéro de téléphone
          // Si phoneNo est vide/null → demander le numéro
          // Si phoneNo existe → navigation directe vers l'accueil
          final userPhoneNo = userData.value?.phoneNo;
          final bool hasPhoneNumber = userPhoneNo != null && userPhoneNo.isNotEmpty;

          if (hasPhoneNumber) {
            // ✅ Utilisateur existant avec numéro de téléphone → MainNavigationScreen
            myCustomPrintStatement("✅ Utilisateur existant avec numéro ($userPhoneNo) - Navigation vers MainNavigationScreen");
            pushAndRemoveUntil(
              context: MyGlobalKeys.navigatorKey.currentContext!,
              screen: const MainNavigationScreen(),
            );
          } else {
            // ⚠️ Utilisateur existant SANS numéro de téléphone → PhoneNumberScreen
            myCustomPrintStatement("⚠️ Utilisateur existant SANS numéro - Navigation vers PhoneNumberScreen");
            pushAndRemoveUntil(
              context: MyGlobalKeys.navigatorKey.currentContext!,
              screen: const PhoneNumberScreen(),
            );
          }

          // ✅ Désactiver le flag APRÈS la navigation complète
          isFacebookSignInInProgress = false;
          myCustomPrintStatement("✅ Navigation terminée - Flag désactivé");
        }

        return UserSocialLoginDeatilModal(
            socialLoginId: profile["id"] ?? '',
            emailId: profile["email"] ?? "",
            userName: profile["name"] ?? "");
      } else if (res.status == LoginStatus.cancelled) {
        myCustomPrintStatement("⚠️ Connexion Facebook annulée par l'utilisateur");
        isFacebookSignInInProgress = false;
        hideLoading();
        return null;
      } else if (res.status == LoginStatus.failed) {
        myCustomPrintStatement('❌ Échec connexion Facebook: ${res.status} - ${res.message}');
        isFacebookSignInInProgress = false;
        hideLoading();
        showSnackbar("Erreur lors de la connexion Facebook: ${res.message}");
        return null;
      }
    } on FirebaseAuthException catch (e) {
      myCustomPrintStatement("❌ FirebaseAuthException: ${e.code} - ${e.message}");
      isFacebookSignInInProgress = false;
      hideLoading();

      if (e.code == 'account-exists-with-different-credential') {
        showSnackbar(
            "Ce compte existe déjà avec un autre fournisseur. Veuillez vous connecter avec Google.");
      } else {
        showSnackbar("Erreur lors de la connexion Facebook: ${e.message}");
      }
      return null;
    } catch (e) {
      myCustomPrintStatement("❌ Erreur inattendue lors de la connexion Facebook: $e");
      isFacebookSignInInProgress = false;
      hideLoading();
      showSnackbar("Erreur lors de la connexion Facebook: ${e.toString()}");
      return null;
    }

    myCustomPrintStatement('❌ Fin de facebookLogin sans résultat');
    isFacebookSignInInProgress = false;
    return null;
  }

  /// Connexion Apple — **web uniquement** dans ce fork (book.misy.app).
  ///
  /// Sur web, `signInWithPopup(OAuthProvider('apple.com'))` gère tout le flow
  /// OAuth (pas besoin du package natif `sign_in_with_apple` ni de nonce
  /// manuel). Réutilise le Services ID Apple déjà configuré pour le portail
  /// chauffeur web — `book.misy.app` doit être déclaré dans ses domaines
  /// (+ provider Apple activé dans Firebase Auth), sinon popup
  /// `auth/operation-not-allowed`.
  ///
  /// Spécificités Apple gérées : `displayName` et `email` peuvent être
  /// absents (masquage d'email, 2ᵉ connexion sans re-partage du nom).
  Future<UserSocialLoginDeatilModal?> appleLogin() async {
    showHomePageMenuNoti.value = true;
    final firebaseAuth = FirebaseAuth.instance;
    try {
      myCustomPrintStatement(' Début connexion Apple...');

      if (!kIsWeb) {
        // Fork web : le chemin natif iOS vit dans la riderapp, pas ici.
        showSnackbar(
            "La connexion Apple est disponible sur le web et l'app iOS.");
        return null;
      }

      // Activer le flag pour bloquer les navigations du listener
      isAppleSignInInProgress = true;
      myCustomPrintStatement(
          '🚫 Apple Sign-In en cours - navigation listener bloquée');

      // Même précaution que Google/Facebook : déconnecter un éventuel
      // utilisateur anonyme (mode invité) avant le popup.
      final currentUser = firebaseAuth.currentUser;
      final wasAnonymous = currentUser?.isAnonymous ?? false;
      if (currentUser != null && wasAnonymous) {
        myCustomPrintStatement('🔄 Déconnexion de l\'utilisateur anonyme');
        await firebaseAuth.signOut();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final provider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');

      final authResult = await firebaseAuth.signInWithPopup(provider);

      if (authResult.user == null) {
        myCustomPrintStatement("⚠️ Connexion Apple annulée ou user null");
        isAppleSignInInProgress = false;
        return null;
      }

      await showLoading();

      // Apple ne fournit pas toujours displayName/email (relay privé,
      // connexions suivantes) → fallbacks sûrs.
      final email = authResult.user?.email ?? '';
      final displayName = (authResult.user?.displayName ?? '').trim();
      final nameParts =
          displayName.isEmpty ? <String>[] : displayName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1 ? nameParts.last : '';
      final fallbackName = displayName.isNotEmpty
          ? displayName
          : (email.isNotEmpty ? email.split('@').first : 'Utilisateur Misy');

      final DocumentSnapshot userSnapshot =
          await FirestoreServices.users.doc(authResult.user?.uid).get();
      CustomAuthProvider customAuthProvider = Provider.of<CustomAuthProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);

      if (userSnapshot.exists == false) {
        // Nouveau compte — même squelette de doc `users` que Google/Facebook.
        Map<String, dynamic> request = {
          'id': authResult.user?.uid,
          'name': fallbackName,
          'lastName': lastName,
          'firstName': firstName.isNotEmpty ? firstName : fallbackName,
          'email': email,
          "verified": true,
          "isBlocked": false,
          "accountDeleted": false,
          "isCustomer": true,
          'phoneNo': "",
          "countryName": "United States",
          'password': authResult.user?.uid,
          'profileImage': authResult.user?.photoURL ?? dummyUserImage,
        };

        await customAuthProvider.signup(
          MyGlobalKeys.navigatorKey.currentContext!,
          request,
          socialLogin: true,
        );
        await customAuthProvider.clearGuestDataOnly();
        customAuthProvider.currentUser = authResult.user;
        await customAuthProvider.getAndUpdateUserModal(showLoader: false);
        hideLoading();

        // Nouveau compte → capture du numéro de téléphone, comme Google.
        pushAndRemoveUntil(
          context: MyGlobalKeys.navigatorKey.currentContext!,
          screen: const PhoneNumberScreen(),
        );
        isAppleSignInInProgress = false;
        myCustomPrintStatement(
            "✅ Nouveau compte Apple créé - Navigation vers PhoneNumberScreen");
      } else {
        // Compte existant — même chemin que Google : maj user + navigation
        // selon présence du numéro de téléphone.
        await customAuthProvider.clearGuestDataOnly();
        customAuthProvider.currentUser = authResult.user;
        await customAuthProvider.getAndUpdateUserModal();
        hideLoading();

        final userPhoneNo = userData.value?.phoneNo;
        final bool hasPhoneNumber =
            userPhoneNo != null && userPhoneNo.isNotEmpty;
        pushAndRemoveUntil(
          context: MyGlobalKeys.navigatorKey.currentContext!,
          screen: hasPhoneNumber
              ? const MainNavigationScreen()
              : const PhoneNumberScreen(),
        );
        isAppleSignInInProgress = false;
        myCustomPrintStatement("✅ Connexion Apple terminée - Flag désactivé");
      }

      return UserSocialLoginDeatilModal(
          socialLoginId: authResult.user!.uid,
          emailId: email,
          userName: fallbackName);
    } on FirebaseAuthException catch (e) {
      myCustomPrintStatement(
          "❌ FirebaseAuthException Apple: ${e.code} - ${e.message}");
      isAppleSignInInProgress = false;
      hideLoading();
      if (e.code == 'account-exists-with-different-credential') {
        showSnackbar(
            "Ce compte existe déjà avec un autre fournisseur. Veuillez vous connecter avec Google ou Facebook.");
      } else if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        // Fermeture volontaire du popup : pas une erreur.
        myCustomPrintStatement("ℹ️ Popup Apple fermé par l'utilisateur");
      } else {
        showSnackbar("Erreur lors de la connexion Apple: ${e.message}");
      }
      return null;
    } catch (e) {
      myCustomPrintStatement("❌ Error during Apple sign-in: $e");
      isAppleSignInInProgress = false;
      hideLoading();
      showSnackbar("Erreur lors de la connexion Apple: ${e.toString()}");
      return null;
    }
  }

  String generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
