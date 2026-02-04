import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/splash_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/web_entry_screen.dart';
import 'package:rider_ride_hailing_app/pages/test_invoice_regeneration_page.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/provider/airtel_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/notification_provider.dart';
import 'package:rider_ride_hailing_app/provider/orange_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/promocodes_provider.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/provider/telma_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_coordinator_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_airtel_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_orange_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_telma_provider.dart';
import 'package:rider_ride_hailing_app/provider/loyalty_chest_provider.dart';
import 'package:rider_ride_hailing_app/services/firebase_push_notifications.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/provider/internet_connectivity_provider.dart';
import 'package:rider_ride_hailing_app/provider/navigation_provider.dart';
import 'package:rider_ride_hailing_app/pages/share/live_share_viewer_screen.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';

import 'contants/global_keys.dart';
import 'contants/theme_data.dart';
import 'provider/auth_provider.dart';
import 'provider/guest_session_provider.dart';
import 'services/sunrise_sunset_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_database/firebase_database.dart';
import 'services/analytics/analytics_service.dart';

import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'provider/trip_provider.dart';
import 'provider/trip_chat_provider.dart';
import 'provider/geo_zone_provider.dart';

/// 🚀 OPTIMISATION: Clear du cache Firestore en arrière-plan (non-bloquant)
/// Exécuté une seule fois pour résoudre les données corrompues
void _clearFirestoreCacheInBackground() {
  // Exécuter en arrière-plan sans bloquer main()
  Future.microtask(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheCleared = prefs.getBool('firestore_cache_cleared_v2') ?? false;

      if (!cacheCleared) {
        print("🧹 [Background] Nettoyage du cache Firestore (one-time fix)...");
        try {
          await FirebaseFirestore.instance.clearPersistence();
          print("✅ [Background] Cache Firestore nettoyé avec succès");
          await prefs.setBool('firestore_cache_cleared_v2', true);
        } catch (clearError) {
          print("⚠️ [Background] Erreur clear cache: $clearError");
        }
      }
    } catch (e) {
      print("⚠️ [Background] Erreur configuration Firestore: $e");
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure error widget for debugging
  // 🔧 FIX: Utiliser Container au lieu de MaterialApp+Scaffold pour éviter
  // les erreurs de layout avec contraintes infinies
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Log l'erreur pour le debugging
    debugPrint('🔴 ErrorWidget: ${details.exception}');
    debugPrint('🔴 Stack: ${details.stack}');

    return Container(
      color: Colors.red.withOpacity(0.9),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Text(
        'Error: ${details.exception}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
        textAlign: TextAlign.center,
      ),
    );
  };
  
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // ⚡ OPTIMISATION DÉMARRAGE RAPIDE: Firebase init avec timeout court (5s)
  // Si timeout, l'app démarre quand même et Firebase se connectera en arrière-plan
  bool firebaseInitialized = false;
  try {
    print("🚀 Starting Firebase initialization...");

    if (Firebase.apps.isEmpty) {
      print("🔧 Firebase.apps is empty, initializing...");
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 5), onTimeout: () {
          print("⚠️ Firebase initialization timed out (5s) - app will continue");
          throw TimeoutException("Firebase initialization timeout");
        });
        firebaseInitialized = true;
        print("✅ Firebase initialized successfully");
      } on TimeoutException {
        print("⚠️ Firebase timeout - continuing without blocking");
        // Réessayer en arrière-plan
        Future.microtask(() async {
          try {
            await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
            print("✅ Firebase initialized in background");
          } catch (e) {
            print("❌ Firebase background init failed: $e");
          }
        });
      } on FirebaseException catch (e) {
        if (e.code == 'duplicate-app') {
          firebaseInitialized = true;
          print("✅ Firebase already initialized by another service");
        } else {
          rethrow;
        }
      }
    } else {
      firebaseInitialized = true;
      print("✅ Firebase already initialized (${Firebase.apps.length} apps), skipping...");
    }
    
    // 🚀 OPTIMISATION: Analytics init en arrière-plan (gain ~500ms)
    // N'est pas critique pour l'affichage du splash
    print("🚀 Starting Analytics initialization (background)...");
    AnalyticsService.initialize().then((_) {
      print("✅ Firebase Analytics initialized successfully");
    }).catchError((e) {
      print("⚠️ Firebase Analytics init error: $e");
    });
    
    // Initialize Firebase services (AFTER Firebase+Analytics)
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      print("✅ Firebase Database persistence enabled");
    } catch (e) {
      print("⚠️ Could not enable Firebase Database persistence: $e");
    }

    // 🚀 OPTIMISATION: Firestore cache clear déplacé en arrière-plan (gain ~2-5s)
    // S'exécute sans bloquer le démarrage de l'app
    _clearFirestoreCacheInBackground();

    // Configurer Firestore persistence immédiatement
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      print("✅ Firestore persistence enabled");
    } catch (e) {
      print("⚠️ Could not configure Firestore: $e");
    }

    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      messaging.subscribeToTopic("all_devices");
      messaging.subscribeToTopic("all_customers");
      await FirebasePushNotifications.firebaseSetup();
      print("✅ Firebase Messaging configured");
    } catch (e) {
      print("⚠️ Firebase Messaging error: $e");
    }
  } catch (e) {
    print("❌ Firebase initialization error: $e");
    print("🔍 Error type: ${e.runtimeType}");
    print("🔍 Error details: ${e.toString()}");
    // Continue without Firebase for now - app should still start
  }

  // Configure EasyLoading with TwistingDots animation globally
  EasyLoading.instance
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorColor = MyColors.horizonBlue
    ..backgroundColor = Colors.transparent
    ..textColor = Colors.white
    ..maskType = EasyLoadingMaskType.none
    ..maskColor = Colors.transparent
    ..boxShadow = []
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..userInteractions = false;
  myCustomLogStatements("EasyLoading maskColor: ${Colors.transparent}");


  // --- Route booking status updates coming from push ---
  void _routeBookingPush(RemoteMessage message) {
    try {
      final raw = message.data;
      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);

      // Normalize payloads coming from different backends
      // Supported:
      //  - type=booking_status_update with status/bookingId
      //  - screen=booking_accepted/driver_reached/ride_started/ride_completed/ride_cancelled
      //  - id for booking id
      final String? type = data['type']?.toString();
      final String? screen = data['screen']?.toString();

      // Ensure bookingId key exists (applyBookingStatusFromPush expects bookingId/booking_id)
      if (data['bookingId'] == null && data['booking_id'] == null) {
        final dynamic id = data['id'];
        if (id != null) {
          data['bookingId'] = id.toString();
        } else {
          // Try to get the current booking ID from TripProvider
          final ctx = MyGlobalKeys.navigatorKey.currentContext;
          if (ctx != null) {
            try {
              final trip = Provider.of<TripProvider>(ctx, listen: false);
              if (trip.booking != null && trip.booking!['id'] != null) {
                data['bookingId'] = trip.booking!['id'].toString();
                myCustomPrintStatement('🔧 Using current booking ID from TripProvider: ${data['bookingId']}');
              }
            } catch (e) {
              myCustomPrintStatement('⚠️ Could not get booking ID from TripProvider: $e');
            }
          }
        }
      }

      // If we received the older payload style with only `screen`, map it to a status
      if ((data['status'] == null && data['booking_status'] == null) && screen != null) {
        switch (screen) {
          case 'booking_accepted':
            data['status'] = 'DRIVER_ACCEPTED';
            break;
          case 'driver_reached':
            data['status'] = 'DRIVER_REACHED';
            break;
          case 'ride_started':
            data['status'] = 'RIDE_STARTED';
            break;
          case 'ride_completed':
            data['status'] = 'RIDE_COMPLETE';
            break;
          case 'ride_cancelled':
            data['status'] = 'TRIP_CANCELLED';
            break;
        }
      }

      // Only route messages that appear to be booking updates
      final bool looksLikeBookingUpdate =
          type == 'booking_status_update' ||
          screen == 'booking_accepted' ||
          screen == 'driver_reached' ||
          screen == 'ride_started' ||
          screen == 'ride_completed' ||
          screen == 'ride_cancelled';

      if (looksLikeBookingUpdate) {
        final ctx = MyGlobalKeys.navigatorKey.currentContext;
        if (ctx != null) {
          final trip = Provider.of<TripProvider>(ctx, listen: false);
          trip.applyBookingStatusFromPush(data);
        }
      }
    } catch (e) {
      myCustomPrintStatement('❌ route booking push error: $e');
    }
  }

  // Foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage m) => _routeBookingPush(m));
  // App opened from background via notification tap
  FirebaseMessaging.onMessageOpenedApp
      .listen((RemoteMessage m) => _routeBookingPush(m));
  // Notification that launched the app from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((m) {
    if (m != null) _routeBookingPush(m);
  });

  await initializeDateFormatting("en_US", null);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => CustomAuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => GuestSessionProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => DarkThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => TripProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => TripChatProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => NavigationProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => GoogleMapProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => NotificationProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => OrangeMoneyPaymentGatewayProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => InternetConnectivityProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => TelmaMoneyPaymentGatewayProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => AirtelMoneyPaymentGatewayProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => AdminSettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => SavedPaymentMethodProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => PromocodesProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => WalletProvider(),
        ),
        // Providers pour les top-ups de portefeuille
        ChangeNotifierProvider(
          create: (context) => WalletTopUpCoordinatorProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => WalletTopUpAirtelProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => WalletTopUpOrangeProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => WalletTopUpTelmaProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => LoyaltyChestProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => GeoZoneProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DarkThemeProvider themeChangeProvider = DarkThemeProvider();
  StreamSubscription<Uri>? _linkSubscription;
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialiser AppLinks
    _appLinks = AppLinks();

    // Initialiser le listener pour les deep links
    _initDeepLinkListener();
    
    // Log app opened
    _logAppOpened();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      DarkThemeProvider themeChangeProv =
          Provider.of<DarkThemeProvider>(context, listen: false);
      GoogleMapProvider mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);

      int getDarkModeTheme = await DevFestPreferences().getDarkModeSetting();
      if (getDarkModeTheme == 1) {
        // Mode automatique: utiliser les vraies heures de lever/coucher du soleil
        final position = mapProvider.currentPosition;
        if (position != null) {
          final isNight = await SunriseSunsetService.isNightTime(
            latitude: position.latitude,
            longitude: position.longitude,
          );
          themeChangeProv.darkTheme = isNight;
        } else {
          // Fallback si pas de position GPS disponible
          final currentTime = DateTime.now();
          if (currentTime.hour >= 6 && currentTime.hour < 18) {
            themeChangeProv.darkTheme = false;
          } else {
            themeChangeProv.darkTheme = true;
          }
        }
      } else if (getDarkModeTheme == 3) {
        Brightness platformBrightness =
            MediaQuery.of(context).platformBrightness;
        if (platformBrightness == Brightness.dark) {
          themeChangeProv.darkTheme = true;
        } else {
          themeChangeProv.darkTheme = false;
        }
      } else if (getDarkModeTheme == 2) {
        themeChangeProv.darkTheme = true;
      } else {
        themeChangeProv.darkTheme = false;
      }
      myCustomPrintStatement(
          "my get current app theme ${themeChangeProv.darkTheme}");
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _logAppOpened();
    }
  }
  
  void _logAppOpened() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    
    await AnalyticsService.logAppOpened(
      userId: userId,
      appVersion: '2.1.0', // Version actuelle du pubspec.yaml
    );
  }

  /// Initialise le listener pour les deep links avec app_links
  void _initDeepLinkListener() {
    // Gérer les liens quand l'app est fermée ou en arrière-plan
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        myCustomPrintStatement("🔗 Deep link reçu: ${uri.toString()}");
        _handleDeepLink(uri.toString());
      },
      onError: (Object err) {
        myCustomPrintStatement("❌ Erreur deep link: $err");
      },
    );

    // Gérer le lien initial quand l'app s'ouvre via un lien
    _handleInitialLink();
  }

  /// Traite le lien initial quand l'app s'ouvre
  Future<void> _handleInitialLink() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        myCustomPrintStatement("🔗 Lien initial reçu: ${initialUri.toString()}");
        _handleDeepLink(initialUri.toString());
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors de la récupération du lien initial: $e");
    }
  }

  /// Traite un deep link reçu
  void _handleDeepLink(String link) {
    try {
      final Uri uri = Uri.parse(link);
      myCustomPrintStatement("🔍 Analyse du lien: ${uri.toString()}");

      // Vérifier si c'est un lien de partage de course en temps réel
      // Note: Le chemin peut être /live ou /live/ selon la redirection web
      if ((uri.host == 'misy-app.com' || uri.host == 'www.misy-app.com') &&
          (uri.path == '/live' || uri.path == '/live/')) {
        final String? rideId = uri.queryParameters['ride'];
        final String? token = uri.queryParameters['t'];

        if (rideId != null && token != null) {
          myCustomPrintStatement("🎯 Lien de partage détecté - ride: $rideId, token: $token");
          _navigateToLiveShareViewer(rideId, token);
        } else {
          myCustomPrintStatement("❌ Paramètres manquants dans le lien de partage");
        }
      } else {
        myCustomPrintStatement("ℹ️ Lien non reconnu: ${uri.toString()}");
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors du traitement du deep link: $e");
    }
  }

  /// Navigue vers l'écran de suivi en temps réel
  void _navigateToLiveShareViewer(String rideId, String token) {
    // Attendre que l'app soit complètement initialisée
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = MyGlobalKeys.navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LiveShareViewerScreen(
              rideId: rideId,
              token: token,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DarkThemeProvider>(
        builder: (BuildContext context, value, child) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: MyColors.transparent, // Transparent status bar
          systemNavigationBarColor: Colors.white.withOpacity(0.1),
          // systemNavigationBarColor: MyColors.transparent,
          // systemNavigationBarIconBrightness: .dark,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent

          // statusBarBrightness: Brightness.dark, // Dark text for status bar
          ));
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
          overlays: []);
      return ValueListenableBuilder(
          valueListenable: selectedLocale,
          builder: (context, languageCode, child) => MaterialApp(
                title: 'Misy', //continue....
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('en'),
                  Locale('fr'),
                  Locale('mg')
                ],
                locale: languageCode,
                localeResolutionCallback: (locale, supportedLocales) {
                  if (locale?.languageCode == 'mg') {
                    return Locale('fr'); // Fallback to French formatting
                  }
                  return supportedLocales.contains(locale)
                      ? locale
                      : Locale('en');
                },
                theme: Styles.themeData(value.darkTheme, context),
                debugShowCheckedModeBanner: false,
                navigatorKey: MyGlobalKeys.navigatorKey,
                navigatorObservers: [
                  if (AnalyticsService.observer != null) AnalyticsService.observer!,
                ],
                home: const SplashScreen(),
                routes: {
                  '/test-invoice': (context) => const TestInvoiceRegenerationPage(),
                },
                builder: EasyLoading.init(),
              ));
    });
  }
}
