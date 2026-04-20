// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/user_modal.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/otp_verification_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/phone_number_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/editor_dashboard_screen.dart';
import 'package:rider_ride_hailing_app/services/admin_auth_service.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/services/firebase_push_notifications.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/loyalty_service.dart';
import 'package:rider_ride_hailing_app/services/password_encrypt_and_decrypt_service.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/services/guest_storage_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:rider_ride_hailing_app/provider/internet_connectivity_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../contants/my_colors.dart';
import '../contants/my_image_url.dart';
import '../contants/sized_box.dart';
import '../functions/navigation_functions.dart';
import '../widget/common_alert_dailog.dart';
import '../widget/round_edged_button.dart';
import '../widget/show_snackbar.dart';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class CustomAuthProvider with ChangeNotifier {
  User? currentUser;
  String numberVerificationOTP = "";
  TextEditingController emailAddressCont = TextEditingController();
  TextEditingController passwordCont = TextEditingController();
  bool _isGuestMode = false;
  final GuestStorageService _guestStorageService = GuestStorageService();

  // Getter pour vérifier si l'utilisateur est en mode invité
  bool get isGuestMode => _isGuestMode;
  splashAuthentication(context) async {
    numberVerificationOTP = await DevFestPreferences().getVerificationCode();
    userData.value = await DevFestPreferences().getUserDetails();
    globalSettings = await DevFestPreferences().getDefaultAppSettingRequest();

    // 🔧 FIX: Restaurer le mode invité AVANT la navigation pour éviter les race conditions
    // (isGuestMode doit être correct quand l'utilisateur arrive sur confirmDestination)
    await checkGuestModeStatus();

    // 🚀 OPTIMISATION: Internet check non-bloquant (gain ~1-3s)
    // L'app assume qu'elle est connectée et vérifie en arrière-plan
    Provider.of<InternetConnectivityProvider>(context, listen: false)
        .internetConnectivityState(); // Sans await - non bloquant

    // 🚀 OPTIMISATION: Demander la permission en parallèle sans bloquer
    // La permission notification n'est pas critique pour l'affichage initial
    Permission.notification.request(); // Sans await - non bloquant

    var adminSettingsProvider =
        Provider.of<AdminSettingsProvider>(context, listen: false);

    // ⚡ OPTIMISATION DÉMARRAGE RAPIDE: Lancer l'auth listener IMMÉDIATEMENT
    // Permet la navigation vers HomeScreen sans attendre Firestore
    setAuthListener(context);

    // ⚡ Charger les données Firestore EN ARRIÈRE-PLAN (non-bloquant)
    // L'UI s'affiche immédiatement, les données arrivent après
    _loadFirestoreDataInBackground(adminSettingsProvider);

    myCustomPrintStatement("getAndSetSettings calling $numberVerificationOTP");
    // ignore: deprecated_member_use
    Locale deviceLocale = WidgetsBinding.instance.window.locale;
    lastSearchSuggestion.value =
        await DevFestPreferences().getSearchSuggestion();
    var mapProvider = Provider.of<GoogleMapProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false);

    // 🚀 Charger la position GPS actuelle (pas de cache)
    _preloadCurrentGpsPosition(mapProvider);
    myCustomPrintStatement(
        "deviceLocale.languageCode ${deviceLocale.languageCode}");
    String languageCode = await DevFestPreferences().getLanguageCode();
    if (languageCode.isEmpty) {
      // Pas de langue sauvegardée : utiliser la langue du téléphone ou anglais par défaut
      final deviceLang = deviceLocale.languageCode;
      final supportedLangs = {'en': 0, 'mg': 1, 'fr': 2, 'it': 3, 'pl': 4};
      final langNames = {'en': 'English', 'mg': 'Malagasy', 'fr': 'French', 'it': 'Italian', 'pl': 'Polish'};

      if (supportedLangs.containsKey(deviceLang)) {
        // Langue du téléphone supportée
        selectedLanguageNotifier.value = languagesList[supportedLangs[deviceLang]!];
        selectedLanguage.value = langNames[deviceLang]!;
      } else {
        // Langue du téléphone non supportée : fallback anglais
        selectedLanguageNotifier.value = languagesList[0]; // English
        selectedLanguage.value = 'English';
        myCustomPrintStatement("Langue téléphone '$deviceLang' non supportée, fallback anglais");
      }
    } else {
      // Langue sauvegardée : utiliser celle-ci
      var languageIndex =
          languagesList.indexWhere((element) => element['key'] == languageCode);
      if (languageIndex >= 0) {
        selectedLanguageNotifier.value = languagesList[languageIndex];
        final langNames = {'en': 'English', 'mg': 'Malagasy', 'fr': 'French', 'it': 'Italian', 'pl': 'Polish'};
        selectedLanguage.value = langNames[languageCode] ?? 'English';
      } else {
        // Code langue invalide : fallback anglais
        selectedLanguageNotifier.value = languagesList[0];
        selectedLanguage.value = 'English';
      }
    }
    myCustomPrintStatement(
        "selected language is that ${selectedLanguageNotifier.value}");
    selectedLocale.value = Locale(selectedLanguageNotifier.value['key']);
    // Note: setAuthListener est déjà appelé plus haut pour un démarrage rapide
  }

  /// ⚡ Charge les données Firestore en arrière-plan sans bloquer l'UI
  void _loadFirestoreDataInBackground(AdminSettingsProvider adminSettingsProvider) {
    myCustomPrintStatement("🚀 Démarrage du chargement Firestore en arrière-plan");

    // Exécuter tous les appels en parallèle sans bloquer
    Future.wait([
      adminSettingsProvider.getDefaultAppSettings().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          myCustomPrintStatement("⏱️ Timeout getDefaultAppSettings - utilisation fallback");
        },
      ),
      FirestoreServices.getVehicleTypes().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          myCustomPrintStatement("⏱️ Timeout getVehicleTypes - utilisation fallback");
        },
      ),
      FirestoreServices.getPricingConfigV2().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          myCustomPrintStatement("⏱️ Timeout getPricingConfigV2 - utilisation fallback");
        },
      ),
      FirestoreServices.getLoyaltyConfig().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          myCustomPrintStatement("⏱️ Timeout getLoyaltyConfig - utilisation fallback");
        },
      ),
      FirestoreServices.getAndSetSettings().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          myCustomPrintStatement("⏱️ Timeout getAndSetSettings - utilisation fallback");
        },
      ),
    ], eagerError: false).then((_) {
      myCustomPrintStatement("✅ Toutes les configurations Firestore chargées");

      // Précharger les images de markers véhicules
      try {
        final mapProvider = Provider.of<GoogleMapProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);
        mapProvider.preloadVehicleMarkerImages();
      } catch (e) {
        myCustomPrintStatement("⚠️ Erreur préchargement markers: $e");
      }
    }).catchError((e) {
      myCustomPrintStatement("⚠️ Erreur chargement Firestore (fallbacks utilisés): $e");
    });
  }

  Widget _postAuthScreen() {
    if (Uri.base.toString().contains('transport-editor')) {
      return const EditorDashboardScreen();
    }
    return const MainNavigationScreen();
  }

  setAuthListener(contex) {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      myCustomPrintStatement("users id and other details ${user == null}");

      // 🚫 BLOQUER la navigation si Google Sign-In ou Facebook Sign-In est en cours
      // Cela empêche les navigations intermédiaires (signOut → anonymous user)
      // et laisse seulement la navigation finale après Social Sign-In
      if (isGoogleSignInInProgress) {
        myCustomPrintStatement("🚫 Navigation bloquée - Google Sign-In en cours");
        return; // Ne pas naviguer
      }
      if (isFacebookSignInInProgress) {
        myCustomPrintStatement("🚫 Navigation bloquée - Facebook Sign-In en cours");
        return; // Ne pas naviguer
      }
      // 🚫 BLOQUER la navigation si logout/suppression de compte est en cours
      // Cela empêche la double navigation (logout manuel + listener automatique)
      if (isLogoutInProgress) {
        myCustomPrintStatement("🚫 Navigation bloquée - Logout en cours");
        return; // Ne pas naviguer
      }

      // ⚡ FIX: Si l'utilisateur est déjà connecté et qu'on reçoit un event pour le même user, ne rien faire
      if (user != null && currentUser != null && user.uid == currentUser!.uid) {
        myCustomPrintStatement("ℹ️ Même utilisateur déjà connecté - skip navigation");
        return;
      }

      // 🎯 Mode éditeur terrain : flow simplifié.
      // Le compte consultant n'a pas de doc Firestore `users/{uid}` (créé
      // via Auth admin SDK uniquement). On court-circuite donc toute la
      // logique user/guest/phoneNo et on re-pousse le dashboard, qui a
      // son propre gate `AdminAuthService` sur le custom claim.
      if (Uri.base.toString().contains('transport-editor')) {
        await hideLoading();
        if (user != null) {
          currentUser = user;
          AdminAuthService.instance.invalidate();
          pushAndRemoveUntil(
            context: MyGlobalKeys.navigatorKey.currentContext!,
            screen: const EditorDashboardScreen(),
          );
        }
        return;
      }

      if (user == null) {
        var getRequest =
            await DevFestPreferences().getUserVerificationRequest();
        if (getRequest.isNotEmpty && globalSettings.enableOTPVerification) {
          pushReplacement(
              context: MyGlobalKeys.navigatorKey.currentContext!,
              screen: OTPVerificationScreen(request: getRequest));
        } else {
          // ✅ MODE INVITÉ: Créer un utilisateur anonyme Firebase pour accéder à Firestore
          myCustomPrintStatement("🎭 Activation du mode invité - création utilisateur anonyme Firebase");
          try {
            // 🔐 CRITIQUE: Créer un utilisateur anonyme pour que Firestore accepte les requêtes
            final UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
            currentUser = userCredential.user;
            myCustomPrintStatement("✅ Utilisateur anonyme créé: ${currentUser?.uid}");
          } catch (e) {
            myCustomPrintStatement("❌ Erreur création utilisateur anonyme: $e");
          }

          await enableGuestMode();
          pushReplacement(
              context: MyGlobalKeys.navigatorKey.currentContext!,
              screen: _postAuthScreen());
        }
      } else {
        currentUser = user;

        // 🎯 FIX: Gérer le cas de l'utilisateur anonyme (mode invité)
        // Les utilisateurs anonymes n'ont pas de document Firestore
        if (user.isAnonymous) {
          myCustomPrintStatement("✅ Utilisateur anonyme détecté - activation mode invité et navigation");
          await enableGuestMode();
          pushAndRemoveUntil(
              context: MyGlobalKeys.navigatorKey.currentContext!,
              screen: _postAuthScreen());
          return; // Sortir tôt pour éviter d'appeler getAndUpdateUserModal
        }

        // 🚀 FIX CRITIQUE: Wrapper getAndUpdateUserModal dans un timeout global
        // Si l'appel prend plus de 15 secondes, forcer la navigation vers MainNavigationScreen
        try {
          await getAndUpdateUserModal(showLoader: false).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              myCustomPrintStatement('⚠️ Timeout global sur getAndUpdateUserModal - navigation forcée');
              // Forcer la navigation même en cas de timeout
              pushAndRemoveUntil(
                context: MyGlobalKeys.navigatorKey.currentContext!,
                screen: _postAuthScreen());
              throw TimeoutException('Global timeout on getAndUpdateUserModal');
            },
          );
        } on TimeoutException catch (e) {
          myCustomPrintStatement('⏱️ Timeout attrapé, l\'app continue normalement: $e');
          return; // L'app a déjà navigé vers MainNavigationScreen
        } catch (e) {
          myCustomPrintStatement('❌ Erreur lors de getAndUpdateUserModal: $e');
          // En cas d'erreur, forcer quand même la navigation pour ne pas bloquer l'utilisateur
          pushAndRemoveUntil(
            context: MyGlobalKeys.navigatorKey.currentContext!,
            screen: _postAuthScreen());
          return;
        }
        // ⚡ FIX: Vérifier phoneNo qui est le champ sauvegardé dans Firestore (ligne 79 user_modal.dart)
        // Le champ 'phone' local est rempli depuis 'phoneNo' de Firestore
        if (userData.value != null && (userData.value!.phoneNo == null || userData.value!.phoneNo!.isEmpty)) {
          var getRequest =
              await DevFestPreferences().getUserVerificationRequest();
          if (getRequest.isNotEmpty) {
            pushAndRemoveUntil(
                context: MyGlobalKeys.navigatorKey.currentContext!,
                screen: OTPVerificationScreen(request: getRequest));
          } else {
            pushAndRemoveUntil(
                screen: const PhoneNumberScreen(),
                context: MyGlobalKeys.navigatorKey.currentContext!);
          }
        } else if (userData.value != null) {
          // ⚡ OPTIMISATION DÉMARRAGE RAPIDE: Naviguer IMMÉDIATEMENT vers HomeScreen
          // La vérification de course active se fait en arrière-plan
          myCustomPrintStatement('⚡ Navigation immédiate vers MainNavigationScreen');
          pushAndRemoveUntil(
              context: MyGlobalKeys.navigatorKey.currentContext!,
              screen: _postAuthScreen());

          // ⚡ Vérifier la course active EN ARRIÈRE-PLAN (non-bloquant)
          // Si une course est trouvée, HomeScreen se mettra à jour automatiquement
          Future.microtask(() async {
            try {
              var tripProvider = Provider.of<TripProvider>(
                  MyGlobalKeys.navigatorKey.currentContext!,
                  listen: false);
              myCustomPrintStatement('🔍 Auth: Vérification course active en arrière-plan');
              CustomTripType? activeTrip = await tripProvider.checkForActiveTrip()
                  .timeout(const Duration(seconds: 5), onTimeout: () => null);
              if (activeTrip != null) {
                myCustomPrintStatement('🚗 Course active trouvée: $activeTrip - mise à jour UI');
                // HomeScreen écoutera les changements via le provider
              }
            } catch (e) {
              myCustomPrintStatement('⚠️ Erreur vérification course active: $e');
            }
          });

          // S'assurer que le token FCM est disponible avant de sauvegarder
          String? fcmToken = deviceId;
          if (fcmToken.isEmpty) {
            // Récupérer le token si pas encore disponible
            fcmToken = await FirebasePushNotifications.getToken() ?? '';
            if (fcmToken.isNotEmpty) {
              deviceId = fcmToken;
            }
          }
          myCustomPrintStatement('📱 Sauvegarde deviceId: $fcmToken');

          await editProfile(
            {
              "deviceId": fcmToken.isNotEmpty ? [fcmToken] : [],
              "preferedLanguage": selectedLanguageNotifier.value["key"]
            },
            showLoader: isInternetConnect,
          );
        }
      }
    });
  }

  Future<void> logInWithPhoneNumberAndPassword(
      {required BuildContext context,
      required String password,
      required String countryCode,
      required String phoneNumber}) async {
    try {
      await showLoading();
      final QuerySnapshot querySnapshot = await FirestoreServices.users
          .where('phoneNo', isEqualTo: phoneNumber)
          .where('countryCode', isEqualTo: countryCode)
          .where('accountDeleted', isNotEqualTo: true)
          .limit(1)
          .get();

      final Map<String, dynamic> userDoc =
          querySnapshot.docs.first.data() as Map<String, dynamic>;
      if (querySnapshot.docs.isNotEmpty) {
        // if (userDoc['isCustomer']) {
        loginFunction(
            context: context, emailId: userDoc['email'], password: password);
        // }
        // else {
        //   await hideLoading();
        //   showSnackbar(translate("youAreDriverMsg"));
        // }
      } else {
        await hideLoading();
        showSnackbar(translate("userNotAvailableMob"));
      }
    } catch (e) {
      await hideLoading();
      showSnackbar(translate("userNotAvailableMob"));
      myCustomPrintStatement('Error signing in: $e');
      // Show error message or handle the error appropriately
    }
  }

  loginFunction(
      {required BuildContext context,
      required String emailId,
      required String password}) async {
    await showLoading();

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: emailId, password: password);
      myCustomPrintStatement(credential);

      // Désactiver le mode invité lors de la connexion
      if (_isGuestMode) {
        await disableGuestMode();
      }

      // await hideLoading();
      showHomePageMenuNoti.value = true;
      passwordCont.clear();
      emailAddressCont.clear();
      // return credential.user!.uid;
    } on FirebaseAuthException catch (e) {
      await hideLoading();
      myCustomPrintStatement("login checked-----------${e.code}");
      if (e.code == 'invalid-email') {
        showSnackbar(translate('userNotAvailable'));
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        showSnackbar(translate("invalidCredentials"));
        passwordCont.clear();
        notifyListeners();
      } else if (e.code == "too-many-requests") {
        showSnackbar(translate("temporarilyDisable"));
      } else {
        if (e.message != null) {
          showSnackbar(e.message ?? "");
        }
      }
      //  else if (e.code == 'user-disabled') {}
    }
  }

  Future forgotPasswordFunction(context, email) async {
    myCustomPrintStatement("email ---------------$email");

    await showLoading();
    final QuerySnapshot emailSnapshot =
        await FirestoreServices.users.where('email', isEqualTo: email).get();
    if (emailSnapshot.docs.isEmpty) {
      await hideLoading();
      showSnackbar(translate("userNotAvailable"));
    } else {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email,
        );
        await hideLoading();

        await showCommonAlertDailog(context,
            successIcon: true,
            headingText: translate('success'),
            message: translate('forgotPasswordSuccess'),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RoundEdgedButton(
                      text: translate('ok'),
                      width: 100,
                      height: 40,
                      onTap: () async {
                        popPage(context: context);
                        popPage(context: context);
                      }),
                  hSizedBox,
                ],
              ),
            ]);

        // showSnackbar("Password reset link has been sent to your email");
        // return true;
      } on FirebaseAuthException catch (e) {
        await hideLoading();
        myCustomPrintStatement("error-----------------------$e");
        if (e.code == "user-not-found") {
          showSnackbar(translate("userNotAvailable"));
        } else if (e.code == "invalid-email") {
          showSnackbar(translate("userNotAvailable"));
        }

        // return false;
      }
    }
  }

  Future editProfile(request,
      {BuildContext? context, bool showLoader = true}) async {
    if (showLoader) {
      await showLoading();
    }

    // ⚡ FIX: Utiliser .set() avec merge au lieu de .update() pour créer le document s'il n'existe pas
    // Cela évite l'erreur NOT_FOUND quand le document Firestore n'est pas encore synchronisé après signup()
    await FirestoreServices.users.doc(currentUser!.uid).set(request, SetOptions(merge: true));

    // ⚡ FIX: Fermer le loading AVANT d'appeler getAndUpdateUserModal()
    // Car getAndUpdateUserModal() peut afficher son propre loading selon le paramètre showLoader
    if (showLoader) {
      await hideLoading();
    }

    // ⚡ FIX: Passer showLoader=false pour éviter d'afficher un loading en double
    // Le loading a déjà été géré par editProfile() ci-dessus
    await getAndUpdateUserModal(showLoader: false);
    if (context != null) {
      popPage(context: context);
    }
  }

  Future checkMobileNumberAndEmailExist(
    BuildContext context,
    Map<String, dynamic> request,
  ) async {
    await showLoading();
    final QuerySnapshot mobileNumberSnapshot = await FirestoreServices.users
        .where('phoneNo',
            isEqualTo:
                request['phoneNo'].isEmpty ? "googleLogin" : request['phoneNo'])
        .where('countryCode',
            isEqualTo: request['countryCode'].isEmpty
                ? "googleLogin"
                : request['countryCode'])
        .where('accountDeleted', isNotEqualTo: true)
        .get();
    final QuerySnapshot emailSnapshot = await FirestoreServices.users
        .where('email', isEqualTo: request['email'])
        .where('accountDeleted', isNotEqualTo: true)
        .get();
    if (mobileNumberSnapshot.docs.isNotEmpty || emailSnapshot.docs.isNotEmpty) {
      await hideLoading();
      String message =
          mobileNumberSnapshot.docs.isNotEmpty ? "mobile number" : "";
      message +=
          mobileNumberSnapshot.docs.isNotEmpty && emailSnapshot.docs.isNotEmpty
              ? " and "
              : "";
      message += emailSnapshot.docs.isNotEmpty ? "email id" : "";
      showSnackbar('This $message ${translate("alreadyExistMsg")} $message.');
    } else {
      await hideLoading();
      if (globalSettings.enableOTPVerification) {
        return await showCommonAlertDailog(
          context,
          successIcon: false,
          headingText: translate(
            "Please confirm phone number",
          ),
          message: translate("confirmNumberMessage"),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RoundEdgedButton(
                  text: translate("cancel"),
                  color: MyColors.blackThemeColorWithOpacity(0.3),
                  width: 100,
                  height: 40,
                  onTap: () {
                    popPage(context: context);
                  },
                ),
                hSizedBox2,
                RoundEdgedButton(
                    text: translate("send"),
                    width: 100,
                    height: 40,
                    onTap: () async {
                      DevFestPreferences().setUserVerificationRequest(request);
                      pushReplacement(
                          context: context,
                          screen: OTPVerificationScreen(
                            request: request,
                          ));
                    }),
                hSizedBox,
              ],
            ),
          ],
        );
      } else {
        await signup(context, request);
      }
    }
  }

  Future signup(BuildContext context, Map request,
      {bool socialLogin = false}) async {
    await showLoading();
    request['accountDeleted'] = false;
    try {
      request['preferedLanguage'] = selectedLanguageNotifier.value['key'];
      if (socialLogin == false) {
        UserCredential credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: request['email'],
          password: request['password'],
        );

        myCustomLogStatements("Result is that ${credential.user!.uid}");
         var  hassedpass = PasswordEncryptAndDecryptService().stringToHashedPassword(password: request['password']);
        request['id'] = credential.user!.uid;
        request['password'] = hassedpass;
      }

      // Désactiver le mode invité lors de l'inscription
      if (_isGuestMode) {
        await disableGuestMode();
      }

      await FirestoreServices.users.doc(request['id']).set(Map<String, dynamic>.from(request));
      if (globalSettings.extraDiscount > 0 &&
          globalSettings.enableTaxiExtraDiscount) {
        var res = await FirestoreServices.users
            .where("isCustomer", isEqualTo: true)
            .get();
        if (res.docs.isNotEmpty &&
            res.docs.length < globalSettings.numberOfUser) {
          request['extraDiscount'] = globalSettings.extraDiscount;
          await FirestoreServices.users.doc(request['id']).set(Map<String, dynamic>.from(request));
        }
      }

      DevFestPreferences().setVerificationCode("");
      DevFestPreferences().setUserVerificationRequest({});
      var add = {
        'image': MyImagesUrl.cashIcon,
        'name': PaymentMethodType.cash.value,
        'mobileNumber': '',
        'isSelected': true,
      };

      final docId = FirestoreServices.users
          .doc(request['id'])
          .collection('savedPaymentMethods')
          .doc();
      add['id'] = docId.id;
      await FirestoreServices.users
          .doc(request['id'])
          .collection('savedPaymentMethods')
          .doc(docId.id)
          .set(add);
    } on FirebaseAuthException catch (e) {
      await hideLoading();
      if (e.code == 'weak-password') {
        showSnackbar(translate("thepasswordprovidedistooweak"));
      } else if (e.code == 'email-already-in-use') {
        showSnackbar(translate("emailAreadyExist"));
      }
      myCustomPrintStatement("error during sign up $e");
      return "";
    } catch (e) {
      myCustomPrintStatement("error during sign up $e");
      await hideLoading();
      return "";
    }
  }

  logout(context) async {
    await showCommonAlertDailog(
      context,
      imageUrl: MyImagesUrl.logout,
      headingText: translate("areYouSure"),
      message: "Cette action mettra fin à votre session.",
      actions: [
        // 🎨 Boutons modernes empilés verticalement (meilleure lisibilité)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton Se déconnecter (primaire en haut pour visibilité)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MyColors.coralPink,
                      MyColors.coralPink.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: MyColors.coralPink.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: () async {
                    await signOutUser();
                    // ⚡ Activer le mode invité après déconnexion
                    await enableGuestMode();

                    // ⚡ FIX: Forcer la fermeture de tout loading résiduel avant navigation
                    // Cela évite le loading infini si un loading est resté ouvert
                    await hideLoading();
                    myCustomPrintStatement("🔒 Loading forcé fermé avant navigation");

                    // ✅ Navigation vers MainNavigationScreen en mode invité (avec bouton "Se connecter")
                    pushAndRemoveUntil(
                        context: context, screen: const MainNavigationScreen());
                  },
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    translate("logout"),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton Annuler (secondaire en bas)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  color: MyColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MyColors.borderLight,
                    width: 1,
                  ),
                ),
                child: TextButton(
                  onPressed: () {
                    popPage(context: context);
                  },
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    translate("cancel"),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: MyColors.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future getAndUpdateUserModal({bool showLoader = false}) async {
    myCustomPrintStatement('getting and updating user modal');
    if (showLoader) {
      await showLoading();
    }

    // 🚀 FIX CRITIQUE: Ajouter timeout sur l'appel Firestore pour éviter le blocage au démarrage
    var querySnapshot = await FirestoreServices.users.doc(currentUser!.uid.toString()).get()
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          myCustomPrintStatement('⚠️ Timeout lors de la récupération des données utilisateur');
          throw TimeoutException('Timeout getting user data');
        },
      );

    if (showLoader) {
      await hideLoading();
    }
    if (querySnapshot.exists) {
      userData.value =
          UserModal.fromJson(querySnapshot.data() as Map<String, dynamic>);
      var sharedPrefrenc = querySnapshot.data() as Map<String, dynamic>;
      sharedPrefrenc['approvedAt'] = null;

      // Convert Timestamp objects to DateTime strings for JSON serialization
      Map<String, dynamic> serializedData = Map<String, dynamic>.from(sharedPrefrenc);
      serializedData.forEach((key, value) {
        if (value is Timestamp) {
          serializedData[key] = value.toDate().toIso8601String();
        }
      });

      DevFestPreferences().setUserDetails(jsonEncode(serializedData));
      myCustomPrintStatement(
          "users id and other details ${userData.value!.id}");

      // 🚀 FIX CRITIQUE: Exécuter initializeLoyaltyForUser en arrière-plan (non-bloquant)
      // Ne pas attendre la complétion pour ne pas bloquer le démarrage de l'app
      // Cette opération peut prendre du temps avec un réseau lent et n'est pas critique
      LoyaltyService.instance.initializeLoyaltyForUser(userData.value!.id).catchError((e) {
        myCustomPrintStatement('⚠️ Erreur initialisation loyalty (non-bloquant): $e');
        // Ignorer l'erreur - l'app continue normalement
        return false; // Retourner false pour satisfaire le type Future<bool>
      });
      
      notifyListeners();
      if (userData.value!.isBlocked) {
        showSnackbar(translate("accountBlockByAdmin"));
        signOutUser();
      }
    } else {
      // 🎯 FIX: Ne PAS déclencher le sign-out automatique en mode invité
      // Les utilisateurs anonymes n'ont pas de document Firestore (c'est normal)
      if (!isGuestMode) {
        myCustomPrintStatement('signing out from here');
        Future.delayed(const Duration(seconds: 10), () {
          if (userData.value == null && !isGuestMode) {
            signOutUser();
          }
        });
      } else {
        myCustomPrintStatement('👤 Mode invité: Pas de document utilisateur (normal)');
      }
    }
  }

  Future<bool> changePasswordFunction({
    required BuildContext context,
    required String oldpassword,
    required String newpassword,
  }) async {
    String email = userData.value!.email;

    // String password = "password";
    // String newPassword = "password";

    await showLoading();

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: oldpassword,
      );

      myCustomPrintStatement("user credenticals  ${userCredential.user}");

      return userCredential.user!.updatePassword(newpassword).then((_) async {
        myCustomPrintStatement("Successfully changed password");
     var  hassedpass = PasswordEncryptAndDecryptService().stringToHashedPassword(password: newpassword);
        editProfile({'password': hassedpass});
        await hideLoading();
        popPage(context: context);
        myCustomPrintStatement('snackbaropen');
        showSnackbar(translate("Passwordchangedsuccessfully"));
        myCustomPrintStatement('before returning true');
        return true;
      }).catchError((error) async {
        myCustomPrintStatement("Password can't be changed ${error.code}");
        await hideLoading();
        // if(error=='')
        if (error.code.toString() == "weak-password") {
          showSnackbar(translate("thepasswordprovidedistooweak"));
        }
        myCustomPrintStatement("Password can't be changed ${error.code}");
        return false;
        //This might happen, when the wrong password is in, the user isn't found, or if the user hasn't logged in recently.
      });
    } on FirebaseAuthException catch (e) {
      await hideLoading();
      if (e.code == 'user-not-found') {
        myCustomPrintStatement('No user found for that email.');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        showSnackbar(translate("Yourcurrentpasswordisincorrect"));
      }
      myCustomPrintStatement("Error is that $e");
      return false;
    }
  }

  Future signOutUser() async {
    // 🚫 Activer le flag pour bloquer la navigation automatique du listener
    isLogoutInProgress = true;
    myCustomPrintStatement("🚫 Logout en cours - navigation listener bloquée");

    await showLoading();

    // 🔐 CRITIQUE: Déconnecter TOUS les providers de connexion sociale
    // Vérifier quelle méthode de connexion a été utilisée
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Récupérer les providers utilisés pour se connecter
      final providers = user.providerData.map((info) => info.providerId).toList();
      myCustomPrintStatement("🔍 Providers détectés: $providers");

      // Déconnexion Google Sign-In si l'utilisateur s'est connecté via Google
      if (providers.contains('google.com')) {
        try {
          final googleSignIn = GoogleSignIn();
          if (await googleSignIn.isSignedIn()) {
            await googleSignIn.signOut();
            myCustomPrintStatement("✅ Google Sign-In déconnecté");
          }
        } catch (e) {
          myCustomPrintStatement("⚠️ Erreur déconnexion Google Sign-In: $e");
        }
      }

      // Déconnexion Facebook Auth si l'utilisateur s'est connecté via Facebook
      if (providers.contains('facebook.com')) {
        try {
          await FacebookAuth.instance.logOut();
          myCustomPrintStatement("✅ Facebook Auth déconnecté");
        } catch (e) {
          myCustomPrintStatement("⚠️ Erreur déconnexion Facebook Auth: $e");
        }
      }
    }

    // Déconnexion Firebase Auth
    await FirebaseAuth.instance.signOut();
    currentUser = null;
    userData.value = null;
    notifyListeners();
    DevFestPreferences().setUserDetails("");
    DevFestPreferences().setVerificationCode("");
    DevFestPreferences().setUserVerificationRequest({});
    // 🎯 NE PAS reset la position GPS - l'utilisateur est toujours au même endroit physiquement
    // DevFestPreferences.updateLocation(LatLng(0, 0));
    await hideLoading();
    if (userStream != null) {
      userStream!.cancel();
      userStream = null;
    }

    // ✅ Réactiver le listener APRÈS la navigation manuelle (dans logout())
    // Le flag sera réactivé après un délai pour laisser le temps à la navigation de se faire
    Future.delayed(const Duration(milliseconds: 500), () {
      isLogoutInProgress = false;
      myCustomPrintStatement("✅ Navigation listener réactivée après logout");
    });
  }

  StreamSubscription<DocumentSnapshot>? userStream;

  Future showLoading() async {
    if (!EasyLoading.isShow) {
      await EasyLoading.show(
        status: null, 
        maskType: EasyLoadingMaskType.custom,
        indicator: LoadingAnimationWidget.twistingDots(
          leftDotColor: MyColors.coralPink,
          rightDotColor: MyColors.horizonBlue,
          size: 45.0,
        ),
      );
    }
  }

  Future hideLoading() async {
    if (EasyLoading.isShow) {
      await EasyLoading.dismiss();
    }
  }

  Future sendOTPSmsToMobileNumber({required String sendToMobileNo}) async {
    Random random = Random();
    int min = 1000; // Minimum 4-digit number
    int max = 9999; // Maximum 4-digit number
    int verificationCode = min + random.nextInt(max - min);
    numberVerificationOTP = verificationCode.toString();
    myCustomPrintStatement("Verification code is $numberVerificationOTP");
    try {
      var headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic ${paymentGateWaySecretKeys!.twillioBasicKey}'
      };
      var request = http.Request(
          'POST',
          Uri.parse(
              'https://api.twilio.com/2010-04-01/Accounts/${AppSecrets.twilioAccountSid}/Messages.json'));
      request.bodyFields = {
        'To': sendToMobileNo,
        'From': '+18609866785',
        'Body': translate("twillioMsg")
            .replaceFirst("verificationCode", verificationCode.toString())
      };
      request.headers.addAll(headers);

      http.StreamedResponse streamedResponse = await request.send();
      http.Response response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        DevFestPreferences().setVerificationCode(numberVerificationOTP);
        var jsonResponse = jsonDecode(response.body.toString());
        myCustomLogStatements(
            "json response of send msg ${response.statusCode} $jsonResponse");
      } else {
        myCustomLogStatements(
            "ERROR :--- Api Fail to fetch with status code :- ${response.statusCode}\n REQUEST :- ${request.bodyBytes} ");
        showSnackbar(
            "ERROR :--- Api Fail to fetch with status code :- ${response.statusCode}");
      }
    } catch (e) {
      showSnackbar("ERROR :---- $e");
      myCustomLogStatements("ERROR ON SEND SMS :- $e");
    }
  }

  deleteUserAccount() {}

  /// Active le mode invité
  Future<void> enableGuestMode() async {
    _isGuestMode = true;
    await _guestStorageService.setGuestMode(true);
    myCustomPrintStatement("✅ Mode invité activé dans AuthProvider");
    notifyListeners();
  }

  /// Désactive le mode invité (appelé lors de la connexion)
  Future<void> disableGuestMode() async {
    _isGuestMode = false;

    // 🔐 Supprimer l'utilisateur anonyme Firebase si présent
    if (currentUser != null && currentUser!.isAnonymous) {
      try {
        await currentUser!.delete();
        myCustomPrintStatement("🗑️ Utilisateur anonyme Firebase supprimé");
      } catch (e) {
        myCustomPrintStatement("⚠️ Erreur suppression utilisateur anonyme: $e");
      }
    }

    await _guestStorageService.clearAllGuestData();
    myCustomPrintStatement("🚪 Mode invité désactivé dans AuthProvider");
    notifyListeners();
  }

  /// ⚡ Nettoyer uniquement les données invité (sans supprimer l'utilisateur Firebase)
  /// Utilisé lors de la connexion sociale où Firebase gère automatiquement la transition
  Future<void> clearGuestDataOnly() async {
    _isGuestMode = false;
    // ⚠️ NE PAS supprimer l'utilisateur Firebase ici
    // Firebase gère automatiquement la transition de anonymous → authenticated
    await _guestStorageService.clearAllGuestData();
    myCustomPrintStatement("🧹 Données invité nettoyées (utilisateur Firebase préservé)");
    notifyListeners();
  }

  /// Vérifie et restaure l'état du mode invité au démarrage
  Future<void> checkGuestModeStatus() async {
    _isGuestMode = await _guestStorageService.isGuestMode();
    if (_isGuestMode) {
      myCustomPrintStatement("🔄 Mode invité détecté au démarrage");
    }
  }

  /// 🚀 OPTIMISATION: Pré-charge uniquement la position GPS en cache (instantané)
  /// La position fraîche sera obtenue par location.dart quand l'utilisateur arrive sur la carte
  void _preloadCurrentGpsPosition(GoogleMapProvider mapProvider) {
    // Exécuter en arrière-plan sans bloquer le splash screen
    Future.microtask(() async {
      try {
        // Vérifier d'abord si les permissions sont déjà accordées
        final permission = await Permission.location.status;
        if (!permission.isGranted) {
          myCustomPrintStatement("⚠️ Permission localisation non accordée - skip pré-chargement GPS");
          return;
        }

        myCustomPrintStatement("🌍 Pré-chargement position GPS (cache uniquement)...");

        // 🚀 OPTIMISATION: Utiliser uniquement getLastKnownPosition (instantané)
        // getCurrentPosition avec timeout de 8s a été retiré pour accélérer le démarrage
        // La position fraîche sera obtenue par location.dart avec le stream GPS
        try {
          final position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            myCustomPrintStatement("⚡ Position instantanée (cache): (${position.latitude}, ${position.longitude})");
            currentPosition = position;
            mapProvider.setPosition(position.latitude, position.longitude);
          } else {
            myCustomPrintStatement("ℹ️ Pas de position en cache - sera obtenue par location.dart");
          }
        } catch (e) {
          myCustomPrintStatement("⚠️ Erreur lecture position cache: $e");
        }
      } catch (e) {
        myCustomPrintStatement("⚠️ Erreur pré-chargement GPS (non-bloquant): $e");
      }
    });
  }
}
