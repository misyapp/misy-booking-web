import 'dart:async';
import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/navigation_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/provider/guest_session_provider.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import '../../utils/ios_map_fix.dart';
import '../../utils/map_utils.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_drawer.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/pickup_and_drop_location_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/schedule_ride_with_custom_time.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/flight_number_entry_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/confirm_destination.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/choose_vehicle_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/select_payment_method_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/request_for_ride.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/drive_on_way.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/payment_mobile_number_confirmation.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/select_available_promocode.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/auth_prompt_bottom_sheet.dart';
import 'package:rider_ride_hailing_app/widget/share_ride_bottom_sheet.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart';
import 'package:rider_ride_hailing_app/provider/orange_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/pages/view_module/open_payment_webview.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/widget/popular_destinations_widget.dart';
import 'package:rider_ride_hailing_app/widget/adaptive/adaptive.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:rider_ride_hailing_app/services/driver_snap_service.dart';

class HomeScreen extends StatefulWidget {
  final CustomTripType? initialTripType;
  const HomeScreen({super.key, this.initialTripType});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true; // 🎨 Garder le State vivant pour éviter reconstruction GoogleMap
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  // 🗺️ Key pour le GoogleMap - utilise un compteur statique pour forcer la recréation après hot restart
  static int _mapKeyCounter = 0;
  late Key _googleMapKey;
  late GoogleMapController _mapController;
  bool _isMapReady = false;
  late AnimationController _bottomSheetController;
  late Animation<double> _bottomSheetAnimation;

  // Animation pulsée pour le bouton de partage quand des viewers suivent
  late AnimationController _sharePulseController;
  late Animation<double> _sharePulseAnimation;

  // Quatre niveaux du bottom sheet (en pourcentage de la hauteur de l'écran)
  static const double _lowestBottomSheetHeight =
      0.10; // 10% - niveau le plus bas (recherche seule)
  static const double _minBottomSheetHeight = 0.30; // 30% - niveau bas (réduit)
  static const double _midBottomSheetHeight =
      0.55; // 55% - niveau moyen (réduit)
  static const double _maxBottomSheetHeight =
      0.78; // 78% - niveau presque plein écran (réduit)

  // Trois niveaux spécifiques pour l'écran chooseVehicle
  static const double _chooseVehicleMinHeight =
      0.38; // 38% - hauteur exacte pour: header (~55px) + 1 catégorie (~100px) + footer (~150px)
  static const double _chooseVehicleMidHeight =
      0.60; // 60% - niveau moyen pour voir ~3 catégories
  static const double _chooseVehicleMaxHeight =
      0.85; // 85% - niveau maximum pour voir toutes les catégories

  // Hauteur fixe pour confirmDestination (bas, fixe, pas de drag)
  static const double _confirmDestinationHeight =
      0.35; // 35% - titre + adresse + bouton (tout visible sans scroll)

  // Hauteur pour requestForRide (recherche chauffeurs)
  static const double _requestForRideHeight =
      0.58; // 58% - même hauteur que driverOnWay pour cohérence

  // Hauteur pour driverOnWay (chauffeur assigné en route)
  static const double _driverOnWayHeight =
      0.58; // 58% - afficher tous les éléments (infos chauffeur, véhicule, prix, chat, bouton annulation)

  double _currentBottomSheetHeight = _midBottomSheetHeight; // Démarrer à 55%
  double _previousBottomSheetHeight = _midBottomSheetHeight;
  LatLng? _mapReferencePosition; // Position de référence pour le centrage
  PaymentMethodType? selectedPaymentMethod;

  // 📍 Protection contre les appels multiples de géocodage
  bool _isProcessingPriceUpdate = false;
  CameraPosition? cameraLastPosition;
  bool loaded = false;
  double _mapBottomPadding = 0.0;
  bool _hasRecenteredForDriverTracking =
      false; // Pour éviter les recentrages répétés
  // 🛰️ Toggle pour la vue satellite en mode "Définir lieu sur la carte"
  bool _locationPickerSatelliteView = false;
  // Pour centrer la carte entre chauffeur et pickup une seule fois par transition
  bool _hasCenteredDriverToPickup = false;
  // Timestamp de la dernière animation de caméra pour éviter les animations multiples
  DateTime? _lastCameraAnimationTime;

  // 🎯 Mode libre de navigation sur la carte
  // Quand l'utilisateur navigue manuellement sur la carte, on désactive le suivi GPS
  // Le bouton de recentrage permet de revenir au mode suivi
  bool _isUserNavigatingMap = false;

  // 🎯 Flag pour distinguer les mouvements de caméra programmatiques des mouvements utilisateur
  // Utilisé pour éviter que animateCamera() déclenche onCameraMoveStarted et réactive le mode libre
  bool _isProgrammaticCameraMove = false;

  // 🎯 Timestamp du dernier clic GPS pour ignorer les onCameraMoveStarted parasites
  // Google Maps peut appeler onCameraMoveStarted plusieurs fois après une animation (chargement tuiles, etc.)
  DateTime? _lastGpsButtonClickTime;

  // 🎯 Timestamp d'initialisation de l'écran pour ignorer les onCameraMoveStarted au démarrage
  // Les premiers recentrages automatiques ne doivent pas activer le mode libre
  DateTime? _screenInitTime;

  // 🎯 GlobalKey pour PopularDestinations - préserve l'état lors des rebuilds
  // Évite le "saut" des adresses populaires lors des changements de hauteur du bottom sheet
  final GlobalKey _popularDestinationsKey = GlobalKey();

  // 🛡️ État du bouton de partage en forme de bouclier
  bool _isShareButtonExpanded = false;

  // 🍎 iOS Liquid Glass: État et extent pour le bottom sheet avec nav bar intégrée
  // L'extent va de 0.0 (collapsed = nav bubble) à 1.0 (expanded = 90%)
  double _iosSheetExtent = 0.0;
  // État discret pour le contenu (0=collapsed, 1=intermediate, 2=expanded)
  int _iosSheetState = 0;
  // 🍎 Flag pour activer l'animation (désactivé pendant le drag)
  bool _iosSheetAnimating = false;
  // 🍎 Tab bar minimize: shrink au scroll down, expand au scroll up
  bool _isNavBarMinimized = false;
  // 🍎 Nav bar interactive: effet de pression et glissement
  bool _navBarPressed = false;
  int _navBarHoverIndex = -1; // Index du bouton sous le doigt (-1 = aucun)
  double _navBarDragX = 0.0; // Position X du doigt pour l'indicateur
  double _lastScrollOffset = 0.0;
  final ScrollController _iosContentScrollController = ScrollController();

  /// Centre précisément l'itinéraire entre le chauffeur et le pickup,
  /// dans la zone visible au-dessus du bottom sheet.
  Future<void> _fitDriverToPickupVisibleAboveBottomView(
    LatLng driverPosition,
    LatLng pickupPosition,
  ) async {
    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    final controller = mapProvider.controller;
    if (controller == null) return;

    try {
      // 🔹 Calculer les limites entre chauffeur et pickup
      final double minLat = math.min(driverPosition.latitude, pickupPosition.latitude);
      final double maxLat = math.max(driverPosition.latitude, pickupPosition.latitude);
      final double minLng = math.min(driverPosition.longitude, pickupPosition.longitude);
      final double maxLng = math.max(driverPosition.longitude, pickupPosition.longitude);

      // 🔹 Calculer les dimensions de l'écran et du bottom sheet
      final screenHeight = MediaQuery.of(context).size.height;

      // Le bottom sheet occupe _currentBottomSheetHeight (ratio 0.55 à 0.78)
      final bottomSheetHeightPx = screenHeight * _currentBottomSheetHeight;
      // Zone visible = hauteur écran - bottom sheet - status bar/app bar (environ 50px)
      final visibleMapHeight = screenHeight - bottomSheetHeightPx - 50;

      myCustomPrintStatement(
          '🎯 Centrage chauffeur→pickup: screenH=${screenHeight.toInt()}, bottomSheet=${bottomSheetHeightPx.toInt()}px, visibleMap=${visibleMapHeight.toInt()}px');

      // 🔹 Ajouter un padding aux bounds (15% de marge)
      final latSpan = maxLat - minLat;
      final lngSpan = maxLng - minLng;
      final latPadding = latSpan * 0.15;
      final lngPadding = lngSpan * 0.15;

      // 🔹 Étendre les bounds vers le SUD pour compenser le bottom sheet
      // Le ratio du bottom sheet par rapport à l'écran détermine l'extension nécessaire
      final bottomSheetRatio = _currentBottomSheetHeight;
      final southExtension = latSpan * bottomSheetRatio * 1.5; // Extension vers le sud

      final adjustedBounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding - southExtension, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      // 🔹 Padding latéral pour éviter que les markers soient coupés par les bords
      const double horizontalPadding = 40.0;

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          adjustedBounds,
          horizontalPadding,
        ),
      );

      myCustomPrintStatement(
          '🎯 Chauffeur → Pickup centré (southExtension=${southExtension.toStringAsFixed(5)})');
    } catch (e) {
      myCustomPrintStatement(
          '❌ Erreur fitDriverToPickupVisibleAboveBottomView: $e');
    }
  }
  int? _lastBookingStatus; // Pour détecter les changements de statut
  Timer? _driverTrackingTimer; // Timer pour le suivi continu du chauffeur
  bool _hasAppliedInitialDriverFit = false;
  // Variables pour l'écoute des chauffeurs proches
  Stream<QuerySnapshot>? usersStream; // Stream pour écouter les chauffeurs
  StreamSubscription<QuerySnapshot>? _driversSubscription;
  CustomTripType? _lastKnownStep;
  List<DriverModal> allDrivers = []; // Liste des chauffeurs proches

  // Variables pour le suivi direct du doigt
  double? _panStartY;
  double? _panStartHeight;

  // Variables pour le debouncing du recentrage
  Timer? _recenterDebounceTimer;
  bool _isCurrentlyRecentering = false;

  @override
  void initState() {
    super.initState();

    // 🗺️ Générer une clé unique pour le GoogleMap basée sur le timestamp
    // Cela force la recréation de la platform view et évite l'erreur "recreating_view" sur iOS
    _mapKeyCounter++;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _googleMapKey = ValueKey('google_map_${timestamp}_$_mapKeyCounter');
    myCustomPrintStatement('🗺️ GoogleMap key générée: google_map_${timestamp}_$_mapKeyCounter');

    // 🎯 Enregistrer le timestamp d'initialisation pour ignorer les mouvements de caméra au démarrage
    _screenInitTime = DateTime.now();

    WidgetsBinding.instance.addObserver(this);
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bottomSheetAnimation = Tween<double>(
      begin: _minBottomSheetHeight,
      end: _currentBottomSheetHeight,
    ).animate(CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
    ));

    // Animation pulsée pour le bouton de partage (quand des viewers suivent)
    _sharePulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _sharePulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _sharePulseController, curve: Curves.easeInOut),
    );
    _sharePulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _sharePulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _sharePulseController.forward();
      }
    });

    // 🍎 iOS: Listener pour tab bar minimize au scroll (Apple Liquid Glass)
    if (Platform.isIOS) {
      _iosContentScrollController.addListener(_onIOSContentScroll);
    }

    // Initialiser le TripProvider avec vérification de course active
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final navProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);

      // 🚀 OPTIMISATION: Lancer getLocation() en parallèle immédiatement
      final locationFuture = getLocation();

      // Vérifier d'abord s'il y a une course active à restaurer
      CustomTripType? initialType = widget.initialTripType;
      if (initialType == null) {
        // Vérifier s'il y a une course active (cela définit aussi le booking si trouvé)
        initialType = await tripProvider.checkForActiveTrip();
        myCustomPrintStatement(
            '🔍 HomeScreen: Résultat vérification course active: $initialType');
        myCustomPrintStatement(
            '🔍 HomeScreen: booking après checkForActiveTrip: ${tripProvider.booking != null ? tripProvider.booking!['id'] : 'null'}');
      }

      // Utiliser l'état par défaut si aucune course active
      initialType ??= CustomTripType.setYourDestination;

      // Si currentStep est déjà défini (ex: depuis postFrameCallback d'un autre écran),
      // ne pas le changer sauf si on a une course active à restaurer ou un initialType explicite
      if (tripProvider.currentStep != null &&
          tripProvider.currentStep != CustomTripType.setYourDestination &&
          widget.initialTripType == null &&
          initialType == CustomTripType.setYourDestination) {
        myCustomPrintStatement(
            '🔍 HomeScreen: currentStep déjà défini (${tripProvider.currentStep}), pas de changement');
      } else {
        // Appeler setScreen pour définir l'état
        tripProvider.setScreen(initialType);
      }

      // Log pour debug
      myCustomPrintStatement(
          '🔍 HomeScreen: currentStep après setScreen: ${tripProvider.currentStep}');
      myCustomPrintStatement(
          '🔍 HomeScreen: booking après setScreen: ${tripProvider.booking != null ? tripProvider.booking!['id'] : 'null'}');

      if (initialType == CustomTripType.setYourDestination) {
        navProvider.setNavigationBarVisibility(true);
        _updateBottomSheetHeight(_midBottomSheetHeight); // Démarrer à 55%
      } else if (initialType == CustomTripType.driverOnWay) {
        // Pour une course active restaurée, vérifier si c'est un écran de paiement
        navProvider.setNavigationBarVisibility(false);

        // Si c'est une course terminée (status 4 ou 5), utiliser la hauteur maximale pour le paiement
        bool isPaymentScreen = tripProvider.booking != null &&
            (tripProvider.booking!['status'] ==
                    BookingStatusType.DESTINATION_REACHED.value ||
                (tripProvider.booking!['status'] ==
                        BookingStatusType.RIDE_COMPLETE.value &&
                    tripProvider.booking!['paymentStatusSummary'] == null));

        if (isPaymentScreen) {
          myCustomPrintStatement(
              '💳 HomeScreen: Course terminée détectée, utilisation hauteur maximale');
          _updateBottomSheetHeight(_maxBottomSheetHeight);

          // S'assurer que l'interface est mise à jour après un court délai
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              myCustomPrintStatement(
                  '💳 HomeScreen: Mise à jour forcée de l\'interface');
              setState(() {});
            }
          });
        } else {
          _updateBottomSheetHeight(_midBottomSheetHeight);
        }
      } else {
        // Pour les autres cas (ex: "Réserver une course"), masquer la barre et ajuster le panneau
        navProvider.setNavigationBarVisibility(false);
        _updateBottomSheetHeight(_midBottomSheetHeight);
      }

      // Initialiser le portefeuille automatiquement si l'utilisateur est connecté ET si la feature est activée
      if (userData.value?.id != null &&
          FeatureToggleService.instance.isDigitalWalletEnabled()) {
        myCustomPrintStatement(
            'HomeScreen: Initializing wallet for user: ${userData.value?.id}');
        walletProvider
            .initializeWallet(userData.value!.id!)
            .catchError((error) {
          myCustomPrintStatement(
              'HomeScreen: Error initializing wallet: $error');
        });
      } else if (userData.value?.id != null) {
        myCustomPrintStatement(
            'HomeScreen: Digital wallet is disabled, skipping wallet initialization');
      }

      // 📬 Écouter les messages non lus dans riderMessages
      if (userData.value?.id != null) {
        FirebaseFirestore.instance
            .collection('riderMessages')
            .where('recipientIds', arrayContains: userData.value!.id)
            .snapshots()
            .listen((snapshot) {
          // Compter les messages non lus (pas dans readBy ET pas archivés)
          final unreadMessages = snapshot.docs.where((doc) {
            final data = doc.data();
            final readBy = data['readBy'] as List<dynamic>?;
            final archivedBy = data['archivedBy'] as List<dynamic>?;

            final isRead = readBy != null && readBy.contains(userData.value!.id);
            final isArchived = archivedBy != null && archivedBy.contains(userData.value!.id);

            return !isRead && !isArchived;
          }).length;

          unreadMessagesCount.value = unreadMessages;
          myCustomPrintStatement('📬 Messages non lus: $unreadMessages');
        });
      }

      // 🚀 OPTIMISATION: _initializeMapReference() est déjà appelé dans initState()
      // Pas besoin de le rappeler ici pour éviter la double initialisation

      // 🚀 OPTIMISATION: getLocation() déjà lancé en parallèle au début (ligne 227)

      // 🚀 FIX CRITIQUE: Initialiser l'écoute des chauffeurs IMMÉDIATEMENT
      // Ne PAS attendre le GPS qui peut bloquer en mode invité
      // Lancement sans delay pour affichage instantané des markers
      try {
        myCustomPrintStatement(
            '🚗 Initialisation IMMÉDIATE de l\'écoute des chauffeurs (sans attendre GPS)');
        setUserStream(); // Sans await pour ne pas bloquer
        myCustomPrintStatement('✅ Écoute chauffeurs démarrée');
      } catch (e) {
        myCustomPrintStatement(
            '❌ Erreur initialisation chauffeurs: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bottomSheetController.dispose();
    _sharePulseController.dispose();
    _iosContentScrollController.dispose(); // 🍎 iOS scroll controller
    _recenterDebounceTimer?.cancel(); // Nettoyer le timer de debounce
    _stopContinuousDriverTracking(); // Arrêter le suivi continu
    _driversSubscription?.cancel();
    usersStream = null; // Nettoyer le stream des chauffeurs
    allDrivers.clear(); // Vider la liste des chauffeurs
    super.dispose();
  }

  /// 🍎 iOS: Détecte la direction du scroll pour minimiser/expand la nav bar
  /// Apple: "Tab bars recede when scrolling down, expand when scrolling up"
  void _onIOSContentScroll() {
    if (!Platform.isIOS || _iosSheetState == 0) return;

    final currentOffset = _iosContentScrollController.offset;
    final delta = currentOffset - _lastScrollOffset;

    // Seuil de scroll pour déclencher le changement (évite les micro-mouvements)
    const threshold = 10.0;

    if (delta > threshold && !_isNavBarMinimized) {
      // Scroll down → minimize
      setState(() {
        _isNavBarMinimized = true;
      });
    } else if (delta < -threshold && _isNavBarMinimized) {
      // Scroll up → expand
      setState(() {
        _isNavBarMinimized = false;
      });
    }

    _lastScrollOffset = currentOffset;
  }


  void _updateBottomSheetHeight(double newHeight) {
    _previousBottomSheetHeight = _currentBottomSheetHeight;

    // Forcer le snap exact vers les valeurs définies
    // Évite les problèmes de précision float qui causeraient un positionnement "entre deux"
    double snappedHeight = newHeight;
    // 💳 Plein écran (100%) pour paymentMobileConfirm
    if ((newHeight - 1.0).abs() < 0.03) {
      snappedHeight = 1.0;
    } else if ((newHeight - _maxBottomSheetHeight).abs() < 0.03) {
      snappedHeight = _maxBottomSheetHeight;
    } else if ((newHeight - _driverOnWayHeight).abs() < 0.03) {
      snappedHeight = _driverOnWayHeight;
    } else if ((newHeight - _midBottomSheetHeight).abs() < 0.03) {
      snappedHeight = _midBottomSheetHeight;
    } else if ((newHeight - _requestForRideHeight).abs() < 0.03) {
      snappedHeight = _requestForRideHeight;
    } else if ((newHeight - _minBottomSheetHeight).abs() < 0.03) {
      snappedHeight = _minBottomSheetHeight;
    } else if ((newHeight - _confirmDestinationHeight).abs() < 0.03) {
      snappedHeight = _confirmDestinationHeight;
    } else if ((newHeight - _lowestBottomSheetHeight).abs() < 0.03) {
      snappedHeight = _lowestBottomSheetHeight;
    }

    setState(() {
      _currentBottomSheetHeight = snappedHeight;
    });

    // NE PAS recentrer automatiquement la carte lors du changement de hauteur du bottom sheet
    // L'utilisateur doit pouvoir naviguer librement sur la carte
    // Le bouton de recentrage GPS permet de revenir sur sa position si souhaité

    // Adapter la carte pour que l'itinéraire reste visible au-dessus de la fenêtre
    _applyMapPadding();
  }

  void _applyMapPadding() {
    if (!mounted) return;
    try {
      final h = MediaQuery.of(context).size.height;
      final bottomPadding =
          (h * _currentBottomSheetHeight).clamp(0.0, h).toDouble();
      // Respecter la contrainte Google Maps: le padding doit être inférieur à la moitié de la hauteur
      final maxAllowedPadding =
          (h / 2) - 10.0; // Google Maps Android constraint
      // Laisser un léger espace de 8px en plus mais respecter la contrainte
      final finalPadding = (bottomPadding + 8.0).clamp(0.0, maxAllowedPadding);
      setState(() {
        _mapBottomPadding = finalPadding;
      });
    } catch (_) {}
  }

  /// Méthode alternative pour obtenir les coordonnées exactement sous la pointe de l'épingle
  /// Utilise la projection écran → LatLng pour une précision maximale
  Future<LatLng?> _getLatLngUnderPinTip() async {
    try {
      if (!_isMapReady) return null;

      final size = MediaQuery.of(context).size;
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

      // Position de la pointe de l'épingle (centre ajusté par le padding de la carte)
      // Convertir en coordonnées écran physiques
      final centerX = (size.width / 2) * devicePixelRatio;
      final centerY = ((size.height / 2) - (_mapBottomPadding / 2)) *
          devicePixelRatio; // Ajusté par le padding

      // Convertir les coordonnées écran en LatLng
      final latLng = await _mapController
          .getLatLng(ScreenCoordinate(x: centerX.round(), y: centerY.round()));

      return latLng;
    } catch (e) {
      myCustomPrintStatement('Erreur lors de la projection écran → LatLng: $e');
      return null;
    }
  }

  /// Méthode publique pour récupérer les coordonnées sous la pointe de l'épingle
  /// Avec fallback automatique entre méthode camera.target et projection écran
  Future<LatLng?> getLocationUnderPin() async {
    // Méthode principale : utiliser la position de la caméra (plus rapide)
    if (cameraLastPosition != null) {
      return cameraLastPosition!.target;
    }

    // Fallback : utiliser la projection écran si pas de position caméra disponible
    return await _getLatLngUnderPinTip();
  }

  /// Détermine si l'itinéraire doit être adapté pour l'étape courante
  bool _shouldAdaptRouteForCurrentStep(CustomTripType? currentStep) {
    // Toutes les étapes où l'itinéraire pickup→dropoff complet doit rester visible
    const routeVisibleSteps = {
      // ❌ CustomTripType.chooseVehicle RETIRÉ - géré par _triggerChooseVehicleRouteAnimation
      //    avec la nouvelle méthode fitRouteAboveBottomSheet (FitBounds + ScrollBy)
      // ❌ CustomTripType.confirmDestination RETIRÉ - géré par _centerOnPickupLocation
      //    qui centre sur le point de prise en charge avec zoom fort (pas d'itinéraire)
      CustomTripType.payment, // "Choisir le mode de paiement" - utilise délai 800ms
      CustomTripType
          .requestForRide, // "Mise en relations avec les chauffeurs à proximité" & "Recherche de chauffeur à proximité"
      // ❌ CustomTripType.driverOnWay retiré - gestion spéciale driver→pickup uniquement
    };

    return currentStep != null && routeVisibleSteps.contains(currentStep);
  }

  /// Vérifie si une position GPS est valide (plus permissive pour développement)
  bool _isValidGpsPosition(LatLng? position) {
    if (position == null) return false;
    // Validation basique : coordonnées dans les limites terrestres
    return position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180;
  }

  /// Obtient la position GPS réelle de l'utilisateur
  /// Retourne null si aucune position GPS n'est disponible (affichera le globe)
  LatLng? _getRealGpsPosition(GoogleMapProvider mapProvider) {
    // 1. Position actuelle utilisateur globale (currentPosition) - GPS en direct
    if (currentPosition != null &&
        _isValidGpsPosition(
            LatLng(currentPosition!.latitude, currentPosition!.longitude))) {
      return LatLng(currentPosition!.latitude, currentPosition!.longitude);
    }

    // 2. Position du mapProvider actuelle (GPS en direct via provider)
    if (mapProvider.currentPosition != null &&
        _isValidGpsPosition(mapProvider.currentPosition)) {
      return mapProvider.currentPosition!;
    }

    // 3. Dernière position GPS sauvegardée (SharedPreferences) - vraie position, pas un fallback fictif
    if (mapProvider.initialPosition != null &&
        _isValidGpsPosition(mapProvider.initialPosition)) {
      return mapProvider.initialPosition!;
    }

    // Pas de position GPS disponible → globe
    return null;
  }

  /// Position initiale pour la carte - GPS réel, ou position d'attente centrée sur Madagascar
  LatLng _getInitialMapPosition(GoogleMapProvider mapProvider) {
    final gpsPosition = _getRealGpsPosition(mapProvider);
    if (gpsPosition != null) {
      return gpsPosition;
    }
    // Pas encore de GPS → centrer sur Madagascar en attendant (sera recentré quand GPS arrive)
    return const LatLng(-18.9, 47.5);
  }

  /// Zoom initial - toujours un zoom raisonnable, sera ajusté quand GPS arrive
  double _getInitialZoom(GoogleMapProvider mapProvider) {
    final gpsPosition = _getRealGpsPosition(mapProvider);
    // Si GPS disponible → zoom 15, sinon zoom 12 en attendant (pas le globe)
    return gpsPosition != null ? 15.0 : 12.0;
  }

  void _initializeMapReference() {
    // 🎯 Utiliser la position GPS actuelle si disponible
    if (currentPosition != null) {
      _mapReferencePosition = LatLng(currentPosition!.latitude, currentPosition!.longitude);
      print("Position de référence initiale (GPS actuel): $_mapReferencePosition");
    } else {
      // Pas de fallback - attendre le GPS
      print("⚠️ Position de référence: en attente du GPS");
    }
  }

  void _initializeMapReferenceFromMap(GoogleMapController controller) async {
    try {
      // Récupérer la position actuelle de la caméra
      final cameraPosition = await controller.getVisibleRegion();
      final centerLat = (cameraPosition.southwest.latitude +
              cameraPosition.northeast.latitude) /
          2;
      final centerLng = (cameraPosition.southwest.longitude +
              cameraPosition.northeast.longitude) /
          2;

      _mapReferencePosition = LatLng(centerLat, centerLng);
      print(
          "Position de référence initialisée depuis la carte: $_mapReferencePosition");
    } catch (e) {
      print("Erreur lors de l'initialisation de la référence: $e");
      // Fallback sur la position par défaut
      _mapReferencePosition = const LatLng(48.8566, 2.3522);
    }
  }

  void _centerMapToReference() {
    if (!_isMapReady) return;
    if (_mapReferencePosition == null) {
      print("Position de référence nulle, centrage annulé");
      return;
    }

    // 🎯 FIX: Ne pas recentrer si l'utilisateur navigue librement sur la carte
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    if (_isUserNavigatingMap &&
        tripProvider.currentStep == CustomTripType.setYourDestination &&
        tripProvider.booking == null) {
      myCustomPrintStatement('🗺️ _centerMapToReference ignoré - utilisateur en mode libre');
      return;
    }

    // Annuler le timer précédent s'il existe
    _recenterDebounceTimer?.cancel();

    // Éviter les recentrages multiples simultanés
    if (_isCurrentlyRecentering) {
      print("🚫 Recentrage en cours, nouveau recentrage ignoré");
      return;
    }

    // PROTECTION iOS : Éviter le recentrage sur les écrans de paiement
    bool isPaymentScreen = tripProvider.currentStep == CustomTripType.payment ||
        tripProvider.currentStep == CustomTripType.confirmDestination ||
        tripProvider.currentStep == CustomTripType.paymentMobileConfirm;

    if (isPaymentScreen) {
      myCustomPrintStatement(
          '🍎 iOS Protection: _centerMapToReference bloqué sur écran de paiement');
      return;
    }

    // Debounce le recentrage pour éviter les appels trop fréquents
    _recenterDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _debouncedCenterMapToReference();
    });
  }

  void _debouncedCenterMapToReference() async {
    if (_isCurrentlyRecentering || !mounted) return;

    _isCurrentlyRecentering = true;

    try {
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);
      final screenHeight = MediaQuery.of(context).size.height;

      print(
          "🎯 Centrage doux vers référence: $_mapReferencePosition, hauteur: $_currentBottomSheetHeight");

      // PROTECTION iOS ULTIME : Sur iOS, ne jamais appeler centerMapToAbsolutePosition
      // Cette méthode cause le dézoom extrême, utiliser un centrage simple à la place
      if (Platform.isIOS) {
        myCustomPrintStatement(
            '🍎 iOS Protection ULTIME: Utilisation centrage doux optimisé');
        await _smoothRecenterMapBasedOnBottomSheetHeight();
      } else {
        // Pour Android, utiliser une version douce aussi pour éviter les freezes
        await _smoothRecenterMapBasedOnBottomSheetHeight();
      }
    } catch (e) {
      print('❌ Erreur lors du recentrage doux: $e');
    } finally {
      _isCurrentlyRecentering = false;
    }
  }

  // Calculer l'opacité de la couverture blanche basée sur la position du bottom sheet
  double _calculateWhiteOverlayOpacity() {
    if (_currentBottomSheetHeight <= _midBottomSheetHeight) {
      return 0.0; // Pas de couverture en dessous de 60%
    }
    // Transition progressive de 60% à 80%
    final progress = (_currentBottomSheetHeight - _midBottomSheetHeight) /
        (_maxBottomSheetHeight - _midBottomSheetHeight);
    return progress.clamp(0.0, 1.0);
  }

  /// Retourne la hauteur actuelle du bottom sheet en pixels selon la plateforme
  double _getCurrentSheetHeightPixels(double screenHeight) {
    if (Platform.isIOS) {
      // Utilise _iosSheetExtent pour iOS
      const double collapsedHeight = 56.0;
      final double intermediateHeight = screenHeight * LiquidGlassColors.intermediateHeightRatio;
      final double expandedHeight = screenHeight * LiquidGlassColors.expandedHeightRatio;

      if (_iosSheetExtent <= 0.10) {
        // État collapsed : hauteur fixe
        return collapsedHeight;
      } else if (_iosSheetExtent <= 0.70) {
        // État intermediate : hauteur fixe 60%
        return intermediateHeight;
      } else {
        // État expanded : interpolation vers 90%
        final t = (_iosSheetExtent - 0.70) / 0.30;
        return intermediateHeight + (expandedHeight - intermediateHeight) * t;
      }
    } else {
      // Android utilise _currentBottomSheetHeight (ratio)
      return screenHeight * _currentBottomSheetHeight;
    }
  }

  getLocation() async {
    var tripProvider = Provider.of<TripProvider>(context, listen: false);
    if (positionStream == null) {
      bool isFirstLocation = true;
      startLocationListner(() async {
        if (loaded == false) {
          loaded = true;
        }
        tripProvider.locationChange();

        // 🎯 Centrer la carte et masquer le placeholder dès réception du premier GPS
        // Avec debounce pour éviter les animations multiples (si resetHomeView a déjà animé)
        if (isFirstLocation && currentPosition != null && _isMapReady) {
          isFirstLocation = false;

          // Vérifier si une animation a eu lieu récemment (debounce 1 seconde)
          final now = DateTime.now();
          if (_lastCameraAnimationTime != null &&
              now.difference(_lastCameraAnimationTime!).inMilliseconds < 1000) {
            myCustomPrintStatement('🎯 GPS: Animation ignorée (debounce actif)');
            setState(() {});
            return;
          }

          // Centrer immédiatement sur la position GPS
          final target = LatLng(currentPosition!.latitude, currentPosition!.longitude);
          _mapReferencePosition = target;
          _lastCameraAnimationTime = now;

          await _mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: target, zoom: 15.0),
            ),
          );

          // GPS reçu - mise à jour effectuée
          setState(() {});

          myCustomPrintStatement('✅ GPS reçu → Carte centrée et placeholder masqué');
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Vérifier que le widget est toujours monté avant d'accéder au context
    if (!mounted) return;

    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    // 🔄 Gestion de la pause/reprise de la recherche de chauffeur
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App passe en arrière-plan → pauser la recherche si en cours
      myCustomPrintStatement('📱 App passant en arrière-plan - vérification pause recherche');
      await tripProvider.pauseDriverSearch();
    }

    if (state == AppLifecycleState.resumed) {
      myCustomPrintStatement('📱 App revenue au premier plan');

      // 🔧 FIX: Vérifier s'il y a une course active dans Firestore
      // Cela permet de restaurer le flow de course si l'app était en arrière-plan
      if (tripProvider.booking == null && tripProvider.currentStep == CustomTripType.setYourDestination) {
        myCustomPrintStatement('🔍 Aucun booking actif - vérification Firestore...');
        tripProvider.checkForActiveTrip().then((activeTrip) {
          if (activeTrip != null && mounted) {
            myCustomPrintStatement('🚗 Course active restaurée depuis Firestore: $activeTrip');
            updateBottomSheetHeight();
          }
        }).catchError((e) {
          myCustomPrintStatement('⚠️ Erreur vérification course active: $e');
        });
      }

      // Vérifier si une recherche était pausée
      if (tripProvider.isSearchPaused) {
        myCustomPrintStatement('⏸️ Recherche pausée détectée - affichage dialog de confirmation');

        // Vérifier si la recherche a expiré
        if (tripProvider.isPausedSearchExpired()) {
          myCustomPrintStatement('⏰ Recherche expirée - annulation automatique');
          tripProvider.cancelPausedSearch();
          _showSearchExpiredSnackbar();
        } else {
          // Afficher le dialog de confirmation
          _showResumeSearchDialog();
        }
      }

      // Gestion existante des permissions de localisation
      if (locationPopUpOpend) {
        updateBottomSheetHeight();
        PermissionStatus m1;
        if (Platform.isAndroid) {
          m1 = await Permission.locationWhenInUse.status;
        } else {
          m1 = await Permission.locationWhenInUse.request();
        }
        if (Platform.isAndroid &&
            (m1 == PermissionStatus.denied) &&
            locationPopUpOpend) {
          showPermissionNeedPopup();
        } else if (Platform.isIOS &&
            (m1 == PermissionStatus.denied ||
                m1 == PermissionStatus.permanentlyDenied) &&
            locationPopUpOpend) {
          ask();
        }
      }
    }
  }

  /// Affiche un dialog pour confirmer la reprise de la recherche de chauffeur
  void _showResumeSearchDialog() {
    if (!mounted) return;

    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(translate("searchPausedTitle")),
          content: Text(translate("searchPausedMessage")),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                tripProvider.cancelPausedSearch();
                // Retourner à l'écran d'accueil
                tripProvider.setScreen(CustomTripType.setYourDestination);
              },
              child: Text(translate("cancelSearch")),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final success = await tripProvider.resumeDriverSearch();
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(translate("resumeSearchFailed")),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(translate("resumeSearch")),
            ),
          ],
        );
      },
    );
  }

  /// Affiche un snackbar indiquant que la recherche a expiré
  void _showSearchExpiredSnackbar() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(translate("searchExpiredMessage")),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Méthodes publiques pour maintenir la compatibilité avec l'ancien HomeScreen
  void updateBottomSheetHeight({int milliseconds = 300}) {
    // Détecter automatiquement si c'est un écran de paiement
    Future.delayed(Duration(milliseconds: milliseconds), () {
      double targetHeight = _midBottomSheetHeight; // Par défaut

      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      // PROTECTION iOS : Ne pas recentrer la carte sur les écrans de paiement
      bool isPaymentRelatedScreen =
          tripProvider.currentStep == CustomTripType.payment ||
              tripProvider.currentStep == CustomTripType.confirmDestination ||
              tripProvider.currentStep == CustomTripType.paymentMobileConfirm;

      // Accès au NavigationProvider pour gérer la visibilité de la barre
      final navProvider = Provider.of<NavigationProvider>(context, listen: false);

      // Écran d'accueil : bottom sheet à 55%
      if (tripProvider.currentStep == CustomTripType.setYourDestination &&
          tripProvider.booking == null) {
        targetHeight = _midBottomSheetHeight;
        navProvider.setNavigationBarVisibility(true); // Barre de navigation visible
        myCustomPrintStatement(
            '🏠 updateBottomSheetHeight: Écran d\'accueil - Hauteur moyenne (55%)');

        // 🧹 Nettoyer la carte si un polyline était affiché (retour après recherche/course)
        // Ne pas nettoyer si un partage en temps réel est actif (LiveShareViewerScreen est affiché)
        final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
        if ((mapProvider.polylineCoordinates.isNotEmpty || mapProvider.markers.isNotEmpty) &&
            !tripProvider.isLiveShareActive) {
          myCustomPrintStatement('🧹 Nettoyage carte: polylines et markers présents, appel resetHomeView');
          resetHomeView();
        }
      }
      // Écran chooseVehicle : bottom sheet à 55% par défaut
      else if (tripProvider.currentStep == CustomTripType.chooseVehicle) {
        targetHeight = _chooseVehicleMidHeight;
        navProvider.setNavigationBarVisibility(false); // Masquer la barre pour afficher le bouton retour
        myCustomPrintStatement(
            '🚗 updateBottomSheetHeight: Écran chooseVehicle - Hauteur moyenne (55%)');
      }
      // 📍 Écran confirmDestination : bottom sheet bas et fixe (pas de drag)
      else if (tripProvider.currentStep == CustomTripType.confirmDestination) {
        targetHeight = _confirmDestinationHeight;
        navProvider.setNavigationBarVisibility(false);
        myCustomPrintStatement(
            '📍 updateBottomSheetHeight: Écran confirmDestination - Hauteur basse fixe (35%)');

        // 🎯 Centrer la carte sur le pickup pour que le pin flottant soit dessus
        _centerMapOnPickupForConfirmation(tripProvider);
      }
      // 🔍 Écran requestForRide : bottom sheet intermédiaire pour voir chauffeurs
      else if (tripProvider.currentStep == CustomTripType.requestForRide) {
        targetHeight = _requestForRideHeight;
        navProvider.setNavigationBarVisibility(false);
        myCustomPrintStatement(
            '🔍 updateBottomSheetHeight: Écran requestForRide - Hauteur intermédiaire (45%)');
      }
      // Définir la hauteur maximale pour les écrans de paiement explicites
      else if (tripProvider.currentStep == CustomTripType.payment ||
          tripProvider.currentStep == CustomTripType.orangeMoneyPayment) {
        targetHeight = _maxBottomSheetHeight;
        myCustomPrintStatement(
            '💳 updateBottomSheetHeight: Écran paiement ${tripProvider.currentStep} - Hauteur maximale (78%)');
      }
      // Écran de confirmation mobile (MVola/Airtel) : plein écran
      else if (tripProvider.currentStep == CustomTripType.paymentMobileConfirm) {
        targetHeight = 1.0;
        myCustomPrintStatement(
            '💳 updateBottomSheetHeight: Écran paymentMobileConfirm - Plein écran (100%)');
      }
      // Vérifier si on doit utiliser la hauteur maximale pour un écran de paiement (driverOnWay + status)
      else if (tripProvider.booking != null &&
          tripProvider.currentStep == CustomTripType.driverOnWay) {
        bool isPaymentScreen = (tripProvider.booking!['status'] ==
                BookingStatusType.DESTINATION_REACHED.value ||
            (tripProvider.booking!['status'] ==
                    BookingStatusType.RIDE_COMPLETE.value &&
                tripProvider.booking!['paymentStatusSummary'] == null));

        if (isPaymentScreen) {
          targetHeight = _maxBottomSheetHeight;
          myCustomPrintStatement(
              '💳 updateBottomSheetHeight: Écran paiement détecté (driverOnWay) - Hauteur maximale');
          isPaymentRelatedScreen = true; // Éviter le recentrage
        } else {
          // 📍 Chauffeur assigné (en route ou arrivé) - hauteur appropriée pour tout afficher
          targetHeight = _driverOnWayHeight;
          myCustomPrintStatement(
              '🚗 updateBottomSheetHeight: Chauffeur assigné (driverOnWay) - Hauteur 58%');
        }
      }

      _updateBottomSheetHeight(targetHeight);

      // ADAPTATION INTELLIGENTE DE L'ITINÉRAIRE
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);

      // Si on a un itinéraire et qu'on arrive sur une étape nécessitant sa visibilité
      if (mapProvider.polylineCoordinates.isNotEmpty &&
          _shouldAdaptRouteForCurrentStep(tripProvider.currentStep)) {
        myCustomPrintStatement(
            '🛣️ Adaptation automatique itinéraire pour étape: ${tripProvider.currentStep}');

        // Délai adaptatif : 800ms pour payment (bottom sheet monte à 78%),
        // 150ms pour les autres étapes (bottom sheet déjà stable)
        final delay = (tripProvider.currentStep == CustomTripType.payment)
            ? const Duration(milliseconds: 800)
            : const Duration(milliseconds: 150);

        myCustomPrintStatement(
            '⏱️ Délai ${delay.inMilliseconds}ms avant adaptation itinéraire');

        Future.delayed(delay, () {
          mapProvider.adaptRouteToBottomSheetHeightChange();
        });
      }
      // NE PAS recentrer automatiquement lors du changement de hauteur
      // L'utilisateur doit pouvoir naviguer librement sur la carte
      // Le bouton de recentrage GPS permet de revenir sur sa position si souhaité
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 🎨 Nécessaire pour AutomaticKeepAliveClientMixin
    myCustomPrintStatement('🔍 HomeScreen BUILD appelée');
    return Consumer<TripProvider>(builder: (context, tripProvider, child) {
      myCustomPrintStatement(
          '🔍 HomeScreen CONSUMER: currentStep=${tripProvider.currentStep}, booking=${tripProvider.booking != null ? tripProvider.booking!['id'] : 'null'}');
      if (_lastKnownStep != tripProvider.currentStep &&
          tripProvider.currentStep == CustomTripType.setYourDestination &&
          !tripProvider.isLiveShareActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            resetHomeView();
          }
        });
      }
      // 🔧 FIX: Ajuster automatiquement la hauteur pour requestForRide et driverOnWay
      // Détection de changement vers ces étapes pour forcer la hauteur à 58%
      if (_lastKnownStep != tripProvider.currentStep) {
        // 🛡️ Reset du bouton de partage quand on quitte driverOnWay
        if (_lastKnownStep == CustomTripType.driverOnWay &&
            tripProvider.currentStep != CustomTripType.driverOnWay) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isShareButtonExpanded) {
              setState(() {
                _isShareButtonExpanded = false;
              });
            }
          });
        }
        if (tripProvider.currentStep == CustomTripType.requestForRide) {
          myCustomPrintStatement(
              '📐 Consumer: Transition vers requestForRide - Ajustement hauteur à 58%');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentBottomSheetHeight != _requestForRideHeight) {
              _updateBottomSheetHeight(_requestForRideHeight);
            }
          });
        } else if (tripProvider.currentStep == CustomTripType.driverOnWay &&
            tripProvider.booking != null) {
          // Vérifier si c'est un écran de paiement ou de course en cours
          bool isPaymentScreen = (tripProvider.booking!['status'] ==
                  BookingStatusType.DESTINATION_REACHED.value ||
              (tripProvider.booking!['status'] ==
                      BookingStatusType.RIDE_COMPLETE.value &&
                  tripProvider.booking!['paymentStatusSummary'] == null));
          if (!isPaymentScreen) {
            myCustomPrintStatement(
                '📐 Consumer: Transition vers driverOnWay - Ajustement hauteur à 58%');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _currentBottomSheetHeight != _driverOnWayHeight) {
                _updateBottomSheetHeight(_driverOnWayHeight);
              }
            });
          }
        }
      }
      _lastKnownStep = tripProvider.currentStep;

      // Vérifier si c'est un écran de paiement et ajuster la hauteur en conséquence
      if (tripProvider.booking != null &&
          tripProvider.currentStep == CustomTripType.driverOnWay) {
        bool isPaymentScreen = (tripProvider.booking!['status'] ==
                BookingStatusType.DESTINATION_REACHED.value ||
            (tripProvider.booking!['status'] ==
                    BookingStatusType.RIDE_COMPLETE.value &&
                tripProvider.booking!['paymentStatusSummary'] == null));

        if (isPaymentScreen &&
            _currentBottomSheetHeight != _maxBottomSheetHeight) {
          myCustomPrintStatement(
              '💳 Consumer: Détection écran paiement - Ajustement hauteur');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateBottomSheetHeight(_maxBottomSheetHeight);
          });
        }
      }
      // --- Centrage carte chauffeur-pickup lors du passage à driverOnWay ---
      // On ne doit exécuter ce bloc qu'une seule fois à la transition vers driverOnWay (et non à chaque build)
      if (!_hasCenteredDriverToPickup && tripProvider.currentStep == CustomTripType.driverOnWay) {
        // 🧹 Supprimer immédiatement les markers des autres chauffeurs
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            removeOtherDriverMarkers();
          }
        });

        // Récupérer les coordonnées du chauffeur et du pickup
        LatLng? driverLatLng;
        LatLng? pickupLatLng;
        try {
          final booking = tripProvider.booking as Map<String, dynamic>?;
          if (booking != null) {
            // Chauffeur
            if (booking['driverLatitude'] != null && booking['driverLongitude'] != null) {
              driverLatLng = LatLng(
                (booking['driverLatitude'] as num).toDouble(),
                (booking['driverLongitude'] as num).toDouble(),
              );
            } else if (booking['driver'] != null &&
                booking['driver'] is Map &&
                booking['driver']['latitude'] != null &&
                booking['driver']['longitude'] != null) {
              driverLatLng = LatLng(
                (booking['driver']['latitude'] as num).toDouble(),
                (booking['driver']['longitude'] as num).toDouble(),
              );
            }
            // Pickup
            if (booking['pickupLatitude'] != null && booking['pickupLongitude'] != null) {
              pickupLatLng = LatLng(
                (booking['pickupLatitude'] as num).toDouble(),
                (booking['pickupLongitude'] as num).toDouble(),
              );
            }
          }
        } catch (e) {
          myCustomPrintStatement('Erreur extraction coordonnées chauffeur/pickup: $e');
        }
        // Si les deux positions sont disponibles, centrer la carte une seule fois
        if (driverLatLng != null && pickupLatLng != null) {
          _hasCenteredDriverToPickup = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _fitDriverToPickupVisibleAboveBottomView(driverLatLng!, pickupLatLng!);
          });
        }
      }

      return WillPopScope(
        onWillPop: () async {
          if (tripProvider.currentStep != null &&
              tripProvider.currentStep != CustomTripType.setYourDestination) {
            // Pour les écrans de réservation ou de saisie d'adresse
            // Note: selectScheduleTime doit toujours permettre le retour car c'est un écran de création
            if (tripProvider.currentStep == CustomTripType.selectScheduleTime ||
                (tripProvider.currentStep ==
                        CustomTripType.choosePickupDropLocation &&
                    tripProvider.booking == null)) {
              // Log abandonment pour l'écran d'adresse si applicable (bouton système Android)
              if (tripProvider.currentStep ==
                  CustomTripType.choosePickupDropLocation) {
                final pickupDropWidgetState =
                    MyGlobalKeys.chooseDropAndPickAddPageKey.currentState;
                if (pickupDropWidgetState != null) {
                  (pickupDropWidgetState as PickupAndDropLocationState)
                      .logAddressAbandonment('system_back_button');
                }
              }

              // Forcer le retour à l'écran de navigation principal pour garantir la reconstruction
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (context) => const MainNavigationScreen()),
                (route) => false,
              );

              // S'assurer que l'état est correctement réinitialisé après la transition
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Provider.of<NavigationProvider>(context, listen: false)
                    .setNavigationBarVisibility(true);
                Provider.of<TripProvider>(context, listen: false)
                    .setScreen(CustomTripType.setYourDestination);
              });

              return false; // Navigation gérée manuellement
            }

            // Logique de retour pour les autres étapes du processus de course
            if (tripProvider.currentStep == CustomTripType.flightNumberEntry &&
                tripProvider.booking == null) {
              // Retour depuis saisie numéro de vol → retour à sélection d'adresse
              tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
              updateBottomSheetHeight();
            } else if (tripProvider.currentStep == CustomTripType.chooseVehicle &&
                tripProvider.booking == null) {
              // Log abandonment for vehicle selection
              final chooseVehicleState =
                  MyGlobalKeys.chooseVehiclePageKey.currentState;
              if (chooseVehicleState != null) {
                (chooseVehicleState as dynamic)
                    .logVehicleAbandonment('system_back_button');
              }

              // Vérifier si on vient de flightNumberEntry (réservation planifiée avec pickup à l'aéroport)
              final isScheduled = tripProvider.rideScheduledTime != null;
              final isPickupAirport = tripProvider.pickLocation?['isAirport'] == true;

              if (isScheduled && isPickupAirport) {
                // Retour vers saisie numéro de vol
                tripProvider.setScreen(CustomTripType.flightNumberEntry);
              } else {
                // Retour vers saisie des adresses
                tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
                GoogleMapProvider mapInstan =
                    Provider.of<GoogleMapProvider>(context, listen: false);
                // Nettoyer complètement la carte (polylines + markers)
                mapInstan.clearAllPolylines();
                mapInstan.markers.removeWhere((key, value) => key == "pickup");
                mapInstan.markers.removeWhere((key, value) => key == "drop");
              }
              updateBottomSheetHeight();
            } else if (tripProvider.currentStep == CustomTripType.payment &&
                tripProvider.booking == null) {
              // Log abandonment for payment selection
              final selectPaymentMethodState =
                  MyGlobalKeys.selectPaymentMethodPageKey.currentState;
              if (selectPaymentMethodState != null) {
                (selectPaymentMethodState as dynamic)
                    .logPaymentAbandonment('system_back_button');
              }

              tripProvider.setScreen(CustomTripType.chooseVehicle);
              updateBottomSheetHeight();
            } else if (tripProvider.currentStep ==
                    CustomTripType.selectAvailablePromocode &&
                tripProvider.booking == null) {
              tripProvider.selectedPromoCode = null;
              tripProvider.setScreen(CustomTripType.chooseVehicle);
              updateBottomSheetHeight();
            } else if (tripProvider.currentStep ==
                    CustomTripType.confirmDestination &&
                tripProvider.booking == null) {
              // Log abandonment for confirmation
              final confirmDestinationState =
                  MyGlobalKeys.confirmDestinationPageKey.currentState;
              if (confirmDestinationState != null) {
                (confirmDestinationState as dynamic)
                    .logConfirmationAbandonment('system_back_button');
              }

              tripProvider.setScreen(CustomTripType.payment);
              updateBottomSheetHeight();
            } else if (tripProvider.currentStep ==
                    CustomTripType.requestForRide &&
                tripProvider.booking == null) {
              // Pas de retour possible depuis requestForRide - l'utilisateur doit annuler
              return false;
            } else if (tripProvider.currentStep ==
                    CustomTripType.paymentMobileConfirm &&
                tripProvider.booking != null) {
              tripProvider.setScreen(CustomTripType.driverOnWay);
              updateBottomSheetHeight();
            }
            return false;
          } else {
            // Si on est déjà à l'accueil, autoriser la fermeture de l'app
            Provider.of<NavigationProvider>(context, listen: false)
                .setNavigationBarVisibility(true);
            return true;
          }
        },
        child: Consumer3<DarkThemeProvider, GoogleMapProvider, TripProvider>(
          builder:
              (context, darkThemeProvider, mapProvider, tripProvider, child) {
            final screenHeight = MediaQuery.of(context).size.height;
            final navProvider =
                Provider.of<NavigationProvider>(context, listen: false);

            // 💳 Force la hauteur 100% pour paymentMobileConfirm
            if (tripProvider.currentStep == CustomTripType.paymentMobileConfirm &&
                _currentBottomSheetHeight < 1.0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  myCustomPrintStatement('💳 Force hauteur 100% pour paymentMobileConfirm');
                  _updateBottomSheetHeight(1.0);
                }
              });
            }

            // --- Reactive bridge: advance UI when backend/FCM updates booking status ---
            final booking = tripProvider.booking as Map<String, dynamic>?;

            bool _hasAssignedDriver(Map<String, dynamic> b) {
              return b['driver_id'] != null ||
                  b['driverId'] != null ||
                  b['driver'] != null ||
                  (b['acceptedDriver'] != null);
            }

            String _statusAsString(dynamic raw) {
              if (raw == null) return '';
              if (raw is String) return raw;
              return raw.toString();
            }

            if (booking != null) {
              final status = _statusAsString(booking['status']);
              final currentBookingStatus = booking['status'] as int?;

              bool isDriverOnWayStatus(String s) {
                // Accept many possible backend labels
                return s == 'DRIVER_ACCEPTED' ||
                    s == 'DRIVER_ASSIGNED' ||
                    s == 'DRIVER_ON_WAY' ||
                    s == 'DRIVER_REACHED' ||
                    s == 'ACCEPTED' ||
                    s == 'ASSIGNED' ||
                    s == 'ON_THE_WAY' ||
                    s == 'ON_WAY';
              }

              bool isRideCancelled(String s) {
                return s == 'TRIP_CANCELLED' ||
                    s == 'RIDE_CANCELLED' ||
                    s == 'CANCELLED' ||
                    s == 'USER_CANCELLED';
              }

              final bool driverAssigned = _hasAssignedDriver(booking) ||
                  (tripProvider.acceptedDriver != null);

              // Détecter le changement de statut pour déclencher le recentrage une seule fois
              if (currentBookingStatus != null &&
                  currentBookingStatus != _lastBookingStatus &&
                  currentBookingStatus >= BookingStatusType.ACCEPTED.value &&
                  !_hasRecenteredForDriverTracking) {
                myCustomPrintStatement(
                    '🗺️ Changement de statut détecté: ${_lastBookingStatus} -> $currentBookingStatus');
                _lastBookingStatus = currentBookingStatus;
                _hasRecenteredForDriverTracking = true;

                // Déclencher le recentrage avec un léger délai
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 800), () async {
                    if (mounted && tripProvider.booking != null) {
                      await recenterMapForDriverTracking();
                    }
                  });
                });
              }

              // If a driver is assigned OR status indicates driver on way -> move UI forward
              // BUT: For scheduled bookings, NEVER transition on simple acceptance - only when ride actually starts
              bool isScheduledBooking = booking['isSchedule'] == true;
              bool rideHasStarted =
                  booking['status'] >= 3; // RIDE_STARTED status value
              bool startRideIsTrue = booking['startRide'] == true;

              // For scheduled bookings, allow advance when startRide=true OR ride has actually started
              // 🔧 FIX: Ne JAMAIS avancer si le booking est annulé (status >= 6)
              // 🔧 FIX: Ne JAMAIS avancer si acceptedBy est null (pas de chauffeur assigné)
              bool isBookingCancelled = booking['status'] >= 6;
              bool shouldAdvanceUI;
              if (isScheduledBooking) {
                // For scheduled bookings: advance when startRide=true OR ride has started
                // BUT NOT if cancelled AND NOT if no driver assigned!
                shouldAdvanceUI = !isBookingCancelled && driverAssigned && (startRideIsTrue || rideHasStarted);
                debugPrint(
                    '[UI] Scheduled booking check - rideStarted=$rideHasStarted, startRide=$startRideIsTrue, cancelled=$isBookingCancelled, driverAssigned=$driverAssigned, shouldAdvance=$shouldAdvanceUI (status=${booking['status']})');
              } else {
                // For immediate bookings: use original logic
                // ⚡ FIX: Ne pas considérer shouldAdvanceUI comme true pour RIDE_COMPLETE/DESTINATION_REACHED
                // car le paiement mobile est en cours et on ne veut pas transitionner vers driverOnWay
                final isRideCompleteStatus = booking['status'] == 5 || booking['status'] == 6;
                shouldAdvanceUI = !isRideCompleteStatus &&
                    (driverAssigned || isDriverOnWayStatus(status));
                debugPrint(
                    '[UI] Immediate booking check - driverAssigned=$driverAssigned, statusCheck=${isDriverOnWayStatus(status)}, isRideComplete=$isRideCompleteStatus');
              }

              if (shouldAdvanceUI &&
                  tripProvider.currentStep != CustomTripType.driverOnWay &&
                  // Don't interrupt payment flows for RIDE_COMPLETE
                  !(booking['status'] == 5 &&
                      (tripProvider.currentStep ==
                              CustomTripType.paymentMobileConfirm ||
                          tripProvider.currentStep ==
                              CustomTripType.orangeMoneyPayment))) {
                debugPrint(
                    '[UI] 🚨 CRITICAL: UI wants to advance to driverOnWay (isScheduled=$isScheduledBooking, shouldAdvance=$shouldAdvanceUI)');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  debugPrint(
                      '[UI] 🚨 CRITICAL: Calling setScreen(driverOnWay) from UI reactive bridge!');
                  tripProvider.setScreen(CustomTripType.driverOnWay);
                  updateBottomSheetHeight();
                });
              } else if (booking['status'] == 5 &&
                  (tripProvider.currentStep ==
                          CustomTripType.paymentMobileConfirm ||
                      tripProvider.currentStep ==
                          CustomTripType.orangeMoneyPayment)) {
                debugPrint(
                    '[UI] 🛡️ BLOCKING UI transition to driverOnWay - RIDE_COMPLETE with active payment flow!');
              } else if (isScheduledBooking &&
                  !shouldAdvanceUI &&
                  driverAssigned) {
                debugPrint(
                    '[UI] ✅ Scheduled booking accepted but correctly NOT advancing to driverOnWay - startRide=$startRideIsTrue, rideStarted=$rideHasStarted (status=${booking['status']})');
              } else if (isScheduledBooking) {
                debugPrint(
                    '[UI] 🔍 Scheduled booking debug - rideStarted=$rideHasStarted, startRide=$startRideIsTrue, driverAssigned=$driverAssigned, shouldAdvance=$shouldAdvanceUI');
              }

              // If cancelled, reset to start state
              if (isRideCancelled(status) &&
                  tripProvider.currentStep !=
                      CustomTripType.setYourDestination) {
                debugPrint('[UI] Reset to setYourDestination (status=$status)');
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await _resetToMainMenuWithPurge();
                });
              }
            }
            // --- End reactive bridge ---

            // 🗺️ OPTIMISATION: UN SEUL Scaffold unifié pour éviter le rechargement de la carte
            // lors des transitions d'état. La GoogleMap garde son GlobalKey et persiste.

            // Déterminer les propriétés conditionnelles du Scaffold
            final needsKeyboardResize = tripProvider.currentStep == CustomTripType.paymentMobileConfirm;
            final isMainMenu = tripProvider.currentStep == null ||
                tripProvider.currentStep == CustomTripType.setYourDestination;
            final isPickupDropOrSchedule = tripProvider.currentStep == CustomTripType.choosePickupDropLocation ||
                tripProvider.currentStep == CustomTripType.selectScheduleTime;
            final isClassicBottomSheet = !isMainMenu && !isPickupDropOrSchedule;

            // Couleur de fond adaptative
            final backgroundColor = isMainMenu
                ? (darkThemeProvider.darkTheme ? Colors.black : Colors.white)
                : (darkThemeProvider.darkTheme ? const Color(0xFF242F3D) : const Color(0xFFE5E9EC));

            return Scaffold(
              key: _scaffoldKey,
              drawer: const CustomDrawer(),
              resizeToAvoidBottomInset: needsKeyboardResize,
              backgroundColor: backgroundColor,
              body: Container(
                color: backgroundColor,
                child: Stack(
                  children: [
                    // 🗺️ GoogleMap UNIQUE avec GlobalKey - persiste lors des transitions
                    Positioned.fill(
                      child: _buildGoogleMap(mapProvider),
                    ),

                    // 📍 Pin flottant pour confirmDestination - permet d'ajuster le lieu par glissement de la carte
                    // Positionné au centre de la zone visible (au-dessus du bottom sheet fixe à 35%)
                    if (tripProvider.currentStep == CustomTripType.confirmDestination)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        // Bottom sheet fixe à 32%, donc le pin est centré dans les 68% supérieurs
                        bottom: screenHeight * _confirmDestinationHeight,
                        child: Center(
                          child: Transform.translate(
                            // Décaler de -25px (moitié hauteur image) pour aligner la pointe du pin avec le centre GPS
                            offset: const Offset(0, -25),
                            child: Image.asset(
                              MyImagesUrl.picupLocationIcon,
                              height: 50,
                              width: 50,
                            ),
                          ),
                        ),
                      ),

                    // 🛰️ Toggle satellite/normal pour le mode "Définir lieu sur la carte"
                    if (pickupLocationPickerHideNoti.value || dropLocationPickerHideNoti.value)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 16,
                        right: 16,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          color: darkThemeProvider.darkTheme
                              ? const Color(0xFF2C2C2E)
                              : Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _locationPickerSatelliteView = !_locationPickerSatelliteView;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                // Par défaut = hybride, toggle pour vue normale
                                _locationPickerSatelliteView
                                    ? Icons.satellite_alt  // En vue normale, afficher icône satellite pour revenir
                                    : Icons.map_outlined,  // En vue hybride, afficher icône map pour passer en normal
                                color: _locationPickerSatelliteView
                                    ? (darkThemeProvider.darkTheme
                                        ? Colors.white70
                                        : Colors.grey[700])
                                    : MyColors.primaryColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 🛡️ Barrière invisible pour fermer le bouton de partage quand on clique ailleurs
                    if (tripProvider.currentStep == CustomTripType.driverOnWay && _isShareButtonExpanded)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            setState(() {
                              _isShareButtonExpanded = false;
                            });
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),

                    // 🛡️ Bouton de partage en forme de bouclier (visible pendant driverOnWay)
                    if (tripProvider.currentStep == CustomTripType.driverOnWay)
                      Builder(
                        builder: (context) {
                          // Gérer l'animation pulsée selon le nombre de viewers
                          final hasViewers = tripProvider.activeShareViewers > 0;
                          if (hasViewers && !_sharePulseController.isAnimating) {
                            _sharePulseController.forward();
                          } else if (!hasViewers && _sharePulseController.isAnimating) {
                            _sharePulseController.stop();
                            _sharePulseController.reset();
                          }

                          return Positioned(
                            top: MediaQuery.of(context).padding.top + 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: () {
                                if (_isShareButtonExpanded) {
                                  // Deuxième clic : ouvrir le bottom sheet
                                  showShareRideBottomSheet(context);
                                  setState(() {
                                    _isShareButtonExpanded = false;
                                  });
                                } else {
                                  // Premier clic : étendre le bouton
                                  setState(() {
                                    _isShareButtonExpanded = true;
                                  });
                                }
                              },
                              child: AnimatedBuilder(
                                animation: _sharePulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: hasViewers ? _sharePulseAnimation.value : 1.0,
                                    child: child,
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: _isShareButtonExpanded ? 16 : 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasViewers ? Colors.green : MyColors.primaryColor,
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (hasViewers ? Colors.green : MyColors.primaryColor).withOpacity(0.3),
                                        blurRadius: hasViewers ? 20 : 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          const Icon(
                                            Icons.shield,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          // Badge avec nombre de viewers
                                          if (hasViewers)
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '${tripProvider.activeShareViewers}',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      AnimatedSize(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOutCubic,
                                        child: _isShareButtonExpanded
                                            ? Padding(
                                                padding: const EdgeInsets.only(left: 10),
                                                child: Text(
                                                  hasViewers
                                                    ? '${tripProvider.activeShareViewers} personne${tripProvider.activeShareViewers > 1 ? 's' : ''} suit'
                                                    : 'Partagez votre course',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // ═══════════════════════════════════════════════════════════
                    // 📍 CONTENU POUR: setYourDestination (Menu Principal)
                    // ═══════════════════════════════════════════════════════════
                    if (isMainMenu) ...[
                      // Couverture blanche progressive pour la transition (Android uniquement)
                      // Sur iOS, nous utilisons _iosSheetExtent qui a sa propre logique
                      if (!Platform.isIOS)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: screenHeight * _currentBottomSheetHeight - 20,
                          child: IgnorePointer(
                            ignoring: _calculateWhiteOverlayOpacity() == 0.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              color: (darkThemeProvider.darkTheme
                                      ? MyColors.blackColor
                                      : MyColors.whiteColor)
                                  .withOpacity(_calculateWhiteOverlayOpacity()),
                            ),
                          ),
                        ),

                      // Bottom Sheet moderne avec gestion des gestes
                      // iOS: Liquid Glass avec nav bar bulle comme état collapsed
                      // Android: Style Material classique avec drag
                      if (Platform.isIOS)
                        _buildIOSLiquidGlassWithNavBar(darkThemeProvider, tripProvider, screenHeight)
                      else
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            height: screenHeight * _currentBottomSheetHeight,
                            decoration: _currentBottomSheetHeight < _maxBottomSheetHeight
                                ? BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1 *
                                            (1.0 - _calculateWhiteOverlayOpacity())),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                        offset: const Offset(0, -2),
                                      ),
                                    ],
                                  )
                                : null,
                            child: ClipRRect(
                              borderRadius:
                                  _currentBottomSheetHeight >= _maxBottomSheetHeight
                                      ? BorderRadius.zero
                                      : const BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                              child: Container(
                                color: darkThemeProvider.darkTheme
                                    ? MyColors.blackColor
                                    : MyColors.whiteColor,
                                child: _buildBottomSheetContent(
                                    darkThemeProvider, tripProvider),
                              ),
                            ),
                          ),
                        ),

                      // Bouton menu en haut à gauche
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 16,
                        child: _buildMenuButton(darkThemeProvider),
                      ),

                      // Bouton "Se connecter" en haut à droite (mode invité)
                      Consumer<CustomAuthProvider>(
                        builder: (context, authProvider, child) {
                          if (!authProvider.isGuestMode) return const SizedBox();
                          return Positioned(
                            top: MediaQuery.of(context).padding.top + 16,
                            right: 16,
                            child: _buildLoginButton(darkThemeProvider, authProvider),
                          );
                        },
                      ),

                      // Bouton de géolocalisation
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        bottom: _getCurrentSheetHeightPixels(screenHeight) + 20,
                        right: 16,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          // Sur iOS, toujours visible sauf en expanded
                          opacity: Platform.isIOS
                              ? (_iosSheetState == 2 ? 0.0 : 1.0)
                              : 1.0 - _calculateWhiteOverlayOpacity(),
                          child: _buildLocationButton(darkThemeProvider),
                        ),
                      ),

                      // Curseurs de sélection drop/pickup (menu principal)
                      // La pointe du pin doit être au centre de la carte (position GPS réelle)
                      ValueListenableBuilder(
                        valueListenable: dropLocationPickerHideNoti,
                        builder: (context, hidePicker, child) => hidePicker == false
                            ? Container()
                            : Center(
                                child: Transform.translate(
                                  // Décalage de -20px (moitié de la hauteur 40px) pour aligner la pointe avec le centre GPS
                                  offset: const Offset(0, -20),
                                  child: Image.asset(
                                    MyImagesUrl.locationSelectFromMap(),
                                    height: 40,
                                    width: 40,
                                  ),
                                ),
                              ),
                      ),
                      ValueListenableBuilder(
                        valueListenable: pickupLocationPickerHideNoti,
                        builder: (context, hidePicker, child) => hidePicker == false
                            ? Container()
                            : Center(
                                child: Transform.translate(
                                  // Décalage de -20px (moitié de la hauteur 40px) pour aligner la pointe avec le centre GPS
                                  offset: const Offset(0, -20),
                                  child: Image.asset(
                                    MyImagesUrl.locationSelectFromMap(),
                                    height: 40,
                                    width: 40,
                                  ),
                                ),
                              ),
                      ),
                    ],

                    // ═══════════════════════════════════════════════════════════
                    // 📍 CONTENU POUR: choosePickupDropLocation / selectScheduleTime
                    // ═══════════════════════════════════════════════════════════
                    if (isPickupDropOrSchedule) ...[
                      // Widget autonome en bas
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: tripProvider.currentStep ==
                                CustomTripType.choosePickupDropLocation
                            ? PickupAndDropLocation(
                                key: MyGlobalKeys.chooseDropAndPickAddPageKey,
                                onTap: (pickup, drop) async {
                                  try {
                                    showLoading();
                                    tripProvider.pickLocation = pickup;
                                    tripProvider.dropLocation = drop;

                                    // 🔧 FIX: Recharger les chauffeurs autour du pickup AVANT de passer à chooseVehicle
                                    // Cela remplit minVehicleDistance pour afficher la disponibilité des catégories
                                    if (pickup['lat'] != null && pickup['lng'] != null) {
                                      await refreshDriversAroundPickup(
                                        pickup['lat'],
                                        pickup['lng'],
                                      );
                                    }

                                    // Analytics tracking
                                    double? distanceKm;
                                    if (pickup['lat'] != null &&
                                        pickup['lng'] != null &&
                                        drop['lat'] != null &&
                                        drop['lng'] != null) {
                                      distanceKm = Geolocator.distanceBetween(
                                            pickup['lat'],
                                            pickup['lng'],
                                            drop['lat'],
                                            drop['lng'],
                                          ) / 1000;
                                    }

                                    AnalyticsService.logDestinationSearched(
                                      fromAddress: pickup['address'] ?? 'Unknown',
                                      toAddress: drop['address'] ?? 'Unknown',
                                      distanceKm: distanceKm,
                                    );

                                    await tripProvider.createPath(topPaddingPercentage: 0.8);

                                    // Vérifier si réservation planifiée avec pickup aéroport
                                    final isScheduled = tripProvider.rideScheduledTime != null;
                                    final isPickupAirport = pickup['isAirport'] == true;

                                    myCustomPrintStatement('🛫 Flight Number Flow Check:');
                                    myCustomPrintStatement('  isScheduled: $isScheduled');
                                    myCustomPrintStatement('  isPickupAirport: $isPickupAirport');

                                    if (isScheduled && isPickupAirport) {
                                      myCustomPrintStatement('  ✅ Affichage FlightNumberEntrySheet');
                                      tripProvider.setScreen(CustomTripType.flightNumberEntry);
                                    } else {
                                      myCustomPrintStatement('  ⏩ Skip vers chooseVehicle');
                                      tripProvider.setScreen(CustomTripType.chooseVehicle);
                                    }

                                    updateBottomSheetHeight();
                                    hideLoading();
                                  } catch (e) {
                                    hideLoading();
                                    print('Erreur lors de la création du trajet: $e');
                                  }
                                },
                              )
                            : const SceduleRideWithCustomeTime(),
                      ),

                      // Curseurs de sélection (mode autonome)
                      if (tripProvider.currentStep == CustomTripType.choosePickupDropLocation)
                        ValueListenableBuilder(
                          valueListenable: dropLocationPickerHideNoti,
                          builder: (context, hidePicker, child) => hidePicker == false
                              ? Container()
                              : Center(
                                  child: Transform.translate(
                                    offset: Offset(0, -_mapBottomPadding / 2),
                                    child: const _CustomLocationPin(),
                                  ),
                                ),
                        ),
                      if (tripProvider.currentStep == CustomTripType.choosePickupDropLocation)
                        ValueListenableBuilder(
                          valueListenable: pickupLocationPickerHideNoti,
                          builder: (context, hidePicker, child) => hidePicker == false
                              ? Container()
                              : Center(
                                  child: Transform.translate(
                                    offset: Offset(0, -_mapBottomPadding / 2),
                                    child: const _CustomLocationPin(),
                                  ),
                                ),
                        ),

                      // Bouton retour (masqué pendant requestForRide, driverOnWay et paymentMobileConfirm)
                      if (tripProvider.currentStep != CustomTripType.requestForRide &&
                          tripProvider.currentStep != CustomTripType.driverOnWay &&
                          tripProvider.currentStep != CustomTripType.paymentMobileConfirm)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 16,
                          left: 16,
                          child: _buildBackButton(darkThemeProvider, tripProvider),
                        ),
                    ],

                    // ═══════════════════════════════════════════════════════════
                    // 📍 CONTENU POUR: Autres étapes (chooseVehicle, payment, etc.)
                    // ═══════════════════════════════════════════════════════════
                    if (isClassicBottomSheet) ...[
                      // Bottom Sheet classique
                      if (tripProvider.currentStep != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (details) {
                              _panStartY = details.globalPosition.dy;
                              _panStartHeight = _currentBottomSheetHeight;
                            },
                            onPanUpdate: (details) {
                              if (_panStartY == null || _panStartHeight == null) return;
                              // 📍 Désactiver le drag pour confirmDestination et paymentMobileConfirm (hauteur fixe)
                              if (tripProvider.currentStep == CustomTripType.confirmDestination ||
                                  tripProvider.currentStep == CustomTripType.paymentMobileConfirm) return;
                              final deltaY = _panStartY! - details.globalPosition.dy;
                              final deltaHeight = deltaY / screenHeight;
                              // Utiliser les limites spécifiques selon l'écran
                              final isChooseVehicle = tripProvider.currentStep == CustomTripType.chooseVehicle;
                              final isDriverOnWay = tripProvider.currentStep == CustomTripType.driverOnWay;
                              final isRequestForRide = tripProvider.currentStep == CustomTripType.requestForRide;
                              final double minHeight;
                              final double maxHeight;
                              if (isChooseVehicle) {
                                minHeight = _chooseVehicleMinHeight;
                                maxHeight = _chooseVehicleMaxHeight;
                              } else if (isDriverOnWay || isRequestForRide) {
                                minHeight = _midBottomSheetHeight; // 55% - minimum
                                maxHeight = _maxBottomSheetHeight; // 78% - maximum pour agrandir
                              } else {
                                minHeight = _lowestBottomSheetHeight;
                                maxHeight = _maxBottomSheetHeight;
                              }
                              final newHeight = (_panStartHeight! + deltaHeight)
                                  .clamp(minHeight, maxHeight);
                              setState(() {
                                _currentBottomSheetHeight = newHeight;
                              });
                            },
                            onPanEnd: (details) {
                              // 📍 Ignorer pour confirmDestination et paymentMobileConfirm (hauteur fixe)
                              if (tripProvider.currentStep == CustomTripType.confirmDestination ||
                                  tripProvider.currentStep == CustomTripType.paymentMobileConfirm) return;

                              final velocity = details.velocity.pixelsPerSecond.dy;
                              final isChooseVehicle = tripProvider.currentStep == CustomTripType.chooseVehicle;
                              final isDriverOnWay = tripProvider.currentStep == CustomTripType.driverOnWay;
                              final isRequestForRide = tripProvider.currentStep == CustomTripType.requestForRide;
                              double targetHeight;

                              if (isChooseVehicle) {
                                // Snap points spécifiques pour chooseVehicle: 38%, 60%, 85%
                                if (velocity > 300) {
                                  // Glissement vers le bas
                                  if (_currentBottomSheetHeight > _chooseVehicleMidHeight) {
                                    targetHeight = _chooseVehicleMidHeight;
                                  } else {
                                    targetHeight = _chooseVehicleMinHeight;
                                  }
                                } else if (velocity < -300) {
                                  // Glissement vers le haut
                                  if (_currentBottomSheetHeight < _chooseVehicleMidHeight) {
                                    targetHeight = _chooseVehicleMidHeight;
                                  } else {
                                    targetHeight = _chooseVehicleMaxHeight;
                                  }
                                } else {
                                  // Snap vers le niveau le plus proche
                                  final distances = {
                                    (_currentBottomSheetHeight - _chooseVehicleMinHeight).abs(): _chooseVehicleMinHeight,
                                    (_currentBottomSheetHeight - _chooseVehicleMidHeight).abs(): _chooseVehicleMidHeight,
                                    (_currentBottomSheetHeight - _chooseVehicleMaxHeight).abs(): _chooseVehicleMaxHeight,
                                  };
                                  final minDistance = distances.keys.reduce((a, b) => a < b ? a : b);
                                  targetHeight = distances[minDistance]!;
                                }
                              } else if (isDriverOnWay || isRequestForRide) {
                                // Snap points spécifiques pour driverOnWay et requestForRide: 55%, 58%, 78%
                                if (velocity > 300) {
                                  // Glissement vers le bas
                                  if (_currentBottomSheetHeight > _driverOnWayHeight) {
                                    targetHeight = _driverOnWayHeight;
                                  } else {
                                    targetHeight = _midBottomSheetHeight;
                                  }
                                } else if (velocity < -300) {
                                  // Glissement vers le haut
                                  if (_currentBottomSheetHeight < _driverOnWayHeight) {
                                    targetHeight = _driverOnWayHeight;
                                  } else {
                                    targetHeight = _maxBottomSheetHeight;
                                  }
                                } else {
                                  // Snap vers le niveau le plus proche (55%, 58%, 78%)
                                  final distances = {
                                    (_currentBottomSheetHeight - _midBottomSheetHeight).abs(): _midBottomSheetHeight,
                                    (_currentBottomSheetHeight - _driverOnWayHeight).abs(): _driverOnWayHeight,
                                    (_currentBottomSheetHeight - _maxBottomSheetHeight).abs(): _maxBottomSheetHeight,
                                  };
                                  final minDistance = distances.keys.reduce((a, b) => a < b ? a : b);
                                  targetHeight = distances[minDistance]!;
                                }
                              } else {
                                // Snap points par défaut pour les autres écrans
                                if (velocity > 300) {
                                  if (_currentBottomSheetHeight > _midBottomSheetHeight) {
                                    targetHeight = _midBottomSheetHeight;
                                  } else if (_currentBottomSheetHeight > _minBottomSheetHeight) {
                                    targetHeight = _minBottomSheetHeight;
                                  } else {
                                    targetHeight = _lowestBottomSheetHeight;
                                  }
                                } else if (velocity < -300) {
                                  if (_currentBottomSheetHeight < _minBottomSheetHeight) {
                                    targetHeight = _minBottomSheetHeight;
                                  } else if (_currentBottomSheetHeight < _midBottomSheetHeight) {
                                    targetHeight = _midBottomSheetHeight;
                                  } else {
                                    targetHeight = _maxBottomSheetHeight;
                                  }
                                } else {
                                  final distances = {
                                    (_currentBottomSheetHeight - _lowestBottomSheetHeight).abs(): _lowestBottomSheetHeight,
                                    (_currentBottomSheetHeight - _minBottomSheetHeight).abs(): _minBottomSheetHeight,
                                    (_currentBottomSheetHeight - _midBottomSheetHeight).abs(): _midBottomSheetHeight,
                                    (_currentBottomSheetHeight - _maxBottomSheetHeight).abs(): _maxBottomSheetHeight,
                                  };
                                  final minDistance = distances.keys.reduce((a, b) => a < b ? a : b);
                                  targetHeight = distances[minDistance]!;
                                }
                              }
                              _updateBottomSheetHeight(targetHeight);
                              _panStartY = null;
                              _panStartHeight = null;
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              height: screenHeight * _currentBottomSheetHeight,
                              constraints: tripProvider.currentStep == CustomTripType.orangeMoneyPayment
                                  ? BoxConstraints(maxHeight: screenHeight * 0.65)
                                  : null,
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                                child: Container(
                                  color: MyColors.bottomSheetBackgroundColor(),
                                  child: SafeArea(
                                    top: false, // Pas de padding en haut pour optimiser l'espace
                                    child: _buildClassicBottomSheetContent(tripProvider),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Bouton retour (masqué pendant requestForRide, driverOnWay et paymentMobileConfirm)
                      if (tripProvider.currentStep != CustomTripType.requestForRide &&
                          tripProvider.currentStep != CustomTripType.driverOnWay &&
                          tripProvider.currentStep != CustomTripType.paymentMobileConfirm &&
                          tripProvider.currentStep != null)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 16,
                          left: 16,
                          child: _buildBackButton(darkThemeProvider, tripProvider),
                        ),
                    ],

                    // ═══════════════════════════════════════════════════════════
                    // 📍 OVERLAYS COMMUNS
                    // ═══════════════════════════════════════════════════════════

                    // Overlay de chargement pendant les transitions
                    if (tripProvider.isTransitioning)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }

  /// Placeholder élégant affiché en attendant la position GPS réelle
  /// Pas de fallback à une position par défaut - on attend le vrai GPS
  Widget _buildMapLoadingPlaceholder() {
    final darkTheme = Provider.of<DarkThemeProvider>(context, listen: false).darkTheme;

    return Container(
      color: MyColors.whiteThemeColor(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône GPS animée
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  darkTheme ? Colors.white70 : MyColors.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Localisation en cours...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: darkTheme ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMap(GoogleMapProvider mapProvider) {
    final double _screenH = MediaQuery.of(context).size.height;
    final double _maxAllowedBottomPadding =
        (_screenH / 2) - 10.0; // Google Maps Android constraint
    final double _clampedBottomPadding =
        _mapBottomPadding.clamp(0.0, _maxAllowedBottomPadding);

    // 🎯 FIX: Attendre la vraie position GPS avant d'afficher la carte
    // Pas de fallback à une position par défaut
    final gpsPosition = _getRealGpsPosition(mapProvider);
    if (gpsPosition == null) {
      // Afficher un placeholder élégant en attendant le GPS
      return _buildMapLoadingPlaceholder();
    }

    // CONFIGURATION ZOOM STABLE - Empêche le zoom anarchique sur iOS
    // ⚡ FIX: Passer l'état de la permission pour activer/désactiver le point bleu GPS
    final iosMapConfig = IOSMapFix.getSecureMapConfig(
      hasLocationPermission: mapProvider.hasLocationPermission,
    );

    // 🛰️ Type de carte selon le contexte :
    // - confirmDestination : Vue hybride par défaut (confirmer lieu de prise en charge)
    // - Location picker : Vue hybride par défaut (définir lieu de prise en charge/dépose sur carte)
    // - Autres : Vue normale
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final isConfirmDestination = tripProvider.currentStep == CustomTripType.confirmDestination;
    final isLocationPickerMode = pickupLocationPickerHideNoti.value || dropLocationPickerHideNoti.value;

    MapType mapType;
    if (isConfirmDestination) {
      // "Faites glisser la carte et confirmez le lieu de prise en charge" : toujours hybride
      mapType = MapType.hybrid;
    } else if (isLocationPickerMode) {
      // "Faites glisser la carte et confirmez le lieu de dépose/prise en charge"
      // Vue hybride par défaut, toggle pour passer en vue normale
      mapType = _locationPickerSatelliteView ? MapType.normal : MapType.hybrid;
    } else {
      // Vue normale par défaut pour les autres écrans
      mapType = MapType.normal;
    }

    // 🎯 Filtrer markers/polylines pour confirmDestination (vue épurée)
    // Pendant confirmDestination: pas de markers (le pin flottant indique la position)
    final markers = isConfirmDestination
        ? <Marker>{}
        : Set<Marker>.from(mapProvider.markers.values);
    final polylines = isConfirmDestination
        ? <Polyline>{}
        : mapProvider.polyLines;

    return GoogleMap(
      mapType: mapType,
      key: _googleMapKey, // 🗺️ Préserver l'instance lors des transitions d'état
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _isMapReady = true;
        mapProvider.setController(controller);
        // Appeler resetHomeView SEULEMENT si on est réellement sur le menu principal
        // et pas en cours de restauration d'une course active ou de visualisation de partage
        final tripProvider = Provider.of<TripProvider>(context, listen: false);
        if (_lastKnownStep == CustomTripType.setYourDestination &&
            tripProvider.currentStep == CustomTripType.setYourDestination &&
            !tripProvider.isLiveShareActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              resetHomeView();
            }
          });
        }
        mapProvider.setMapStyle(context);

        // 🔧 FIX: Démarrer le stream Firestore pour surveiller les bookings
        // Cela permet de détecter quand un chauffeur démarre une course planifiée
        // même si les notifications push sont désactivées
        // (Restauration du comportement d'avant la refonte graphique)
        tripProvider.setBookingStream();

        // 🎯 Appliquer le padding immédiatement
        _applyMapPadding();

        // 🎯 FIX: Recentrer le point bleu dans la zone visible dès l'ouverture
        // Attendre un court délai pour que la carte soit complètement chargée
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && currentPosition != null) {
            recenterMapWithAdaptivePadding();
          }
        });
      },
      initialCameraPosition: CameraPosition(
        // 🎯 GPS réel uniquement - plus de fallback
        target: gpsPosition,
        zoom: 15.0,
      ),
      // CONFIGURATION ZOOM STABLE - Applique les paramètres anti-zoom anarchique
      minMaxZoomPreference: iosMapConfig['minMaxZoomPreference'],
      myLocationEnabled: iosMapConfig['myLocationEnabled'],
      myLocationButtonEnabled: iosMapConfig['myLocationButtonEnabled'],
      zoomGesturesEnabled: iosMapConfig['zoomGesturesEnabled'],
      zoomControlsEnabled: iosMapConfig['zoomControlsEnabled'],
      scrollGesturesEnabled: iosMapConfig['scrollGesturesEnabled'],
      rotateGesturesEnabled: iosMapConfig['rotateGesturesEnabled'],
      tiltGesturesEnabled: iosMapConfig['tiltGesturesEnabled'],
      mapToolbarEnabled: iosMapConfig['mapToolbarEnabled'],
      padding: EdgeInsets.only(bottom: _clampedBottomPadding),
      markers: markers,
      polylines: polylines,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(
          () => EagerGestureRecognizer(),
        ),
      },
      // 🎯 FIX: Détecter quand l'utilisateur commence à naviguer manuellement
      onCameraMoveStarted: () {
        // 🎯 Ignorer les mouvements de caméra programmatiques (ex: bouton GPS)
        // Cela évite que animateCamera() réactive le mode libre
        if (_isProgrammaticCameraMove) {
          myCustomPrintStatement('🎯 Mouvement caméra programmatique - ignoré');
          return;
        }

        // 🎯 Ignorer les mouvements de caméra pendant les 5 premières secondes après le démarrage
        // Les recentrages automatiques au démarrage ne doivent pas activer le mode libre
        if (_screenInitTime != null) {
          final elapsedSinceInit = DateTime.now().difference(_screenInitTime!);
          if (elapsedSinceInit.inMilliseconds < 5000) {
            myCustomPrintStatement('🎯 Mouvement caméra ignoré - initialisation écran (${elapsedSinceInit.inMilliseconds}ms)');
            return;
          }
        }

        // 🎯 Ignorer les onCameraMoveStarted parasites pendant 2 secondes après un clic GPS
        // Google Maps peut déclencher plusieurs onCameraMoveStarted après une animation
        // (chargement de tuiles, ajustements internes, etc.)
        if (_lastGpsButtonClickTime != null) {
          final elapsed = DateTime.now().difference(_lastGpsButtonClickTime!);
          if (elapsed.inMilliseconds < 2000) {
            myCustomPrintStatement('🎯 Mouvement caméra ignoré - protection temporelle GPS (${elapsed.inMilliseconds}ms)');
            return;
          }
        }

        // Activer le mode libre dès que l'utilisateur touche la carte
        // (seulement sur le menu principal, pas pendant une course)
        final tripProvider = Provider.of<TripProvider>(context, listen: false);
        if (tripProvider.currentStep == CustomTripType.setYourDestination &&
            tripProvider.booking == null) {
          if (!_isUserNavigatingMap) {
            _isUserNavigatingMap = true;
            myCustomPrintStatement('🗺️ Mode libre activé - utilisateur navigue sur la carte');
          }
        }
      },
      onCameraMove: (CameraPosition position) {
        cameraLastPosition = position;
      },
      onCameraIdle: () {
        if (cameraLastPosition != null && dropLocationPickerHideNoti.value) {
          MyGlobalKeys.chooseDropAndPickAddPageKey.currentState!
              .pickedLocationLatLong(
            latitude: cameraLastPosition!.target.latitude,
            longitude: cameraLastPosition!.target.longitude,
          );
        }
        if (cameraLastPosition != null && pickupLocationPickerHideNoti.value) {
          MyGlobalKeys.chooseDropAndPickAddPageKey.currentState!
              .pickUpLocationMapLatLong(
            latitude: cameraLastPosition!.target.latitude,
            longitude: cameraLastPosition!.target.longitude,
          );
        }
        // 📍 Géocodage inverse pour l'étape confirmDestination
        if (cameraLastPosition != null && isConfirmDestination) {
          _updatePickupLocationFromMap(cameraLastPosition!.target);
        }
      },
    );
  }

  // 🎯 Flag pour bloquer la mise à jour du pickup pendant le centrage initial
  bool _isInitialPickupCentering = false;

  /// 📍 Centre la carte sur le pickup pour confirmDestination
  /// Le pickup apparaît exactement sous le pin flottant (centre de la zone visible)
  void _centerMapOnPickupForConfirmation(TripProvider tripProvider) {
    final pickupLat = tripProvider.pickLocation?['lat'];
    final pickupLng = tripProvider.pickLocation?['lng'];

    if (pickupLat == null || pickupLng == null || _mapController == null) {
      myCustomPrintStatement('⚠️ Impossible de centrer: pickup ou controller null');
      return;
    }

    final pickupPosition = LatLng(pickupLat, pickupLng);

    myCustomPrintStatement('📍 Centrage pickup: position=$pickupPosition');

    // Désactiver le mode libre et bloquer la mise à jour du pickup
    _isUserNavigatingMap = false;
    _isProgrammaticCameraMove = true;
    _isInitialPickupCentering = true; // Bloquer _updatePickupLocationFromMap

    // Attendre que le bottom sheet soit en place avant de centrer
    Future.delayed(const Duration(milliseconds: 350), () async {
      if (!mounted || _mapController == null) return;

      // Animation simple : centrer directement sur le pickup
      // Le pin flottant est positionné pour être au centre de la zone visible
      // donc le pickup doit être au centre de la carte (pas d'offset nécessaire
      // car le pin est au centre de la zone au-dessus du bottom sheet)
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pickupPosition,
            zoom: 17.5, // Zoom précis pour voir le lieu exact
          ),
        ),
      );

      myCustomPrintStatement('✅ Carte centrée sur pickup');

      // Réactiver la mise à jour du pickup après un délai
      Future.delayed(const Duration(milliseconds: 500), () {
        _isInitialPickupCentering = false;
      });
    });
  }

  /// 📍 Met à jour l'adresse de prise en charge via géocodage inverse
  /// (mise à jour silencieuse - la vérification du prix se fait au moment de confirmer)
  Future<void> _updatePickupLocationFromMap(LatLng position) async {
    // Éviter les appels multiples simultanés
    if (_isProcessingPriceUpdate) return;

    // 🎯 Ne pas mettre à jour pendant le centrage initial (évite de changer l'adresse)
    if (_isInitialPickupCentering) {
      myCustomPrintStatement('⏳ Centrage en cours, mise à jour pickup ignorée');
      return;
    }

    try {
      _isProcessingPriceUpdate = true;

      final address = await getAddressByLatLong(
        position.latitude,
        position.longitude,
      );

      if (!mounted || address.isEmpty) {
        _isProcessingPriceUpdate = false;
        return;
      }

      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      // Mettre à jour la position de prise en charge
      tripProvider.pickLocation = {
        'lat': position.latitude,
        'lng': position.longitude,
        'address': address,
      };

      myCustomPrintStatement('📍 Position mise à jour: $address');
    } catch (e) {
      myCustomPrintStatement('Erreur géocodage inverse: $e');
    } finally {
      _isProcessingPriceUpdate = false;
    }
  }

  /// 🎨 Placeholder simple avec fond map style + point bleu GPS
  Widget _buildMenuButton(DarkThemeProvider darkThemeProvider) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme
            ? MyColors.blackColor.withOpacity(0.8)
            : MyColors.whiteColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Ouvrir le tiroir gauche (CustomDrawer)
            _scaffoldKey.currentState?.openDrawer();
          },
          child: Icon(
            Icons.menu,
            color: darkThemeProvider.darkTheme
                ? MyColors.whiteColor
                : MyColors.blackColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Bouton "Se connecter" affiché uniquement en mode invité
  Widget _buildLoginButton(
      DarkThemeProvider darkThemeProvider, CustomAuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MyColors.primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MyColors.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            // Navigation directe vers l'écran de connexion
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginPage(),
              ),
            );
            // Rafraîchir l'écran après retour
            setState(() {});
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline,
                color: MyColors.whiteColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                translate("Se connecter"),
                style: TextStyle(
                  color: MyColors.whiteColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationButton(DarkThemeProvider darkThemeProvider) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme
            ? MyColors.blackColor.withOpacity(0.8)
            : MyColors.whiteColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // 🎯 FIX: Désactiver le mode libre et recentrer sur la position GPS
            _isUserNavigatingMap = false;
            _isProgrammaticCameraMove = true; // 🎯 Marquer comme mouvement programmatique
            _lastGpsButtonClickTime = DateTime.now(); // 🎯 Enregistrer le timestamp pour protection temporelle
            myCustomPrintStatement('🎯 Bouton GPS appuyé - mode libre désactivé');

            final mapProvider =
                Provider.of<GoogleMapProvider>(context, listen: false);

            // Vérifier que le contrôleur de carte est disponible
            if (mapProvider.controller == null) {
              myCustomPrintStatement('❌ Erreur: Contrôleur de carte non disponible');
              _isProgrammaticCameraMove = false;
              return;
            }

            try {
              // Récupérer la position GPS en temps réel
              myCustomPrintStatement('📍 Récupération position GPS...');
              final Position livePosition = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 5),
              );

              final LatLng positionToUse = LatLng(livePosition.latitude, livePosition.longitude);
              myCustomPrintStatement('📍 Position GPS obtenue: $positionToUse');

              // Mettre à jour les caches pour cohérence
              currentPosition = livePosition;
              mapProvider.currentPosition = positionToUse;
              _mapReferencePosition = positionToUse;

              // Animer directement avec le contrôleur pour éviter tout problème
              await mapProvider.controller!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: positionToUse,
                    zoom: 16.0,
                    bearing: 0.0,
                  ),
                ),
              );
              myCustomPrintStatement('✅ Recentrage sur position GPS EN DIRECT: $positionToUse');
            } catch (e) {
              myCustomPrintStatement('❌ Erreur récupération GPS: $e');

              // Fallback: utiliser la dernière position connue si disponible
              LatLng? lastKnown = mapProvider.currentPosition;
              if (lastKnown == null && currentPosition != null) {
                lastKnown = LatLng(currentPosition!.latitude, currentPosition!.longitude);
              }

              if (lastKnown != null && mapProvider.controller != null) {
                await mapProvider.controller!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: lastKnown,
                      zoom: 16.0,
                      bearing: 0.0,
                    ),
                  ),
                );
                _mapReferencePosition = lastKnown;
                myCustomPrintStatement('⚠️ Recentrage sur dernière position connue: $lastKnown');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Position GPS non disponible')),
                );
              }
            } finally {
              // 🎯 Réinitialiser le flag après un court délai pour s'assurer que l'animation est terminée
              Future.delayed(const Duration(milliseconds: 500), () {
                _isProgrammaticCameraMove = false;
                myCustomPrintStatement('🎯 Flag programmatique réinitialisé');
              });
            }
          },
          child: Icon(
            Icons.my_location,
            color: darkThemeProvider.darkTheme
                ? MyColors.whiteColor
                : MyColors.blackColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🍎 iOS LIQUID GLASS : Bottom sheet avec nav bar intégrée comme état collapsed
  // ═══════════════════════════════════════════════════════════════════════════

  /// Construit le Liquid Glass bottom sheet iOS avec 3 états:
  /// - Collapsed (80px): Nav bar bulle expandable
  /// - Intermediate (38%): Titre + options véhicules + recherche
  /// - Expanded (90%): Contenu complet avec destinations populaires
  Widget _buildIOSLiquidGlassWithNavBar(
    DarkThemeProvider darkThemeProvider,
    TripProvider tripProvider,
    double screenHeight,
  ) {
    final isDarkMode = darkThemeProvider.darkTheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Hauteurs pour les 3 états (utilise les constantes de LiquidGlassColors)
    const double collapsedHeight = 56.0; // Même hauteur que la capsule
    final double intermediateHeight = screenHeight * LiquidGlassColors.intermediateHeightRatio; // 60%
    final double expandedHeight = screenHeight * LiquidGlassColors.expandedHeightRatio; // 90%

    // Calculer la hauteur actuelle basée sur l'extent
    double currentHeight;
    double currentMargin;
    double currentBottomMargin;
    BorderRadius currentBorderRadius;

    // Calcul basé sur l'extent (0.0 à 1.0) avec interpolation fluide
    if (_iosSheetExtent <= 0.10) {
      // État collapsed (0.0 à 0.10) - HAUTEUR FIXE nav bar (pas de variation)
      // La nav bar reste à sa place sans remonter pendant le drag
      currentHeight = collapsedHeight;
      currentMargin = 16.0;
      currentBottomMargin = bottomPadding + 8.0;
      currentBorderRadius = BorderRadius.circular(36.0);
    } else if (_iosSheetExtent <= 0.55) {
      // État intermediate (0.10 à 0.55) - snap à 0.5
      // La hauteur suit le doigt de collapsed (56px) à intermediate (60% écran)
      // Interpolation de la hauteur : collapsed → intermediate
      final heightT = (_iosSheetExtent - 0.10) / 0.40; // Atteint intermediateHeight à extent 0.5
      final clampedHeightT = heightT.clamp(0.0, 1.0);
      currentHeight = collapsedHeight + (intermediateHeight - collapsedHeight) * clampedHeightT;
      // Bulle flottante : marges et coins arrondis constants
      currentMargin = 12.0;
      currentBottomMargin = bottomPadding + 8.0;
      currentBorderRadius = BorderRadius.circular(36.0);
    } else if (_iosSheetExtent <= 0.70) {
      // Transition intermediate → expanded (0.55 à 0.70)
      // Les marges et arrondis du bas commencent à disparaître
      final t = (_iosSheetExtent - 0.55) / 0.15;
      currentHeight = intermediateHeight;
      currentMargin = 12.0 * (1.0 - t);
      currentBottomMargin = (bottomPadding + 8.0) * (1.0 - t);
      final bottomRadius = 36.0 * (1.0 - t);
      currentBorderRadius = BorderRadius.only(
        topLeft: Radius.circular(36.0),
        topRight: Radius.circular(36.0),
        bottomLeft: Radius.circular(bottomRadius),
        bottomRight: Radius.circular(bottomRadius),
      );
    } else {
      // État expanded (0.70 à 1.0) - snap à 1.0
      // La hauteur grandit, les arrondis du haut restent constants
      final t = (_iosSheetExtent - 0.70) / 0.30;
      currentHeight = intermediateHeight + (expandedHeight - intermediateHeight) * t;
      currentMargin = 0.0;
      currentBottomMargin = 0.0;
      currentBorderRadius = BorderRadius.only(
        topLeft: Radius.circular(36.0),
        topRight: Radius.circular(36.0),
      );
    }

    // Couleur de fond Liquid Glass avec opacité progressive (70% → 92%)
    final backgroundColor = isDarkMode
        ? LiquidGlassColors.sheetBackgroundDark
        : LiquidGlassColors.sheetBackground;
    final currentOpacity = LiquidGlassColors.getOpacity(_iosSheetExtent);

    // GestureDetector unique qui englobe tout pour ne pas perdre le gesture pendant le drag
    return AnimatedPositioned(
      duration: _iosSheetAnimating ? const Duration(milliseconds: 300) : Duration.zero,
      curve: Curves.easeOutCubic,
      left: currentMargin,
      right: currentMargin,
      bottom: currentBottomMargin,
      height: currentHeight,
      child: GestureDetector(
        onVerticalDragUpdate: (details) => _onIOSSheetDragUpdate(details, screenHeight),
        onVerticalDragEnd: _onIOSSheetDragEnd,
        onTap: _iosSheetState == 0 ? _onIOSSheetTap : null,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: currentBorderRadius,
          child: BackdropFilter(
            filter: LiquidGlassColors.getBlurFilter(_iosSheetExtent),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(currentOpacity),
                borderRadius: currentBorderRadius,
                boxShadow: [
                  BoxShadow(
                    color: LiquidGlassColors.shadowColor,
                    blurRadius: LiquidGlassColors.shadowBlurRadius,
                    spreadRadius: 0,
                    offset: LiquidGlassColors.shadowOffset,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar (visible seulement en intermediate/expanded)
                  if (_iosSheetState != 0) _buildIOSHandleBar(),
                  // Contenu au-dessus de la nav bar (vide en collapsed)
                  if (_iosSheetState != 0)
                    Expanded(
                      child: _buildIOSSheetContentWithoutNavBar(darkThemeProvider, tripProvider),
                    ),
                  // Spacer pour pousser la nav bar en bas en collapsed
                  if (_iosSheetState == 0) const Spacer(),
                  // Nav bar toujours fixe en bas
                  _buildIOSCollapsedContent(darkThemeProvider, tripProvider),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handle bar style iOS - Zone de drag élargie pour faciliter le geste
  Widget _buildIOSHandleBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      color: Colors.transparent, // Zone de touche invisible élargie
      child: Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }

  /// Contenu du Liquid Glass selon l'état
  Widget _buildIOSSheetContent(
    DarkThemeProvider darkThemeProvider,
    TripProvider tripProvider,
  ) {
    switch (_iosSheetState) {
      case 0:
        return _buildIOSCollapsedContent(darkThemeProvider, tripProvider);
      case 1:
        return _buildIOSIntermediateContent(darkThemeProvider, tripProvider);
      case 2:
        return _buildIOSExpandedContent(darkThemeProvider, tripProvider);
      default:
        return _buildIOSIntermediateContent(darkThemeProvider, tripProvider);
    }
  }

  /// Contenu de la sheet SANS la nav bar (pour intermediate/expanded)
  Widget _buildIOSSheetContentWithoutNavBar(
    DarkThemeProvider darkThemeProvider,
    TripProvider tripProvider,
  ) {
    final isDarkMode = darkThemeProvider.darkTheme;

    return SingleChildScrollView(
      controller: _iosSheetState == 2 ? _iosContentScrollController : null,
      physics: _iosSheetState == 2
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Text(
              translate('chooseYourTrip'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : MyColors.blackColor,
              ),
            ),
            const SizedBox(height: 12),
            // Options véhicules
            _buildVehicleOptions(darkThemeProvider),
            const SizedBox(height: 8),
            // Champ de recherche
            _buildSearchField(darkThemeProvider),
            // Actions rapides (Définir sur carte + Dernier résultat)
            _buildQuickActions(darkThemeProvider),
            // Destinations populaires
            _buildAdditionalContent(darkThemeProvider),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// État collapsed: Nav bar bulle avec 4 items + bouton loupe (expandable)
  /// Animation interactive: scale up quand pressé, indicateur glisse avec le doigt
  Widget _buildIOSCollapsedContent(
    DarkThemeProvider darkThemeProvider,
    TripProvider tripProvider,
  ) {
    final isDarkMode = darkThemeProvider.darkTheme;
    // Couleurs adaptées au fond Liquid Glass
    final activeColor = isDarkMode ? MyColors.whiteColor : MyColors.blackColor;
    final inactiveColor = isDarkMode
        ? MyColors.whiteColor.withOpacity(0.6)
        : MyColors.blackColor.withOpacity(0.5);
    final activeBgColor = isDarkMode
        ? MyColors.whiteColor.withOpacity(0.2)
        : MyColors.blackColor.withOpacity(0.1);

    // Obtenir l'index de navigation actuel depuis MainNavigationScreen
    final currentIndex = MainNavigationScreenState.instance?.currentIndex ?? 0;
    // Index à afficher comme sélectionné (hover pendant drag, sinon current)
    final displayIndex = _navBarPressed && _navBarHoverIndex >= 0
        ? _navBarHoverIndex
        : currentIndex;

    return Row(
      children: [
        // Capsule principale avec les 4 onglets - interactive
        Expanded(
          child: GestureDetector(
            onPanStart: (details) => _onNavBarPanStart(details),
            onPanUpdate: (details) => _onNavBarPanUpdate(details),
            onPanEnd: (details) => _onNavBarPanEnd(details),
            onTapDown: (_) => setState(() => _navBarPressed = true),
            onTapUp: (_) => setState(() => _navBarPressed = false),
            onTapCancel: () => setState(() => _navBarPressed = false),
            child: AnimatedScale(
              scale: _navBarPressed ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / 4;
                    return Stack(
                      children: [
                        // Indicateur de sélection animé (fond du bouton actif)
                        AnimatedPositioned(
                          duration: _navBarPressed
                              ? const Duration(milliseconds: 50) // Rapide pendant drag
                              : const Duration(milliseconds: 200), // Plus lent après relâchement
                          curve: Curves.easeOutCubic,
                          left: displayIndex * itemWidth + (itemWidth - 60) / 2,
                          top: 4,
                          child: Container(
                            width: 60,
                            height: 48,
                            decoration: BoxDecoration(
                              color: activeBgColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        // Les 4 items de navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 1. Home
                            _buildIOSNavItemStatic(
                              icon: Icons.home_outlined,
                              activeIcon: Icons.home,
                              label: translate('home'),
                              isSelected: displayIndex == 0,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                            ),
                            // 2. Mes Trajets
                            _buildIOSNavItemStatic(
                              icon: Icons.directions_car_outlined,
                              activeIcon: Icons.directions_car,
                              label: translate('myBooking'),
                              isSelected: displayIndex == 1,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                            ),
                            // 3. Courrier
                            _buildIOSNavItemStatic(
                              icon: Icons.mail_outlined,
                              activeIcon: Icons.mail,
                              label: translate('myMail'),
                              isSelected: displayIndex == 2,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                            ),
                            // 4. Profil
                            _buildIOSNavItemStatic(
                              icon: Icons.person_outline,
                              activeIcon: Icons.person,
                              label: translate('myProfile'),
                              isSelected: displayIndex == 3,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Bouton loupe séparé
        _buildIOSSearchButton(isDarkMode, tripProvider),
      ],
    );
  }

  /// Item de navigation statique (sans gesture, utilisé dans le Stack)
  Widget _buildIOSNavItemStatic({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? activeColor : inactiveColor,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? activeColor : inactiveColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Début du pan sur la nav bar
  void _onNavBarPanStart(DragStartDetails details) {
    setState(() {
      _navBarPressed = true;
      _navBarDragX = details.localPosition.dx;
      _updateNavBarHoverIndex(details.localPosition.dx);
    });
  }

  /// Mise à jour pendant le pan sur la nav bar
  void _onNavBarPanUpdate(DragUpdateDetails details) {
    setState(() {
      _navBarDragX = details.localPosition.dx;
      _updateNavBarHoverIndex(details.localPosition.dx);
    });
  }

  /// Fin du pan sur la nav bar - navigation vers l'onglet sélectionné
  void _onNavBarPanEnd(DragEndDetails details) {
    final targetIndex = _navBarHoverIndex;
    setState(() {
      _navBarPressed = false;
      _navBarHoverIndex = -1;
    });
    // Naviguer vers l'onglet si valide
    if (targetIndex >= 0 && targetIndex <= 3) {
      _onIOSNavItemTap(targetIndex);
    }
  }

  /// Calcule l'index du bouton sous le doigt
  void _updateNavBarHoverIndex(double localX) {
    // La capsule fait toute la largeur disponible moins le bouton loupe
    // On divise en 4 zones égales
    final screenWidth = MediaQuery.of(context).size.width;
    final capsuleWidth = screenWidth - 32 - 12 - 56; // padding - gap - loupe
    final itemWidth = capsuleWidth / 4;

    int index = (localX / itemWidth).floor();
    index = index.clamp(0, 3);
    _navBarHoverIndex = index;
  }

  /// Item de navigation iOS (style Apple TV) - Labels toujours visibles sous l'icône
  Widget _buildIOSNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
    required Color activeBgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Item de navigation iOS avec badge (pour courrier) - Labels toujours visibles sous l'icône
  Widget _buildIOSNavItemWithBadge({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
    required Color activeBgColor,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                style: const TextStyle(fontSize: 9),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bouton loupe iOS (bulle circulaire) - Même couleur Liquid Glass, séparé visuellement
  Widget _buildIOSSearchButton(bool isDarkMode, TripProvider tripProvider) {
    return GestureDetector(
      onTap: () {
        // Toujours naviguer vers la sélection pickup/drop
        tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.search,
          color: isDarkMode
              ? MyColors.whiteColor.withOpacity(0.9)
              : MyColors.blackColor.withOpacity(0.7),
          size: 26,
        ),
      ),
    );
  }

  /// État intermediate: Contenu complet (carte + dernier résultat + destinations) + nav bar en bas
  Widget _buildIOSIntermediateContent(DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    final isDarkMode = darkThemeProvider.darkTheme;

    return Column(
      children: [
        // Contenu scrollable
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    translate('chooseYourTrip'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : MyColors.blackColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Options véhicules
                  _buildVehicleOptions(darkThemeProvider),
                  const SizedBox(height: 8),
                  // Champ de recherche
                  _buildSearchField(darkThemeProvider),
                  // Actions rapides (Définir sur carte + Dernier résultat)
                  _buildQuickActions(darkThemeProvider),
                  // Destinations populaires
                  _buildAdditionalContent(darkThemeProvider),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        // Nav bar en bas
        _buildIOSBottomNavBar(darkThemeProvider, tripProvider),
      ],
    );
  }

  /// État expanded: Contenu complet avec scroll + nav bar en bas
  /// Le scroll déclenche le minimize/expand de la nav bar (Apple Liquid Glass)
  Widget _buildIOSExpandedContent(DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    final isDarkMode = darkThemeProvider.darkTheme;

    return Column(
      children: [
        // Contenu scrollable avec controller pour détecter direction du scroll
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Reset nav bar à l'état normal quand on atteint le haut
              if (notification is ScrollEndNotification) {
                if (_iosContentScrollController.offset <= 0 && _isNavBarMinimized) {
                  setState(() => _isNavBarMinimized = false);
                }
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _iosContentScrollController,
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    Text(
                      translate('chooseYourTrip'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : MyColors.blackColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Options véhicules
                    _buildVehicleOptions(darkThemeProvider),
                    const SizedBox(height: 8),
                    // Champ de recherche
                    _buildSearchField(darkThemeProvider),
                    // Actions rapides
                    _buildQuickActions(darkThemeProvider),
                    // Destinations populaires
                    _buildAdditionalContent(darkThemeProvider),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Nav bar en bas (se minimize au scroll)
        _buildIOSBottomNavBar(darkThemeProvider, tripProvider),
      ],
    );
  }

  /// Nav bar en bas du Liquid Glass (pour intermediate et expanded)
  /// Apple: "Tab bars recede when scrolling, bringing focus to content"
  Widget _buildIOSBottomNavBar(DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    final isDarkMode = darkThemeProvider.darkTheme;
    // Couleurs adaptées au fond du Liquid Glass
    final activeColor = isDarkMode ? MyColors.horizonBlue : MyColors.horizonBlue;
    final inactiveColor = isDarkMode
        ? Colors.white.withOpacity(0.6)
        : MyColors.textSecondary;
    final activeBgColor = isDarkMode
        ? MyColors.horizonBlue.withOpacity(0.15)
        : MyColors.horizonBlue.withOpacity(0.1);
    final currentIndex = MainNavigationScreenState.instance?.currentIndex ?? 0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Animation fluide entre état normal et minimisé
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        20,
        _isNavBarMinimized ? 6 : 12,
        20,
        bottomPadding + (_isNavBarMinimized ? 4 : 8),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isNavBarMinimized ? 0.7 : 1.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildIOSNavItemMinimizable(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: translate('home'),
              isSelected: currentIndex == 0,
              isMinimized: _isNavBarMinimized,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              activeBgColor: activeBgColor,
              onTap: () => _onIOSNavItemTap(0),
            ),
            _buildIOSNavItemMinimizable(
              icon: Icons.directions_car_outlined,
              activeIcon: Icons.directions_car,
              label: translate('myBooking'),
              isSelected: currentIndex == 1,
              isMinimized: _isNavBarMinimized,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              activeBgColor: activeBgColor,
              onTap: () => _onIOSNavItemTap(1),
            ),
            ValueListenableBuilder<int>(
              valueListenable: unreadMessagesCount,
              builder: (context, count, child) {
                return _buildIOSNavItemMinimizable(
                  icon: Icons.mail_outlined,
                  activeIcon: Icons.mail,
                  label: translate('myMail'),
                  isSelected: currentIndex == 2,
                  isMinimized: _isNavBarMinimized,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  activeBgColor: activeBgColor,
                  badgeCount: count,
                  onTap: () => _onIOSNavItemTap(2),
                );
              },
            ),
            _buildIOSNavItemMinimizable(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: translate('myProfile'),
              isSelected: currentIndex == 3,
              isMinimized: _isNavBarMinimized,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              activeBgColor: activeBgColor,
              onTap: () => _onIOSNavItemTap(3),
            ),
          ],
        ),
      ),
    );
  }

  /// Nav item qui supporte l'état minimisé (icône seule sans label)
  Widget _buildIOSNavItemMinimizable({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required bool isMinimized,
    required Color activeColor,
    required Color inactiveColor,
    required Color activeBgColor,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final displayIcon = isSelected ? activeIcon : icon;
    final color = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isMinimized ? 12 : 16,
          vertical: isMinimized ? 6 : 8,
        ),
        decoration: isSelected
            ? BoxDecoration(
                color: activeBgColor,
                borderRadius: BorderRadius.circular(isMinimized ? 16 : 20),
              )
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(displayIcon, color: color, size: isMinimized ? 22 : 24),
                  // Label caché quand minimisé
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: isMinimized ? 0 : 16,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 100),
                      opacity: isMinimized ? 0 : 1,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Badge pour les notifications
            if (badgeCount > 0)
              Positioned(
                top: -4,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Gestion du drag sur le Liquid Glass iOS
  void _onIOSSheetDragUpdate(DragUpdateDetails details, double screenHeight) {
    setState(() {
      // Désactiver l'animation pendant le drag (le sheet suit le doigt immédiatement)
      _iosSheetAnimating = false;

      // Le sheet suit le doigt
      _iosSheetExtent -= details.primaryDelta! / (screenHeight * 0.5);
      _iosSheetExtent = _iosSheetExtent.clamp(0.0, 1.0);

      // Mettre à jour l'état discret pour le contenu
      // On garde collapsed tant que la hauteur n'est pas suffisante pour intermediate
      // (attendre extent ~0.40 pour avoir assez de place pour le contenu intermediate)
      if (_iosSheetExtent < 0.40) {
        _iosSheetState = 0; // collapsed - garder nav bar
      } else if (_iosSheetExtent < 0.70) {
        _iosSheetState = 1; // intermediate
      } else {
        _iosSheetState = 2; // expanded
      }
    });
  }

  /// Snap vers l'état le plus proche quand on relâche le doigt
  /// États fixes : 0.0 (collapsed), 0.5 (intermediate), 1.0 (expanded)
  void _onIOSSheetDragEnd(DragEndDetails details) {
    double targetExtent;
    int targetState;

    // Seuils de snap : favoriser le retour à collapsed si on n'est pas allé assez loin
    // collapsed (0.0) ↔ intermediate (0.5) : seuil à 0.40
    // intermediate (0.5) ↔ expanded (1.0) : seuil à 0.75
    if (_iosSheetExtent < 0.40) {
      // Snap vers collapsed - redescendre automatiquement
      targetExtent = 0.0;
      targetState = 0;
    } else if (_iosSheetExtent < 0.75) {
      // Snap vers intermediate (valeur fixe 0.5)
      targetExtent = 0.5;
      targetState = 1;
    } else {
      // Snap vers expanded
      targetExtent = 1.0;
      targetState = 2;
    }

    // Animer vers l'état cible avec AnimatedPositioned
    setState(() {
      _iosSheetAnimating = true; // Activer l'animation
      _iosSheetExtent = targetExtent;
      _iosSheetState = targetState;
      if (targetState != 2) {
        _isNavBarMinimized = false;
      }
    });
  }

  /// Tap sur le sheet collapsed pour l'expandre vers intermediate
  void _onIOSSheetTap() {
    setState(() {
      _iosSheetAnimating = true;
      _iosSheetExtent = 0.5;
      _iosSheetState = 1;
    });
  }

  /// Navigation vers un autre onglet depuis le Liquid Glass
  void _onIOSNavItemTap(int index) {
    final currentIndex = MainNavigationScreenState.instance?.currentIndex ?? 0;

    if (index == 0 && currentIndex == 0) {
      // Si déjà sur Home, expand le sheet
      _onIOSSheetTap();
    } else if (index != 0 && _iosSheetState != 0) {
      // Si on navigue vers un autre onglet et que la sheet est ouverte,
      // on anime d'abord la fermeture puis on navigue
      setState(() {
        _iosSheetAnimating = true;
        _iosSheetExtent = 0.0;
        _iosSheetState = 0;
      });
      // Naviguer après l'animation (150ms pour une transition rapide)
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          MainNavigationScreenState.instance?.navigateToIndex(index);
        }
      });
    } else {
      // Sinon, naviguer directement vers l'onglet demandé
      MainNavigationScreenState.instance?.navigateToIndex(index);
    }
  }

  Widget _buildBottomSheetContent(
      DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    return GestureDetector(
      // Capture les gestes sur toute la surface MAIS laisse passer les taps aux enfants
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        // Enregistrer la position de départ pour calculer le suivi direct
        _panStartY = details.globalPosition.dy;
        _panStartHeight = _currentBottomSheetHeight;
      },
      onPanUpdate: (details) {
        if (_panStartY == null || _panStartHeight == null) return;
        // 📍 Désactiver le drag uniquement pour confirmDestination (hauteur fixe)
        final tripProvider = Provider.of<TripProvider>(context, listen: false);
        if (tripProvider.currentStep == CustomTripType.confirmDestination) return;

        // Calculer la différence depuis le début du pan
        final screenHeight = MediaQuery.of(context).size.height;
        final deltaY = _panStartY! -
            details.globalPosition.dy; // Inversé car Y augmente vers le bas

        // Convertir le déplacement en pourcentage de hauteur d'écran
        final deltaHeight = deltaY / screenHeight;

        // Limites spécifiques pour driverOnWay et requestForRide
        final isDriverOnWay = tripProvider.currentStep == CustomTripType.driverOnWay;
        final isRequestForRide = tripProvider.currentStep == CustomTripType.requestForRide;
        final minH = (isDriverOnWay || isRequestForRide) ? _midBottomSheetHeight : _lowestBottomSheetHeight;
        final maxH = _maxBottomSheetHeight;

        // Appliquer le changement à la hauteur de départ
        final newHeight = (_panStartHeight! + deltaHeight)
            .clamp(minH, maxH);

        setState(() {
          _currentBottomSheetHeight = newHeight;
        });

        // Optimiser l'application du map padding pour éviter les freezes
        // Ne pas appliquer de padding pendant le drag continu pour plus de fluidité
        _applyMapPadding();
      },
      onPanEnd: (details) {
        // 📍 Ignorer uniquement pour confirmDestination (hauteur fixe)
        final tripProvider = Provider.of<TripProvider>(context, listen: false);
        if (tripProvider.currentStep == CustomTripType.confirmDestination) return;

        // Snapping vers le niveau le plus proche
        final velocity = details.velocity.pixelsPerSecond.dy;
        final isDriverOnWay = tripProvider.currentStep == CustomTripType.driverOnWay;
        final isRequestForRide = tripProvider.currentStep == CustomTripType.requestForRide;
        double targetHeight;

        if (isDriverOnWay || isRequestForRide) {
          // Snap points spécifiques pour driverOnWay et requestForRide: 55%, 58%, 78%
          if (velocity > 300) {
            // Glissement vers le bas
            if (_currentBottomSheetHeight > _driverOnWayHeight) {
              targetHeight = _driverOnWayHeight;
            } else {
              targetHeight = _midBottomSheetHeight;
            }
          } else if (velocity < -300) {
            // Glissement vers le haut
            if (_currentBottomSheetHeight < _driverOnWayHeight) {
              targetHeight = _driverOnWayHeight;
            } else {
              targetHeight = _maxBottomSheetHeight;
            }
          } else {
            // Snap vers le niveau le plus proche
            final distances = {
              (_currentBottomSheetHeight - _midBottomSheetHeight).abs(): _midBottomSheetHeight,
              (_currentBottomSheetHeight - _driverOnWayHeight).abs(): _driverOnWayHeight,
              (_currentBottomSheetHeight - _maxBottomSheetHeight).abs(): _maxBottomSheetHeight,
            };
            final minDistance = distances.keys.reduce((a, b) => a < b ? a : b);
            targetHeight = distances[minDistance]!;
          }
        } else if (velocity > 300) {
          // Glissement rapide vers le bas (seuil réduit pour plus de réactivité)
          if (_currentBottomSheetHeight > _midBottomSheetHeight) {
            targetHeight = _midBottomSheetHeight;
          } else if (_currentBottomSheetHeight > _minBottomSheetHeight) {
            targetHeight = _minBottomSheetHeight;
          } else {
            targetHeight = _lowestBottomSheetHeight;
          }
        } else if (velocity < -300) {
          // Glissement rapide vers le haut (seuil réduit pour plus de réactivité)
          if (_currentBottomSheetHeight < _minBottomSheetHeight) {
            targetHeight = _minBottomSheetHeight;
          } else if (_currentBottomSheetHeight < _midBottomSheetHeight) {
            targetHeight = _midBottomSheetHeight;
          } else {
            targetHeight = _maxBottomSheetHeight;
          }
        } else {
          // Snap vers le niveau le plus proche
          final distanceToLowest =
              (_currentBottomSheetHeight - _lowestBottomSheetHeight).abs();
          final distanceToMin =
              (_currentBottomSheetHeight - _minBottomSheetHeight).abs();
          final distanceToMid =
              (_currentBottomSheetHeight - _midBottomSheetHeight).abs();
          final distanceToMax =
              (_currentBottomSheetHeight - _maxBottomSheetHeight).abs();

          final distances = {
            distanceToLowest: _lowestBottomSheetHeight,
            distanceToMin: _minBottomSheetHeight,
            distanceToMid: _midBottomSheetHeight,
            distanceToMax: _maxBottomSheetHeight,
          };

          final minDistance = distances.keys.reduce((a, b) => a < b ? a : b);
          targetHeight = distances[minDistance]!;
        }

        _updateBottomSheetHeight(targetHeight);

        // Nettoyer les variables de tracking
        _panStartY = null;
        _panStartHeight = null;

        // Centrer la carte seulement si la hauteur a réellement changé
        if (targetHeight != _previousBottomSheetHeight) {
          Future.delayed(const Duration(milliseconds: 100), () {
            final tripProvider =
                Provider.of<TripProvider>(context, listen: false);
            final mapProvider =
                Provider.of<GoogleMapProvider>(context, listen: false);

            // 🎯 FIX: Désactiver temporairement le mode libre pour permettre le recentrage
            // Le drag du bottom sheet n'est pas une navigation manuelle sur la carte
            final wasUserNavigating = _isUserNavigatingMap;
            _isUserNavigatingMap = false;
            _isProgrammaticCameraMove = true;

            // Si on a un itinéraire actif, le réadapter à la nouvelle hauteur pour tous les écrans de réservation
            if (mapProvider.polylineCoordinates.isNotEmpty &&
                _shouldAdaptRouteForCurrentStep(tripProvider.currentStep)) {
              myCustomPrintStatement(
                  '🔄 Réadaptation itinéraire après changement hauteur bottom sheet - Étape: ${tripProvider.currentStep}');
              mapProvider.adaptRouteToBottomSheetHeightChange();
            } else {
              // Sinon, centrer normalement sur la position de référence
              _centerMapToReference();
            }

            // 🎯 Réinitialiser le flag programmatique après un délai
            Future.delayed(const Duration(milliseconds: 500), () {
              _isProgrammaticCameraMove = false;
            });
          });
        }
      },
      child: Column(
        children: [
          // Barre de manipulation visuelle (plus petite maintenant)
          Container(
            width: double.infinity,
            height: 24,
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: darkThemeProvider.darkTheme
                      ? MyColors.whiteColor.withOpacity(0.3)
                      : MyColors.blackColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          Expanded(
            child: _buildDefaultContent(darkThemeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultContent(DarkThemeProvider darkThemeProvider) {
    // Calcul optimisé des opacités pour réduire les lags
    // Utiliser des seuils discrets pour éviter les recalculs constants

    // Opacité pour les widgets "Trajets" et "Trajets planifiés"
    double vehicleOptionsOpacity = 0.0;
    if (_currentBottomSheetHeight > _lowestBottomSheetHeight) {
      if (_currentBottomSheetHeight >= _minBottomSheetHeight) {
        vehicleOptionsOpacity = 1.0;
      } else {
        // Transition progressive mais simplifiée
        final range = _minBottomSheetHeight - _lowestBottomSheetHeight;
        final progress =
            (_currentBottomSheetHeight - _lowestBottomSheetHeight) / range;
        vehicleOptionsOpacity = progress.clamp(0.0, 1.0);
      }
    }

    // Opacité pour le widget des destinations populaires
    double popularDestinationsOpacity = 0.0;
    if (_currentBottomSheetHeight > _minBottomSheetHeight) {
      if (_currentBottomSheetHeight >= _midBottomSheetHeight) {
        popularDestinationsOpacity = 1.0;
      } else {
        // Transition progressive mais simplifiée
        final range = _midBottomSheetHeight - _minBottomSheetHeight;
        final progress =
            (_currentBottomSheetHeight - _minBottomSheetHeight) / range;
        popularDestinationsOpacity = progress.clamp(0.0, 1.0);
      }
    }

    // Opacité pour le titre "Choisissez votre trajet"
    double titleOpacity = vehicleOptionsOpacity;

    // Le scroll n'est activé que lorsque le bottom sheet est à sa hauteur maximale (78%)
    final bool isFullyExpanded = _currentBottomSheetHeight >= _maxBottomSheetHeight - 0.02;

    return SingleChildScrollView(
      physics: isFullyExpanded
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre avec transition en fondu optimisée
            AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: titleOpacity,
              child: Container(
                height: titleOpacity > 0 ? null : 0,
                child: titleOpacity > 0
                    ? Column(
                        children: [
                          Text(
                            translate('chooseYourTrip'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: darkThemeProvider.darkTheme
                                  ? MyColors.whiteColor
                                  : MyColors.blackColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // Options de véhicules avec transition optimisée
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: vehicleOptionsOpacity,
              child: Container(
                height: vehicleOptionsOpacity > 0 ? null : 0,
                child: vehicleOptionsOpacity > 0
                    ? Column(
                        children: [
                          _buildVehicleOptions(darkThemeProvider),
                          const SizedBox(height: 8),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // Champ de recherche toujours visible
            _buildSearchField(darkThemeProvider),

            // Raccourcis d'actions rapides - toujours monté, visibility contrôlée
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: popularDestinationsOpacity,
              child: IgnorePointer(
                ignoring: popularDestinationsOpacity == 0,
                child: _buildQuickActions(darkThemeProvider),
              ),
            ),

            // Destinations populaires - toujours monté, visibility contrôlée
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: popularDestinationsOpacity,
              child: IgnorePointer(
                ignoring: popularDestinationsOpacity == 0,
                child: _buildAdditionalContent(darkThemeProvider),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleOptions(DarkThemeProvider darkThemeProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildVehicleOption(
            iconPath: MyImagesUrl.trajetsAllonsY,
            title: translate('trips'),
            subtitle: translate('letsGo'),
            darkThemeProvider: darkThemeProvider,
            onTap: () {
              // Analytics tracking
              final authProvider =
                  Provider.of<CustomAuthProvider>(context, listen: false);
              AnalyticsService.logRideTypeClicked(
                rideType: 'immediate',
                userId: userData.value?.id,
              );

              // Navigation vers la page de création de trajet
              Provider.of<TripProvider>(context, listen: false)
                  .setScreen(CustomTripType.choosePickupDropLocation);
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildVehicleOption(
            iconPath: MyImagesUrl.trajetsPlanifies,
            title: translate('scheduledTrips'),
            subtitle: translate('bookInAdvance'),
            darkThemeProvider: darkThemeProvider,
            onTap: () async {
              // Log Analytics event pour clic bouton course planifiée
              final userDetails = await DevFestPreferences().getUserDetails();
              final userId = userDetails?.id;

              await AnalyticsService.logScheduledRideButtonClicked(
                userId: userId,
              );

              // Navigation vers la page "réserver une course"
              Provider.of<TripProvider>(context, listen: false)
                  .setScreen(CustomTripType.selectScheduleTime);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleOption({
    required String iconPath,
    required String title,
    required String subtitle,
    required DarkThemeProvider darkThemeProvider,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme
            ? MyColors.whiteColor.withOpacity(0.08)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                iconPath,
                height: 60,
                width: 110,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: darkThemeProvider.darkTheme
                      ? MyColors.whiteColor
                      : MyColors.blackColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: darkThemeProvider.darkTheme
                      ? MyColors.whiteColor.withOpacity(0.6)
                      : MyColors.blackColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(DarkThemeProvider darkThemeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme
            ? MyColors.whiteColor.withOpacity(0.1)
            : MyColors.blackColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Analytics tracking
            final authProvider =
                Provider.of<CustomAuthProvider>(context, listen: false);
            AnalyticsService.logRideTypeClicked(
              rideType: 'immediate',
              userId: userData.value?.id,
            );

            // Navigation vers la page de création de trajet
            Provider.of<TripProvider>(context, listen: false)
                .setScreen(CustomTripType.choosePickupDropLocation);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: darkThemeProvider.darkTheme
                      ? MyColors.whiteColor.withOpacity(0.7)
                      : MyColors.blackColor.withOpacity(0.7),
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    translate('Whereto'),
                    style: TextStyle(
                      fontSize: 16,
                      color: darkThemeProvider.darkTheme
                          ? MyColors.whiteColor.withOpacity(0.7)
                          : MyColors.blackColor.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Section des raccourcis d'actions rapides
  /// Affiche le bouton "Choisir sur la carte" et la dernière adresse utilisée
  /// Style identique aux destinations favorites (PopularDestinationsWidget)
  Widget _buildQuickActions(DarkThemeProvider darkThemeProvider) {
    return ValueListenableBuilder(
      valueListenable: lastSearchSuggestion,
      builder: (context, lastSearchList, child) {
        return Column(
          children: [
            const SizedBox(height: 12),
            // Bouton "Choisir un point sur la carte"
            _buildQuickActionItem(
              icon: Icons.map_outlined,
              title: translate("Set from map"),
              subtitle: translate("Pick a location on the map"),
              darkThemeProvider: darkThemeProvider,
              onTap: () => _openMapLocationPicker(),
            ),

            // Dernière adresse (si disponible)
            if (lastSearchList.isNotEmpty)
              _buildLastAddressItem(lastSearchList.first, darkThemeProvider),
          ],
        );
      },
    );
  }

  /// Item d'action rapide - Style identique aux destinations favorites
  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required DarkThemeProvider darkThemeProvider,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: darkThemeProvider.darkTheme
                    ? MyColors.whiteColor.withOpacity(0.1)
                    : const Color(0xFFF9F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: MyColors.horizonBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkThemeProvider.darkTheme
                          ? MyColors.whiteColor
                          : MyColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle.toLowerCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: darkThemeProvider.darkTheme
                          ? MyColors.whiteColor.withOpacity(0.7)
                          : MyColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: darkThemeProvider.darkTheme
                  ? MyColors.whiteColor.withOpacity(0.5)
                  : MyColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Bouton de la dernière adresse utilisée
  /// Style identique aux destinations favorites
  Widget _buildLastAddressItem(
      Map lastSearch, DarkThemeProvider darkThemeProvider) {
    final dropAddress = lastSearch['drop']?['address'] ?? '';
    if (dropAddress.isEmpty) return const SizedBox.shrink();

    // Extraire un nom court de l'adresse (premier segment)
    final addressParts = dropAddress.split(',');
    final shortName = addressParts.isNotEmpty ? addressParts.first.trim() : dropAddress;
    final cityPart = addressParts.length > 1 ? addressParts.skip(1).take(2).join(',').trim() : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _navigateToLastAddress(lastSearch),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: darkThemeProvider.darkTheme
                    ? MyColors.whiteColor.withOpacity(0.1)
                    : const Color(0xFFF9F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.history_rounded,
                color: MyColors.horizonBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkThemeProvider.darkTheme
                          ? MyColors.whiteColor
                          : MyColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (cityPart.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      cityPart,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: darkThemeProvider.darkTheme
                            ? MyColors.whiteColor.withOpacity(0.7)
                            : MyColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: darkThemeProvider.darkTheme
                  ? MyColors.whiteColor.withOpacity(0.5)
                  : MyColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Navigue vers le choix de véhicule avec la dernière adresse
  /// Utilise la position GPS actuelle comme pickup
  Future<void> _navigateToLastAddress(Map lastSearch) async {
    try {
      showLoading();

      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      // Pickup = position GPS actuelle
      tripProvider.pickLocation = {
        "lat": currentPosition!.latitude,
        "lng": currentPosition!.longitude,
        "address": currentFullAddress ?? '',
      };

      // Drop = adresse de l'historique
      tripProvider.dropLocation = {
        "lat": lastSearch['drop']['lat'],
        "lng": lastSearch['drop']['lng'],
        "address": lastSearch['drop']['address'],
      };

      myCustomPrintStatement('🚗 Raccourci dernière adresse:');
      myCustomPrintStatement('  Pickup: ${tripProvider.pickLocation}');
      myCustomPrintStatement('  Drop: ${tripProvider.dropLocation}');

      // Recharger les chauffeurs autour du pickup
      if (currentPosition != null) {
        await refreshDriversAroundPickup(
          currentPosition!.latitude,
          currentPosition!.longitude,
        );
      }

      // Calculer l'itinéraire
      await tripProvider.createPath(topPaddingPercentage: 0.8);

      hideLoading();

      // Naviguer vers le choix de véhicule
      tripProvider.setScreen(CustomTripType.chooseVehicle);
    } catch (e) {
      hideLoading();
      myCustomPrintStatement('❌ Erreur navigation dernière adresse: $e');
      showSnackbar(translate("Une erreur s'est produite. Veuillez réessayer."));
    }
  }

  /// Ouvre le sélecteur de position sur la carte
  /// Affiche directement le pin de sélection sur la carte (mode drop location)
  void _openMapLocationPicker() {
    // Activer le mode sélection sur carte avec le pin
    dropLocationPickerHideNoti.value = true;

    // Naviguer vers l'écran de saisie d'adresse avec le mode carte actif
    Provider.of<TripProvider>(context, listen: false)
        .setScreen(CustomTripType.choosePickupDropLocation);
  }

  /// Purge complètement l'écran et recalcule la position utilisateur
  Future<void> _resetToMainMenuWithPurge(
      {bool recalculatePosition = true,
      int? status,
      CustomTripType? currentStep,
      void Function(String)? showInAppBanner}) async {
    // Ajout de la protection contre les faux signaux d'annulation
    if (status != null &&
        status == BookingStatusType.CANCELLED.value &&
        currentStep != null) {
      if (currentStep == CustomTripType.driverOnWay ||
          currentStep == CustomTripType.requestForRide ||
          currentStep == CustomTripType.payment) {
        print('⚠️ Faux signal d’annulation ignoré : course active');
        return;
      }

      if (showInAppBanner != null) {
        showInAppBanner("Reconnexion en cours…");
      }
    }
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);

      // 0. Réinitialiser les flags de recentrage pour les futures courses
      _hasRecenteredForDriverTracking = false;
      _lastBookingStatus = null;
      _stopContinuousDriverTracking(); // Arrêter le suivi continu

      // 1. Nettoyer toutes les données de trip
      tripProvider.clearAllTripData();

      // 2. Purger complètement la carte : polylines, markers, et autres éléments visuels
      myCustomPrintStatement(
          '🧹 Nettoyage complet de la carte et des itinéraires');
      mapProvider
          .clearAllPolylines(); // Utiliser la méthode dédiée qui nettoie tout
      mapProvider.hideMarkers(); // Masquer tous les markers

      // Arrêter explicitement toutes les animations d'itinéraire en cours
      mapProvider.stopRouteAnimation();

      // Réinitialiser tous les flags et états de la carte
      mapProvider.visiblePolyline = false;
      mapProvider.visibleCoveredPolyline = false;

      // 3. Recalculer la position actuelle de l'utilisateur
      if (recalculatePosition) {
        await getCurrentLocation();

        // 4. Recentrer la carte sur la position actuelle avec padding adaptatif
        if (mapProvider.controller != null && currentPosition != null) {
          await recenterMapWithAdaptivePadding();
        }
      }

      // 5. Remettre l'état à l'écran principal
      tripProvider.setScreen(CustomTripType.setYourDestination);

      // 6. Restaurer la barre de navigation
      Provider.of<NavigationProvider>(context, listen: false)
          .setNavigationBarVisibility(true);

      // 7. Ajuster la hauteur du bottom sheet
      updateBottomSheetHeight();

      // 8. Notifier les listeners
      mapProvider.notifyListeners();

      print('🏠 Menu principal purgé et position recalculée');
    } catch (e) {
      print('❌ Erreur lors de la purge du menu principal: $e');
    }
  }

  /// Version optimisée du recentrage qui évite les freezes de la carte
  /// Utilise des animations plus douces et des calculs simplifiés
  Future<void> _smoothRecenterMapBasedOnBottomSheetHeight() async {
    try {
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);

      if (mapProvider.controller == null || _mapReferencePosition == null) {
        return;
      }

      print('🎯 Recentrage doux optimisé:');
      print('   - Bottom sheet height: ${(_currentBottomSheetHeight * 100).toInt()}%');
      print('   - Map padding: ${_mapBottomPadding.toInt()}px');

      // 🎯 Centrer sur la position de référence
      // Le GoogleMap widget a déjà le padding appliqué, donc Google Maps centre
      // automatiquement dans la zone visible !
      await mapProvider.controller!.animateCamera(
        CameraUpdate.newLatLng(_mapReferencePosition!),
      );

      print('✅ Carte recentrée au milieu de la zone visible');
    } catch (e) {
      print('❌ Erreur lors du recentrage doux optimisé: $e');
    }
  }

  /// Recentre la carte avec un padding adaptatif pour positionner le point bleu
  /// au milieu de la zone visible (entre le haut de l'écran et le bottom sheet)
  Future<void> recenterMapWithAdaptivePadding() async {
    try {
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);
      final tripProvider =
          Provider.of<TripProvider>(context, listen: false);

      // 🎯 FIX: Ne pas recentrer si l'utilisateur navigue librement sur la carte
      if (_isUserNavigatingMap &&
          tripProvider.currentStep == CustomTripType.setYourDestination &&
          tripProvider.booking == null) {
        myCustomPrintStatement('🗺️ Recentrage adaptatif ignoré - utilisateur en mode libre');
        return;
      }

      // PROTECTION ROBUSTE : Vérifier que tous les éléments nécessaires sont disponibles
      if (mapProvider.controller == null ||
          currentPosition == null ||
          !mounted ||
          !_isValidGpsPosition(currentPosition != null
              ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
              : null)) {
        print(
            '⚠️ Recentrage annulé: position invalide ou contrôleur indisponible');
        return;
      }

      print('📍 Recentrage adaptatif:');
      print('   - Bottom sheet height: ${(_currentBottomSheetHeight * 100).toInt()}%');
      print('   - Map padding: ${_mapBottomPadding.toInt()}px');

      // 🎯 Centrer sur la position utilisateur
      // Le GoogleMap widget a déjà le padding appliqué, donc Google Maps centre
      // automatiquement le point bleu au milieu de la zone visible !
      await mapProvider.controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
            zoom: 15,
          ),
        ),
      );

      print('✅ Point bleu centré au milieu de la zone visible');
    } catch (e) {
      print('❌ Erreur lors du recentrage adaptatif: $e');
      // Fallback vers recentrage simple
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);
      if (mapProvider.controller != null && currentPosition != null) {
        await mapProvider.controller!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target:
                  LatLng(currentPosition!.latitude, currentPosition!.longitude),
              zoom: 15,
            ),
          ),
        );
      }
    }
  }

  /// Recentre la carte pour afficher le chauffeur et la destination pendant la course
  Future<void> recenterMapForDriverTracking() async {
    try {
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      if (mapProvider.controller == null) {
        return;
      }

      final driver = tripProvider.acceptedDriver;

      LatLng? driverPoint = tripProvider.smoothedDriverPosition;

      if (driverPoint == null &&
          driver?.currentLat != null &&
          driver?.currentLng != null) {
        final double lat = driver!.currentLat!;
        final double lng = driver.currentLng!;
        driverPoint = LatLng(lat, lng);
      }

      if (driverPoint != null && tripProvider.pickLocation != null) {
        // ✅ Ne plus masquer la polyline - elle affiche maintenant driver→pickup
        // Le polyline est mis à jour en live par createPath() dans trip_provider

        final pickupLat = tripProvider.pickLocation!['lat'] as double?;
        final pickupLng = tripProvider.pickLocation!['lng'] as double?;

        if (pickupLat != null && pickupLng != null) {
          final pickupPoint = LatLng(pickupLat, pickupLng);

          // Calculer les bounds entre driver et pickup
          double minLat = math.min(driverPoint.latitude, pickupPoint.latitude);
          double maxLat = math.max(driverPoint.latitude, pickupPoint.latitude);
          double minLng = math.min(driverPoint.longitude, pickupPoint.longitude);
          double maxLng = math.max(driverPoint.longitude, pickupPoint.longitude);

          // Ajouter un padding pour éviter que les marqueurs soient coupés
          final latPadding = (maxLat - minLat) * 0.25;
          final lngPadding = (maxLng - minLng) * 0.25;

          minLat -= latPadding;
          maxLat += latPadding;
          minLng -= lngPadding;
          maxLng += lngPadding;

          final bounds = LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          );

          // Centrer avec padding pour les 45% supérieurs de l'écran
          final screenHeight = MediaQuery.of(context).size.height;

          // 🎯 APPROCHE DIRECTE : Calcul manuel du centre et zoom
          final centerLat = (minLat + maxLat) / 2;
          final centerLng = (minLng + maxLng) / 2;

          // Décaler vers le haut pour compenser le bottom sheet
          final latSpan = maxLat - minLat;
          final adjustedCenterLat = centerLat + (latSpan * 0.25);

          // Calculer zoom agressif selon la distance
          final latDiff = maxLat - minLat;
          final lngDiff = maxLng - minLng;
          final maxDiff = math.max(latDiff, lngDiff);

          double targetZoom;
          if (maxDiff < 0.001) {      // < 100m
            targetZoom = 18.0;
          } else if (maxDiff < 0.005) { // < 500m
            targetZoom = 16.0;
          } else if (maxDiff < 0.01) {  // < 1km
            targetZoom = 15.0;
          } else if (maxDiff < 0.02) {  // < 2km
            targetZoom = 14.0;
          } else {                      // > 2km
            targetZoom = 13.0;
          }

          myCustomPrintStatement('🎯 recenterMapForDriverTracking: centre=$adjustedCenterLat,$centerLng, zoom=$targetZoom');

          // Animation directe
          await mapProvider.controller!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(adjustedCenterLat, centerLng),
                zoom: targetZoom,
              ),
            ),
          );

          myCustomPrintStatement(
              '✅ Carte recenterée AGRESSIVEMENT : driver↔pickup zoom=$targetZoom');
        }
      } else if (driverPoint != null) {
        // Fallback: centrer sur le driver seulement
        await mapProvider.controller!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: driverPoint,
              zoom: 16.0,
            ),
          ),
        );
      }
    } catch (e) {
      myCustomPrintStatement(
          '❌ Erreur lors du recentrage pour suivi chauffeur: $e');
    }
  }

  /// Démarre le suivi continu du chauffeur et du point d'arrivée
  void _startContinuousDriverTracking() {
    // Arrêter le timer existant s'il y en a un
    _driverTrackingTimer?.cancel();

    myCustomPrintStatement(
        '🔄 Démarrage du suivi continu - Phase "Le chauffeur est en chemin"...');

    // Créer un timer qui met à jour la position moins fréquemment pour éviter les saccades
    _driverTrackingTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final tripProvider = Provider.of<TripProvider>(context, listen: false);

        // Vérifier si on doit continuer le suivi
        // ARRÊTER le suivi dès que la course commence (chauffeur a récupéré le passager)
        if (tripProvider.booking == null ||
            tripProvider.currentStep != CustomTripType.driverOnWay ||
            tripProvider.booking!['status'] >=
                BookingStatusType.RIDE_STARTED.value) {
          if (tripProvider.booking!['status'] >=
              BookingStatusType.RIDE_STARTED.value) {
            myCustomPrintStatement(
                '🛑 Arrêt du suivi - Course COMMENCÉE, chauffeur a récupéré le passager');
          } else {
            myCustomPrintStatement(
                '🛑 Arrêt du suivi - course terminée ou état changé');
          }
          _stopContinuousDriverTracking();
          return;
        }

        // Effectuer le recentrage continu
        await _continuousDriverTracking();
      } catch (e) {
        myCustomPrintStatement('❌ Erreur dans le suivi continu: $e');
      }
    });
  }

  /// Arrête le suivi continu du chauffeur
  void _stopContinuousDriverTracking() {
    if (_driverTrackingTimer != null) {
      _driverTrackingTimer!.cancel();
      _driverTrackingTimer = null;
      myCustomPrintStatement(
          '🛑 Suivi continu arrêté - Fin de la phase "Le chauffeur est en chemin"');
    }
  }

  /// Effectue le recentrage continu sur le chauffeur et la destination
  Future<void> _continuousDriverTracking() async {
    try {
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);

      if (mapProvider.controller == null || !mounted) {
        return;
      }

      // Vérifier si on a les positions nécessaires
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final driver = tripProvider.acceptedDriver;
      // Utiliser en priorité la position lissée fournie par le TripProvider
      LatLng? driverPoint = tripProvider.smoothedDriverPosition;

      if (driverPoint == null &&
          driver?.currentLat != null &&
          driver?.currentLng != null) {
        final double lat = driver!.currentLat!;
        final double lng = driver.currentLng!;
        driverPoint = LatLng(lat, lng);
      }

      // Ajustement dynamique de la vue pour le suivi continu du chauffeur
      if (driverPoint != null && mapProvider.controller != null) {
        final tripProvider = Provider.of<TripProvider>(context, listen: false);

        if (tripProvider.currentStep == CustomTripType.driverOnWay) {
          myCustomPrintStatement('🚗 DRIVER ON WAY - Début centrage driver→pickup');
          myCustomPrintStatement('📍 Driver position: ${driverPoint.latitude}, ${driverPoint.longitude}');

          // ✅ Ne plus masquer la polyline - elle affiche maintenant driver→pickup en live
          // Le polyline est tracé et mis à jour par createPath() dans trip_provider

          LatLng? pickupPoint;

          if (tripProvider.pickLocation != null) {
            myCustomPrintStatement('📦 PickLocation data: ${tripProvider.pickLocation}');
            final pickupLat = tripProvider.pickLocation!['lat'] as double?;
            final pickupLng = tripProvider.pickLocation!['lng'] as double?;
            if (pickupLat != null && pickupLng != null) {
              pickupPoint = LatLng(pickupLat, pickupLng);
              myCustomPrintStatement('📍 Pickup position: ${pickupPoint.latitude}, ${pickupPoint.longitude}');
            } else {
              myCustomPrintStatement('❌ Pickup lat/lng are null!');
            }
          } else {
            myCustomPrintStatement('❌ tripProvider.pickLocation is null!');
          }

          if (pickupPoint != null) {
            myCustomPrintStatement('✅ Calcul bounds driver→pickup...');
            // Calculer les bounds entre driver et pickup
            double minLat = math.min(driverPoint.latitude, pickupPoint.latitude);
            double maxLat = math.max(driverPoint.latitude, pickupPoint.latitude);
            double minLng = math.min(driverPoint.longitude, pickupPoint.longitude);
            double maxLng = math.max(driverPoint.longitude, pickupPoint.longitude);

            myCustomPrintStatement('📐 Bounds bruts: minLat=$minLat, maxLat=$maxLat, minLng=$minLng, maxLng=$maxLng');

            // Distance entre driver et pickup
            final distance = math.sqrt(math.pow(maxLat - minLat, 2) + math.pow(maxLng - minLng, 2));
            myCustomPrintStatement('📏 Distance driver↔pickup: ${(distance * 111).toStringAsFixed(2)} km');

            // Ajouter un padding pour éviter que les marqueurs soient trop proches des bords
            final latPadding = math.max((maxLat - minLat) * 0.25, 0.005); // Min 500m
            final lngPadding = math.max((maxLng - minLng) * 0.25, 0.005);

            minLat -= latPadding;
            maxLat += latPadding;
            minLng -= lngPadding;
            maxLng += lngPadding;

            // 🎯 APPROCHE AGRESSIVE : Calculer centre et zoom manuellement
            final centerLat = (minLat + maxLat) / 2;
            final centerLng = (minLng + maxLng) / 2;

            // Décaler vers le haut pour compenser le bottom sheet (45% visibles)
            final latSpan = maxLat - minLat;
            final adjustedCenterLat = centerLat + (latSpan * 0.25); // Décaler vers le haut

            // Calculer le zoom approprié selon la distance
            final latDiff = maxLat - minLat;
            final lngDiff = maxLng - minLng;
            final maxDiff = math.max(latDiff, lngDiff);

            // Zoom agressif : Plus la distance est petite, plus on zoome
            double targetZoom;
            if (maxDiff < 0.001) {      // < 100m
              targetZoom = 18.0;
            } else if (maxDiff < 0.005) { // < 500m
              targetZoom = 16.0;
            } else if (maxDiff < 0.01) {  // < 1km
              targetZoom = 15.0;
            } else if (maxDiff < 0.02) {  // < 2km
              targetZoom = 14.0;
            } else {                      // > 2km
              targetZoom = 13.0;
            }

            myCustomPrintStatement('🎯 Centre ajusté: lat=$adjustedCenterLat, lng=$centerLng');
            myCustomPrintStatement('🔍 Zoom calculé: $targetZoom (span=$maxDiff)');

            // Animation directe vers la position calculée
            await mapProvider.controller!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(adjustedCenterLat, centerLng),
                  zoom: targetZoom,
                ),
              ),
            );

            myCustomPrintStatement(
              '🎯 Vue optimisée : itinéraire driver→pickup dans les 45% supérieurs',
            );
          } else {
            // Si pas de pickup, centrer sur le driver avec padding bottom
            final screenHeight = MediaQuery.of(context).size.height;
            final double bottomOffset = screenHeight * 0.25; // Décaler vers le haut

            await mapProvider.controller!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: driverPoint,
                  zoom: 16.0,
                ),
              ),
            );

            // Décaler légèrement vers le haut
            await mapProvider.controller!.animateCamera(
              CameraUpdate.scrollBy(0, bottomOffset),
            );
          }
        }
      }
    } catch (e) {
      myCustomPrintStatement('❌ Erreur lors du recentrage continu: $e');
    }
  }

  /// Effectue le zoom intelligent sans gérer le timer (utilisé par le suivi continu)
  Future<void> _performIntelligentZoom(LatLng driverPosition,
      {bool animateCamera = true, bool useMoveCamera = false}) async {
    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    try {
      // Liste des points à afficher
      List<LatLng> importantPoints = [];

      // 1️⃣ Ajouter la position du chauffeur
      importantPoints.add(driverPosition);

      // 2️⃣ Ajouter le point de prise en charge (pickup)
      if (tripProvider.pickLocation != null) {
        try {
          final pickupLat = tripProvider.pickLocation!['lat'] as double?;
          final pickupLng = tripProvider.pickLocation!['lng'] as double?;
          if (pickupLat != null && pickupLng != null) {
            importantPoints.add(LatLng(pickupLat, pickupLng));
          }
        } catch (e) {
          myCustomPrintStatement('❌ Erreur conversion pickLocation: $e');
        }
      }

      // 🧭 Étape spéciale : si le chauffeur est en chemin, ignorer complètement le dropoff point
      // --- Gestion de la course annulée (corrige le loader infini et désynchro) ---
      final currentBooking = tripProvider.booking;
      final currentStatus = currentBooking != null ? currentBooking['status'] : null;

      final bool isCancelled =
          currentStatus == BookingStatusType.CANCELLED.value ||
          currentStatus == BookingStatusType.RIDE_COMPLETE.value &&
              (tripProvider.booking?['cancelledBy'] == 'USER' ||
               tripProvider.booking?['cancelledBy'] == 'SYSTEM') ||
          currentStatus == 'CANCELLED' ||
          currentStatus == 'RIDE_CANCELLED' ||
          currentStatus == 'USER_CANCELLED';

      if (isCancelled) {
        myCustomPrintStatement('🚫 Booking annulé détecté - reset interface rider');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navProvider = Provider.of<NavigationProvider>(context, listen: false);

          // Réinitialisation complète
          tripProvider.booking = null;
          tripProvider.clearAllTripData();
          tripProvider.setScreen(CustomTripType.setYourDestination);
          navProvider.setNavigationBarVisibility(true);

          _updateBottomSheetHeight(_lowestBottomSheetHeight);
          if (mounted) setState(() {});
        });
      }
      if (tripProvider.currentStep == CustomTripType.driverOnWay) {
        myCustomPrintStatement('🧭 Zoom intelligent: dropoff ignoré (chauffeur en chemin)');

        if (tripProvider.pickLocation != null) {
          final pickupLat = tripProvider.pickLocation!['lat'] as double?;
          final pickupLng = tripProvider.pickLocation!['lng'] as double?;
          if (pickupLat != null && pickupLng != null) {
            await _fitMapToPointsInVisibleArea(
              [driverPosition, LatLng(pickupLat, pickupLng)],
              animate: animateCamera,
              useMoveCamera: useMoveCamera,
            );
            return; // Empêche l’ajout ultérieur du dropoff
          }
        }
      }

      // 3️⃣ Ajouter uniquement les points de polyline situés ENTRE le chauffeur et le pickup
      if (mapProvider.polylineCoordinates.isNotEmpty) {
        final int pickupIndex = mapProvider.polylineCoordinates.indexWhere((p) {
          if (tripProvider.pickLocation != null) {
            final pickupLat = tripProvider.pickLocation!['lat'] as double?;
            final pickupLng = tripProvider.pickLocation!['lng'] as double?;
            if (pickupLat != null && pickupLng != null) {
              return (p.latitude - pickupLat).abs() < 0.0005 &&
                     (p.longitude - pickupLng).abs() < 0.0005;
            }
          }
          return false;
        });

        if (pickupIndex > 0) {
          // Garder seulement les points jusqu'au pickup
          importantPoints.addAll(mapProvider.polylineCoordinates.sublist(0, pickupIndex + 1));
        } else {
          // Si on ne trouve pas le pickup précisément, prendre les 40% premiers points
          final int partialLength = (mapProvider.polylineCoordinates.length * 0.4).floor();
          importantPoints.addAll(mapProvider.polylineCoordinates.take(partialLength));
        }
      }

      // 4️⃣ Appliquer le fit caméra uniquement sur ces points
      await _fitMapToPointsInVisibleArea(
        importantPoints,
        animate: animateCamera,
        useMoveCamera: useMoveCamera,
      );
    } catch (e) {
      myCustomPrintStatement('❌ Erreur zoom intelligent: $e');
      await _fallbackZoomOnDriver(driverPosition);
    }
  }

  /// Centrage intelligent pour "Le chauffeur est en chemin" - inclut chauffeur, pickup et itinéraire
  Future<void> _zoomOnDriverPosition(LatLng driverPosition) async {
    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    try {
      // Rassembler tous les points importants à afficher
      List<LatLng> importantPoints = [driverPosition];

      // Ajouter le point de prise en charge si disponible
      if (tripProvider.pickLocation != null) {
        try {
          final pickupLat = tripProvider.pickLocation!['lat'] as double?;
          final pickupLng = tripProvider.pickLocation!['lng'] as double?;
          if (pickupLat != null && pickupLng != null) {
            importantPoints.add(LatLng(pickupLat, pickupLng));
          }
        } catch (e) {
          myCustomPrintStatement('❌ Erreur conversion pickLocation: $e');
        }
      }

      // Ajouter uniquement le segment d'itinéraire entre le chauffeur et le pickup
      if (mapProvider.polylineCoordinates.isNotEmpty) {
        // On suppose que la polyline actuelle va du chauffeur → pickup → destination.
        // Ici, on ne garde que la première moitié (jusqu'au pickup).
        final int halfIndex = (mapProvider.polylineCoordinates.length / 2).floor();
        importantPoints.addAll(mapProvider.polylineCoordinates.sublist(0, halfIndex));

        // Ajout de quelques points intermédiaires pour une vue fluide
        if (halfIndex > 4) {
          int quarterIndex = halfIndex ~/ 2;
          importantPoints.add(mapProvider.polylineCoordinates[quarterIndex]);
          importantPoints.add(mapProvider.polylineCoordinates[halfIndex - 1]);
        }
      }

      // Calculer les bounds optimaux pour tous les points importants
      await _fitMapToPointsInVisibleArea(
        importantPoints,
        animate: true,
        useMoveCamera: false,
      );
      _hasAppliedInitialDriverFit = true;

      myCustomPrintStatement(
          '🚗 ZOOM intelligent "Le chauffeur est en chemin" - ${importantPoints.length} points inclus');

      // Démarrer le suivi continu seulement si pas déjà actif
      if (_driverTrackingTimer == null) {
        _startContinuousDriverTracking();
      }
    } catch (e) {
      myCustomPrintStatement('❌ Erreur zoom intelligent chauffeur: $e');
      // Fallback sur l'ancien comportement
      await _fallbackZoomOnDriver(driverPosition);
    }
  }

  /// Ajuste la caméra pour afficher tous les points dans la zone visible (1/3 supérieur)
  Future<void> _fitMapToPointsInVisibleArea(List<LatLng> points,
      {bool animate = true, bool useMoveCamera = false}) async {
    if (points.isEmpty) return;

    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    if (mapProvider.controller == null) {
      myCustomPrintStatement(
          '⚠️ _fitMapToPointsInVisibleArea: controller indisponible');
      return;
          }

    // Calculer les bounds des points
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (LatLng point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Ajouter une marge pour éviter que les points soient collés aux bords
    double latSpan = (maxLat - minLat);
    double lngSpan = (maxLng - minLng);

    // Réduire la marge pour conserver un zoom plus proche tout en gardant un léger buffer
    double latPadding = latSpan * 0.08;
    double lngPadding = lngSpan * 0.08;

    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;

    // Créer les bounds avec padding adapté à la zone visible
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    final double bottomSheetRatio = _currentBottomSheetHeight.clamp(0.0, 0.9);
    final LatLng reference = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );
    final double referenceBottomSheetRatio =
        (bottomSheetRatio > 0 ? bottomSheetRatio : 0.55).clamp(0.55, 0.75);

    try {
      await IOSMapFix.safeFitBounds(
        controller: mapProvider.controller!,
        points: [
          bounds.northeast,
          bounds.southwest,
          ...points,
        ],
        bottomSheetRatio: referenceBottomSheetRatio,
        debugSource: 'driverOnWay-fit',
      );
    } catch (e) {
      myCustomPrintStatement('❌ Erreur repositionnement caméra: $e');
      final CameraUpdate fallbackUpdate = CameraUpdate.newLatLngBounds(
        bounds,
        200.0,
      );
      if (animate) {
        await mapProvider.controller!.animateCamera(fallbackUpdate);
      } else if (useMoveCamera) {
        await mapProvider.controller!.moveCamera(fallbackUpdate);
      }
    }

    // Toujours remonter légèrement la vue pour conserver le chauffeur
    // dans la partie visible située au-dessus du bottom sheet.
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    // Calcul dynamique du décalage vertical selon la hauteur du bottom sheet
    final double moveUpPx = (screenHeight * referenceBottomSheetRatio) / 2;

    // Décale la caméra vers le haut pour que l'itinéraire reste visible
    await mapProvider.controller!.animateCamera(
      CameraUpdate.scrollBy(0, -moveUpPx),
    );

    // Optionnel : recentrage fin autour de la zone visible
    mapProvider.centerMapToAbsolutePosition(
      referencePosition: reference,
      bottomSheetHeightRatio: referenceBottomSheetRatio,
      screenHeight: screenHeight,
    );
  }

  /// Fallback : zoom simple sur le chauffeur (ancien comportement)
  Future<void> _fallbackZoomOnDriver(LatLng driverPosition) async {
    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    await mapProvider.controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: driverPosition,
          zoom: 15.0,
        ),
      ),
    );
  }

  Widget _buildAdditionalContent(DarkThemeProvider darkThemeProvider) {
    // Utiliser GlobalKey pour préserver l'état et éviter les recréations
    return PopularDestinationsWidget(key: _popularDestinationsKey);
  }

  Widget _buildClassicBottomSheetContent(TripProvider tripProvider) {
    // PRIORITÉ ABSOLUE : Vérifier les écrans de paiement en premier
    if (tripProvider.currentStep == CustomTripType.paymentMobileConfirm) {
      return const PaymentMobileNumberConfirmation();
    }

    // Ajout du cas Orange Money manquant
    if (tripProvider.currentStep == CustomTripType.orangeMoneyPayment) {
      return Consumer<OrangeMoneyPaymentGatewayProvider>(
        builder: (context, orangeProvider, child) {
          // Afficher la WebView pour Orange Money si l'URL est disponible
          if (orangeProvider.paymentUrl.isNotEmpty) {
            return OpenPaymentWebview(
              webViewUrl: orangeProvider.paymentUrl,
              onCancellation: () {
                // Retourner à l'écran précédent en cas d'annulation
                tripProvider.setScreen(CustomTripType.driverOnWay);
              },
            );
          } else {
            // En cas d'erreur ou URL manquante, retourner au driver on way
            WidgetsBinding.instance.addPostFrameCallback((_) {
              tripProvider.setScreen(CustomTripType.driverOnWay);
            });
            return const SizedBox.shrink();
          }
        },
      );
    }

    // 🔧 FIX: Vérifier que dropLocation est disponible avant d'afficher chooseVehicle
    if (tripProvider.currentStep == CustomTripType.chooseVehicle &&
        (tripProvider.pickLocation == null || tripProvider.dropLocation == null)) {
      myCustomPrintStatement('⚠️ chooseVehicle sans pickup/drop valides - retour à setYourDestination');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        tripProvider.setScreen(CustomTripType.setYourDestination);
      });
      return const SizedBox.shrink();
    }

    return tripProvider.currentStep == CustomTripType.selectScheduleTime
        ? const SceduleRideWithCustomeTime()
        : tripProvider.currentStep == CustomTripType.flightNumberEntry
            ? const FlightNumberEntrySheet()
            : tripProvider.currentStep == CustomTripType.chooseVehicle
                ? ChooseVehicle(
                key: MyGlobalKeys.chooseVehiclePageKey,
                pickLocation: tripProvider.pickLocation!,
                drpLocation: tripProvider.dropLocation!,
                isCollapsed: _currentBottomSheetHeight <= _chooseVehicleMinHeight + 0.05, // Position basse (38%)
                enableScroll: _currentBottomSheetHeight >= _chooseVehicleMaxHeight - 0.05, // Scroll uniquement en position max (85%)
                onTap: (sVehicle) async {
                  tripProvider.selectedVehicle = sVehicle;

                  // Log Analytics event pour sélection véhicule
                  final price = tripProvider.calculatePriceForVehicle(sVehicle,
                      withReservation: tripProvider.rideScheduledTime != null);
                  final userDetails =
                      await DevFestPreferences().getUserDetails();
                  final userId = userDetails?.id;

                  await AnalyticsService.logVehicleSelected(
                    vehicleType: sVehicle.id,
                    vehicleName: sVehicle.name,
                    price: price,
                    isScheduled: tripProvider.rideScheduledTime != null,
                    userId: userId,
                  );

                  // ✅ INTERCEPTION MODE INVITÉ: Vérifier si l'utilisateur doit se connecter
                  final authProvider = Provider.of<CustomAuthProvider>(context, listen: false);
                  if (authProvider.isGuestMode) {
                    myCustomPrintStatement("🚫 Mode invité détecté - Affichage du prompt d'authentification");

                    // Sauvegarder l'état de la réservation pour le restaurer après connexion
                    final guestSessionProvider =
                        Provider.of<GuestSessionProvider>(context, listen: false);
                    await guestSessionProvider.updateBookingData(
                      pickupLocation: LatLng(
                        tripProvider.pickLocation!['lat'],
                        tripProvider.pickLocation!['lng'],
                      ),
                      pickupAddress: tripProvider.pickLocation!['address'],
                      destinationLocation: LatLng(
                        tripProvider.dropLocation!['lat'],
                        tripProvider.dropLocation!['lng'],
                      ),
                      destinationAddress: tripProvider.dropLocation!['address'],
                      selectedVehicleType: sVehicle.id,
                      estimatedPrice: price,
                    );

                    // Afficher le bottom sheet d'authentification
                    await showAuthPromptBottomSheet(
                      context,
                      onAuthSuccess: () {
                        myCustomPrintStatement("✅ Authentification réussie - Reprise du flow de réservation");
                        // Après connexion réussie, continuer directement vers confirmDestination
                        // Le mode de paiement est déjà sélectionné dans choose_vehicle_sheet
                        selectedPaymentMethod = selectPayMethod.value ?? PaymentMethodType.cash;
                        tripProvider.setScreen(CustomTripType.confirmDestination);
                        updateBottomSheetHeight();
                      },
                    );
                    return; // Ne pas continuer si en mode invité
                  }

                  // Continue le flow normal pour les utilisateurs authentifiés
                  // Le mode de paiement est déjà sélectionné dans choose_vehicle_sheet
                  selectedPaymentMethod = selectPayMethod.value ?? PaymentMethodType.cash;
                  tripProvider.setScreen(CustomTripType.confirmDestination);
                  updateBottomSheetHeight();
                },
              )
            : tripProvider.currentStep ==
                    CustomTripType.selectAvailablePromocode
                ? SelectAvailablePromocode(
                    onSelect: (selectedValue) {
                      tripProvider.selectedPromoCode = selectedValue;
                      // Retourner à chooseVehicle au lieu de payment (le paiement est intégré dans chooseVehicle)
                      tripProvider.setScreen(CustomTripType.chooseVehicle);
                      updateBottomSheetHeight();
                    },
                  )
                : tripProvider.currentStep == CustomTripType.payment
                    ? SelectPaymentMethod(
                        key: MyGlobalKeys.selectPaymentMethodPageKey,
                        onTap: (payMethod) async {
                          selectedPaymentMethod = payMethod;

                          // Log Analytics event pour sélection méthode de paiement
                          final tripPrice = tripProvider.selectedPromoCode !=
                                  null
                              ? tripProvider.calculatePriceAfterCouponApply()
                              : tripProvider.calculatePrice(
                                  tripProvider.selectedVehicle!);
                          final userDetails =
                              await DevFestPreferences().getUserDetails();
                          final userId = userDetails?.id;
                          final adminProvider =
                              Provider.of<AdminSettingsProvider>(context,
                                  listen: false);
                          final hasPromo =
                              adminProvider.getPaymentPromoDiscount(payMethod) >
                                  0;

                          await AnalyticsService.logPaymentMethodSelected(
                            paymentMethod: payMethod.value,
                            tripPrice: tripPrice,
                            hasPromo: hasPromo,
                            userId: userId,
                          );

                          tripProvider
                              .setScreen(CustomTripType.confirmDestination);
                          updateBottomSheetHeight();
                        },
                      )
                    : tripProvider.currentStep ==
                            CustomTripType.confirmDestination
                        ? ConfirmDestination(
                            key: MyGlobalKeys.confirmDestinationPageKey,
                            paymentMethod: selectedPaymentMethod!,
                          )
                        : tripProvider.currentStep ==
                                CustomTripType.requestForRide
                            ? const RequestForRide()
                            : (tripProvider.currentStep ==
                                            CustomTripType.driverOnWay &&
                                        tripProvider.booking != null) ||
                                    (tripProvider.booking != null &&
                                        ((tripProvider.booking!['status'] ==
                                                BookingStatusType
                                                    .DESTINATION_REACHED
                                                    .value) ||
                                            (tripProvider.booking!['status'] ==
                                                    BookingStatusType
                                                        .RIDE_COMPLETE.value &&
                                                tripProvider.booking![
                                                        'paymentStatusSummary'] ==
                                                    null)))
                                ? (() {
                                    myCustomPrintStatement(
                                        '🔍 HomeScreen BUILD: Conditions DriverOnWay OK - currentStep: ${tripProvider.currentStep}, booking: ${tripProvider.booking?['id']}, status: ${tripProvider.booking?['status']}');

                                    // Le recentrage est maintenant géré par les listeners des providers

                                    return DriverOnWay(
                                      booking: tripProvider.booking!,
                                      driver: tripProvider.acceptedDriver,
                                      selectedVehicle:
                                          tripProvider.selectedVehicle,
                                      onCancelTap: (reason) {
                                        tripProvider.cancelRideWithBooking(
                                          reason: reason,
                                          cancelAnotherRide:
                                              tripProvider.booking!,
                                        );
                                        updateBottomSheetHeight();
                                      },
                                    );
                                  })()
                                : tripProvider.currentStep ==
                                            CustomTripType.driverOnWay &&
                                        tripProvider.booking == null
                                    ? (() {
                                        myCustomPrintStatement(
                                            '🔍 HomeScreen BUILD: DriverOnWay avec booking NULL');
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 8, 16, 16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.directions_car),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    translate('Driverisontheirway'),
                                                    style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              if (tripProvider.pickLocation !=
                                                  null)
                                                Text(
                                                    '${translate('pickupLocation')} : ${tripProvider.pickLocation!['address'] ?? ''}'),
                                              if (tripProvider.dropLocation !=
                                                  null)
                                                Text(
                                                    '${translate('DropLocation')} : ${tripProvider.dropLocation!['address'] ?? ''}'),
                                              if (tripProvider
                                                      .selectedVehicle !=
                                                  null)
                                                Text(
                                                    '${translate('Selectvehicletype')} : ${tripProvider.selectedVehicle?.name ?? ''}'),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    tripProvider.cancelRideWithBooking(
                                                      reason: 'user_cancelled',
                                                      cancelAnotherRide:
                                                          tripProvider.booking!,
                                                    );
                                                    updateBottomSheetHeight();
                                                  },
                                                  child: Text(
                                                      translate('cancelRide')),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })()
                                    : (() {
                                        myCustomPrintStatement(
                                            '🔍 HomeScreen BUILD: Cas par défaut (Container) - currentStep: ${tripProvider.currentStep}');
                                        return Container(height: 1);
                                      })();
  }

  Widget _buildBackButton(
      DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: MyColors.whiteColor, // Toujours blanc
        shape: BoxShape.circle, // Cercle au lieu de rectangle arrondi
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            // Déclarer tripProvider en premier
            final tripProvider =
                Provider.of<TripProvider>(context, listen: false);

            // Logique de retour unifiée pour les écrans de réservation et de saisie d'adresse
            // Note: selectScheduleTime doit toujours permettre le retour car c'est un écran de création
            if (tripProvider.currentStep == CustomTripType.selectScheduleTime ||
                (tripProvider.currentStep ==
                        CustomTripType.choosePickupDropLocation &&
                    tripProvider.booking == null)) {
              // Log abandonment pour l'écran d'adresse si applicable
              if (tripProvider.currentStep ==
                  CustomTripType.choosePickupDropLocation) {
                // Déclencher l'abandon via la clé globale du widget
                final pickupDropWidgetState =
                    MyGlobalKeys.chooseDropAndPickAddPageKey.currentState;
                if (pickupDropWidgetState != null) {
                  (pickupDropWidgetState as PickupAndDropLocationState)
                      .logAddressAbandonment('back_button');
                }
              }

              // Nettoyage immédiat (synchrone) pour l'UI
              final mapProvider =
                  Provider.of<GoogleMapProvider>(context, listen: false);

              // 1. Nettoyer immédiatement les données de trip
              tripProvider.clearAllTripData();
              tripProvider.setScreen(CustomTripType.setYourDestination);

              // 2. Réinitialiser les curseurs de sélection sur carte
              dropLocationPickerHideNoti.value = false;
              pickupLocationPickerHideNoti.value = false;
              _locationPickerSatelliteView = false; // Reset satellite toggle

              // 3. Purger immédiatement la carte
              mapProvider.polylineCoordinates.clear();
              mapProvider.polyLines.clear();
              mapProvider.markers.removeWhere((key, value) =>
                  key == 'pickup' || key == 'drop' || key.startsWith('route'));
              mapProvider.notifyListeners();

              // 4. Restaurer la barre de navigation immédiatement
              Provider.of<NavigationProvider>(context, listen: false)
                  .setNavigationBarVisibility(true);

              // 5. Opérations lourdes en arrière-plan (sans bloquer l'UI)
              Future.delayed(Duration.zero, () async {
                await getCurrentLocation();
                if (mapProvider.controller != null && currentPosition != null) {
                  await recenterMapWithAdaptivePadding();
                }
                updateBottomSheetHeight();
              });
            } else if (tripProvider.currentStep ==
                    CustomTripType.chooseVehicle &&
                tripProvider.booking == null) {
              tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
              GoogleMapProvider mapInstan =
                  Provider.of<GoogleMapProvider>(context, listen: false);
              mapInstan.polylineCoordinates.clear();
              mapInstan.markers.removeWhere((key, value) => key == "pickup");
              mapInstan.markers.removeWhere((key, value) => key == "drop");
              updateBottomSheetHeight();
            } else if (tripProvider.currentStep == CustomTripType.payment &&
                tripProvider.booking == null) {
              tripProvider.setScreen(CustomTripType.chooseVehicle);
              updateBottomSheetHeight();
            } else if (tripProvider.currentStep ==
                    CustomTripType.confirmDestination &&
                tripProvider.booking == null) {
              tripProvider.setScreen(CustomTripType.chooseVehicle);
              updateBottomSheetHeight();
            } else if (tripProvider.currentStep ==
                    CustomTripType.selectAvailablePromocode &&
                tripProvider.booking == null) {
              // Retour depuis l'écran de sélection de code promo vers chooseVehicle
              tripProvider.setScreen(CustomTripType.chooseVehicle);
              updateBottomSheetHeight();
            } else if (tripProvider.currentStep ==
                    CustomTripType.requestForRide &&
                tripProvider.booking == null) {
              // Pas de retour possible depuis requestForRide - l'utilisateur doit annuler
              return;
            }
          },
          child: Icon(
            Icons.chevron_left,
            color: MyColors.blackColor, // Toujours noir sur fond blanc
            size: 28,
          ),
        ),
      ),
    );
  }

  /// 🔄 Recharge les chauffeurs autour d'une position spécifique (pickup sélectionné)
  /// Appelé depuis pickup_and_drop_location_sheet quand l'utilisateur choisit un pickup
  /// Attend que les premières données soient chargées avant de retourner
  Future<void> refreshDriversAroundPickup(double lat, double lng) async {
    if (!mounted) return;

    myCustomPrintStatement('🔄 Rechargement des chauffeurs autour du pickup: $lat, $lng');

    // Réinitialiser les distances des chauffeurs
    minVehicleDistance.clear();
    nearestVehicleLatLng.clear();
    nearestDriverTime.value.clear();

    // Obtenir le TripProvider et mettre à jour la position de pickup
    // 🔧 FIX: Préserver l'adresse existante si elle existe
    final bookingProvider = Provider.of<TripProvider>(context, listen: false);
    final existingAddress = bookingProvider.pickLocation?['address'];
    final existingIsAirport = bookingProvider.pickLocation?['isAirport'];
    final existingFlightNumber = bookingProvider.pickLocation?['flightNumber'];

    bookingProvider.pickLocation = {
      'lat': lat,
      'lng': lng,
      'address': existingAddress ?? '',
      if (existingIsAirport != null) 'isAirport': existingIsAirport,
      if (existingFlightNumber != null) 'flightNumber': existingFlightNumber,
    };

    // Nettoyer les anciens markers de chauffeurs
    var mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    List<String> keysToRemove = [];
    mapProvider.markers.forEach((key, value) {
      final MarkerId markerId = value.markerId;
      if (markerId != const MarkerId('pickup') &&
          markerId != const MarkerId('drop') &&
          markerId != const MarkerId('driver_vehicle')) {
        keysToRemove.add(key);
      }
    });
    for (var key in keysToRemove) {
      mapProvider.markers.remove(key);
    }

    // Annuler l'ancien stream
    _driversSubscription?.cancel();

    // Utiliser .first pour obtenir le premier événement du stream et attendre
    usersStream = FirestoreServices.users
        .where('isCustomer', isEqualTo: false)
        .where('isOnline', isEqualTo: true)
        .snapshots();

    // Completer pour signaler que les données initiales sont chargées
    final completer = Completer<void>();
    bool firstEventReceived = false;

    _driversSubscription = usersStream!.listen((event) async {
      if (!mounted) return;
      allDrivers = [];
      List driver8NearMarker = [];

      minVehicleDistance.clear();
      nearestVehicleLatLng.clear();

      for (int i = 0; i < event.docs.length; i++) {
        DriverModal m = DriverModal.fromJson(event.docs[i].data() as Map);

        if (bookingProvider.acceptedDriver == null) {
          if (m.currentLat != null && m.currentLng != null) {
            var distance = getDistance(m.currentLat!, m.currentLng!, lat, lng);

            if (distance <= globalSettings.distanceLimitNow ||
                distance <= globalSettings.distanceLimitScheduled) {
              driver8NearMarker.add({"distance": distance, "driverData": m});

              // Calculer la distance minimale par type de véhicule
              if (minVehicleDistance[m.vehicleType] == null) {
                minVehicleDistance[m.vehicleType!] = distance;
                nearestVehicleLatLng[m.vehicleType!] = LatLng(m.currentLat!, m.currentLng!);
              } else {
                if (minVehicleDistance[m.vehicleType]! > distance) {
                  minVehicleDistance[m.vehicleType!] = distance;
                  nearestVehicleLatLng[m.vehicleType!] = LatLng(m.currentLat!, m.currentLng!);
                }
              }

              allDrivers.add(m);
            }
          }
        }
      }

      // Trier par distance et prendre les 8 plus proches
      driver8NearMarker.sort((a, b) => a['distance']!.compareTo(b['distance']!));

      // Ne pas afficher les 8 markers pendant requestForRide (géré par RequestForRide widget)
      if (bookingProvider.acceptedDriver == null &&
          driver8NearMarker.isNotEmpty &&
          bookingProvider.currentStep != CustomTripType.requestForRide) {
        final int limit = driver8NearMarker.length > 8 ? 8 : driver8NearMarker.length;
        addOnly8NearDriverMarker(driver8NearMarker.sublist(0, limit));
      }

      // Ne pas supprimer les markers pendant requestForRide (géré par RequestForRide widget)
      if (bookingProvider.currentStep != CustomTripType.requestForRide) {
        removeOtherDriverMarkers();
      }

      myCustomPrintStatement('✅ ${driver8NearMarker.length} chauffeurs rechargés autour du pickup: $lat, $lng');
      myCustomPrintStatement('📍 minVehicleDistance: ${minVehicleDistance.keys.toList()}');
      myCustomPrintStatement('📍 nearestVehicleLatLng: ${nearestVehicleLatLng.keys.toList()}');

      // Signaler que le premier événement a été traité
      if (!firstEventReceived) {
        firstEventReceived = true;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    // Attendre le premier événement avec un timeout de 5 secondes
    try {
      await completer.future.timeout(const Duration(seconds: 5));
      myCustomPrintStatement('✅ Données initiales des chauffeurs chargées');
    } catch (e) {
      myCustomPrintStatement('⚠️ Timeout en attendant les données des chauffeurs: $e');
    }
  }
}

/// Widget épingle personnalisée avec pointe exactement au centre pour une précision GPS parfaite
class _CustomLocationPin extends StatelessWidget {
  const _CustomLocationPin({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DarkThemeProvider>(
      builder: (context, darkThemeProvider, child) {
        final pinColor = darkThemeProvider.darkTheme
            ? MyColors.whiteColor
            : MyColors.blackColor;
        final shadowColor = darkThemeProvider.darkTheme
            ? MyColors.blackColor.withOpacity(0.3)
            : MyColors.blackColor.withOpacity(0.2);

        return CustomPaint(
          size: const Size(40, 40),
          painter: _LocationPinPainter(
            pinColor: pinColor,
            shadowColor: shadowColor,
          ),
        );
      },
    );
  }
}

/// CustomPainter pour dessiner une épingle avec la pointe exactement au centre
class _LocationPinPainter extends CustomPainter {
  final Color pinColor;
  final Color shadowColor;

  _LocationPinPainter({
    required this.pinColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Dessiner l'ombre légèrement décalée
    final shadowOffset = Offset(1, 1);
    _drawPin(canvas, shadowPaint, centerX + shadowOffset.dx,
        centerY + shadowOffset.dy);

    // Dessiner l'épingle principale
    _drawPin(canvas, paint, centerX, centerY);
  }

  void _drawPin(Canvas canvas, Paint paint, double centerX, double centerY) {
    // Cercle (tête de l'épingle) - positionné au-dessus du centre
    final circleRadius = 8.0;
    final circleCenter =
        Offset(centerX, centerY - 15); // Tête au-dessus du centre
    canvas.drawCircle(circleCenter, circleRadius, paint);

    // Point blanc à l'intérieur du cercle pour le style
    if (paint.color != MyColors.whiteColor) {
      final innerPaint = Paint()
        ..color = MyColors.whiteColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(circleCenter, 3.0, innerPaint);
    }

    // Tige épaisse et visible pour pointer précisément
    final stemPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Ligne verticale du bas du cercle jusqu'au centre exact (point GPS)
    canvas.drawLine(
      Offset(centerX, centerY - 7), // Début de la tige (bas du cercle)
      Offset(centerX, centerY), // Fin exactement au centre = point GPS
      stemPaint,
    );

    // Point de précision très visible exactement au centre (point GPS réel)
    final precisionPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), 2.5, precisionPaint);

    // Cercle blanc à l'intérieur du point pour le contraste
    final innerPrecisionPaint = Paint()
      ..color = paint.color == MyColors.whiteColor
          ? MyColors.blackColor
          : MyColors.whiteColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), 1.0, innerPrecisionPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// FONCTIONS POUR GESTION DES CHAUFFEURS PROCHES
extension DriversManagement on HomeScreenState {
  /// Fonction principale qui écoute les chauffeurs en ligne et met à jour les markers
  setUserStream() async {
    if (!mounted) return;

    _driversSubscription?.cancel();
    usersStream = FirestoreServices.users
        .where('isCustomer', isEqualTo: false)
        .where('isOnline', isEqualTo: true)
        .snapshots();
    var bookingProvider = Provider.of<TripProvider>(context, listen: false);
    _driversSubscription = usersStream!.listen((event) async {
      if (!mounted) return;
      allDrivers = [];
      List driver8NearMarker = [];

      // 🔧 FIX: Réinitialiser les distances et positions à chaque mise à jour
      // pour recalculer correctement par rapport au pickup actuel
      minVehicleDistance.clear();
      nearestVehicleLatLng.clear();

      // 🎯 LOGIQUE: Utiliser pickup location si disponible, sinon position GPS utilisateur
      final bool hasPickupLocation = bookingProvider.pickLocation != null &&
          bookingProvider.pickLocation!['lat'] != null &&
          bookingProvider.pickLocation!['lng'] != null;

      // 🔧 FIX: Pas de fallback - si pas de position, on ne peut pas calculer les distances
      final bool hasGpsPosition = currentPosition != null;

      if (!hasPickupLocation && !hasGpsPosition) {
        myCustomPrintStatement('⚠️ Pas de position pour calculer les distances aux chauffeurs');
        return;
      }

      final double referenceLat = hasPickupLocation
          ? bookingProvider.pickLocation!['lat']
          : currentPosition!.latitude;

      final double referenceLng = hasPickupLocation
          ? bookingProvider.pickLocation!['lng']
          : currentPosition!.longitude;

      myCustomPrintStatement('🚗 Calcul des 8 conducteurs les plus proches:');
      myCustomPrintStatement('  hasPickupLocation: $hasPickupLocation');
      myCustomPrintStatement('  referenceLat: $referenceLat, referenceLng: $referenceLng');

      for (int i = 0; i < event.docs.length; i++) {
        DriverModal m = DriverModal.fromJson(event.docs[i].data() as Map);

        if (bookingProvider.acceptedDriver == null) {
          if (m.currentLat != null && m.currentLng != null) {
            var distance = getDistance(
                m.currentLat!,
                m.currentLng!,
                applyDummyMadasagarPosition
                    ? -18.932972240415356
                    : referenceLat,
                applyDummyMadasagarPosition
                    ? 47.47820354998112
                    : referenceLng);

            if (distance <= globalSettings.distanceLimitNow ||
                distance <= globalSettings.distanceLimitScheduled) {
              driver8NearMarker.add({"distance": distance, "driverData": m});
              if (minVehicleDistance[m.vehicleType] == null) {
                minVehicleDistance[m.vehicleType!] = distance;
                nearestVehicleLatLng[m.vehicleType!] =
                    LatLng(m.currentLat!, m.currentLng!);
              } else {
                if (minVehicleDistance[m.vehicleType] > distance) {
                  minVehicleDistance[m.vehicleType!] = distance;
                  nearestVehicleLatLng[m.vehicleType!] =
                      LatLng(m.currentLat!, m.currentLng!);
                }
              }

              allDrivers.add(m);
            }
          }
        } else {
          if (m.id == bookingProvider.acceptedDriver!.id) {
            var mapProvider =
                Provider.of<GoogleMapProvider>(context, listen: false);
            allDrivers = [];
            bookingProvider.acceptedDriver = m;
            allDrivers.add(m);

            final bool driverOnWayManagedByTripProvider =
                bookingProvider.booking != null &&
                    bookingProvider.currentStep == CustomTripType.driverOnWay;

            if (!driverOnWayManagedByTripProvider) {
              mapProvider.createUpdateMarker(
                m.id,
                LatLng(m.currentLat!, m.currentLng!),
                url: vehicleMap[m.vehicleType!]!.marker,
                rotate: true,
                animateToCenter: (bookingProvider.booking != null &&
                        bookingProvider.booking!['acceptedBy'] == m.id)
                    ? bookingProvider.booking!['status'] > 1
                        ? false
                        : true
                    : false,
                onTap: () {},
              );
            }

            bookingProvider.notifyListeners();
          }
        }
      }
      driver8NearMarker.sort(
        (a, b) => a['distance']!.compareTo(b['distance']!),
      );
      // Ne pas afficher les 8 markers pendant requestForRide (géré par RequestForRide widget)
      if (bookingProvider.acceptedDriver == null &&
          driver8NearMarker.isNotEmpty &&
          bookingProvider.currentStep != CustomTripType.requestForRide) {
        final int limit =
            driver8NearMarker.length > 8 ? 8 : driver8NearMarker.length;
        addOnly8NearDriverMarker(driver8NearMarker.sublist(0, limit));
      }
      // Ne pas supprimer les markers pendant requestForRide (géré par RequestForRide widget)
      if (bookingProvider.currentStep != CustomTripType.requestForRide) {
        removeOtherDriverMarkers();
      }
    });
  }

  /// Ajoute les markers des 8 chauffeurs les plus proches sur la carte
  /// Utilise le snap-to-road pour afficher les chauffeurs sur les routes
  addOnly8NearDriverMarker(List driver8NearMarker) async {
    if (!mounted) return;
    var mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    var bookingProvider = Provider.of<TripProvider>(context, listen: false);

    // 🔄 OPTIMISATION: On ne supprime plus les markers ici
    // La suppression se fait APRÈS avoir créé les nouveaux markers dans _snapAndUpdateDriverMarkers
    // pour éviter le "saut" visuel pendant le chargement du snap-to-road

    // Collecter les IDs des chauffeurs dans la nouvelle liste
    final newDriverIds = driver8NearMarker
        .map((d) => (d['driverData'] as DriverModal).id)
        .toSet();

    myCustomPrintStatement('🔄 Mise à jour des chauffeurs: ${newDriverIds.length} chauffeurs');

    // 🛤️ Snap-to-road : projeter les positions des chauffeurs sur les routes (async)
    // La suppression des anciens markers se fait dans cette fonction après avoir créé les nouveaux
    _snapAndUpdateDriverMarkers(driver8NearMarker, mapProvider, bookingProvider, newDriverIds);
  }

  /// Snappe les chauffeurs sur les routes et met à jour les markers
  Future<void> _snapAndUpdateDriverMarkers(
    List driver8NearMarker,
    GoogleMapProvider mapProvider,
    TripProvider bookingProvider,
    Set<String> newDriverIds,
  ) async {
    // Lancer le snap en parallèle pour tous les chauffeurs
    final snapResults = await DriverSnapService.snapMultipleDrivers(
      driver8NearMarker.map((d) => d as Map<String, dynamic>).toList(),
    );

    if (!mounted) return;

    // Créer une map des résultats par driverId
    final snapMap = <String, DriverSnapResult>{};
    for (final result in snapResults) {
      snapMap[result.driverId] = result;
    }

    // ➕ Maintenant on ajoute/met à jour les 8 markers avec positions snappées
    for (var i = 0; i < driver8NearMarker.length; i++) {
      final driverData = driver8NearMarker[i]['driverData'];
      final driverId = driverData.id;

      final bool driverOnWayManagedByTripProvider =
          bookingProvider.booking != null &&
              bookingProvider.currentStep == CustomTripType.driverOnWay;

      final bool isAcceptedDriver = bookingProvider.acceptedDriver != null &&
          bookingProvider.acceptedDriver!.id == driverId;

      if (driverOnWayManagedByTripProvider && isAcceptedDriver) {
        continue; // Géré par TripProvider
      }

      // Récupérer la position snappée ou utiliser la position brute
      final snapResult = snapMap[driverId];
      final LatLng displayPosition = snapResult?.snappedPosition ??
          LatLng(driverData.currentLat!, driverData.currentLng!);

      // Calculer l'ancienne position pour l'animation
      LatLng? oldLocation;
      if (driverData.isOnline &&
          driverData.oldLat != null &&
          driverData.oldLng != null &&
          (driverData.currentLat != driverData.oldLat ||
              driverData.currentLng != driverData.oldLng)) {
        // Utiliser la dernière position snappée en cache si disponible
        final cachedSnap = DriverSnapService.getCachedResult(driverId);
        if (cachedSnap != null && cachedSnap.isSnapped) {
          oldLocation = cachedSnap.snappedPosition;
        } else {
          oldLocation = LatLng(driverData.oldLat!, driverData.oldLng!);
        }
      }

      final url = vehicleMap[driverData.vehicleType!]!.marker;
      final bool animateToCenter = bookingProvider.booking != null &&
          bookingProvider.booking!['acceptedBy'] == driverId &&
          bookingProvider.booking!['status'] > 1;

      // Utiliser le bearing du snap si disponible
      final double? snappedBearing = snapResult?.bearing;

      mapProvider.createUpdateMarker(
        driverId,
        displayPosition,
        rotate: true,
        oldLocation: oldLocation,
        onTap: () {},
        url: url,
        animateToCenter: animateToCenter,
        forcedRotation: snappedBearing, // Utiliser le bearing de la route
      );
    }

    // 🧹 APRÈS avoir créé les nouveaux markers, supprimer ceux qui ne sont plus dans la liste
    List<String> keysToRemove = [];
    mapProvider.markers.forEach((key, value) {
      final MarkerId markerId = value.markerId;
      // Ne pas supprimer les markers pickup, drop, et driver_vehicle (conducteur accepté)
      if (markerId != const MarkerId('pickup') &&
          markerId != const MarkerId('drop') &&
          markerId != const MarkerId('driver_vehicle') &&
          !newDriverIds.contains(key)) {
        keysToRemove.add(key);
      }
    });

    if (keysToRemove.isNotEmpty) {
      myCustomPrintStatement('🧹 Suppression de ${keysToRemove.length} anciens markers');
      for (var key in keysToRemove) {
        mapProvider.markers.remove(key);
      }
      mapProvider.notifyListeners();
    }
  }

  /// Supprime les markers des chauffeurs qui ne sont plus proches
  /// IMPORTANT: Quand un chauffeur est assigné, supprime TOUS les autres markers
  removeOtherDriverMarkers() {
    if (!mounted) return;
    var bookingProvider = Provider.of<TripProvider>(context, listen: false);
    var mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);

    // Si un conducteur est accepté, supprimer TOUS les markers des autres chauffeurs
    if (bookingProvider.acceptedDriver != null) {
      final acceptedDriverId = bookingProvider.acceptedDriver!.id;

      // Collecter les IDs des markers à supprimer
      List<String> markersToRemove = [];
      mapProvider.markers.forEach((key, value) {
        final MarkerId markerId = value.markerId;
        // Garder uniquement: pickup, drop, driver_vehicle, et le chauffeur assigné
        if (markerId != const MarkerId('pickup') &&
            markerId != const MarkerId('drop') &&
            markerId != const MarkerId('driver_vehicle') &&
            key != acceptedDriverId) {
          markersToRemove.add(key);
        }
      });

      // Supprimer les markers des autres chauffeurs
      for (String markerId in markersToRemove) {
        mapProvider.markers.remove(markerId);
      }

      if (markersToRemove.isNotEmpty) {
        myCustomPrintStatement('🧹 Supprimé ${markersToRemove.length} markers de chauffeurs non assignés');
      }

      // Mettre à jour allDrivers pour ne garder que le chauffeur assigné
      allDrivers = [bookingProvider.acceptedDriver!];
    }

    // Vérification finale du nombre de markers
    int finalDriverCount = 0;
    mapProvider.markers.forEach((key, value) {
      final MarkerId markerId = value.markerId;
      if (markerId != const MarkerId('pickup') &&
          markerId != const MarkerId('drop') &&
          markerId != const MarkerId('driver_vehicle')) {
        finalDriverCount++;
      }
    });

    myCustomPrintStatement('✅ Vérification finale: $finalDriverCount markers conducteurs');

    if (finalDriverCount > 8 && bookingProvider.acceptedDriver == null) {
      myCustomPrintStatement('  ⚠️ ATTENTION: Plus de 8 markers détectés!');
    }

    mapProvider.notifyListeners();
  }

  Future<void> resetHomeView() async {
    if (!mounted) return;
    if (!_isMapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMapReady) {
          resetHomeView();
        }
      });
      return;
    }

    myCustomPrintStatement('🏠 HomeScreen: resetHomeView triggered');

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);

    // 🎯 FIX: Réinitialiser le mode libre lors du retour au menu principal
    // L'utilisateur veut voir sa position actuelle quand il revient du flow de réservation
    _isUserNavigatingMap = false;

    _stopContinuousDriverTracking();
    _hasAppliedInitialDriverFit = false;
    _hasRecenteredForDriverTracking = false;
    _lastBookingStatus = null;

    tripProvider.stopRideTracking();
    tripProvider.resetDriverTrackingForHome();

    mapProvider.clearDriverPreviewPath();
    mapProvider.clearAllPolylines();
    mapProvider.stopRouteAnimation();
    mapProvider.markers.removeWhere((key, value) =>
        key == 'driver_vehicle' || key == 'pickup' || key == 'drop');
    mapProvider.clearDriverVehicleSnapshot();
    mapProvider.hideMarkers();
    mapProvider.visiblePolyline = false;
    mapProvider.visibleCoveredPolyline = false;
    mapProvider.notifyListeners();

    _driversSubscription?.cancel();
    _driversSubscription = null;
    usersStream = null;
    allDrivers.clear();

    await getCurrentLocation();
    if (currentPosition != null) {
      final target =
          LatLng(currentPosition!.latitude, currentPosition!.longitude);
      _mapReferencePosition = target;

      // Animation simple et unique pour recentrer sur la position GPS
      // Utilisé uniquement lors du retour au menu après une course
      if (mapProvider.controller != null && tripProvider.currentStep == CustomTripType.setYourDestination) {
        _lastCameraAnimationTime = DateTime.now(); // Pour le debounce avec getLocation()
        await mapProvider.controller!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: target, zoom: 15),
          ),
        );
      }
    }

    if (currentPosition != null) {
      await setUserStream();
    }
    _applyMapPadding();
  }
}
