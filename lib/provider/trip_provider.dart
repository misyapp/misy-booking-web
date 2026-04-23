import 'dart:async';
import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'dart:math';
import '../utils/ios_map_fix.dart';
import '../utils/map_utils.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/modal/promocodes_modal.dart';
import 'package:rider_ride_hailing_app/modal/vehicle_modal.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/pending_scheduled_booking_requested.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/provider/geo_zone_provider.dart';
import 'package:rider_ride_hailing_app/models/geo_zone.dart';
import 'package:rider_ride_hailing_app/services/geo_zone_service.dart';
import 'package:rider_ride_hailing_app/pages/view_module/rate_us_screen.dart';
import 'package:rider_ride_hailing_app/provider/airtel_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/orange_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/provider/promocodes_provider.dart';
import 'package:rider_ride_hailing_app/provider/telma_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/provider/navigation_provider.dart';
import 'package:rider_ride_hailing_app/services/booking_service_scheduler.dart';
import 'package:rider_ride_hailing_app/services/firebase_push_notifications.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/services/generate_invoice_pdf_service.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/loyalty_service.dart';
import 'package:rider_ride_hailing_app/provider/trip_chat_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_payment_proccess_loader.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';

class _DriverMotionSample {
  _DriverMotionSample({
    required this.position,
    required this.timestamp,
  });

  final LatLng position;
  final DateTime timestamp;
}

class TripProvider extends ChangeNotifier {
  CustomTripType? _currentStep = CustomTripType.setYourDestination;

  // Timer pour la notification séquentielle des chauffeurs
  Timer? _sequentialNotificationTimer;

  // 🔧 FIX: Timer pour le retry automatique de pendingRequest
  // Ce timer recrée la course si aucun chauffeur n'accepte - doit être annulé lors de l'annulation manuelle
  Timer? _pendingRequestRetryTimer;

  // 🔄 État de pause de la recherche de chauffeur
  // Quand l'app passe en arrière-plan pendant une recherche PENDING_REQUEST,
  // la recherche est mise en pause et nécessite confirmation au retour
  bool _isSearchPaused = false;
  DateTime? _searchPausedAt;
  Map<String, dynamic>? _pausedSearchData; // Données sauvegardées pour reprendre

  bool get isSearchPaused => _isSearchPaused;
  DateTime? get searchPausedAt => _searchPausedAt;
  Map<String, dynamic>? get pausedSearchData => _pausedSearchData;

  // Flag pour empêcher les appels multiples de l'animation chooseVehicle
  bool _isAnimatingChooseVehicleRoute = false;

  // Flag pour indiquer une transition entre étapes (affiche overlay de chargement)
  bool _isTransitioning = false;

  // Getter for currentStep
  CustomTripType? get currentStep => _currentStep;

  // Getter for isTransitioning
  bool get isTransitioning => _isTransitioning;

  // Méthode pour forcer l'assignation lors de la restauration (bypass des protections)
  void _forceSetCurrentStepForRestoration(
      CustomTripType newStep, String reason) {
    myCustomPrintStatement('🔓 BYPASS: Forçage currentStep pour restauration');
    myCustomPrintStatement('   Raison: $reason');
    myCustomPrintStatement('   From: $_currentStep → To: $newStep');
    _currentStep = newStep;
    myCustomPrintStatement('✅ BYPASS: currentStep forcé à $newStep');
  }

  // Setter with complete logging and protection
  set currentStep(CustomTripType? newStep) {
    myCustomPrintStatement('🔥🔥🔥 CRITICAL: currentStep SETTER CALLED');
    myCustomPrintStatement('   From: $_currentStep → To: $newStep');
    myCustomPrintStatement(
        '   Current booking: ${booking != null ? booking!['id'] : 'NULL'}');
    myCustomPrintStatement('   Stack trace:');
    myCustomPrintStatement(StackTrace.current.toString());

    // Protection simplifiée - permettre driverOnWay si booking existe OU pour les restaurations
    if (newStep == CustomTripType.driverOnWay) {
      myCustomPrintStatement('🚨 ATTEMPTING TO SET DRIVER_ON_WAY!');
      myCustomPrintStatement('   booking exists: ${booking != null}');

      // Permettre toujours pour les courses terminées/en cours de paiement
      if (booking != null) {
        int status = booking!['status'] ?? -1;
        if (status >= BookingStatusType.DESTINATION_REACHED.value ||
            (status == BookingStatusType.RIDE_COMPLETE.value &&
                booking!['paymentStatusSummary'] == null)) {
          myCustomPrintStatement(
              '✅ Allowed: Course terminée ou paiement en attente');
        }
      }
    }

    // Guard: si on est déjà sur cet écran, ne pas re-déclencher toute la chaîne
    if (_currentStep == newStep) {
      myCustomPrintStatement(
          '⏭️ currentStep déjà à $newStep - skip notifyListeners');
      return;
    }

    myCustomPrintStatement('✅ Setting currentStep to: $newStep');
    _currentStep = newStep;
    notifyListeners(); // S'assurer que l'UI se met à jour

    // 🔧 FIX: Mettre à jour la hauteur du bottom sheet pour requestForRide (58%) et driverOnWay
    if (newStep == CustomTripType.requestForRide || newStep == CustomTripType.driverOnWay) {
      myCustomPrintStatement('📐 Déclenchement updateBottomSheetHeight pour $newStep');
      Future.delayed(const Duration(milliseconds: 300), () {
        if (MyGlobalKeys.homePageKey.currentState != null) {
          myCustomPrintStatement('📐 Appel updateBottomSheetHeight maintenant');
          MyGlobalKeys.homePageKey.currentState!
              .updateBottomSheetHeight(milliseconds: 300);
        } else {
          myCustomPrintStatement('⚠️ homePageKey.currentState est null!');
        }
      });
    }
  }

  Map? pickLocation;
  Map? dropLocation;
  Map? booking;
  VehicleModal? selectedVehicle;
  PromoCodeModal? selectedPromoCode;

  double paymentMethodDiscountAmount = 0;
  double paymentMethodDiscountPercentage = 0;

  DriverModal? acceptedDriver;
  Stream<QuerySnapshot>? bookingStream;
  Stream<QuerySnapshot>? scheduledBookingStream;
  StreamSubscription<QuerySnapshot>? scheduledBookingStreamSub;
  StreamSubscription<QuerySnapshot>? _bookingStreamSubscription;

  // Listener spécifique pour détecter la suppression du booking actif (pour paiement cash)
  StreamSubscription<DocumentSnapshot>? _activeBookingListener;

  // Variables pour optimiser le zoom adaptatif
  double? _lastZoomLevel;
  DateTime? _lastZoomUpdate;
  int? _lastDistanceBand;
  static const Duration _zoomUpdateCooldown = Duration(seconds: 3);

  // Variables pour le suivi en temps réel du driver
  StreamSubscription<DocumentSnapshot>? _driverLocationStreamSub;
  final List<_DriverMotionSample> _driverMotionHistory = [];
  Ticker? _driverMotionTicker;
  DateTime? _driverInterpolationStartTime;
  LatLng? _driverInterpolationStartPosition;
  LatLng? _driverInterpolationTargetPosition;
  Duration _driverInterpolationDuration = const Duration(milliseconds: 1200);
  bool _isDriverExtrapolating = false;
  DateTime? _driverExtrapolationStartTime;
  static const Duration _driverExtrapolationTrigger = Duration(seconds: 8);
  static const Duration _driverExtrapolationSegment = Duration(seconds: 3);
  static const Duration _driverExtrapolationMax = Duration(seconds: 12);
  LatLng? _smoothedDriverPosition;
  DateTime? _lastFirestoreDriverUpdate;
  DateTime? _lastMarkerUpdateTime;
  Timer? _driverExtrapolationTimer;
  ui.Offset? _driverAverageVelocity;

  // Variables pour le zoom adaptatif pendant "driver on way"
  double? _lastDriverToPickupDistance;
  DateTime? _lastAdaptiveZoomUpdate;
  static const Duration _adaptiveZoomCooldown = Duration(seconds: 3); // 3 secondes pour un zoom dynamique fluide

  // Flag pour le centrage initial quand la course passe à RIDE_STARTED
  bool _hasInitialRideStartedFit = false;
  static const double _adaptiveZoomDistanceChangeThreshold = 0.15; // 15% de changement pour être réactif

  LatLng? get smoothedDriverPosition => _smoothedDriverPosition;
  DateTime? _lastRouteRefresh;
  LatLng? _lastDeviationPosition;
  int _consecutiveDeviationSamples = 0;

  static const Duration _routeRefreshCooldown = Duration(seconds: 25);
  static const double _routeDeviationThresholdMeters = 35.0;
  static const double _minimumDeviationMovementMeters = 8.0;
  static const int _requiredDeviationSamples = 2;

  // Nouvelles propriétés pour le partage en temps réel
  StreamSubscription<DocumentSnapshot>? _liveShareStreamSubscription;
  Map<String, dynamic>? _currentLiveShareData;
  bool _isLiveShareActive = false;
  String? _currentLiveShareRideId; // Pour décrémenter le compteur de viewers

  // 🛡️ Session de partage en attente (pour le bouton bouclier de retour)
  String? _pendingLiveShareRideId;
  String? _pendingLiveShareToken;
  DateTime? _pendingLiveShareExpiresAt;
  bool _liveShareDismissedByUser = false; // L'utilisateur a cliqué sur "Fermer"

  Map<String, dynamic>? get currentLiveShareData => _currentLiveShareData;
  bool get isLiveShareActive => _isLiveShareActive;

  /// Vérifie si une session de partage est en attente (bouton bouclier à afficher)
  bool get hasPendingLiveShare {
    if (_liveShareDismissedByUser) return false;
    if (_pendingLiveShareRideId == null || _pendingLiveShareToken == null) return false;
    if (_pendingLiveShareExpiresAt != null && DateTime.now().isAfter(_pendingLiveShareExpiresAt!)) return false;
    return true;
  }

  String? get pendingLiveShareRideId => _pendingLiveShareRideId;
  String? get pendingLiveShareToken => _pendingLiveShareToken;

  /// Nombre de personnes qui suivent actuellement la course partagée
  int get activeShareViewers {
    if (booking == null) return 0;
    return (booking!['activeViewers'] as num?)?.toInt() ?? 0;
  }

  double? distance;
  bool showCancelButton = true;
  bool loadingOnPayButton = false;
  bool showSateftyAlertWidget = false;
  bool cancelBookingLoder = false;
  bool _userCancelledManually =
      false; // Flag pour éviter les messages d'annulation quand l'utilisateur annule lui-même
  bool _scheduledBookingAwaitingReassignment =
      false; // Flag pour indiquer qu'une course planifiée attend un nouveau chauffeur après désistement
  bool firstTimeAtApp = true;
  bool firstTimeBookingAtApp = true;
  PaymentMethodType? confirmMobileNumberPaymentType;
  DateTime? rideScheduledTime;
  setPaymentConfirmMobileNumber(PaymentMethodType set) {
    confirmMobileNumberPaymentType = set;
    notifyListeners();
  }

  // Helper method to safely set driverOnWay only when appropriate
  void _safeSetDriverOnWay({required String source}) {
    myCustomPrintStatement('🔍 _safeSetDriverOnWay called from: $source');
    myCustomPrintStatement(
        '   Current booking: ${booking != null ? booking!['id'] : 'NULL'}');
    myCustomPrintStatement('   Current step: $currentStep');
    myCustomPrintStatement('   Booking status: ${booking?['status']}');

    // CRITICAL: If no booking exists, DON'T transition to driverOnWay
    if (booking == null) {
      myCustomPrintStatement(
          '🛑 BLOCKING driverOnWay - NO ACTIVE BOOKING! Source: $source');
      return;
    }

    // CRITICAL: Don't interrupt payment flows for RIDE_COMPLETE
    if (booking!['status'] == BookingStatusType.RIDE_COMPLETE.value &&
        (currentStep == CustomTripType.paymentMobileConfirm ||
            currentStep == CustomTripType.orangeMoneyPayment)) {
      myCustomPrintStatement(
          '🛑 BLOCKING driverOnWay - RIDE_COMPLETE with active payment flow! Current: $currentStep');
      return;
    }

    if (booking!['isSchedule'] == true) {
      bool rideHasStarted =
          booking!['status'] >= BookingStatusType.RIDE_STARTED.value;
      bool startRideIsTrue = booking!['startRide'] == true;
      bool driverAccepted = booking!['acceptedBy'] != null;
      myCustomPrintStatement(
          '   Scheduled booking - status: ${booking!['status']}, rideStarted: $rideHasStarted, startRide: $startRideIsTrue, driverAccepted: $driverAccepted');

      // 🔧 FIX: Pour les courses planifiées, le flow "driverOnWay" doit s'afficher
      // SEULEMENT quand le chauffeur confirme le début du job (startRide=true)
      // PAS simplement quand il accepte la réservation
      if (!rideHasStarted && !startRideIsTrue) {
        myCustomPrintStatement(
            '🛑 BLOCKING driverOnWay for scheduled booking - startRide=$startRideIsTrue, rideStarted=$rideHasStarted (driver must confirm to show flow)');
        return; // Don't set driverOnWay until driver confirms start
      }
    }

    // Guard: si déjà sur driverOnWay, le setter va ignorer — pas besoin de relancer les effets
    if (currentStep == CustomTripType.driverOnWay) {
      myCustomPrintStatement(
          '⏭️ _safeSetDriverOnWay: déjà sur driverOnWay - skip (source: $source)');
      return;
    }

    myCustomPrintStatement('✅ Setting driverOnWay from: $source');
    currentStep = CustomTripType.driverOnWay; // This will go through the setter

    // 🔧 FIX: Mettre à jour la hauteur du bottom sheet pour driverOnWay (58%)
    // Utilise un délai court pour laisser le widget se construire
    Future.delayed(const Duration(milliseconds: 100), () {
      if (MyGlobalKeys.homePageKey.currentState != null) {
        MyGlobalKeys.homePageKey.currentState!
            .updateBottomSheetHeight(milliseconds: 200);
      }
    });

    // 🔧 FIX: Naviguer vers MainNavigationScreen si l'utilisateur n'est pas sur la page d'accueil
    // Cela garantit que le flow de course est visible peu importe où se trouve l'utilisateur
    _navigateToHomeIfNeeded();
  }

  /// Navigue vers la page d'accueil si l'utilisateur est sur une autre page
  void _navigateToHomeIfNeeded() {
    try {
      final context = MyGlobalKeys.navigatorKey.currentContext;
      if (context == null) {
        myCustomPrintStatement('⚠️ _navigateToHomeIfNeeded: context is null');
        return;
      }

      final navigator = Navigator.of(context);

      // Cas 1: L'utilisateur est sur une page pushée (sous-page)
      if (navigator.canPop()) {
        myCustomPrintStatement('🏠 Utilisateur sur une sous-page - navigation vers MainNavigationScreen pour afficher le flow de course');

        // Utiliser pushAndRemoveUntil pour revenir à MainNavigationScreen
        pushAndRemoveUntil(
          context: context,
          screen: const MainNavigationScreen(),
        );
        return;
      }

      // Cas 2: L'utilisateur est sur MainNavigationScreen mais pas sur l'onglet Accueil
      final mainNavState = MainNavigationScreenState.instance;
      if (mainNavState != null) {
        myCustomPrintStatement('🏠 Utilisateur sur MainNavigationScreen - navigation vers onglet Accueil');
        mainNavState.goToHome();
      } else {
        myCustomPrintStatement('✅ Utilisateur déjà sur l\'écran d\'accueil - pas de navigation nécessaire');
      }
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur _navigateToHomeIfNeeded: $e');
    }
  }

  /// Annulation manuelle de la course (remplacement complet)
  Future<void> cancelRide({String? reason}) async {
    myCustomPrintStatement('🛑 ANNULATION MANUELLE DEMANDÉE - reason=$reason');

    if (booking == null) {
      myCustomPrintStatement('⚠️ Aucun booking actif à annuler');
      return;
    }

    final bookingId = booking!['id'];
    final driverId = booking!['acceptedBy'];
    final userId = userData.value?.id;

    if (bookingId == null || userId == null) {
      myCustomPrintStatement('❌ Impossible d’annuler : bookingId ou userId manquant');
      return;
    }

    cancelBookingLoder = true;
    notifyListeners();

    // 🔧 FIX: Annuler immédiatement le timer de retry pour éviter la recréation de la course
    _pendingRequestRetryTimer?.cancel();
    _pendingRequestRetryTimer = null;
    myCustomPrintStatement('🛑 Timer de retry annulé');

    try {
      // --- Étape 1 : Préparer les données d'annulation ---
      myCustomPrintStatement('📡 Tentative d\'annulation Firestore pour $bookingId...');

      // Récupérer les données complètes du booking avant suppression
      final bookingDoc = await FirestoreServices.bookingRequest.doc(bookingId).get()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Booking fetch timeout');
      });

      if (!bookingDoc.exists) {
        myCustomPrintStatement('⚠️ Booking déjà supprimé');
        await clearAllTripData();
        currentStep = CustomTripType.setYourDestination;
        return;
      }

      Map<String, dynamic> bookingData = bookingDoc.data() as Map<String, dynamic>;

      // Ajouter les informations d'annulation
      bookingData['status'] = BookingStatusType.CANCELLED_BY_RIDER.value;
      bookingData['cancelledBy'] = 'rider';
      bookingData['cancellationReason'] = reason ?? 'Annulation manuelle';
      bookingData['cancelledAt'] = FieldValue.serverTimestamp();

      // --- Étape 2 : Migrer vers cancelledBooking ---
      await FirestoreServices.cancelledBooking.doc(bookingId).set(bookingData)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Migration to cancelledBooking timeout');
      });

      myCustomPrintStatement('✅ Booking migré vers cancelledBooking');

      // --- Étape 3 : Supprimer de bookingRequest ---
      await FirestoreServices.bookingRequest.doc(bookingId).delete()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Booking deletion timeout');
      });

      myCustomPrintStatement('✅ Booking supprimé de bookingRequest');

      // --- Étape 4 : Notification driver ---
      if (driverId != null && driverId.isNotEmpty) {
        try {
          await FirestoreServices.users
              .doc(driverId)
              .collection('notifications')
              .add({
            'type': 'ride_cancelled',
            'ride_id': bookingId,
            'title': 'Course annulée',
            'message': 'Le passager a annulé la course.',
            'timestamp': FieldValue.serverTimestamp(),
          });
          myCustomPrintStatement('📨 Notification envoyée au chauffeur');
        } catch (e) {
          myCustomPrintStatement('⚠️ Échec envoi notification chauffeur: $e');
        }
      }

      // --- Étape 5 : Purge locale immédiate ---
      _userCancelledManually = true; // Éviter les messages d'annulation
      await clearAllTripData();
      currentStep = CustomTripType.setYourDestination;

      myCustomPrintStatement('✅ Annulation complète terminée côté client');

      // Réinitialiser le flag après un délai
      Future.delayed(const Duration(seconds: 2), () {
        _userCancelledManually = false;
      });
    } catch (e) {
      myCustomPrintStatement('❌ Erreur pendant annulation Firestore: $e');

      // Fallback : essayer de supprimer le document même en cas d'erreur
      try {
        myCustomPrintStatement('🔄 Tentative de suppression du booking en fallback...');
        await FirestoreServices.bookingRequest.doc(bookingId).delete()
            .timeout(const Duration(seconds: 5));
        myCustomPrintStatement('✅ Booking supprimé en fallback');
      } catch (deleteError) {
        myCustomPrintStatement('❌ Impossible de supprimer le booking: $deleteError');
      }

      // Purge locale pour débloquer l'UI de toute façon
      _userCancelledManually = true;
      await clearAllTripData();
      currentStep = CustomTripType.setYourDestination;

      showSnackbar('Erreur réseau : annulation locale effectuée.');

      // Réinitialiser le flag après un délai
      Future.delayed(const Duration(seconds: 2), () {
        _userCancelledManually = false;
      });
    } finally {
      cancelBookingLoder = false;
      notifyListeners();
    }
  }

  /// Purge toutes les données du voyage en cours et remet le provider à zéro
  /// Traite l'attribution des points de fidélité après une course terminée
  Future<void> _processLoyaltyPoints() async {
    try {
      if (booking == null || userData.value == null) {
        myCustomPrintStatement('LoyaltyPoints: Booking ou user data manquant');
        return;
      }

      // Vérifier que la course est bien terminée
      if (booking!['status'] != BookingStatusType.RIDE_COMPLETE.value) {
        myCustomPrintStatement(
            'LoyaltyPoints: Course pas encore terminée (status: ${booking!['status']})');
        return;
      }

      // Récupérer le montant payé
      final ridePriceToPay = booking!['ride_price_to_pay'];
      if (ridePriceToPay == null) {
        myCustomPrintStatement('LoyaltyPoints: Montant à payer non défini');
        return;
      }

      double amount;
      try {
        amount = double.parse(ridePriceToPay.toString());
      } catch (e) {
        myCustomPrintStatement(
            'LoyaltyPoints: Erreur parsing montant: $ridePriceToPay - $e');
        return;
      }

      if (amount <= 0) {
        myCustomPrintStatement('LoyaltyPoints: Montant invalide: $amount');
        return;
      }

      // Générer un ID unique pour éviter les doublons
      final bookingId = booking!['id'];
      final userId = userData.value!.id;

      // Vérifier si les points ont déjà été attribués pour cette course
      final loyaltyService = LoyaltyService.instance;
      final transactionId = '${userId}_${bookingId}_ride_complete';

      final alreadyProcessed =
          await loyaltyService.transactionExists(transactionId, userId);
      if (alreadyProcessed) {
        myCustomPrintStatement(
            'LoyaltyPoints: Points déjà attribués pour booking $bookingId');
        return;
      }

      // Attribuer les points
      final success = await loyaltyService.addPoints(
        userId: userId,
        amount: amount,
        reason: 'Course terminée (ID: $bookingId)',
        bookingId: bookingId,
      );

      if (success) {
        myCustomPrintStatement(
            '✅ LoyaltyPoints: Points attribués avec succès pour booking $bookingId (montant: $amount MGA)');
      } else {
        myCustomPrintStatement(
            '❌ LoyaltyPoints: Échec attribution points pour booking $bookingId');
      }
    } catch (e) {
      myCustomPrintStatement('❌ LoyaltyPoints: Erreur traitement - $e');
    }
  }

  Future<void> clearAllTripData() async {
    myCustomPrintStatement('🧹 TripProvider: Purge complète des données');

    // Arrêter le suivi en temps réel
    stopRideTracking();

    // 🔧 FIX: Annuler le timer de retry pendingRequest pour éviter la recréation de la course
    _pendingRequestRetryTimer?.cancel();
    _pendingRequestRetryTimer = null;

    // 🔧 FIX: Réinitialiser le flag de réassignation
    _scheduledBookingAwaitingReassignment = false;

    // Réinitialiser tous les états du voyage
    pickLocation = null;
    dropLocation = null;
    selectedVehicle = null;
    selectedPromoCode = null;
    paymentMethodDiscountAmount = 0;
    paymentMethodDiscountPercentage = 0;
    acceptedDriver = null;
    distance = null;
    rideScheduledTime = null;

    // CRITIQUE : Arrêter le bookingStream pour éviter la réassignation
    if (_bookingStreamSubscription != null) {
      try {
        await _bookingStreamSubscription!.cancel();
        _bookingStreamSubscription = null;
        bookingStream = null;
        myCustomPrintStatement('✅ Booking stream subscription annulée');
      } catch (e) {
        myCustomPrintStatement('⚠️ Erreur arrêt booking stream: $e');
      }
    }

    // Arrêter les streams actifs
    if (scheduledBookingStreamSub != null) {
      scheduledBookingStreamSub!.cancel();
      scheduledBookingStreamSub = null;
    }

    if (_liveShareStreamSubscription != null) {
      _liveShareStreamSubscription!.cancel();
      _liveShareStreamSubscription = null;
    }

    // Arrêter le tracking de position du driver
    stopDriverLocationTracking();

    // Réinitialiser les données de partage en temps réel
    _currentLiveShareData = null;
    _isLiveShareActive = false;

    // Nettoyer le booking actuel
    booking = null;

    // Supprimer la sauvegarde locale
    DevFestPreferences prefs = DevFestPreferences();
    await prefs.clearActiveBooking();

    // Réinitialiser les streams
    bookingStream = null;
    scheduledBookingStream = null;

    // Nettoyer les polylines sur la carte
    try {
      var mapProvider = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);
      mapProvider.clearAllPolylines();
      mapProvider.hideMarkers();
      myCustomPrintStatement('✅ Polylines et markers nettoyés');
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur nettoyage polylines: $e');
    }

    // 🔧 FIX: Nettoyer le chat pour éviter que les messages de l'ancienne course persistent
    try {
      var chatProvider = Provider.of<TripChatProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);
      chatProvider.disposeChat();
      myCustomPrintStatement('✅ Chat nettoyé');
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur nettoyage chat: $e');
    }

    myCustomPrintStatement('✅ TripProvider: Purge complète terminée');
    notifyListeners();
  }

  /// Vérifie s'il existe une course active et restaure l'état approprié
  Future<CustomTripType?> checkForActiveTrip() async {
    // Variables déclarées en dehors du try-catch pour être accessibles dans le catch
    DevFestPreferences prefs = DevFestPreferences();
    var localBooking = await prefs.getActiveBooking();
    bool hasLocalBooking = false;

    myCustomPrintStatement(
        '🔍 TripProvider: Cache local booking trouvé: ${localBooking != null ? localBooking['id'] : 'null'}');
    if (localBooking != null) {
      myCustomPrintStatement(
          '🔍 TripProvider: Statut cache local: ${localBooking['status']}');
      myCustomPrintStatement(
          '🔍 TripProvider: PaymentStatus cache local: ${localBooking['paymentStatusSummary']}');
      myCustomPrintStatement(
          '🔍 TripProvider: Contenu complet cache: $localBooking');
    } else {
      myCustomPrintStatement(
          '⚠️ TripProvider: AUCUN CACHE LOCAL TROUVÉ - Vérifiez si une course est en cours et sauvegardée');
    }

    try {
      myCustomPrintStatement(
          '🔍 TripProvider: Vérification de course active existante');

      if (userData.value?.id == null) {
        myCustomPrintStatement(
            '⚠️ Pas d\'utilisateur connecté - aucune restauration');
        return null;
      }

      if (localBooking != null) {
        int status = localBooking['status'] ?? -1;

        // Vérifier si c'est une course planifiée future (plus de 5 minutes dans le futur)
        bool isScheduledFuture = false;
        if (localBooking['isSchedule'] == true && localBooking['scheduleTime'] != null) {
          try {
            DateTime scheduledTime = (localBooking['scheduleTime'] as Timestamp).toDate();
            DateTime now = DateTime.now();
            int minutesUntilScheduled = scheduledTime.difference(now).inMinutes;

            // 🔧 FIX: Si le chauffeur a accepté la course (status >= ACCEPTED ou acceptedBy != null),
            // on doit afficher le flow de course même si c'est dans le futur
            bool driverAccepted = localBooking['acceptedBy'] != null ||
                                  status >= BookingStatusType.ACCEPTED.value;

            // Si la course est prévue dans plus de 5 minutes ET le chauffeur n'a pas accepté, c'est une course future
            isScheduledFuture = minutesUntilScheduled > 5 && !driverAccepted;

            if (isScheduledFuture) {
              myCustomPrintStatement(
                  '⏰ Course planifiée future détectée (dans $minutesUntilScheduled min) - ignorée pour restauration');
            } else if (driverAccepted && minutesUntilScheduled > 5) {
              // 🔧 FIX: Vérifier si startRide=true avant d'afficher le flow
              bool startRideFlag = localBooking['startRide'] == true;
              if (startRideFlag) {
                myCustomPrintStatement(
                    '🚗 Course planifiée acceptée ET démarrée (dans $minutesUntilScheduled min) - AFFICHAGE DU FLOW');
              } else {
                myCustomPrintStatement(
                    '📅 Course planifiée confirmée mais pas démarrée (startRide=false) - pas de flow');
                // 🔧 FIX: Marquer comme "future" pour ne pas restaurer le flow
                isScheduledFuture = true;
              }
            }
          } catch (e) {
            myCustomPrintStatement('⚠️ Erreur vérification scheduleTime: $e');
          }
        }

        // Si la course locale est toujours active (et pas une réservation future)
        bool isLocalActiveRide =
            !isScheduledFuture &&
            ((status >= BookingStatusType.PENDING_REQUEST.value &&
                    status <= BookingStatusType.DESTINATION_REACHED.value) ||
                (status == BookingStatusType.RIDE_COMPLETE.value &&
                    localBooking['paymentStatusSummary'] == null));

        if (isLocalActiveRide) {
          myCustomPrintStatement(
              '📱 Course active trouvée dans cache local - ID: ${localBooking['id']}, statut: $status');
          hasLocalBooking = true;

          // Si on a une course locale et pas de connexion, on peut la restaurer directement
          // Ceci permet de continuer même hors ligne
          if (status == BookingStatusType.DESTINATION_REACHED.value ||
              (status == BookingStatusType.RIDE_COMPLETE.value &&
                  localBooking['paymentStatusSummary'] == null)) {
            // Restaurer immédiatement pour l'écran de paiement
            booking = localBooking;
            myCustomPrintStatement(
                '💳 Restauration directe de l\'écran de paiement depuis cache');

            // Restaurer les locations pickup et drop
            if (localBooking['pickLat'] != null &&
                localBooking['pickLng'] != null) {
              pickLocation = {
                'lat': localBooking['pickLat'],
                'lng': localBooking['pickLng'],
                'address': localBooking['pickAddress'] ?? 'Adresse de prise en charge',
                'city': localBooking['city'] ?? '',
              };
            }
            if (localBooking['dropLat'] != null &&
                localBooking['dropLng'] != null) {
              dropLocation = {
                'lat': localBooking['dropLat'],
                'lng': localBooking['dropLng'],
                'address':
                    localBooking['dropAddress'] ?? 'Adresse de destination',
              };
            }

            // Restaurer les données du véhicule si disponibles
            if (localBooking['selectedVehicle'] != null) {
              try {
                selectedVehicle =
                    VehicleModal.fromJson(localBooking['selectedVehicle']);
              } catch (e) {
                myCustomPrintStatement(
                    '⚠️ Erreur restauration véhicule depuis cache: $e');
              }
            }

            // Essayer de restaurer le driver si disponible
            if (localBooking['acceptedBy'] != null &&
                localBooking['acceptedBy'].isNotEmpty) {
              try {
                var driverDoc = await FirestoreServices.users
                    .doc(localBooking['acceptedBy'])
                    .get();
                if (driverDoc.exists) {
                  acceptedDriver = DriverModal.fromJson(
                      driverDoc.data() as Map<String, dynamic>);
                  myCustomPrintStatement(
                      '✅ Driver restauré depuis Firestore pour écran paiement');
                }
              } catch (e) {
                myCustomPrintStatement(
                    '⚠️ Erreur restauration driver: $e - Continuera sans driver');
                // L'écran peut s'afficher même sans les détails complets du driver
                // Les infos essentielles sont dans le booking (nom, téléphone, etc.)
              }
            }

            // Démarrer le stream pour les mises à jour
            setBookingStream();

            // Notification immédiate
            myCustomPrintStatement(
                '💳 Notification listeners immédiate après restauration cache');
            notifyListeners();

            // Forcer la mise à jour du bottom sheet après restauration - IMMÉDIATE et DIFFÉRÉE
            if (MyGlobalKeys.homePageKey.currentState != null) {
              myCustomPrintStatement(
                  '💳 Forçage IMMÉDIAT mise à jour bottom sheet');
              MyGlobalKeys.homePageKey.currentState!
                  .updateBottomSheetHeight(milliseconds: 0);
            }

            Future.delayed(const Duration(milliseconds: 200), () {
              if (MyGlobalKeys.homePageKey.currentState != null) {
                myCustomPrintStatement(
                    '💳 Forçage DIFFÉRÉ mise à jour bottom sheet');
                MyGlobalKeys.homePageKey.currentState!
                    .updateBottomSheetHeight(milliseconds: 100);
              }
              myCustomPrintStatement(
                  '💳 Notification listeners différée après restauration cache');
              notifyListeners();
            });

            return CustomTripType.driverOnWay;
          }
        }
      }

      // Récupérer les bookings de l'utilisateur
      myCustomPrintStatement(
          '🔍 TripProvider: Interrogation Firestore pour user: ${userData.value!.id}');
      var querySnapshot = await FirestoreServices.bookingRequest
          .where('requestBy', isEqualTo: userData.value!.id)
          .orderBy('scheduleTime', descending: true)
          .limit(10) // Limiter aux 10 plus récents
          .get();

      myCustomPrintStatement(
          '🔍 TripProvider: ${querySnapshot.docs.length} bookings trouvés dans Firestore');
      if (querySnapshot.docs.isEmpty) {
        myCustomPrintStatement('✅ Aucun booking trouvé dans Firestore');
        return null;
      }

      // Chercher une course active (statut entre PENDING_REQUEST et DESTINATION_REACHED)
      for (var doc in querySnapshot.docs) {
        var bookingData = doc.data() as Map<String, dynamic>;
        int status = bookingData['status'] ?? -1;

        myCustomPrintStatement(
            '🔍 TripProvider: Booking ${bookingData['id']}: statut=$status, paymentStatus=${bookingData['paymentStatusSummary']}');

        // Vérifier si c'est une course planifiée future (plus de 5 minutes dans le futur)
        bool isScheduledFuture = false;
        if (bookingData['isSchedule'] == true && bookingData['scheduleTime'] != null) {
          try {
            DateTime scheduledTime = (bookingData['scheduleTime'] as Timestamp).toDate();
            DateTime now = DateTime.now();
            int minutesUntilScheduled = scheduledTime.difference(now).inMinutes;

            // 🔧 FIX: Si le chauffeur a accepté la course (status >= ACCEPTED ou acceptedBy != null),
            // on doit afficher le flow de course même si c'est dans le futur
            bool driverAccepted = bookingData['acceptedBy'] != null ||
                                  status >= BookingStatusType.ACCEPTED.value;

            // Si la course est prévue dans plus de 5 minutes ET le chauffeur n'a pas accepté, c'est une course future
            isScheduledFuture = minutesUntilScheduled > 5 && !driverAccepted;

            if (isScheduledFuture) {
              myCustomPrintStatement(
                  '⏰ Course planifiée future ${bookingData['id']} (dans $minutesUntilScheduled min) - ignorée pour restauration');
            } else if (driverAccepted && minutesUntilScheduled > 5) {
              // 🔧 FIX: Vérifier si startRide=true avant d'afficher le flow
              bool startRideFlag = bookingData['startRide'] == true;
              if (startRideFlag) {
                myCustomPrintStatement(
                    '🚗 Course planifiée ${bookingData['id']} acceptée ET démarrée (dans $minutesUntilScheduled min) - AFFICHAGE DU FLOW');
              } else {
                myCustomPrintStatement(
                    '📅 Course planifiée ${bookingData['id']} confirmée mais pas démarrée (startRide=false) - pas de flow');
                // 🔧 FIX: Marquer comme "future" pour ne pas restaurer le flow
                isScheduledFuture = true;
              }
            }
          } catch (e) {
            myCustomPrintStatement('⚠️ Erreur vérification scheduleTime: $e');
          }
        }

        // Course active si :
        // - statut entre 0 (PENDING_REQUEST) et 4 (DESTINATION_REACHED)
        // - ou statut 5 (RIDE_COMPLETE) mais paiement en cours (paymentStatusSummary == null)
        // - ET ce n'est PAS une course planifiée future
        bool isActiveRide =
            !isScheduledFuture &&
            ((status >= BookingStatusType.PENDING_REQUEST.value &&
                    status <= BookingStatusType.DESTINATION_REACHED.value) ||
                (status == BookingStatusType.RIDE_COMPLETE.value &&
                    bookingData['paymentStatusSummary'] == null));

        if (isActiveRide) {
          myCustomPrintStatement(
              '🎯 Course active trouvée - ID: ${bookingData['id']}, statut: $status');

          // Restaurer les données de booking
          booking = bookingData;

          // Sauvegarder localement pour persistance
          DevFestPreferences prefs = DevFestPreferences();
          await prefs.saveActiveBooking(bookingData);

          // Restaurer les locations pickup et drop depuis les champs individuels
          if (bookingData['pickLat'] != null &&
              bookingData['pickLng'] != null) {
            pickLocation = {
              'lat': bookingData['pickLat'],
              'lng': bookingData['pickLng'],
              'address': bookingData['pickAddress'] ?? 'Adresse de prise en charge',
              'city': bookingData['city'] ?? '',
            };
            myCustomPrintStatement(
                '✅ PickupLocation restauré: ${pickLocation?['address']}');
          }
          if (bookingData['dropLat'] != null &&
              bookingData['dropLng'] != null) {
            dropLocation = {
              'lat': bookingData['dropLat'],
              'lng': bookingData['dropLng'],
              'address': bookingData['dropAddress'] ?? 'Adresse de destination',
            };
            myCustomPrintStatement(
                '✅ DropLocation restauré: ${dropLocation?['address']}');
          }

          // Restaurer le véhicule sélectionné
          if (bookingData['selectedVehicle'] != null) {
            try {
              selectedVehicle =
                  VehicleModal.fromJson(bookingData['selectedVehicle']);
              myCustomPrintStatement(
                  '✅ Véhicule sélectionné restauré: ${selectedVehicle?.name}');
            } catch (e) {
              myCustomPrintStatement('⚠️ Erreur restauration véhicule: $e');
            }
          }

          // Restaurer le driver si accepté
          if (bookingData['acceptedBy'] != null &&
              bookingData['acceptedBy'].isNotEmpty) {
            try {
              var driverDoc = await FirestoreServices.users
                  .doc(bookingData['acceptedBy'])
                  .get();
              if (driverDoc.exists) {
                acceptedDriver = DriverModal.fromJson(
                    driverDoc.data() as Map<String, dynamic>);
                myCustomPrintStatement(
                    '✅ Driver restauré: ${acceptedDriver?.fullName}');
              }
            } catch (e) {
              myCustomPrintStatement('⚠️ Erreur restauration driver: $e');
            }
          }

          // Déterminer l'état approprié selon le statut
          CustomTripType targetState;
          if (status == BookingStatusType.PENDING_REQUEST.value) {
            // 🔧 FIX: Vérifier si le booking PENDING_REQUEST est trop vieux (>60s)
            // Si oui, c'est un booking périmé qu'on doit supprimer, pas restaurer
            if (bookingData['requestTime'] != null) {
              try {
                int requestTimeSecs = (bookingData['requestTime'] as Timestamp).seconds;
                int currentTimeSecs = Timestamp.now().seconds;
                int ageSeconds = currentTimeSecs - requestTimeSecs;

                if (ageSeconds > 60) {
                  myCustomPrintStatement(
                      '⚠️ Booking PENDING_REQUEST trop vieux (${ageSeconds}s) - suppression');

                  // Supprimer le booking périmé
                  await FirestoreServices.bookingRequest.doc(bookingData['id']).delete();

                  // Nettoyer le cache local
                  DevFestPreferences prefs = DevFestPreferences();
                  await prefs.clearActiveBooking();

                  // Ne pas restaurer ce booking
                  booking = null;
                  continue; // Passer au booking suivant s'il y en a
                }
              } catch (e) {
                myCustomPrintStatement('⚠️ Erreur vérification âge booking: $e');
              }
            }

            targetState = CustomTripType.requestForRide;
          } else if (status == BookingStatusType.DESTINATION_REACHED.value) {
            // Course terminée, afficher l'écran de paiement
            targetState = CustomTripType.driverOnWay;
            myCustomPrintStatement(
                '💳 Course terminée - Restauration de l\'écran de paiement');
          } else if (status == BookingStatusType.RIDE_COMPLETE.value &&
              bookingData['paymentStatusSummary'] == null) {
            // Course complète mais paiement en attente
            targetState = CustomTripType.driverOnWay;
            myCustomPrintStatement('💳 Course complète - Paiement en attente');
          } else {
            // Pour les autres statuts (ACCEPTED, DRIVER_REACHED, RIDE_STARTED)
            // 🔧 FIX: Pour les courses planifiées, ne pas afficher driverOnWay si startRide=false
            // Le chauffeur a confirmé la réservation mais n'a pas encore démarré la course
            bool isScheduledBooking = bookingData['isSchedule'] == true;
            bool startRideFlag = bookingData['startRide'] == true;

            if (isScheduledBooking && !startRideFlag && status == BookingStatusType.ACCEPTED.value) {
              // Course planifiée confirmée mais pas encore démarrée → rester sur l'écran d'accueil
              targetState = CustomTripType.setYourDestination;
              myCustomPrintStatement(
                  '📅 Course planifiée confirmée mais startRide=false - pas de flow driverOnWay');
            } else {
              targetState = CustomTripType.driverOnWay;
            }
          }

          myCustomPrintStatement('✅ État cible déterminé: $targetState');

          // 🔧 FIX: Démarrer le stream pour écouter les mises à jour du booking
          // Sans ça, l'app ne détecte pas quand le driver termine la course
          setBookingStream();
          myCustomPrintStatement('🔄 Booking stream démarré après restauration Firestore');

          // Notification immédiate après restauration Firestore
          myCustomPrintStatement(
              '💳 Notification listeners après restauration Firestore');
          notifyListeners();

          return targetState;
        }
      }

      myCustomPrintStatement('✅ Aucune course active trouvée');

      // 🔧 FIX: Démarrer le stream même sans course active pour détecter
      // quand une course planifiée est démarrée par le chauffeur (startRide=true)
      // Cela permet de gérer le cas où l'utilisateur a désactivé les notifications push
      setBookingStream();
      myCustomPrintStatement('🔄 Booking stream démarré (aucune course active - surveillance courses planifiées)');

      return null;
    } catch (e) {
      myCustomPrintStatement(
          '❌ Erreur lors de la vérification de course active: $e');

      // Si on a une erreur réseau mais une course locale, on peut quand même restaurer
      if (hasLocalBooking && localBooking != null) {
        int status = localBooking['status'] ?? -1;
        myCustomPrintStatement(
            '📱 Utilisation du cache local suite à erreur réseau - statut: $status');

        // Déterminer l'état selon le statut local
        if (status == BookingStatusType.PENDING_REQUEST.value) {
          // 🔧 FIX: Vérifier si le booking local PENDING_REQUEST est trop vieux (>60s)
          if (localBooking['requestTime'] != null) {
            try {
              int requestTimeSecs = (localBooking['requestTime'] as Timestamp).seconds;
              int currentTimeSecs = Timestamp.now().seconds;
              int ageSeconds = currentTimeSecs - requestTimeSecs;

              if (ageSeconds > 60) {
                myCustomPrintStatement(
                    '⚠️ Booking local PENDING_REQUEST trop vieux (${ageSeconds}s) - suppression cache');
                DevFestPreferences prefs = DevFestPreferences();
                await prefs.clearActiveBooking();
                return null; // Ne pas restaurer
              }
            } catch (e) {
              myCustomPrintStatement('⚠️ Erreur vérification âge booking local: $e');
            }
          }

          booking = localBooking;
          return CustomTripType.requestForRide;
        }

        booking = localBooking;

        // 🔧 FIX: Démarrer le stream même en cas d'erreur réseau pour capter les mises à jour
        setBookingStream();
        myCustomPrintStatement('🔄 Booking stream démarré après restauration cache local (erreur réseau)');

        if (status >= BookingStatusType.ACCEPTED.value &&
            status <= BookingStatusType.DESTINATION_REACHED.value) {
          return CustomTripType.driverOnWay;
        } else if (status == BookingStatusType.RIDE_COMPLETE.value &&
            localBooking['paymentStatusSummary'] == null) {
          return CustomTripType.driverOnWay; // Écran de paiement
        }
      } else {
        // 🔧 FIX: Même en erreur réseau sans cache local, démarrer le stream
        // pour surveiller les courses planifiées
        setBookingStream();
        myCustomPrintStatement('🔄 Booking stream démarré (erreur réseau, pas de cache - surveillance)');
      }

      return null;
    }
  }

  setScreen(CustomTripType? v) {
    if (CustomTripType.setYourDestination == v) {
      // Purger les données de voyage seulement si on avait un état actif
      if (_currentStep != null &&
          _currentStep != CustomTripType.setYourDestination) {
        myCustomPrintStatement(
            '🏠 Retour au menu principal détecté - nettoyage de la carte');

        // Nettoyer complètement les itinéraires et l'état de la carte
        final mapProvider = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false,
        );
        mapProvider.clearAllPolylines();
        mapProvider.stopRouteAnimation();
        mapProvider.hideMarkers();
        mapProvider.visiblePolyline = false;
        mapProvider.visibleCoveredPolyline = false;

        myCustomPrintStatement(
            '✅ Carte nettoyée et prête pour le menu principal');
      }

      resetDriverTrackingForHome();
      rideScheduledTime = null;
      // Recentrer automatiquement la carte sur la position GPS de l'utilisateur
      // quand il revient à la page d'accueil
      _recenterOnUserLocationWhenBackHome();
    }

    // Reset polyline et dézoom quand on revient à la saisie d'adresses depuis le choix de véhicule
    if (v == CustomTripType.choosePickupDropLocation &&
        _currentStep == CustomTripType.chooseVehicle) {
      myCustomPrintStatement(
          '⬅️ Retour à la saisie d\'adresses depuis choix de véhicule - reset polyline et dézoom');

      final mapProvider = Provider.of<GoogleMapProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false,
      );

      // Supprimer le polyline
      mapProvider.clearAllPolylines();
      mapProvider.stopRouteAnimation();
      mapProvider.visiblePolyline = false;
      mapProvider.visibleCoveredPolyline = false;

      // Dézoomer et recentrer sur la position utilisateur
      Future.delayed(const Duration(milliseconds: 300), () {
        mapProvider.centerOnUserLocationSimple();
        myCustomPrintStatement(
            '✅ Polyline supprimé et carte recentrée sur position utilisateur');
      });
    }

    // CRITICAL DEBUG: Track all transitions to driverOnWay for scheduled bookings
    if (v == CustomTripType.driverOnWay &&
        booking != null &&
        booking!['isSchedule'] == true) {
      myCustomPrintStatement(
          "🚨 CRITICAL: Trying to set driverOnWay for SCHEDULED BOOKING!");
      myCustomPrintStatement("   Booking ID: ${booking!['id']}");
      myCustomPrintStatement("   Booking status: ${booking!['status']}");
      myCustomPrintStatement("   StartRide flag: ${booking!['startRide']}");
      myCustomPrintStatement("   Current step: $currentStep");
      myCustomPrintStatement("   Stack trace:");
      myCustomPrintStatement(StackTrace.current.toString());

      // BLOCK transition for scheduled bookings that haven't started AND don't have startRide = true
      bool rideStarted =
          booking!['status'] >= BookingStatusType.RIDE_STARTED.value;
      bool startRideIsTrue = booking!['startRide'] == true;

      if (!rideStarted && !startRideIsTrue) {
        myCustomPrintStatement(
            "🛑 BLOCKING driverOnWay transition for scheduled booking - not ready (rideStarted: $rideStarted, startRide: $startRideIsTrue)!");
        return; // Don't set the screen
      }
    }

    myCustomPrintStatement("the sreen is going to change $v");

    // 🔧 FIX: Ne pas afficher l'overlay de transition pour le retour au menu principal
    // L'overlay n'est nécessaire que pour les transitions complexes (animations de route, etc.)
    final bool skipTransitionOverlay = v == CustomTripType.setYourDestination;

    if (!skipTransitionOverlay) {
      // Activer l'overlay de chargement pour bloquer les interactions pendant 1s
      _isTransitioning = true;
      notifyListeners(); // Notifier immédiatement pour afficher l'overlay
    }

    currentStep = v;

    if (!skipTransitionOverlay) {
      // Désactiver l'overlay après 1s pour permettre les interactions
      Future.delayed(const Duration(milliseconds: 1000), () {
        _isTransitioning = false;
        notifyListeners();
        myCustomPrintStatement("🔓 Transition terminée, interactions réactivées");
      });
    }

    // Déclencher le suivi en temps réel quand on passe à driverOnWay
    if (v == CustomTripType.driverOnWay &&
        booking != null &&
        acceptedDriver != null) {
      startRideTracking();
    }

    // Déclencher l'animation d'itinéraire lors de la transition vers "Choisissez votre course"
    if (v == CustomTripType.chooseVehicle) {
      // ⚠️ NOTE: Ne PAS vider minVehicleDistance ici car refreshDriversAroundPickup
      // est appelé AVANT setScreen dans home_screen.dart onTap callback
      // Le clear est fait dans refreshDriversAroundPickup avant de recharger les chauffeurs
      myCustomPrintStatement('📍 chooseVehicle - minVehicleDistance: ${minVehicleDistance.keys.toList()}');

      _triggerChooseVehicleRouteAnimation();

      // ⚠️ IMPORTANT : Ne pas recentrer la carte après l'animation chooseVehicle
      // car _triggerChooseVehicleRouteAnimation() a déjà positionné la caméra correctement
      // avec la nouvelle méthode fitRouteAboveBottomSheet (FitBounds + ScrollBy)
    }
    // Centrer sur le point de prise en charge lors de la transition vers "Confirmer le lieu de prise en charge"
    else if (v == CustomTripType.confirmDestination) {
      _centerOnPickupLocation();

      // ⚠️ Ne pas recentrer automatiquement après car on vient de positionner la caméra
    }
    // Centrer sur le point de prise en charge lors de la transition vers "Le chauffeur est en chemin"
    else if (v == CustomTripType.driverOnWay) {
      _centerOnPickupForDriverOnWay();

      // ⚠️ Ne pas recentrer automatiquement après car on vient de positionner la caméra
    }
    else {
      // Recentrer la carte si un itinéraire est visible et qu'on change de flow
      // (mais PAS pour chooseVehicle, confirmDestination ni driverOnWay car leur animation gère le positionnement)
      _recenterMapIfRouteVisible();
    }

    // Recentrer le point bleu utilisateur selon le nouveau contexte d'écran
    // ⚠️ Sauf pour chooseVehicle où on veut voir l'ITINÉRAIRE
    // ⚠️ Sauf pour confirmDestination où on veut voir le PICKUP
    // ⚠️ Sauf pour driverOnWay où on veut voir le PICKUP et le chauffeur qui approche
    if (v != CustomTripType.chooseVehicle &&
        v != CustomTripType.confirmDestination &&
        v != CustomTripType.driverOnWay) {
      _recenterUserLocationForCurrentContext();
    }

    notifyListeners();
    // 🔧 FIX: Vérifier si homePageKey.currentState existe avant d'appeler
    // Peut être null si appelé pendant initState avant que le widget soit construit
    if (MyGlobalKeys.homePageKey.currentState != null) {
      MyGlobalKeys.homePageKey.currentState!
          .updateBottomSheetHeight(milliseconds: 20);
    }
  }

  /// Déclenche l'animation d'itinéraire lors de la transition vers "Choisissez votre course"
  void _triggerChooseVehicleRouteAnimation() {
    try {
      myCustomPrintStatement(
          "🎬 Déclenchement animation itinéraire pour menu 'Choisissez votre course'");

      // ⚠️ PROTECTION : Éviter les appels multiples qui s'accumulent
      if (_isAnimatingChooseVehicleRoute) {
        myCustomPrintStatement(
            "⚠️ Animation déjà en cours, appel ignoré pour éviter l'accumulation");
        return;
      }

      final mapProvider = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);

      // Vérifications immédiates
      if (mapProvider.polylineCoordinates.isEmpty) {
        myCustomPrintStatement(
            "⚠️ Pas d'itinéraire disponible pour l'animation");
        return;
      }

      if (mapProvider.controller == null) {
        myCustomPrintStatement("⚠️ Controller de carte non initialisé");
        return;
      }

      myCustomPrintStatement(
          "✅ Itinéraire disponible (${mapProvider.polylineCoordinates.length} points), controller OK");

      // Marquer l'animation comme en cours
      _isAnimatingChooseVehicleRoute = true;

      // ⏱️ Attendre que le bottom sheet soit stabilisé APRÈS le rebuild
      // On utilise SchedulerBinding pour attendre la fin du frame actuel
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // 800ms permet à la bottom sheet de terminer complètement son animation
        // avant de calculer les bounds et padding de l'itinéraire
        Future.delayed(const Duration(milliseconds: 800), () async {
          try {
            // Vérifier qu'on est toujours sur chooseVehicle
            if (currentStep != CustomTripType.chooseVehicle) {
              myCustomPrintStatement(
                  "⚠️ L'utilisateur a changé d'écran, animation annulée");
              _isAnimatingChooseVehicleRoute = false;
              return;
            }

            myCustomPrintStatement(
                "🎯 Déclenchement de fitRouteAboveBottomSheet maintenant");

            // Déclencher l'animation avec la nouvelle méthode
            await mapProvider.triggerRouteAnimation();

            myCustomPrintStatement(
                "✅ Animation fitRouteAboveBottomSheet terminée");
          } catch (e) {
            myCustomPrintStatement(
                "❌ Erreur lors de l'animation d'itinéraire (postFrame): $e");
          } finally {
            // Réinitialiser le flag dans tous les cas
            _isAnimatingChooseVehicleRoute = false;
          }
        });
      });
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur lors du déclenchement de l'animation d'itinéraire: $e");
      _isAnimatingChooseVehicleRoute = false;
    }
  }

  /// Centre la carte sur le point de prise en charge avec un zoom fort
  /// lors de la transition vers "Confirmer le lieu de prise en charge"
  void _centerOnPickupLocation() {
    try {
      myCustomPrintStatement(
          "📍 Centrage sur point de prise en charge pour 'Confirmer le lieu'");

      // Vérifier que le pickup existe
      if (pickLocation == null) {
        myCustomPrintStatement(
            "⚠️ Pas de point de prise en charge disponible");
        return;
      }

      final mapProvider = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);

      if (mapProvider.controller == null) {
        myCustomPrintStatement("⚠️ Controller de carte non initialisé");
        return;
      }

      final pickupLat = pickLocation!['lat'];
      final pickupLng = pickLocation!['lng'];

      myCustomPrintStatement(
          "✅ Point pickup trouvé: ($pickupLat, $pickupLng)");

      // Attendre que le bottom sheet soit stabilisé
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 200), () async {
          try {
            // ⚠️ NE PAS vérifier currentStep pour permettre l'animation
            // même si l'utilisateur avance rapidement vers l'écran suivant
            myCustomPrintStatement(
                "🎯 Centrage sur pickup avec zoom 17.5 maintenant");

            // Centrer avec un zoom fort (17.5) pour bien voir le point
            await mapProvider.controller!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(pickupLat, pickupLng),
                  zoom: 17.5,
                  bearing: 0.0,
                  tilt: 0.0,
                ),
              ),
            );

            myCustomPrintStatement(
                "✅ Centrage sur pickup terminé");
          } catch (e) {
            myCustomPrintStatement(
                "❌ Erreur lors du centrage sur pickup: $e");
          }
        });
      });
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur lors du déclenchement du centrage pickup: $e");
    }
  }

  /// Affiche l'itinéraire du chauffeur jusqu'au point de prise en charge
  /// lors de la transition vers "Le chauffeur est en chemin"
  void _centerOnPickupForDriverOnWay() {
    try {
      myCustomPrintStatement(
          "🚗 Affichage itinéraire chauffeur → pickup pour 'Le chauffeur est en chemin'");

      // Vérifier que le pickup et le chauffeur existent
      if (pickLocation == null) {
        myCustomPrintStatement(
            "⚠️ Pas de point de prise en charge disponible");
        return;
      }

      if (acceptedDriver == null ||
          acceptedDriver!.currentLat == null ||
          acceptedDriver!.currentLng == null) {
        myCustomPrintStatement(
            "⚠️ Pas de position chauffeur disponible");
        return;
      }

      final mapProvider = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);

      if (mapProvider.controller == null) {
        myCustomPrintStatement("⚠️ Controller de carte non initialisé");
        return;
      }

      final pickupLat = pickLocation!['lat'];
      final pickupLng = pickLocation!['lng'];
      final driverLat = acceptedDriver!.currentLat!;
      final driverLng = acceptedDriver!.currentLng!;

      myCustomPrintStatement(
          "✅ Chauffeur: ($driverLat, $driverLng) → Pickup: ($pickupLat, $pickupLng)");

      // Attendre que le bottom sheet soit stabilisé à sa taille finale
      // 800ms permet à la bottom sheet de terminer complètement son animation
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 800), () async {
          try {
            // Vérifier qu'on est toujours sur driverOnWay
            if (currentStep != CustomTripType.driverOnWay) {
              myCustomPrintStatement(
                  "⚠️ L'utilisateur a changé d'écran, affichage annulé");
              return;
            }

            final context = MyGlobalKeys.navigatorKey.currentContext;
            if (context == null) {
              myCustomPrintStatement("⚠️ Contexte non disponible");
              return;
            }

            myCustomPrintStatement(
                "🎯 Affichage itinéraire chauffeur → pickup avec IOSMapFix");

            // ✅ La polyline affiche maintenant driver→pickup (tracée par createPath)
            // Pas besoin de la masquer, elle est mise à jour en live

            // Créer une liste de 2 points : chauffeur et pickup
            final routePoints = [
              LatLng(driverLat, driverLng),
              LatLng(pickupLat, pickupLng),
            ];

            // Déterminer le ratio du bottom sheet pour driverOnWay
            // D'après GoogleMapProvider._getBottomSheetHeightForCurrentContext():
            // driverOnWay utilise 0.55 (55% de l'écran) sauf si écran de paiement (0.78)
            // Ici on est toujours au début de driverOnWay donc 0.55
            const bottomSheetRatio = 0.55;

            // Utiliser IOSMapFix.safeFitBounds qui gère mieux les longs trajets nord-sud
            // en calculant le déplacement précis pour compenser le bottom sheet
            // IMPORTANT: Timeout de 3s pour éviter de figer la bottom sheet
            try {
              await IOSMapFix.safeFitBounds(
                controller: mapProvider.controller!,
                points: routePoints,
                bottomSheetRatio: bottomSheetRatio,
                debugSource: "driverOnWay_chauffeur_vers_pickup",
              ).timeout(
                const Duration(seconds: 3),
                onTimeout: () {
                  myCustomPrintStatement(
                      "⏱️ Timeout animation chauffeur→pickup (3s) - bottom sheet non bloquée");
                },
              );

              myCustomPrintStatement(
                  "✅ Affichage itinéraire chauffeur → pickup terminé");
            } on TimeoutException {
              myCustomPrintStatement(
                  "⚠️ Animation chauffeur→pickup annulée après timeout");
            }
          } catch (e) {
            myCustomPrintStatement(
                "❌ Erreur lors de l'affichage itinéraire chauffeur → pickup: $e");
          }
        });
      });
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur lors du déclenchement affichage itinéraire driverOnWay: $e");
    }
  }

  /// Recentre automatiquement la carte sur la position GPS de l'utilisateur
  /// quand il revient à la page d'accueil (setYourDestination)
  void _recenterOnUserLocationWhenBackHome() {
    try {
      myCustomPrintStatement(
          '🎯 Recentrage automatique demandé au retour à l\'accueil');

      // Utiliser le HomeScreen pour le recentrage adaptatif si possible
      final homeScreenState = MyGlobalKeys.homePageKey.currentState;
      if (homeScreenState != null) {
        // Demander au HomeScreen de faire le recentrage adaptatif
        Future.delayed(const Duration(milliseconds: 500), () async {
          try {
            await homeScreenState.recenterMapWithAdaptivePadding();
            myCustomPrintStatement('✅ Recentrage adaptatif effectué');
          } catch (e) {
            myCustomPrintStatement('⚠️ Fallback vers recentrage classique: $e');
            // Fallback vers l'ancienne méthode
            final mapProvider = Provider.of<GoogleMapProvider>(
              MyGlobalKeys.navigatorKey.currentContext!,
              listen: false,
            );
            mapProvider.recenterOnUserLocation(zoom: 15.0);
          }
        });
      } else {
        // Fallback vers recentrage classique
        myCustomPrintStatement(
            '⚠️ HomeScreen non accessible, utilisation du recentrage classique');
        final mapProvider = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false,
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          mapProvider.recenterOnUserLocation(zoom: 15.0);
        });
      }

      myCustomPrintStatement(
          "🎯 Recentrage automatique sur position utilisateur déclenché");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors du recentrage automatique: $e");
    }
  }

  /// Recentre le point bleu utilisateur selon le contexte d'écran actuel
  void _recenterUserLocationForCurrentContext() {
    try {
      // Liste des étapes où il faut ÉVITER de recentrer la carte
      // pour ne pas perturber la saisie d'adresses
      final stepsToAvoidRecentering = {
        CustomTripType.choosePickupDropLocation, // Saisie adresses
        CustomTripType.selectScheduleTime, // Réservation
        CustomTripType.confirmDestination, // Confirmation
      };

      // Si on est dans une étape de saisie, ne pas recentrer
      if (stepsToAvoidRecentering.contains(currentStep)) {
        myCustomPrintStatement(
            "⏸️ Étape de saisie détectée ($currentStep) - pas de recentrage pour ne pas perturber l'utilisateur");
        return;
      }

      final mapProvider = Provider.of<GoogleMapProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false,
      );

      // Seulement recentrer sur le point bleu s'il n'y a pas d'itinéraire
      if (mapProvider.polylineCoordinates.isEmpty) {
        // Pour les étapes de saisie et l'écran d'accueil, utiliser le centrage simple sans compensation
        // pour ne pas déplacer la carte vers le nord
        final inputSteps = {
          CustomTripType.setYourDestination, // Écran d'accueil - pas de compensation
          CustomTripType.choosePickupDropLocation,
          CustomTripType.selectScheduleTime,
          CustomTripType.confirmDestination,
        };

        // Délai pour que le changement d'écran soit bien traité
        Future.delayed(const Duration(milliseconds: 300), () {
          if (inputSteps.contains(currentStep)) {
            myCustomPrintStatement(
                "🎯 Utilisation du centrage simple pour étape de saisie: $currentStep");
            mapProvider.centerOnUserLocationSimple();
          } else {
            myCustomPrintStatement(
                "🎯 Utilisation du centrage avec compensation pour: $currentStep");
            mapProvider.recenterUserLocationForAllContexts();
          }
        });
        myCustomPrintStatement(
            "🎯 Recentrage point bleu programmé pour nouveau contexte: $currentStep");
      } else {
        myCustomPrintStatement(
            "🎯 Itinéraire présent - pas de recentrage sur point bleu");
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur recentrage point bleu contextuel: $e");
    }
  }

  /// Recentre la carte pour que l'itinéraire reste visible quand le bottom sheet change de hauteur
  void _recenterMapIfRouteVisible() {
    try {
      final mapProvider = Provider.of<GoogleMapProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false,
      );

      // Si il y a un itinéraire affiché (polylineCoordinates non vide)
      if (mapProvider.polylineCoordinates.isNotEmpty) {
        // Utiliser le padding dynamique intelligent qui prend en compte le bottom sheet
        recenterMapWithDynamicPadding(mapProvider);
        myCustomPrintStatement(
            "🎯 Recentrage automatique avec padding adaptatif lors du changement d'écran");
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur accès GoogleMapProvider: $e");
    }
  }

  /// Recentre la carte avec un padding dynamique intelligent pour les itinéraires
  void recenterMapWithDynamicPadding(GoogleMapProvider mapProvider) {
    try {
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenSize = MediaQuery.of(context).size;
      final screenHeight = screenSize.height;
      final screenWidth = screenSize.width;

      // Obtenir la hauteur réelle du bottom sheet depuis le HomeScreen
      double currentBottomSheetHeight = _getCurrentBottomSheetHeight();
      final bottomSheetHeightPx = screenHeight * currentBottomSheetHeight;

      // Calculer les bounds de l'itinéraire sans padding initial
      final bounds = GoogleMapProvider.getLatLongBoundsFromLatLngList(
        mapProvider.polylineCoordinates,
        topPaddingPercentage: 0.0,
        bottomPaddingPercentage: 0.0,
      );

      if (bounds != null) {
        // Analyser l'orientation de l'itinéraire
        final routeInfo = _analyzeRouteOrientation(bounds, screenSize);

        // Calculer le padding dynamique basé sur l'orientation et le bottom sheet
        final padding = _calculateDynamicPadding(
          routeInfo: routeInfo,
          screenHeight: screenHeight,
          screenWidth: screenWidth,
          bottomSheetHeightPx: bottomSheetHeightPx,
          context: context,
        );

        // Attendre que le bottom sheet termine son animation et atteigne sa taille finale
        // 800ms permet à la bottom sheet de terminer complètement son animation
        // avant de calculer les bounds et padding de l'itinéraire
        Future.delayed(const Duration(milliseconds: 800), () async {
          try {
            // SOLUTION RADICALE : Utiliser IOSMapFix sur toutes les plateformes
            myCustomPrintStatement(
                "🛡️ SOLUTION RADICALE: Utilisation IOSMapFix pour éviter tous les problèmes de zoom");
            myCustomPrintStatement(
                "📐 Recentrage avec bottomSheetRatio=${(currentBottomSheetHeight * 100).toInt()}% "
                "(${(bottomSheetHeightPx).toInt()}px sur ${screenHeight.toInt()}px) pour étape: $currentStep");
            await IOSMapFix.safeFitBounds(
              controller: mapProvider.controller!,
              points: mapProvider.polylineCoordinates,
              bottomSheetRatio: currentBottomSheetHeight,
              debugSource: "createPath-recentering-${currentStep.toString().split('.').last}",
            ).timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                myCustomPrintStatement('⏰ Timeout recenterMapWithDynamicPadding - continuant sans recentrage');
              },
            );
            myCustomPrintStatement(
                "✅ Carte recentrée - Orientation: ${routeInfo['orientation']}, "
                "Padding: $padding, BottomSheet: ${(bottomSheetHeightPx).toInt()}px");
          } catch (e) {
            myCustomPrintStatement("❌ Erreur animation caméra: $e");
          }
        });
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur recentrage dynamique: $e");
    }
  }

  /// Obtient la hauteur actuelle du bottom sheet depuis le HomeScreen
  double _getCurrentBottomSheetHeight() {
    try {
      // Tenter d'accéder à l'état du HomeScreen pour obtenir la hauteur réelle
      final homeScreenState = MyGlobalKeys.homePageKey.currentState;
      if (homeScreenState != null) {
        // Utiliser reflection ou une méthode publique si disponible
        // Pour l'instant, utiliser une estimation basée sur l'étape actuelle
        return _estimateBottomSheetHeight();
      }
    } catch (e) {
      myCustomPrintStatement(
          "❌ Impossible d'obtenir la hauteur du bottom sheet: $e");
    }
    return 0.4; // Valeur par défaut
  }

  /// Estime la hauteur du bottom sheet basée sur l'étape actuelle
  /// IMPORTANT: Ces valeurs doivent correspondre aux constantes de home_screen.dart
  double _estimateBottomSheetHeight() {
    switch (currentStep) {
      case CustomTripType.setYourDestination:
        return 0.10; // _lowestBottomSheetHeight - Niveau le plus bas
      case CustomTripType.confirmDestination:
        return 0.30; // _minBottomSheetHeight - Niveau bas
      case CustomTripType.chooseVehicle:
      case CustomTripType.requestForRide:
        return 0.55; // _midBottomSheetHeight - Niveau moyen
      case CustomTripType.driverOnWay:
        return 0.78; // _maxBottomSheetHeight - Niveau élevé
      case CustomTripType.payment:
      case CustomTripType.orangeMoneyPayment:
        return 0.78; // _maxBottomSheetHeight - Écrans de paiement
      case CustomTripType.paymentMobileConfirm:
        return 1.0; // Plein écran pour MVola/Airtel
      default:
        return 0.55; // Valeur par défaut (niveau moyen)
    }
  }

  double _getBottomSheetRatioForTracking() {
    // Tenter d'obtenir la hauteur réelle si disponible, sinon estimer.
    double ratio = _getCurrentBottomSheetHeight();

    // Pendant les flux de paiement ou de confirmation, le panneau est plus grand.
    if (currentStep == CustomTripType.paymentMobileConfirm) {
      ratio = 1.0; // Plein écran pour MVola/Airtel
    } else if (currentStep == CustomTripType.payment ||
        currentStep == CustomTripType.orangeMoneyPayment) {
      ratio = math.max(ratio, 0.78); // _maxBottomSheetHeight
    }

    // Ajuster selon l'état de la course si disponibles
    if (booking != null) {
      final status = booking!['status'];
      if (status == BookingStatusType.DRIVER_REACHED.value) {
        ratio = math.max(ratio, 0.75);
      } else if (status == BookingStatusType.RIDE_STARTED.value) {
        ratio = math.max(ratio, 0.65);
      }
    }

    // Limites de sécurité pour éviter valeurs extrêmes
    if (ratio.isNaN || ratio.isInfinite) {
      ratio = 0.5;
    }

    return ratio.clamp(0.2, 0.9);
  }

  /// Analyse l'orientation et les caractéristiques de l'itinéraire
  Map<String, dynamic> _analyzeRouteOrientation(
      LatLngBounds bounds, Size screenSize) {
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = bounds.northeast.longitude - bounds.southwest.longitude;

    // Ratio d'aspect de l'itinéraire
    final routeAspectRatio = latSpan / lngSpan;
    final screenAspectRatio = screenSize.height / screenSize.width;

    String orientation;
    if (routeAspectRatio > 1.5) {
      orientation = "nord_sud"; // Itinéraire principalement vertical
    } else if (routeAspectRatio < 0.67) {
      orientation = "est_ouest"; // Itinéraire principalement horizontal
    } else {
      orientation = "diagonal"; // Itinéraire diagonal/carré
    }

    return {
      'orientation': orientation,
      'latSpan': latSpan,
      'lngSpan': lngSpan,
      'routeAspectRatio': routeAspectRatio,
      'screenAspectRatio': screenAspectRatio,
      'isVertical': routeAspectRatio > 1.2,
      'isHorizontal': routeAspectRatio < 0.8,
    };
  }

  /// Calcule le padding dynamique basé sur l'orientation de l'itinéraire
  double _calculateDynamicPadding({
    required Map<String, dynamic> routeInfo,
    required double screenHeight,
    required double screenWidth,
    required double bottomSheetHeightPx,
    required BuildContext context,
  }) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final orientation = routeInfo['orientation'] as String;
    final isVertical = routeInfo['isVertical'] as bool;
    final routeAspectRatio = routeInfo['routeAspectRatio'] as double;

    // Padding de base
    double topPadding = statusBarHeight + 40; // Barre de statut + marge
    double bottomPadding = bottomSheetHeightPx + 40; // Bottom sheet + marge
    double sidePadding = 40; // Marges latérales

    // Ajustements spécifiques selon l'orientation
    switch (orientation) {
      case "nord_sud":
        // Pour les itinéraires Nord/Sud, augmenter SIGNIFICATIVEMENT le padding vertical
        bottomPadding =
            bottomSheetHeightPx + 100; // Marge beaucoup plus importante en bas
        topPadding += 60; // Marge beaucoup plus importante en haut

        // Si l'itinéraire est TRÈS vertical (ratio > 2.0), augmenter encore plus
        if (routeAspectRatio > 2.0) {
          bottomPadding = bottomSheetHeightPx + 150;
          topPadding += 80;
        }

        // Réduire le padding latéral car l'itinéraire est vertical
        sidePadding = 20;
        break;

      case "est_ouest":
        // Pour les itinéraires Est/Ouest, privilégier le padding latéral
        sidePadding = 80; // Marges latérales plus importantes
        bottomPadding = bottomSheetHeightPx + 40; // Marge standard en bas
        break;

      case "diagonal":
        // Padding équilibré pour les itinéraires diagonaux
        bottomPadding = bottomSheetHeightPx + 60;
        sidePadding = 40;
        break;
    }

    // Pour les itinéraires très verticaux, s'assurer qu'ils ne passent pas derrière le bottom sheet
    if (isVertical) {
      // Calculer l'espace disponible au-dessus du bottom sheet
      final availableHeight =
          screenHeight - bottomSheetHeightPx - statusBarHeight;

      // Si l'espace est restreint, augmenter ENCORE PLUS le padding
      if (availableHeight < screenHeight * 0.5) {
        bottomPadding = bottomSheetHeightPx + 120;
        topPadding += 40;
      }

      // Protection additionnelle pour les écrans très petits ou bottom sheet très grand
      if (bottomSheetHeightPx > screenHeight * 0.7) {
        bottomPadding = bottomSheetHeightPx + 160;
        topPadding += 60;
      }
    }

    // Retourner le padding le plus important (CameraUpdate.newLatLngBounds utilise un seul padding)
    final maxPadding = [topPadding, bottomPadding, sidePadding]
        .reduce((a, b) => a > b ? a : b);

    myCustomPrintStatement("📏 Padding calculé - Orientation: $orientation, "
        "AspectRatio: ${routeAspectRatio.toStringAsFixed(2)}, "
        "Top: ${topPadding.toInt()}, Bottom: ${bottomPadding.toInt()}, "
        "Side: ${sidePadding.toInt()}, Max: ${maxPadding.toInt()}");

    return maxPadding;
  }

  final ValueNotifier<int> selectPayMethod = ValueNotifier(-1);
  bool bookingsLoading = false;
  bool currentBookingLoading = false;
  List myPastBookings = [];
  List myCancelledBookings = [];
  List myCurrentBookings = [];
  List scheduledBookingsList = [];

  getMyBookingList() async {
    // Guard contre userData null
    if (userData.value == null) {
      myCustomPrintStatement('⚠️ getMyBookingList: userData null, skip');
      return;
    }

    bookingsLoading = true;
    notifyListeners();

    // Récupérer les courses terminées
    var res = await FirestoreServices.bookingHistory
        .where('requestBy', isEqualTo: userData.value!.id)
        .orderBy('endTime', descending: true)
        .get();

    myPastBookings = List.generate(
        res.docs.length, (index) => (res.docs[index].data() as Map)).toList();

    // Récupérer les courses annulées
    await getMyCancelledBookings();

    bookingsLoading = false;
    notifyListeners();
  }

  /// Récupère les courses annulées de l'utilisateur
  Future<void> getMyCancelledBookings() async {
    // Guard contre userData null
    if (userData.value == null) {
      myCustomPrintStatement('⚠️ getMyCancelledBookings: userData null, skip');
      return;
    }

    try {
      var res = await FirestoreServices.cancelledBooking
          .where('requestBy', isEqualTo: userData.value!.id)
          .orderBy('cancelledAt', descending: true)
          .get();

      myCancelledBookings = List.generate(
          res.docs.length, (index) => (res.docs[index].data() as Map))
          .where(_isValidBooking)
          .toList();

      myCustomPrintStatement('📋 Courses annulées récupérées: ${myCancelledBookings.length}');
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur récupération courses annulées: $e');
      // Si l'index n'existe pas, essayer sans orderBy
      try {
        var res = await FirestoreServices.cancelledBooking
            .where('requestBy', isEqualTo: userData.value!.id)
            .get();

        myCancelledBookings = List.generate(
            res.docs.length, (index) => (res.docs[index].data() as Map))
            .where(_isValidBooking)
            .toList();

        myCustomPrintStatement('📋 Courses annulées récupérées (sans tri): ${myCancelledBookings.length}');
      } catch (e2) {
        myCustomPrintStatement('❌ Erreur récupération courses annulées: $e2');
        myCancelledBookings = [];
      }
    }
  }

  /// Vérifie si une course a les données essentielles pour être affichée
  bool _isValidBooking(Map booking) {
    // Vérifier que les champs essentiels existent et ne sont pas null/vides
    final pickAddress = booking['pickAddress'];
    final requestBy = booking['requestBy'];

    // La course doit avoir au minimum une adresse de prise en charge
    if (pickAddress == null || pickAddress.toString().isEmpty || pickAddress == 'N/A') {
      myCustomPrintStatement('⚠️ Course ignorée (pickAddress invalide): ${booking['id']}');
      return false;
    }

    // La course doit avoir un demandeur
    if (requestBy == null || requestBy.toString().isEmpty) {
      myCustomPrintStatement('⚠️ Course ignorée (requestBy invalide): ${booking['id']}');
      return false;
    }

    return true;
  }

  getMyCurrentList() async {
    // Guard contre userData null
    if (userData.value == null) {
      myCustomPrintStatement('⚠️ getMyCurrentList: userData null, skip');
      return;
    }

    currentBookingLoading = true;
    notifyListeners();
    var res = await FirestoreServices.bookingRequest
        .where('requestBy', isEqualTo: userData.value!.id)
        .orderBy('scheduleTime', descending: false)
        .get();

    myCurrentBookings = List.generate(
        res.docs.length, (index) => (res.docs[index].data() as Map)).toList();

    // Check for active scheduled bookings that should be in driverOnWay state
    for (var bookingData in myCurrentBookings) {
      if (bookingData['isSchedule'] == true &&
          bookingData['startRide'] == true &&
          bookingData['acceptedBy'] != null &&
          booking == null) {
        myCustomPrintStatement(
            '🚗 Found active scheduled booking: ${bookingData['id']}');
        booking = bookingData;
        _safeSetDriverOnWay(source: 'myCurrentBookings-activeScheduled');
        await setBookingStream(); // Start listening for updates
        break;
      }
    }

    currentBookingLoading = false;
    notifyListeners();
  }

  locationChange() async {
    myCustomPrintStatement('locationChange---------------check---------------');

    var mapProvider = Provider.of<GoogleMapProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false);
    mapProvider.setPosition(
        currentPosition!.latitude, currentPosition!.longitude);

    // Mettre à jour la position du driver en temps réel pendant la course
    if (booking != null &&
        acceptedDriver != null &&
        booking!['status'] >= BookingStatusType.ACCEPTED.value &&
        booking!['status'] < BookingStatusType.RIDE_COMPLETE.value) {
      updateDriverLocationOnMap();
    }
    // if (mapProvider.initialPosition != null) {
    //   mapProvider.createUpdateMarker('',
    //       LatLng(currentPosition!.latitude, currentPosition!.longitude),
    //       rotate: true, animateToCenter: booking != null ? false : true);
    // }

    // Ne mettre à jour Firestore que si l'utilisateur est connecté (pas en mode invité)
    if (userData.value != null && userData.value!.id != null) {
      await FirestoreServices.users.doc(userData.value!.id).update({
        'currentLat': currentPosition!.latitude,
        'currentLng': currentPosition!.longitude,
      });
    }
  }

  /// Applique le zoom adaptatif quand la course est en cours
  /// Force le centrage pour afficher driver + polyline + destination dans les 50% supérieurs
  Future<void> _applyAdaptiveZoomForRideInProgress() async {
    try {
      if (acceptedDriver?.currentLat == null ||
          acceptedDriver?.currentLng == null ||
          dropLocation == null ||
          booking == null) {
        return;
      }

      final context = MyGlobalKeys.navigatorKey.currentContext;
      if (context == null) return;

      final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);

      final driverPoint =
          LatLng(acceptedDriver!.currentLat!, acceptedDriver!.currentLng!);
      final destinationPoint =
          LatLng(dropLocation!['lat'], dropLocation!['lng']);

      // Collecter tous les points à afficher: driver, destination, et toute la polyline
      final points = <LatLng>[driverPoint, destinationPoint];
      if (mapProvider.polylineCoordinates.isNotEmpty) {
        // Ajouter tous les points de la polyline pour s'assurer qu'elle soit entièrement visible
        points.addAll(mapProvider.polylineCoordinates);
      }

      // Bottom sheet pendant RIDE_STARTED = environ 55% de l'écran
      // On veut afficher dans les 45-50% supérieurs
      const double bottomSheetRatio = 0.55;

      myCustomPrintStatement(
          '🎯 Centrage course en cours: ${points.length} points, bottomSheetRatio=$bottomSheetRatio');

      // Forcer le centrage avec IOSMapFix pour prendre en compte le bottom sheet
      try {
        await IOSMapFix.safeFitBounds(
          controller: mapProvider.controller!,
          points: points,
          bottomSheetRatio: bottomSheetRatio,
          debugSource: 'rideInProgress-initialFit',
        );
        myCustomPrintStatement(
            '✅ Centrage initial course en cours réussi');
      } catch (e) {
        myCustomPrintStatement(
            '⚠️ IOSMapFix.safeFitBounds échoué, fallback: $e');
        // Fallback: centrer sur le milieu entre driver et destination
        final centerLat = (driverPoint.latitude + destinationPoint.latitude) / 2;
        final centerLng = (driverPoint.longitude + destinationPoint.longitude) / 2;
        final distance = getDistance(
          driverPoint.latitude,
          driverPoint.longitude,
          destinationPoint.latitude,
          destinationPoint.longitude,
        );
        final zoom = _calculateZoomForDistance(distance);
        await mapProvider.animateToNewTarget(
          centerLat,
          centerLng,
          zoom: zoom,
        );
      }
    } catch (e) {
      myCustomPrintStatement(
          '❌ Erreur lors de l\'application du zoom adaptatif: $e');
    }
  }

  createPath({
    double topPaddingPercentage = 0.01,
  }) async {
    var mapProvider = Provider.of<GoogleMapProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false);

    // 🚗 driverOnWay: Nettoyer les éléments visuels de l'étape précédente
    // Supprimer le marker drop et l'animation polyline pour n'afficher que driver→pickup
    if (booking != null &&
        booking!['status'] >= BookingStatusType.ACCEPTED.value &&
        booking!['status'] < BookingStatusType.RIDE_STARTED.value) {
      // Supprimer le marker de destination (drop) - on ne l'affiche qu'après RIDE_STARTED
      mapProvider.markers.remove('drop');
      // Arrêter toute animation de route en cours et nettoyer l'animated_path
      mapProvider.stopRouteAnimation();
      myCustomPrintStatement(
          '🧹 driverOnWay: drop marker et animated_path supprimés');
    }

    // S'assurer qu'il y ait toujours assez de padding pour déclencher l'animation de dézoom
    topPaddingPercentage = booking?['status'] ==
            BookingStatusType.PENDING_REQUEST.value
        ? 0.5 // Padding élevé pour demande en attente
        : 0.1; // Padding minimum pour garantir l'animation dans tous les autres cas
    // myCustomPrintStatement("$booking -- --- --- --- -- --  create path -- -- -- ");
    if (pickLocation != null) {
      booking == null ||
              booking!['status'] <= BookingStatusType.DRIVER_REACHED.value
          ? mapProvider.createUpdateMarker(
              'pickup', LatLng(pickLocation!['lat'], pickLocation!['lng']),
              url: MyImagesUrl.picupLocationIcon,
              isAsset: true,
              animateToCenter: false,
              address: "Pickup Location: ${dropLocation!['address']}")
          : mapProvider.createUpdateMarker(
              'pickup',
              LatLng(pickLocation!['lat'], pickLocation!['lng']),
              url: MyImagesUrl.pickupCircleIconTheme(),
              isAsset: true,
              animateToCenter: false,
            );
    }

    if (dropLocation != null &&
        (booking == null ||
            booking!['status'] >= BookingStatusType.RIDE_STARTED.value)) {
      mapProvider.createUpdateMarker(
          'drop', LatLng(dropLocation!['lat'], dropLocation!['lng']),
          url: MyImagesUrl.dropLocationCircleIconTheme(),
          animateToCenter: false,
          isAsset: true,
          address: "Drop Location: ${dropLocation!['address']}");
    }
    if (pickLocation != null &&
        dropLocation != null &&
        (booking == null ||
            booking!['status'] == BookingStatusType.PENDING_REQUEST.value)) {
      // 📍 Demande en attente : tracer pickup → drop
      await mapProvider.getPolilyine(
        pickLocation!['lat'],
        pickLocation!['lng'],
        dropLocation!['lat'],
        dropLocation!['lng'],
        topPaddingPercentage: topPaddingPercentage,
      );
    } else if (pickLocation != null &&
        booking != null &&
        booking!['status'] >= BookingStatusType.ACCEPTED.value &&
        booking!['status'] < BookingStatusType.RIDE_STARTED.value &&
        acceptedDriver != null &&
        acceptedDriver!.currentLat != null &&
        acceptedDriver!.currentLng != null) {
      // 🚗 Chauffeur en route vers le pickup (driverOnWay) : tracer driver → pickup
      myCustomPrintStatement(
          '🚗 createPath: driverOnWay - traçage driver → pickup');
      await mapProvider.getPolilyine(
        acceptedDriver!.currentLat!,
        acceptedDriver!.currentLng!,
        pickLocation!['lat'],
        pickLocation!['lng'],
        topPaddingPercentage: topPaddingPercentage,
      );

      // Centrer sur l'itinéraire driver→pickup
      await _fitDriverRouteAboveBottomSheet();
    } else if (pickLocation != null &&
        dropLocation != null &&
        booking != null &&
        booking!['status'] >= BookingStatusType.RIDE_STARTED.value) {
      // 🏁 Course en cours : tracer du chauffeur vers la destination
      if (acceptedDriver != null &&
          acceptedDriver!.currentLat != null &&
          acceptedDriver!.currentLng != null) {
        // 🚗 Ajouter/mettre à jour le marker du driver
        await addDriverVehicleMarker();

        // Tracer depuis la position actuelle du chauffeur vers la destination
        await mapProvider.getPolilyine(
          acceptedDriver!.currentLat!,
          acceptedDriver!.currentLng!,
          dropLocation!['lat'],
          dropLocation!['lng'],
          topPaddingPercentage: topPaddingPercentage, // Animation garantie
        );

        // Appliquer le zoom adaptatif pour afficher chauffeur et destination
        await _applyAdaptiveZoomForRideInProgress();
      } else {
        // Fallback : tracer pickup vers drop si pas de position chauffeur
        await mapProvider.getPolilyine(
          pickLocation!['lat'],
          pickLocation!['lng'],
          dropLocation!['lat'],
          dropLocation!['lng'],
          topPaddingPercentage: topPaddingPercentage, // Animation garantie
        );
      }
    } else if (acceptedDriver != null) {
      // Fallback si conditions ci-dessus non remplies
      if (acceptedDriver!.currentLat != null &&
          acceptedDriver!.currentLng != null &&
          pickLocation != null) {
        await mapProvider.getPolilyine(
          acceptedDriver!.currentLat!,
          acceptedDriver!.currentLng!,
          pickLocation!['lat'],
          pickLocation!['lng'],
          topPaddingPercentage: topPaddingPercentage, // Animation garantie
        );
      }
    } else {
      // Si acceptedDriver est null, tracer juste entre pickup et drop
      myCustomPrintStatement(
          '⚠️ createPath: acceptedDriver is null, using pickup to drop route');
      await mapProvider.getPolilyine(
        pickLocation!['lat'],
        pickLocation!['lng'],
        dropLocation!['lat'],
        dropLocation!['lng'],
        topPaddingPercentage: topPaddingPercentage,
      );
    }

    mapProvider.coveredPolylineCoordinates = [];

    if (booking != null) {
      if (booking!['coveredPath'].isNotEmpty) {
        for (int i = 0; i < booking!['coveredPath'].length; i++) {
          mapProvider.coveredPolylineCoordinates.add(LatLng(
              booking!['coveredPath'][i]['lat'],
              booking!['coveredPath'][i]['lng']));
        }
        mapProvider.visibleCoveredPolyline = true;
      }
    }

    // Afficher le chemin parcouru en rose
    await mapProvider.updatePolyline(polylineName: "coveredPath");
    if (mapProvider.coveredPolylineCoordinates.isNotEmpty) {
      mapProvider.addPolyline(
        Polyline(
          polylineId: const PolylineId('coveredPath'),
          color: Colors.pink, // Rose pour le chemin parcouru
          width: 6,
          geodesic: true,
          visible: true,
          points: mapProvider.coveredPolylineCoordinates,
        ),
      );
    }

    // Ajouter le marqueur du véhicule du driver si disponible
    if (acceptedDriver != null) {
      await addDriverVehicleMarker();
    }
    mapProvider.notifyListeners();

    final bool isDriverOnWay = booking != null &&
        booking!['status'] != null &&
        booking!['status'] >= BookingStatusType.ACCEPTED.value &&
        booking!['status'] <= BookingStatusType.DRIVER_REACHED.value;

    if (isDriverOnWay) {
      Future.microtask(() => _fitDriverRouteAboveBottomSheet());
    } else {
      // Appliquer le recentrage intelligent pour les autres cas (ex: course en cours)
      _recenterMapIfRouteVisible();
    }

    // MapServices.visiblePolyline = true;
    // updateBottomPortion.value++;
  }

  /// Calcule le prix d'une course selon le système configuré (V1 ou V2)
  calculatePrice(VehicleModal selectedVehicleData) {
    // Vérifier si le nouveau système V2 est activé et disponible
    if (pricingConfigV2 != null && pricingConfigV2!.enableNewPricingSystem) {
      myCustomPrintStatement('TripProvider: Calcul avec système V2 activé');
      return calculatePriceV2Sync(selectedVehicleData);
    } else {
      myCustomPrintStatement('TripProvider: Calcul avec système V1 legacy');
      return calculatePriceLegacy(selectedVehicleData);
    }
  }

  /// Calcule le prix après application d'un coupon promotionnel
  calculatePriceAfterCouponApply() {
    var totalPrice = calculatePrice(selectedVehicle!);
    var discount = totalPrice * (selectedPromoCode?.discountPercent ?? 0) / 100;

    return totalPrice -
        (discount < selectedPromoCode!.maxRideAmount
            ? discount
            : selectedPromoCode!.maxRideAmount);
  }

  /// Calcule la réduction basée sur le mode de paiement sélectionné
  void calculatePaymentMethodDiscount(PaymentMethodType? paymentMethod) {
    try {
      AdminSettingsProvider? adminProvider = Provider.of<AdminSettingsProvider>(
          MyGlobalKeys.homePageKey.currentContext!,
          listen: false);

      paymentMethodDiscountAmount = 0;
      paymentMethodDiscountPercentage = 0;

      if (paymentMethod != null && adminProvider.isPaymentPromoActive()) {
        paymentMethodDiscountPercentage =
            adminProvider.getPaymentPromoDiscount(paymentMethod);

        if (paymentMethodDiscountPercentage > 0) {
          double basePrice = calculatePrice(selectedVehicle!);

          // Appliquer d'abord le code promo si présent
          if (selectedPromoCode != null) {
            basePrice = calculatePriceAfterCouponApply();
          }

          paymentMethodDiscountAmount =
              (basePrice * paymentMethodDiscountPercentage / 100);
          myCustomPrintStatement(
              'Payment method discount calculated: $paymentMethodDiscountAmount (${paymentMethodDiscountPercentage}%) for ${paymentMethod.value}');
        }
      }

      notifyListeners();
    } catch (e) {
      myCustomPrintStatement('Error calculating payment method discount: $e');
      paymentMethodDiscountAmount = 0;
      paymentMethodDiscountPercentage = 0;
    }
  }

  /// Obtient le prix final après application de toutes les promotions
  double getPriceAfterPaymentPromo(double basePrice) {
    return basePrice - paymentMethodDiscountAmount;
  }

  /// Mappe l'ID du véhicule vers la catégorie du nouveau système de tarification
  ///
  /// Cette méthode convertit les IDs de véhicules de l'ancien système vers
  /// les catégories standardisées du nouveau système V2.
  String _mapVehicleIdToCategory(VehicleModal vehicle) {
    // Mapping des IDs connus vers les catégories V2
    const Map<String, String> idToCategoryMap = {
      "02b2988097254a04859a":
          "classic", // ID spécial hardcodé pour taxis (pas taxi-moto!)
    };

    // Vérifier d'abord par ID exact
    if (idToCategoryMap.containsKey(vehicle.id)) {
      return idToCategoryMap[vehicle.id]!;
    }

    // Fallback sur le nom du véhicule (méthode robuste)
    final vehicleName = vehicle.name.toLowerCase();

    if (vehicleName.contains('bajaj') || vehicleName.contains('tuk')) {
      return 'bajaj';
    } else if (vehicleName.contains('taxi') || vehicleName.contains('moto')) {
      return 'taxi_moto';
    } else if (vehicleName.contains('classic') ||
        vehicleName.contains('standard') ||
        vehicleName.contains('misy classic')) {
      return 'classic';
    } else if (vehicleName.contains('confort') ||
        vehicleName.contains('comfort')) {
      return 'confort';
    } else if (vehicleName.contains('4x4') || vehicleName.contains('suv')) {
      return '4x4';
    } else if (vehicleName.contains('van') || vehicleName.contains('minibus')) {
      return 'van';
    } else if (vehicleName.contains('colis') || vehicleName.contains('delivery')) {
      return 'colis';
    }

    // Fallback final : utiliser 'classic' par défaut
    myCustomPrintStatement(
      'TripProvider: Catégorie de véhicule inconnue pour ID ${vehicle.id} / nom "${vehicle.name}", utilisation de "classic" par défaut',
      showPrint: true,
    );
    return 'classic';
  }

  /// Indique si la course en cours touche un aéroport (pickup ou drop).
  /// Utilisé pour appliquer le supplément aéroport configurable
  /// (`globalSettings.airportSurcharge`) dans le calcul du prix.
  bool get _isAirportRide =>
      (pickLocation?['isAirport'] == true) ||
      (dropLocation?['isAirport'] == true);

  /// Supplément aéroport applicable à la course en cours (0 si pas concernée).
  double get _airportSurchargeForCurrentTrip =>
      _isAirportRide ? globalSettings.airportSurcharge : 0;

  /// Calcule le prix pour l'affichage UI (méthode helper)
  ///
  /// Cette méthode permet de calculer le prix de n'importe quel véhicule
  /// sans avoir à le sélectionner d'abord. Utilisée pour l'affichage des prix
  /// dans choose_vehicle_sheet.
  double calculatePriceForVehicle(VehicleModal vehicle,
      {bool withReservation = false}) {
    // Sauvegarder le véhicule actuellement sélectionné
    final previousVehicle = selectedVehicle;
    final previousScheduleTime = rideScheduledTime;

    // Temporairement définir le véhicule pour le calcul
    selectedVehicle = vehicle;
    if (withReservation) {
      rideScheduledTime =
          DateTime.now().add(Duration(hours: 1)); // Simulation réservation
    }

    // Calculer le prix de base
    final price = calculatePrice(vehicle);

    // Restaurer les valeurs précédentes
    selectedVehicle = previousVehicle;
    rideScheduledTime = previousScheduleTime;

    // 🛫 Ajouter le supplément aéroport si applicable (pickup ou drop = aéroport)
    return price + _airportSurchargeForCurrentTrip;
  }

  /// Calcule le prix avec le nouveau système de tarification V2 (synchrone)
  /// Intègre les multiplicateurs de zones géographiques si disponibles
  double calculatePriceV2Sync(VehicleModal selectedVehicleData) {
    try {
      final config = pricingConfigV2!;
      final vehicleCategory = _mapVehicleIdToCategory(selectedVehicleData);
      final distance = totalWilltake.value.distance; // en km
      final requestTime = DateTime.now();
      final isScheduled = rideScheduledTime != null;

      myCustomPrintStatement(
          'TripProvider: Calcul V2 sync - $vehicleCategory, ${distance}km, programmé: $isScheduled');

      // Récupérer la zone courante depuis le service statique (synchronisée par GeoZoneProvider)
      final currentZone = GeoZoneService.currentZone;

      // DEBUG: Log détaillé de la zone
      myCustomPrintStatement('🗺️ === DEBUG ZONE PRICING ===');
      myCustomPrintStatement('   currentZone: ${currentZone?.name ?? "NULL"}');
      myCustomPrintStatement('   zonePricing: ${currentZone?.pricing != null ? "OK" : "NULL"}');
      if (currentZone?.pricing != null) {
        final p = currentZone!.pricing!;
        myCustomPrintStatement('   → basePriceMultiplier: ${p.basePriceMultiplier}');
        myCustomPrintStatement('   → perKmMultiplier: ${p.perKmMultiplier}');
        myCustomPrintStatement('   → trafficMultiplier: ${p.trafficMultiplier}');
        myCustomPrintStatement('   → vehicleOverrides keys: ${p.vehicleOverrides?.keys.toList()}');
      }
      myCustomPrintStatement('   vehicleCategory: $vehicleCategory');
      myCustomPrintStatement('   vehicleId: ${selectedVehicleData.id}');
      myCustomPrintStatement('🗺️ ===========================');

      // Vérifier si on a un pricing de zone avec override pour cette catégorie
      final zonePricing = currentZone?.pricing;

      // Chercher l'override par nom standardisé OU par ID de document Firestore
      VehiclePricingOverride? vehicleOverride;
      if (zonePricing?.vehicleOverrides != null) {
        // D'abord chercher par nom standardisé (ex: "classic", "confort")
        vehicleOverride = zonePricing!.vehicleOverrides![vehicleCategory];

        // Si pas trouvé, chercher par ID de document Firestore
        if (vehicleOverride == null) {
          vehicleOverride = zonePricing.vehicleOverrides![selectedVehicleData.id];
          if (vehicleOverride != null) {
            myCustomPrintStatement('🗺️ Override trouvé par ID Firestore: ${selectedVehicleData.id}');
          }
        }
      }

      // 1. Prix de base selon la distance (avec multiplicateurs de zone)
      double basePrice;
      double effectiveFloorPrice = config.getFloorPrice(vehicleCategory);
      double effectivePricePerKm = config.getPricePerKm(vehicleCategory);

      // Appliquer les overrides de zone si disponibles
      if (vehicleOverride != null) {
        myCustomPrintStatement('🗺️ Zone override trouvé pour $vehicleCategory');
        myCustomPrintStatement('   🔧 override.basePrice: ${vehicleOverride.basePrice}');
        myCustomPrintStatement('   🔧 override.perKmCharge: ${vehicleOverride.perKmCharge}');
        if (vehicleOverride.basePrice != null) {
          effectiveFloorPrice = vehicleOverride.basePrice!;
          myCustomPrintStatement('   ✅ Appliqué basePrice: $effectiveFloorPrice');
        } else if (vehicleOverride.basePriceMultiplier != null) {
          effectiveFloorPrice *= vehicleOverride.basePriceMultiplier!;
        }
        if (vehicleOverride.perKmCharge != null) {
          effectivePricePerKm = vehicleOverride.perKmCharge!;
          myCustomPrintStatement('   ✅ Appliqué perKmCharge: $effectivePricePerKm');
        } else if (vehicleOverride.perKmMultiplier != null) {
          effectivePricePerKm *= vehicleOverride.perKmMultiplier!;
        }
        myCustomPrintStatement('   📊 Prix finaux: floor=$effectiveFloorPrice, perKm=$effectivePricePerKm');
      } else if (zonePricing != null) {
        // Appliquer les multiplicateurs globaux de zone
        if (zonePricing.basePriceMultiplier != null && zonePricing.basePriceMultiplier != 1.0) {
          effectiveFloorPrice *= zonePricing.basePriceMultiplier!;
          myCustomPrintStatement('🗺️ Zone basePriceMultiplier: x${zonePricing.basePriceMultiplier}');
        }
        if (zonePricing.perKmMultiplier != null && zonePricing.perKmMultiplier != 1.0) {
          effectivePricePerKm *= zonePricing.perKmMultiplier!;
          myCustomPrintStatement('🗺️ Zone perKmMultiplier: x${zonePricing.perKmMultiplier}');
        }
      }

      if (distance <= config.floorPriceThreshold) {
        // Prix plancher pour courtes distances
        basePrice = effectiveFloorPrice;
      } else {
        // Prix au kilomètre + prix de base
        // Note: si perKmCharge = 0 (prix fixe), on garde le prix de base
        basePrice = effectiveFloorPrice + (effectivePricePerKm * distance);
      }

      // 2. Majoration pour courses longues
      if (distance > config.longTripThreshold) {
        final extraDistance = distance - config.longTripThreshold;
        final extraCost = effectivePricePerKm *
            extraDistance *
            (config.longTripMultiplier - 1.0);
        basePrice += extraCost;
      }

      // 3. Majoration embouteillages - Zone configurée = pas de surge global
      // Si une zone est configurée, elle gère son propre surge (ou pas)
      if (zonePricing != null) {
        // Zone configurée : utiliser le multiplicateur de zone (même si 1.0 = pas de surge)
        final zoneTrafficMultiplier = zonePricing.getCurrentTrafficMultiplier(atTime: requestTime);
        if (zoneTrafficMultiplier != 1.0) {
          basePrice *= zoneTrafficMultiplier;
          myCustomPrintStatement('🚦 Zone traffic multiplier: x$zoneTrafficMultiplier');
        } else {
          myCustomPrintStatement('🚦 Zone configurée sans surge (multiplicateur = 1.0)');
        }
      } else {
        // Pas de zone : utiliser le surge global si applicable
        if (config.isTrafficTime(requestTime)) {
          basePrice *= config.trafficMultiplier;
          myCustomPrintStatement('🚦 Global traffic multiplier: x${config.trafficMultiplier}');
        }
      }

      // 4. Surcoût de réservation
      if (isScheduled) {
        basePrice += config.getReservationSurcharge(vehicleCategory);
      }

      // 5. Vérifier le minimum de zone si défini
      if (zonePricing?.minimumFare != null && basePrice < zonePricing!.minimumFare!) {
        myCustomPrintStatement('🗺️ Prix minimum de zone appliqué: ${zonePricing.minimumFare}');
        basePrice = zonePricing.minimumFare!;
      }

      // 6. Arrondi
      if (config.enableRounding) {
        basePrice = (basePrice / config.roundingStep).round() *
            config.roundingStep.toDouble();
      }

      myCustomPrintStatement(
          'TripProvider: Prix calculé V2: ${basePrice.toStringAsFixed(0)} MGA');

      return basePrice;
    } catch (e) {
      myCustomPrintStatement(
        'TripProvider: Erreur calcul V2 sync - $e, fallback vers legacy',
        showPrint: true,
      );
      return calculatePriceLegacy(selectedVehicleData);
    }
  }

  /// Méthode de calcul legacy (ancienne formule) pour fallback d'urgence
  ///
  /// Cette méthode preserve exactement l'ancienne logique de calcul
  /// en cas d'échec complet du nouveau système.
  double calculatePriceLegacy(VehicleModal selectedVehicleData) {
    return ((((selectedVehicleData.price * totalWilltake.value.distance) +
                        selectedVehicleData.basePrice +
                        (totalWilltake.value.time *
                            selectedVehicleData.perMinCharge)) -
                    ((selectedVehicleData.price *
                                totalWilltake.value.distance) +
                            selectedVehicleData.basePrice +
                            (totalWilltake.value.time *
                                selectedVehicleData.perMinCharge)) *
                        (selectedVehicleData.discount / 100)) -
                ((selectedVehicleData.id == "02b2988097254a04859a" &&
                        (userData.value?.extraDiscount ?? 0) > 0 &&
                        globalSettings.enableTaxiExtraDiscount)
                    ? (userData.value?.extraDiscount ?? 0)
                    : 0))
            .isNegative
        ? 0
        : ((((selectedVehicleData.price * totalWilltake.value.distance) +
                        selectedVehicleData.basePrice +
                        (totalWilltake.value.time *
                            selectedVehicleData.perMinCharge)) -
                    ((selectedVehicleData.price *
                                totalWilltake.value.distance) +
                            selectedVehicleData.basePrice +
                            (totalWilltake.value.time *
                                selectedVehicleData.perMinCharge)) *
                        (selectedVehicleData.discount / 100)) -
                ((selectedVehicleData.id == "02b2988097254a04859a" &&
                        (userData.value?.extraDiscount ?? 0) > 0 &&
                        globalSettings.enableTaxiExtraDiscount)
                    ? (userData.value?.extraDiscount ?? 0)
                    : 0)) +
            (rideScheduledTime == null
                ? 0
                : globalSettings.scheduleRideServiceFee);
  }

  String generateOtp() {
    var rnd = Random();
    var next = rnd.nextDouble() * 10000;
    while (next < 1000) {
      next *= 10;
    }
    return next.toInt().toString();
  }

  // Lock provider-level : empêche deux createRequest() concurrents.
  // Contrairement au lock widget (_isCreatingBooking dans confirm_destination.dart),
  // celui-ci persiste même si le widget est rebuild/recréé.
  bool _isCreatingRequest = false;

  Future<bool> createRequest(
      {required VehicleModal vehicleDetails,
      required String paymentMethod,
      required pickupLocation,
      required dropLocation,
      required bool isScheduled,
      PromoCodeModal? promocodeDetails,
      DateTime? scheduleTime,
      String bookingId = ""}) async {
    // 🔒 Lock provider-level : empêcher les appels concurrents
    if (_isCreatingRequest) {
      myCustomPrintStatement(
          '🛑 createRequest BLOQUÉ — déjà en cours (provider lock)');
      return false;
    }
    _isCreatingRequest = true;

    try {
      // Guard: utilisateur non connecté → bloquer la création
      if (userData.value == null || userData.value!.id == null) {
        myCustomPrintStatement(
            '🛑 createRequest: userData est null - utilisateur non connecté');
        return false;
      }

      var res = await FirestoreServices.bookingRequest
          .where('requestBy', isEqualTo: userData.value!.id)
          .get();

    if (res.docs.isEmpty) {
      myCustomPrintStatement(
          "booking is empty schedule time ---:--- $scheduleTime");
      myCustomPrintStatement(
          '[DEBUG NETWORK FAIL] createBooking() called - Case 1: Empty booking list, bookingId=$bookingId');
      await createBooking(vehicleDetails, paymentMethod, pickupLocation, dropLocation,
          isScheduled: isScheduled,
          scheduleTime: scheduleTime,
          bookingId: bookingId,
          promocodeDetails: promocodeDetails);
      return true; // ✅ Création réussie
    } else {
      myCustomPrintStatement("-----mizan user have already booking");
      // if user have current booking so he cant reach to this process-----
      // if user have schedule bookings so he can create request for schedule booking && current booking---

      if (scheduleTime != null) {
        //requesting for schedule booking
        myCustomPrintStatement("-----mizan requesting for schedule booking");
        bool canCreateRide = true;

        for (int i = 0; i < res.docs.length; i++) {
          Map check = res.docs[i].data() as Map;
          if (check['isSchedule'] == true) {
            // ignore: non_constant_identifier_names
            DateTime scheduleTime_a =
                (check['scheduleTime'] as Timestamp).toDate();
            DateTime currentTime = scheduleTime;
            // 🔧 FIX: Utiliser la différence ABSOLUE en minutes pour comparer correctement
            // Cela prend en compte les jours, heures ET minutes
            int differenceInMinutes = scheduleTime_a.difference(currentTime).inMinutes.abs();

            myCustomPrintStatement(
                "🔍 Vérification conflit horaire:");
            myCustomPrintStatement(
                "   Course existante: ${scheduleTime_a.toString()}");
            myCustomPrintStatement(
                "   Nouvelle course: ${currentTime.toString()}");
            myCustomPrintStatement(
                "   Différence: $differenceInMinutes minutes (${(differenceInMinutes / 60).toStringAsFixed(1)}h)");

            // Conflit seulement si moins de 30 minutes d'écart (dans les deux sens)
            if (differenceInMinutes <= 30) {
              myCustomPrintStatement(
                "   ❌ CONFLIT DÉTECTÉ: Les courses sont trop proches (< 30min)");
              canCreateRide = false;
              break; // Sortir de la boucle dès qu'un conflit est trouvé
            } else {
              myCustomPrintStatement(
                "   ✅ PAS DE CONFLIT: Les courses sont suffisamment espacées");
            }
          }
        }
        if (canCreateRide == false) {
          showSnackbar(translate("youalreadyhaveschedulebooking"));
          // 🔧 FIX: Revenir à l'écran de sélection d'horaire pour que l'utilisateur puisse choisir un autre créneau
          myCustomPrintStatement("⚠️ Création de course planifiée bloquée: conflit horaire détecté - retour à selectScheduleTime");
          setScreen(CustomTripType.selectScheduleTime);
          return false; // ❌ Création échouée à cause du conflit
        } else {
          myCustomPrintStatement(
              '[DEBUG NETWORK FAIL] createBooking() called - Case 2: Can create ride, bookingId=$bookingId');
          await createBooking(
              vehicleDetails, paymentMethod, pickupLocation, dropLocation,
              isScheduled: isScheduled,
              scheduleTime: scheduleTime,
              bookingId: bookingId,
              promocodeDetails: promocodeDetails);
          return true; // ✅ Création réussie
          //create ride
        }
      } else {
        //requesting for current booking
        myCustomPrintStatement("-----mizan requesting for current booking");
        bool canCreateRide = true;

        for (int i = 0; i < res.docs.length; i++) {
          Map check = res.docs[i].data() as Map;
          if (check['isSchedule'] == true) {
            DateTime scheduleTime =
                (check['scheduleTime'] as Timestamp).toDate();
            DateTime currentTime = DateTime.now();
            // 🔧 FIX: Pour une course immédiate, vérifier seulement si la course planifiée
            // est dans les 30 prochaines minutes (pas besoin de abs() ici car on regarde vers le futur)
            int differenceInMinutes = scheduleTime.difference(currentTime).inMinutes;

            myCustomPrintStatement(
                "🔍 Vérification course immédiate vs planifiée:");
            myCustomPrintStatement(
                "   Course planifiée: ${scheduleTime.toString()}");
            myCustomPrintStatement(
                "   Maintenant: ${currentTime.toString()}");
            myCustomPrintStatement(
                "   Différence: $differenceInMinutes minutes");

            // Empêcher course immédiate seulement si une course planifiée démarre dans moins de 30min
            if (differenceInMinutes > 0 && differenceInMinutes <= 30) {
              myCustomPrintStatement(
                "   ❌ CONFLIT: Course planifiée démarre dans moins de 30min");
              canCreateRide = false;
              break;
            } else {
              myCustomPrintStatement(
                "   ✅ PAS DE CONFLIT: Course planifiée suffisamment éloignée");
            }
          }
        }
        if (canCreateRide == false) {
          showSnackbar(translate("youalreadyhaveschedulebooking30"));
          return false; // ❌ Création échouée - course planifiée trop proche
        } else {
          myCustomPrintStatement(
              '[DEBUG NETWORK FAIL] createBooking() called - Case 3: Can create scheduled ride, bookingId=$bookingId');
          await createBooking(
              vehicleDetails, paymentMethod, pickupLocation, dropLocation,
              isScheduled: isScheduled,
              scheduleTime: scheduleTime,
              bookingId: bookingId,
              promocodeDetails: promocodeDetails);
          return true; // ✅ Création réussie
          //create ride
        }
      }

      myCustomPrintStatement("you have already booked a ride");
    }
    return true; // Par défaut, considérer comme réussi (cas edge)
    } finally {
      _isCreatingRequest = false;
      myCustomPrintStatement('🔓 createRequest: provider lock released');
    }
  }

  createBooking(
    VehicleModal vehicleDetails,
    paymentMethod,
    pickupLocation,
    dropLocation, {
    DateTime? scheduleTime,
    required bool isScheduled,
    String bookingId = "",
    PromoCodeModal? promocodeDetails,
  }) async {
    myCustomPrintStatement(
        '[DEBUG NETWORK FAIL] createBooking() ENTRY - bookingId=$bookingId, isScheduled=$isScheduled');
    if (bookingId.isNotEmpty) {
      myCustomPrintStatement(
          '[DEBUG NETWORK FAIL] 🔄 REUSING EXISTING BOOKING ID - will use transaction to protect acceptedBy');
    }
    Map<String, dynamic> data = {
      "id": bookingId.isEmpty
          ? FirestoreServices.bookingHistory.doc().id
          : bookingId,
      "paymentMethod": paymentMethod,
      "requestBy": userData.value!.id,
      // Entreprise B2B — tag la course si le réservateur est membre d'une entreprise
      if (userData.value!.companyId != null) "companyId": userData.value!.companyId,
      // Shadow ban flag - if true, drivers won't see this booking
      "isShadowBanned": userData.value!.isShadowBanned,
      // Infos du passager pour le suivi en direct
      "riderFirstName": userData.value!.firstName,
      "riderProfileImage": userData.value!.profileImage,
      "vehicle": vehicleDetails.id,
      // Données du véhicule pour le live share (marker, image, nom)
      "selectedVehicle": {
        "id": vehicleDetails.id,
        "name": vehicleDetails.name,
        "marker": vehicleDetails.marker,
        "image": vehicleDetails.image,
      },
      "otherVehicleCanRecive":
          vehicleDetails.otherCategory + [vehicleDetails.id],
      "vehicle_price_per_km": vehicleDetails.price,
      "vehicle_base_price": vehicleDetails.basePrice,
      "isSchedule": isScheduled,
      "isPreviousSchedule": booking?['isPreviousSchedule'] ?? isScheduled,
      "scheduleTime": Timestamp.fromDate(scheduleTime ?? DateTime.now()),
      // "commission_percentage":commissionPercent.toString(),
      'city': pickupLocation!['city'] ?? '',
      "pickLat": pickupLocation!['lat'],
      "pickLng": pickupLocation!['lng'],
      "bookingOTP": generateOtp(),
      "pickAddress": pickupLocation!['address'] ?? 'Adresse de prise en charge',
      "pickIsAirport": pickupLocation['isAirport'] ?? false,
      "pickFlightNumber": pickupLocation['flightNumber'] ?? '',
      "dropAddress": dropLocation!['address'] ?? 'Destination',
      "dropIsAirport": dropLocation['isAirport'] ?? false,
      "dropFlightNumber": dropLocation['flightNumber'] ?? '',
      "waiting_time_rate_per_min": vehicleDetails.waitingTimeFee,
      "vehicle_price_per_min": vehicleDetails.perMinCharge,
      "ride_status": "Running",
      "ride_cancelled_by": "",
      "distance_in_km_approx": totalWilltake.value.distance.toStringAsFixed(2),
      "currentRouteIndex": 0, //  0 = for pickup - via[0]
      "surcharge": 1,
      "coveredPath": [],
      "dropLat": dropLocation!['lat'],
      "dropLng": dropLocation!['lng'],
      "requestTime": Timestamp.now(),
      "acceptedBy": null,
      "acceptedTime": null,
      "startedTime": null,
      "chats": [],
      "endTime": null,
      "rejectedBY": [],
      "isBookingConfirmed": isScheduled ? 0 : 2,
      "startRide": isScheduled ? false : true,
      "status": 0,
      "promocodeDetails": promocodeDetails?.toBookingStore(),
      "discount": vehicleDetails.discount,
      "total_ride_price":
          calculatePriceForVehicle(vehicleDetails, withReservation: isScheduled)
              .toStringAsFixed(2),
      // 🛫 Supplément aéroport — déjà inclus dans `total_ride_price` via
      // `calculatePriceForVehicle()`. On stocke ici le montant à part pour
      // la traçabilité (audit, facturation, affichage dashboard).
      "airport_surcharge": _airportSurchargeForCurrentTrip,
    };
    // Obtenir la commission effective depuis la zone courante
    final categoryName = _mapVehicleIdToCategory(vehicleDetails);
    final commissionInfo = GeoZoneService.getCommissionForVehicleSync(
      vehicleId: vehicleDetails.id,
      categoryName: categoryName,
      globalDefault: globalSettings.adminCommission,
    );

    // Stocker le taux de commission et les infos d'audit
    data['admin_commission_in_per'] = commissionInfo.rate;
    data['commission_source'] = commissionInfo.source;
    if (commissionInfo.zoneId != null) {
      data['commission_zone_id'] = commissionInfo.zoneId;
      data['commission_zone_name'] = commissionInfo.zoneName;
    }

    myCustomPrintStatement('💰 Commission booking: ${commissionInfo.rate}% (source: ${commissionInfo.source})');

    data["ride_extra_discount"] = "0.0";
    data["rideScheduledServiceFee"] =
        booking?['isPreviousSchedule'] ?? isScheduled
            ? globalSettings.scheduleRideServiceFee
            : 0;
    // vehicle discount and extar discount (During the first signup, the client wants a function to provide customers with a special discount. Below is the work.)
    // 100000 - 100000*0.4 = 60000
    data["ride_price_to_pay"] = (double.parse(data['total_ride_price']) -
            (double.parse(data['total_ride_price']) *
                (vehicleDetails.discount / 100)))
        .toStringAsFixed(2);
    // 60000 * commission% = commission amount
    data["ride_price_commission"] = ((double.parse(data['ride_price_to_pay']) *
            (commissionInfo.rate / 100)))
        .toStringAsFixed(2);
    // 100000 - 60000 = 40000
    data["ride_discount_price"] = (double.parse(data["total_ride_price"]) *
            (vehicleDetails.discount / 100))
        .toStringAsFixed(2);
    // 40000 - 6000 = 36000
    data["ride_bonus_price"] = (double.parse(data['ride_discount_price'])
        //  -
        //         (double.parse(data['ride_discount_price']) *
        //             (globalSettings.adminCommission / 100))
        )
        .toStringAsFixed(2);
    if (vehicleDetails.id == "02b2988097254a04859a" &&
        userData.value!.extraDiscount > 0 &&
        globalSettings.enableTaxiExtraDiscount) {
      double applyedDiscount = double.parse(data['ride_price_to_pay']) <=
              userData.value!.extraDiscount
          ? (userData.value!.extraDiscount -
              (userData.value!.extraDiscount -
                      double.parse(data['ride_price_to_pay']))
                  .abs())
          : double.parse(data['ride_price_to_pay']) -
              userData.value!.extraDiscount;
      double discountIsAppling = double.parse(data['ride_price_to_pay']) <=
              userData.value!.extraDiscount
          ? applyedDiscount
          : double.parse(data['ride_price_to_pay']) - applyedDiscount;
      data['ride_price_to_pay'] = (double.parse(data['ride_price_to_pay']) <=
                  userData.value!.extraDiscount
              ? 0
              : applyedDiscount)
          .toStringAsFixed(2);

      data["ride_extra_discount"] = discountIsAppling.toStringAsFixed(2);
      data["ride_bonus_price"] =
          (double.parse(data["ride_bonus_price"]) + discountIsAppling)
              .toStringAsFixed(2);
    }
    data["ride_bonus_price_commission"] =
        (double.parse(data['ride_bonus_price']) *
                (commissionInfo.rate / 100))
            .toStringAsFixed(2);
// 40000 * 0.15 = 6000
    if (vehicleDetails.id == "02b2988097254a04859a" &&
        userData.value!.extraDiscount > 0 &&
        globalSettings.enableTaxiExtraDiscount) {
      data["ride_price_commission"] =
          (double.parse(data["ride_price_commission"]) -
                  double.parse(data["ride_bonus_price_commission"]))
              .abs()
              .toString();
    }
    // 60000 - 9000 = 51000
    data['ride_driver_earning'] = (double.parse(data['ride_price_to_pay']) -
            double.parse(data['ride_price_commission']))
        .toStringAsFixed(2);
    data['ride_driver_total_earning'] =
        (double.parse(data['ride_driver_earning']) +
                (double.parse(data['ride_bonus_price']) -
                    double.parse(data["ride_bonus_price_commission"])))
            .toStringAsFixed(2);
    // vehicle discount and extar discount (During the first signup, the client wants a function to provide customers with a special discount. Above is the work.)

    // promocode discount system

    if (promocodeDetails != null && bookingId.isEmpty) {
      var discount = double.parse(data['ride_price_to_pay'].toString()) *
          promocodeDetails.discountPercent /
          100;
      // condition for max discount on coupoun
      data['ride_promocode_discount'] =
          discount < promocodeDetails.maxRideAmount
              ? discount
              : promocodeDetails.maxRideAmount;
      // deducting the promocode price ride total paying
      data['ride_price_to_pay'] =
          (double.parse(data['ride_price_to_pay'].toString()) -
                  data['ride_promocode_discount'])
              .toString();
      Provider.of<PromocodesProvider>(MyGlobalKeys.homePageKey.currentContext!,
              listen: false)
          .removePromocode(promocodeDetails.id);
      FirestoreServices.promocodesCollection.doc(promocodeDetails.id).update({
        'usedByUsers': FieldValue.arrayUnion([userData.value!.id]),
      });

      // deducting the promocode price ride total paying price
    }
    // promocode discount system

    // payment method promo discount system
    if (paymentMethodDiscountAmount > 0 && bookingId.isEmpty) {
      data['ride_payment_method_discount'] = paymentMethodDiscountAmount;
      data['ride_payment_method_discount_percentage'] =
          paymentMethodDiscountPercentage;
      // deducting the payment method promo from ride total paying price
      data['ride_price_to_pay'] =
          (double.parse(data['ride_price_to_pay'].toString()) -
                  paymentMethodDiscountAmount)
              .toString();
      myCustomPrintStatement(
          'Payment method promo applied: ${paymentMethodDiscountAmount} (${paymentMethodDiscountPercentage}%) - New total: ${data['ride_price_to_pay']}');
    }
    // payment method promo discount system

    // all near available drivers
    List<String> driveIsAvailable = [];

    // Créer d'abord le document booking avant d'envoyer les notifications
    if (bookingId.isEmpty) {
      // Si mode séquentiel activé, créer avec showOnly vide pour éviter les notifications prematurées
      if (globalSettings.enableSequentialNotification) {
        data['showOnly'] = [];
        data['sequentialMode'] = true;
        data['currentNotifiedDriverIndex'] = 0;
      }

      // Créer le document
      await FirestoreServices.bookingRequest.doc(data['id']).set(data);

      // Sauvegarder localement pour persistance de la nouvelle course
      booking = data;
      DevFestPreferences prefs = DevFestPreferences();
      await prefs.saveActiveBooking(data);
      myCustomPrintStatement(
          '💾 Nouvelle course sauvegardée localement - ID: ${data['id']}');

      driveIsAvailable =
          await FirestoreServices.sendNotificationToAllNearbyDriversDeviceIds(
              vehicleDetails.otherCategory + [vehicleDetails.id],
              pickLocation!['lat'],
              pickLocation!['lng'],
              isScheduled: isScheduled,
              bookingId: data['id']); // Passer l'ID de la booking

      // Si mode séquentiel activé ET chauffeurs disponibles ET course NON planifiée, démarrer le timer
      // Pour les courses planifiées, on ne doit pas annuler si aucun chauffeur n'accepte immédiatement
      if (globalSettings.enableSequentialNotification && driveIsAvailable.isNotEmpty && !isScheduled) {
        _startSequentialNotificationTimer(data['id']);
      }
    } else {
      driveIsAvailable = List.generate(
        booking!['showOnly'].length,
        (index) => booking!['showOnly'][index] as String,
      );
      data['rejectedBY'] = booking == null ? [] : booking!['rejectedBY'];
    }

    // all near available drivers

    if (driveIsAvailable.isNotEmpty) {
      // Si mode séquentiel, ne pas mettre à jour showOnly ici (géré par le système séquentiel)
      if (!globalSettings.enableSequentialNotification ||
          bookingId.isNotEmpty) {
        data['showOnly'] = driveIsAvailable;

        if (bookingId.isEmpty) {
          await FirestoreServices.bookingRequest
              .doc(data['id'])
              .update({'showOnly': driveIsAvailable});
        } else {
          myCustomPrintStatement(
              '[DEBUG NETWORK FAIL] 🔄 Using TRANSACTION to safely update without overwriting acceptedBy');

          bool driverAcceptedDuringUpdate = false;
          Map<String, dynamic>? currentBookingData;

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            DocumentReference docRef =
                FirestoreServices.bookingRequest.doc(data['id']);
            DocumentSnapshot docSnapshot = await transaction.get(docRef);

            if (docSnapshot.exists) {
              currentBookingData = docSnapshot.data() as Map<String, dynamic>;

              if (currentBookingData!['acceptedBy'] == null ||
                  currentBookingData!['acceptedBy'] == '') {
                myCustomPrintStatement(
                    '[DEBUG NETWORK FAIL] ✅ acceptedBy is null, safe to update showOnly');
                transaction.update(docRef, {'showOnly': driveIsAvailable});
              } else {
                myCustomPrintStatement(
                    '[DEBUG NETWORK FAIL] ⚠️ Driver accepted during network outage! acceptedBy=${currentBookingData!['acceptedBy']}');
                driverAcceptedDuringUpdate = true;
              }
            } else {
              myCustomPrintStatement(
                  '[DEBUG NETWORK FAIL] 📝 Document doesn\'t exist, creating it');
              transaction.set(docRef, data);
            }
          });

          // GESTION POST-TRANSACTION
          if (driverAcceptedDuringUpdate && currentBookingData != null) {
            myCustomPrintStatement(
                '[DEBUG NETWORK FAIL] 🎉 Driver found! Updating local booking and UI...');

            // Mettre à jour les données locales avec les vraies données de Firebase
            booking = currentBookingData;

            // Déclencher la transition vers driverOnWay
            await setBookingStreamInner();

            myCustomPrintStatement(
                '[DEBUG NETWORK FAIL] ✅ Driver acceptance processed, stopping notification flow');
            // Pas besoin de continuer l'envoi de notifications
            return;
          }
        }
      }

      // CRITICAL: Start booking stream to listen for driver acceptance
      if (bookingId.isEmpty) {
        myCustomPrintStatement(
            '🔄 Starting booking stream to listen for driver acceptance');
        await setBookingStream();
      }

      if (bookingId.isEmpty && scheduleTime != null && isScheduled) {
        // Sauvegarder le booking complet pour les notifications futures
        Map<String, dynamic> scheduledBookingData =
            Map<String, dynamic>.from(data);

        push(
            context: MyGlobalKeys.navigatorKey.currentContext!,
            screen: const PendingScheduledBookingRequested());
        final schedulerOk = await BookingServiceScheduler().createScheduledJob(
            timestamp:
                scheduleTime.subtract(const Duration(minutes: 20)).toUtc(),
            bookingId: data['id']);
        if (!schedulerOk) {
          myCustomPrintStatement(
              '⚠️ SCHEDULER: Job creation failed for ${data['id']}');
        }

        showSnackbar(translate(
            "Your scheduled booking request has been successfully placed"));

        // Ajouter à la liste AVANT resetAll pour préserver la référence
        if (!scheduledBookingsList
            .any((b) => b['id'] == scheduledBookingData['id'])) {
          scheduledBookingsList.add(scheduledBookingData);
          myCustomPrintStatement(
              '📦 Scheduled booking preserved in list: ${scheduledBookingData['id']}');
        }

        // Utiliser resetAllExceptScheduled pour garder le listener actif
        // Cela permet de détecter quand le chauffeur confirme ou quand la course
        // est transformée en course immédiate
        resetAllExceptScheduled();
      }
    } else {
      // Pas de chauffeurs EN LIGNE disponibles

      // 🔧 FIX: Pour les courses PLANIFIÉES, on garde la course active même sans chauffeurs en ligne
      // Les chauffeurs (même hors ligne) pourront être notifiés plus tard
      if (isScheduled && scheduleTime != null && bookingId.isEmpty) {
        myCustomPrintStatement(
            '📅 Course planifiée créée sans chauffeurs en ligne - les chauffeurs seront notifiés plus tard');

        // Sauvegarder le booking complet pour les notifications futures
        Map<String, dynamic> scheduledBookingData =
            Map<String, dynamic>.from(data);

        // Démarrer le stream pour écouter les changements
        await setBookingStream();

        push(
            context: MyGlobalKeys.navigatorKey.currentContext!,
            screen: const PendingScheduledBookingRequested());
        final schedulerOkNoDrivers = await BookingServiceScheduler().createScheduledJob(
            timestamp:
                scheduleTime.subtract(const Duration(minutes: 20)).toUtc(),
            bookingId: data['id']);
        if (!schedulerOkNoDrivers) {
          myCustomPrintStatement(
              '⚠️ SCHEDULER: Job creation failed (no drivers) for ${data['id']}');
        }

        showSnackbar(translate(
            "Your scheduled booking request has been successfully placed"));

        // Ajouter à la liste AVANT resetAll pour préserver la référence
        if (!scheduledBookingsList
            .any((b) => b['id'] == scheduledBookingData['id'])) {
          scheduledBookingsList.add(scheduledBookingData);
          myCustomPrintStatement(
              '📦 Scheduled booking preserved in list: ${scheduledBookingData['id']}');
        }

        // Utiliser resetAllExceptScheduled pour garder le listener actif
        resetAllExceptScheduled();
        return;
      }

      // Pour les courses IMMÉDIATES sans chauffeurs - annuler
      if (bookingId.isEmpty) {
        // Seulement pour les nouvelles courses immédiates
        data['cancelledBy'] = 'system';
        data['cancelledReason'] = 'no_drivers_available';
        data['cancelledTime'] = Timestamp.now();

        myCustomPrintStatement(
            'No drivers available - migrating booking ${data['id']} to cancelledBooking');

        try {
          // Migrer vers cancelledBooking
          await FirestoreServices.cancelledBooking.doc(data['id']).set(data);

          // Supprimer de bookingRequest
          await FirestoreServices.bookingRequest.doc(data['id']).delete();

          myCustomPrintStatement(
              'Successfully migrated booking ${data['id']} to cancelledBooking');
        } catch (e) {
          myCustomPrintStatement(
              'Error migrating booking to cancelledBooking: $e');
        }
      }

      showSnackbar(translate("noDriverFound"));
      setScreen(CustomTripType.confirmDestination);

      // Arrêter la recherche - nettoyer les données
      booking = null;
      clearAllTripData();
      myCustomPrintStatement('🛑 Recherche arrêtée - aucun chauffeur disponible');
      return;
    }
    myCustomPrintStatement('sending notifications....manish $data');
  }

  setBookingStream() async {
    // myCustomPrintStatement('booking stream call -------------------------------------------mizan');

    // Guard contre userData null
    if (userData.value == null) {
      myCustomPrintStatement('⚠️ setBookingStream: userData null, skip');
      return;
    }

    // Annuler l'ancien listener s'il existe
    if (_bookingStreamSubscription != null) {
      await _bookingStreamSubscription!.cancel();
      _bookingStreamSubscription = null;
      myCustomPrintStatement('🛑 Ancien booking stream annulé');
    }

    // Listen to all bookings for the current user to catch status changes immediately
    bookingStream = FirestoreServices.bookingRequest
        .where('requestBy', isEqualTo: userData.value!.id)
        .orderBy('scheduleTime', descending: false)
        .snapshots();
    _bookingStreamSubscription = bookingStream!.listen((event) async {
      myCustomPrintStatement(
          '🔄 Booking stream received ${event.docs.length} documents');
      if (event.docs.isNotEmpty) {
        // Log all bookings to debug
        for (var doc in event.docs) {
          var data = doc.data() as Map<String, dynamic>;
          myCustomPrintStatement(
              '📋 Booking ${data['id']}: status=${data['status']}, ride_status=${data['ride_status']}, acceptedBy=${data['acceptedBy']}, startRide=${data['startRide']}');
        }
        if (booking != null) {
          // booking is ongoing
          var foundMap = event.docs.where((element) {
            var map = (element.data() as Map<String, dynamic>);
            // Filtrer les bookings annulés (statut >= 6)
            if (map['status'] != null && map['status'] >= BookingStatusType.CANCELLED.value) {
              myCustomPrintStatement('🚫 Booking ${map['id']} ignoré (statut annulé: ${map['status']})');
              return false;
            }
            return booking!['id'] == map['id'];
          });
          // myCustomPrintStatement("foundMap ${foundMap.length}");
          if (foundMap.isNotEmpty) {
            // booking is found in my request list - not deleted or cancelled
            Map check = foundMap.first.data() as Map<String, dynamic>;

            // DETAILED DEBUGGING FOR ACCEPTANCE DETECTION
            myCustomPrintStatement('🔍 Checking acceptance conditions:');
            myCustomPrintStatement(
                '   Local booking acceptedBy: ${booking!['acceptedBy']}');
            myCustomPrintStatement(
                '   Stream booking acceptedBy: ${check['acceptedBy']}');
            myCustomPrintStatement('   Local booking ID: ${booking!['id']}');
            myCustomPrintStatement('   Stream booking ID: ${check['id']}');
            myCustomPrintStatement(
                '   Local booking status: ${booking!['status']}');
            myCustomPrintStatement(
                '   Stream booking status: ${check['status']}');
            myCustomPrintStatement('   Current step: $currentStep');

            bool ch = false;

            // IMPROVED ACCEPTANCE DETECTION LOGIC
            bool wasNotAccepted = (booking!['acceptedBy'] == null ||
                booking!['acceptedBy'] == '');
            bool isNowAccepted =
                (check['acceptedBy'] != null && check['acceptedBy'] != '');
            bool sameBooking = (booking!['id'] == check['id']);
            bool notAlreadyOnDriverOnWay =
                (currentStep != CustomTripType.driverOnWay);

            // 🔧 FIX: Detect when a DIFFERENT driver has accepted (driver reassignment)
            // This happens when driver 1 cancels and driver 2 accepts the same booking
            bool driverChanged = isNowAccepted &&
                booking!['acceptedBy'] != null &&
                booking!['acceptedBy'] != '' &&
                booking!['acceptedBy'] != check['acceptedBy'];

            // 🔧 FIX: Detect when startRide changes from false to true (driver confirms scheduled booking)
            // This triggers the driverOnWay flow for scheduled bookings
            bool startRideJustActivated = check['isSchedule'] == true &&
                booking!['startRide'] != true &&
                check['startRide'] == true;

            myCustomPrintStatement(
                '🔍 Acceptance checks: wasNotAccepted=$wasNotAccepted, isNowAccepted=$isNowAccepted, sameBooking=$sameBooking, notAlreadyOnDriverOnWay=$notAlreadyOnDriverOnWay, driverChanged=$driverChanged, startRideJustActivated=$startRideJustActivated');

            if (((wasNotAccepted && isNowAccepted) || driverChanged) &&
                sameBooking) {

              // 🔧 FIX: Réinitialiser le flag de réassignation car un nouveau chauffeur a accepté
              if (_scheduledBookingAwaitingReassignment) {
                myCustomPrintStatement(
                    '✅ Nouveau chauffeur accepté - réinitialisation du flag _scheduledBookingAwaitingReassignment');
                _scheduledBookingAwaitingReassignment = false;
              }

              // 🔧 FIX: Reset acceptedDriver when driver changes so it gets refreshed
              if (driverChanged) {
                myCustomPrintStatement(
                    '🔄 Driver changed from ${booking!['acceptedBy']} to ${check['acceptedBy']} - resetting acceptedDriver');
                acceptedDriver = null;
              }
              myCustomPrintStatement(
                  '✅✅✅ DRIVER ACCEPTED! Checking if should transition - BookingID: ${booking!['id']}, DriverID: ${check['acceptedBy']}');

              // CRITICAL: Update booking data FIRST, then conditionally set screen state
              booking = check; // Update booking data immediately

              // 🔧 FIX: Toujours transitionner vers driverOnWay quand un chauffeur accepte
              // Que ce soit une course planifiée ou immédiate, l'utilisateur doit voir le flow de course
              bool isScheduledBooking = check['isSchedule'] == true;
              bool rideHasStarted =
                  check['status'] >= BookingStatusType.RIDE_STARTED.value;
              bool startRideIsTrue = check['startRide'] == true;

              myCustomPrintStatement(
                  '🔍 Transition checks - isScheduled: $isScheduledBooking, rideStarted: $rideHasStarted, startRide: $startRideIsTrue');

              // Pour les courses PLANIFIÉES : ne PAS passer en driverOnWay tant que
              // le driver n'a pas CONFIRMÉ (isBookingConfirmed==2 ou startRide==true).
              // Le rider reste sur l'écran "Mes réservations" — pas de polyline.
              // La transition se fera via le path startRideJustActivated plus bas.
              if (isScheduledBooking &&
                  !startRideIsTrue &&
                  check['isBookingConfirmed'] != 2) {
                myCustomPrintStatement(
                    '📅 Scheduled booking accepted but NOT confirmed — staying on pending screen (isBookingConfirmed=${check['isBookingConfirmed']})');
              } else {
                myCustomPrintStatement(
                    '🚗 Transitioning to driverOnWay - isScheduled: $isScheduledBooking, rideStarted: $rideHasStarted, startRide: $startRideIsTrue');
                _safeSetDriverOnWay(
                    source: 'mainStream-acceptance'); // Set the screen state
              }

              myCustomPrintStatement(
                  '🔄 Updated booking data and screen state');
              myCustomPrintStatement('   Booking is null? ${booking == null}');
              myCustomPrintStatement('   Current step: $currentStep');

              notifyListeners(); // Notify UI to rebuild with new state

              // Force UI update by updating bottom sheet height
              if (MyGlobalKeys.homePageKey.currentState != null) {
                MyGlobalKeys.homePageKey.currentState!
                    .updateBottomSheetHeight(milliseconds: 100);
              }

              // Asynchronously fetch driver details and update map
              Future.microtask(() async {
                try {
                  await afterAcceptFunctionality();
                  myCustomPrintStatement(
                      '✅ Stream acceptance flow completed successfully');
                } catch (e) {
                  myCustomPrintStatement(
                      '❌ Error in stream afterAcceptFunctionality: $e');
                }
              });

              ch = true; // Mark as handled to skip the next block
            } else if (startRideJustActivated && sameBooking && isNowAccepted) {
              // 🔧 FIX: Le chauffeur vient de confirmer une course planifiée (startRide est passé de false à true)
              // C'est le moment d'afficher le flow "Chauffeur en route"
              // 🔧 FIX: On vérifie aussi que acceptedBy n'est pas null pour éviter un état incohérent
              myCustomPrintStatement(
                  '🚗✅ SCHEDULED BOOKING CONFIRMED BY DRIVER! startRide changed to true - BookingID: ${check['id']}');

              // Update booking data
              booking = check;

              // Sauvegarder localement pour persistance
              DevFestPreferences prefs = DevFestPreferences();
              await prefs.saveActiveBooking(check as Map<String, dynamic>);

              // Activer le flow driverOnWay
              _safeSetDriverOnWay(source: 'stream-startRideJustActivated');

              myCustomPrintStatement(
                  '🔄 Scheduled booking confirmed - transitioning to driverOnWay');
              notifyListeners();

              // Force UI update
              if (MyGlobalKeys.homePageKey.currentState != null) {
                MyGlobalKeys.homePageKey.currentState!
                    .updateBottomSheetHeight(milliseconds: 100);
              }

              // Fetch driver details
              Future.microtask(() async {
                try {
                  await afterAcceptFunctionality();
                  myCustomPrintStatement(
                      '✅ Scheduled booking confirmation flow completed successfully');
                } catch (e) {
                  myCustomPrintStatement(
                      '❌ Error in scheduled booking confirmation afterAcceptFunctionality: $e');
                }
              });

              ch = true; // Mark as handled
            } else if (startRideJustActivated && sameBooking && !isNowAccepted) {
              // 🔧 FIX: État incohérent - startRide=true mais acceptedBy=null
              // Ne pas transitionner vers driverOnWay car il n'y a pas de chauffeur
              myCustomPrintStatement(
                  '⚠️ INCONSISTENT STATE: startRide=true but acceptedBy=null - NOT transitioning to driverOnWay');
              // Update booking data anyway to keep local state in sync
              booking = check;
            } else {
              // Check if this is a scheduled booking that needs handling
              bool isScheduledBookingUpdate =
                  (check['isSchedule'] == true && check['acceptedBy'] != null);

              if (isScheduledBookingUpdate && sameBooking) {
                // Distinguish between acceptance and ride start
                bool rideHasStarted =
                    check['status'] >= BookingStatusType.RIDE_STARTED.value;
                bool startRideIsTrue = check['startRide'] == true;
                bool shouldActivateRide = startRideIsTrue || rideHasStarted;
                // 🔧 FIX: Ne pas vérifier currentStep - si le chauffeur accepte, on doit transitionner
                // peu importe où se trouve l'utilisateur dans l'app
                bool justAccepted =
                    check['status'] == BookingStatusType.ACCEPTED.value;

                // 🔧 FIX: Detect when a DIFFERENT driver has accepted (driver reassignment)
                bool scheduledDriverChanged = booking!['acceptedBy'] != null &&
                    booking!['acceptedBy'] != '' &&
                    booking!['acceptedBy'] != check['acceptedBy'];

                myCustomPrintStatement(
                    '🔍 Scheduled booking checks - rideStarted: $rideHasStarted, startRide: $startRideIsTrue, shouldActivate: $shouldActivateRide, driverChanged: $scheduledDriverChanged');

                // 🔧 FIX: Reset acceptedDriver when driver changes for scheduled bookings
                if (scheduledDriverChanged) {
                  myCustomPrintStatement(
                      '🔄 Scheduled booking driver changed from ${booking!['acceptedBy']} to ${check['acceptedBy']} - resetting acceptedDriver');
                  acceptedDriver = null;
                }

                if (shouldActivateRide) {
                  // Guard: ne pas re-déclencher si déjà sur driverOnWay pour ce même booking
                  if (currentStep == CustomTripType.driverOnWay &&
                      booking!['id'] == check['id'] &&
                      acceptedDriver != null) {
                    myCustomPrintStatement(
                        '⏭️ Scheduled booking déjà activé (driverOnWay) - skip re-trigger');
                    booking = check; // Mettre à jour les données sans re-déclencher le flow
                  } else {
                  myCustomPrintStatement(
                      '🚗✅ SCHEDULED BOOKING READY TO ACTIVATE! - BookingID: ${booking!['id']}, startRide: $startRideIsTrue, rideStarted: $rideHasStarted');

                  // Update booking data and transition to driverOnWay
                  booking = check;

                  // Sauvegarder localement pour persistance
                  DevFestPreferences prefs = DevFestPreferences();
                  await prefs.saveActiveBooking(check as Map<String, dynamic>);
                  _safeSetDriverOnWay(source: 'scheduledBooking-rideStarted');

                  myCustomPrintStatement(
                      '🔄 Updated scheduled booking and set currentStep to driverOnWay');
                  notifyListeners();

                  // Force UI update
                  if (MyGlobalKeys.homePageKey.currentState != null) {
                    MyGlobalKeys.homePageKey.currentState!
                        .updateBottomSheetHeight(milliseconds: 100);
                  }

                  // Fetch driver details
                  Future.microtask(() async {
                    try {
                      await afterAcceptFunctionality();
                      myCustomPrintStatement(
                          '✅ Scheduled booking activation completed successfully');
                    } catch (e) {
                      myCustomPrintStatement(
                          '❌ Error in scheduled booking afterAcceptFunctionality: $e');
                    }
                  });
                  }
                } else if (justAccepted) {
                  // 🔧 FIX: Pour les courses planifiées, quand le chauffeur CONFIRME la réservation (justAccepted)
                  // on ne déclenche PAS le flow driverOnWay. On attend que startRide=true (chauffeur démarre la course)
                  myCustomPrintStatement(
                      '📅 SCHEDULED BOOKING CONFIRMED (not started yet) - BookingID: ${booking!['id']}');
                  myCustomPrintStatement(
                      '   Le flow driverOnWay sera affiché quand startRide=true');

                  // Update booking data (mais PAS de transition vers driverOnWay)
                  booking = check;

                  // Sauvegarder localement pour persistance
                  DevFestPreferences prefs = DevFestPreferences();
                  await prefs.saveActiveBooking(check as Map<String, dynamic>);

                  // 📢 Envoyer une notification locale au passager pour l'informer que la réservation est confirmée
                  try {
                    String pickupTimeFormatted = '';
                    if (check['scheduleTime'] != null) {
                      DateTime scheduleDateTime = (check['scheduleTime'] as Timestamp).toDate();
                      pickupTimeFormatted = DateFormat('HH:mm').format(scheduleDateTime);
                    }

                    String notificationTitle = translate('driverOnWayForScheduledRide');
                    String notificationBody = translate('driverPreparingForPickup')
                        .replaceAll('{time}', pickupTimeFormatted);

                    FirebasePushNotifications.showLocalNotification(
                      title: notificationTitle,
                      body: notificationBody,
                      payload: {
                        'screen': 'booking_accepted',
                        'bookingId': check['id'],
                      },
                    );
                    myCustomPrintStatement('📢 Notification envoyée au passager - Réservation confirmée pour $pickupTimeFormatted');
                  } catch (e) {
                    myCustomPrintStatement('❌ Erreur envoi notification scheduled booking: $e');
                  }

                  // 🔧 NE PAS appeler _safeSetDriverOnWay - on reste sur l'écran actuel (setYourDestination)
                  // Le flow driverOnWay sera déclenché quand startRide=true (bloc shouldActivateRide ci-dessus)

                  myCustomPrintStatement(
                      '📅 Scheduled booking data updated - waiting for startRide=true to show flow');
                  notifyListeners();
                } else {
                  myCustomPrintStatement(
                      '🔄 SCHEDULED BOOKING status update - BookingID: ${booking!['id']}, status: ${check['status']}');
                  booking = check;
                  notifyListeners();
                }

                ch = true; // Mark as handled
              } else {
                myCustomPrintStatement(
                    '⚠️ Scheduled booking conditions not met - no transition performed');
                myCustomPrintStatement(
                    '   isScheduledBookingUpdate: $isScheduledBookingUpdate, sameBooking: $sameBooking');
              }
            }
            // }
            if (ch == false) {
              var lastStatus = booking == null ? 10 : booking!['status'];
              var lastAcceptedBy = booking == null ? null : booking!['acceptedBy'];
              booking = foundMap.first.data() as Map;

              // 🔧 FIX: Detect driver cancellation/reassignment - reset acceptedDriver if acceptedBy changed or cleared
              if (lastAcceptedBy != null &&
                  lastAcceptedBy != '' &&
                  (booking!['acceptedBy'] == null || booking!['acceptedBy'] == '' || booking!['acceptedBy'] != lastAcceptedBy)) {
                myCustomPrintStatement(
                    '🔄 acceptedBy changed/cleared: $lastAcceptedBy -> ${booking!['acceptedBy']} - resetting acceptedDriver');

                // Capturer le nom du chauffeur AVANT de le réinitialiser
                final String withdrawnDriverName = acceptedDriver?.fullName ?? '';
                acceptedDriver = null;

                // If acceptedBy is now null (driver cancelled), handle based on booking type
                if (booking!['acceptedBy'] == null || booking!['acceptedBy'] == '') {
                  // 🔧 FIX: Pour les courses programmées, rester sur selectScheduleTime
                  // car la course existe déjà dans Firestore et attend un nouveau chauffeur
                  // Si on va sur requestForRide, l'app essaie de recréer la course
                  bool isScheduledBooking = booking!['isSchedule'] == true;

                  if (isScheduledBooking) {
                    // 🔧 FIX: Pour les courses planifiées, gérer selon l'état actuel
                    myCustomPrintStatement('🚗 Driver withdrew from SCHEDULED booking - currentStep: $currentStep');

                    // Activer le flag pour bloquer pendingRequestFunctionality et le timer de retry
                    _scheduledBookingAwaitingReassignment = true;

                    // Annuler le timer de retry pour éviter de recréer la course
                    _pendingRequestRetryTimer?.cancel();
                    _pendingRequestRetryTimer = null;
                    myCustomPrintStatement('🛑 Timer retry annulé - course planifiée attend un nouveau chauffeur');

                    // 🔧 FIX: Si on était sur driverOnWay (le chauffeur avait confirmé), revenir à setYourDestination
                    // car l'écran driverOnWay a besoin des infos chauffeur pour fonctionner
                    if (currentStep == CustomTripType.driverOnWay) {
                      myCustomPrintStatement('🔄 Retour à setYourDestination car le chauffeur s\'est désisté pendant driverOnWay');
                      currentStep = CustomTripType.setYourDestination;
                      // Réinitialiser startRide localement car le chauffeur s'est désisté
                      booking!['startRide'] = false;
                      notifyListeners();
                    }

                    // Afficher une SnackBar pour informer l'utilisateur
                    Future.microtask(() {
                      try {
                        if (MyGlobalKeys.navigatorKey.currentContext != null) {
                          String message;
                          if (withdrawnDriverName.isNotEmpty) {
                            message = translate('driverUnavailableNewAssignment')
                                .replaceAll('{driverName}', withdrawnDriverName);
                          } else {
                            message = translate('driverWithdrewSearchingNew');
                          }

                          ScaffoldMessenger.of(MyGlobalKeys.navigatorKey.currentContext!)
                              .showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        myCustomPrintStatement('⚠️ Could not show driver withdrew notification: $e');
                      }
                    });
                  } else {
                    myCustomPrintStatement('🚗 Driver withdrew from IMMEDIATE booking - transitioning back to requestForRide');
                    currentStep = CustomTripType.requestForRide;
                    notifyListeners();

                    // Afficher un message uniquement pour les courses immédiates
                    Future.microtask(() {
                      try {
                        if (MyGlobalKeys.navigatorKey.currentContext != null) {
                          String message;
                          if (withdrawnDriverName.isNotEmpty) {
                            message = translate('driverUnavailableNewAssignment')
                                .replaceAll('{driverName}', withdrawnDriverName);
                          } else {
                            message = translate('driverWithdrewSearchingNew');
                          }

                          ScaffoldMessenger.of(MyGlobalKeys.navigatorKey.currentContext!)
                              .showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        myCustomPrintStatement('⚠️ Could not show driver withdrew notification: $e');
                      }
                    });
                  }
                }
              }

              if (lastStatus != booking!['status']) {
                if (MyGlobalKeys.homePageKey.currentState != null) {
                  MyGlobalKeys.homePageKey.currentState!
                      .updateBottomSheetHeight(milliseconds: 500);
                }
              }
              setBookingStreamInner();
            }
          } else {
            myCustomPrintStatement("mizan------ completed-------");
            //booking is delete/ most probably cancelled.

            // If current booking was cancelled by driver, mark it and reset
            if (booking != null &&
                booking!['status'] != BookingStatusType.CANCELLED.value) {
              myCustomPrintStatement(
                  "🚨 Booking missing from stream - likely cancelled by driver");

              // CRITIQUE: Purge complète des données de trip
              await clearAllTripData();
              myCustomPrintStatement('✅ clearAllTripData() terminé après suppression du booking');

              currentStep = CustomTripType.setYourDestination;
              acceptedDriver = null;

              // Reset navigation bar visibility
              try {
                final navigationProvider = Provider.of<NavigationProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false);
                navigationProvider.setNavigationBarVisibility(true);
              } catch (e) {
                myCustomPrintStatement(
                    '⚠️ Could not reset navigation bar visibility: $e');
              }

              // Show cancellation notification (sauf si l'utilisateur a annulé manuellement)
              Future.microtask(() {
                try {
                  if (MyGlobalKeys.navigatorKey.currentContext != null &&
                      !_userCancelledManually) {
                    String cancellationMessage = translate('Trip was cancelled by driver');

                    ScaffoldMessenger.of(
                            MyGlobalKeys.navigatorKey.currentContext!)
                        .showSnackBar(
                      SnackBar(
                        content: Text(cancellationMessage),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  // Réinitialiser le flag après utilisation
                  _userCancelledManually = false;
                  MyGlobalKeys.homePageKey.currentState
                      ?.updateBottomSheetHeight(milliseconds: 100);
                } catch (e) {
                  myCustomPrintStatement(
                      '⚠️ Could not show cancellation notification: $e');
                }
              });

              notifyListeners();
            }

            checkAndReset();
            // resetAll();
          }
        } else {
          // booking object not assinged - (if have current booking and restart the app)
          var foundMap = event.docs.where((element) {
            //checking current booking
            var map = (element.data() as Map<String, dynamic>);

            // Filtrer les bookings annulés (statut >= 6)
            if (map['status'] != null && map['status'] >= BookingStatusType.CANCELLED.value) {
              myCustomPrintStatement('🚫 Booking ${map['id']} ignoré lors de la restauration (statut annulé: ${map['status']})');
              return false;
            }

            // Détecter les courses immédiates ET les courses planifiées transformées
            // Une course planifiée transformée a startRide=true ou un chauffeur accepté
            return map['isSchedule'] == false ||
                (map['startRide'] == true && map['acceptedBy'] != null);
          });
          // myCustomPrintStatement("foundMap ${foundMap.length}");
          if (foundMap.isNotEmpty) {
            //if current booking is found
            Map check = foundMap.first.data() as Map<String, dynamic>;
            var lastStatus = booking == null ? 10 : booking!['status'];
            booking = check;
            if (lastStatus != booking!['status']) {
              MyGlobalKeys.homePageKey.currentState!
                  .updateBottomSheetHeight(milliseconds: 500);
            }
            setBookingStreamInner();
          } else {
            //if current booking not found then check have a schedule ride or not

            for (int i = 0; i < event.docs.length; i++) {
              Map check = event.docs[i].data() as Map;

              // Filtrer les bookings annulés
              if (check['status'] != null && check['status'] >= BookingStatusType.CANCELLED.value) {
                myCustomPrintStatement('🚫 Scheduled booking ${check['id']} ignoré (statut annulé: ${check['status']})');
                continue;
              }

              if (check['isSchedule'] == true) {
                if (check['status'] ==
                    BookingStatusType.PENDING_REQUEST.value) {
                  // booking = check;

                  // await pendingRequestFunctionality();
                  // // resetAll();
                  // break;
                } else if (check['status'] >=
                    BookingStatusType.ACCEPTED.value) {
                  // myCustomPrintStatement("accepted by driver------");

                  DateTime scheduleTime =
                      (check['scheduleTime'] as Timestamp).toDate();
                  DateTime currentTime = DateTime.now();
                  int difference =
                      scheduleTime.difference(currentTime).inMinutes;

                  // 🔧 FIX: Afficher le flow dès que le chauffeur accepte (acceptedBy != null)
                  // Ne pas attendre startRide == true pour montrer le flow de course
                  bool driverAccepted = check['acceptedBy'] != null;
                  bool withinTimeWindow = difference <= 60;
                  bool rideStarted = check['startRide'] == true;

                  // 🔧 FIX: Si startRide=true, afficher le flow immédiatement (même si hors fenêtre de temps)
                  // Cela gère le cas où l'utilisateur a désactivé les notifications push
                  if ((withinTimeWindow && driverAccepted) || rideStarted) {
                    myCustomPrintStatement(
                        '🚗 Scheduled ride ready for flow: ${check['id']}, startRide: $rideStarted, withinWindow: $withinTimeWindow, driverAccepted: $driverAccepted');
                    booking = check;
                    _safeSetDriverOnWay(
                        source: 'scheduledLoop-becoming-active');
                    notifyListeners(); // Force UI update immediately
                    await afterAcceptFunctionality();
                    break;
                  }
                }
              }
            }

            ///for loop end
          }
        }
        // 🔧 FIX: Ne pas appeler resetAll() si l'utilisateur est en train de créer une course
        // Sinon, lors de la création d'une 2e course planifiée, le listener détecte
        // le booking en attente (status=0) mais ne l'assigne pas à booking (course future),
        // donc booking==null et resetAll() est appelé, ramenant l'utilisateur au menu principal
        if (booking == null) {
          // Vérifier si l'utilisateur est en train de créer/configurer une course
          bool isCreatingRide = currentStep == CustomTripType.choosePickupDropLocation ||
                               currentStep == CustomTripType.confirmDestination ||
                               currentStep == CustomTripType.chooseVehicle ||
                               currentStep == CustomTripType.selectScheduleTime ||
                               currentStep == CustomTripType.flightNumberEntry ||
                               currentStep == CustomTripType.payment ||
                               currentStep == CustomTripType.selectAvailablePromocode ||
                               currentStep == CustomTripType.setYourDestination;

          if (isCreatingRide) {
            myCustomPrintStatement(
                "⚠️ Booking null mais utilisateur en création de course (step: $currentStep) - pas de resetAll()");
          } else {
            myCustomPrintStatement(
                "🔄 Booking null et pas en création - appel resetAll()");
            resetAll();
          }
        }
        if (booking != null) {
          // if(booking!['status']>=BookingStatusType.PENDING_REQUEST){
          pickLocation = {
            "lat": booking!['pickLat'],
            "lng": booking!['pickLng'],
            "address": booking!['pickAddress'] ?? 'Adresse de prise en charge',
          };
          dropLocation = {
            "lat": booking!['dropLat'],
            "lng": booking!['dropLng'],
            "address": booking!['dropAddress'] ?? 'Destination',
          };
          if (booking!['status'] < BookingStatusType.RIDE_COMPLETE.value) {
            // Ne PAS dessiner le polyline pour les courses planifiées non confirmées
            // (le rider ne doit rien voir tant que le driver n'a pas confirmé)
            final isScheduledNotConfirmed = booking!['isSchedule'] == true &&
                booking!['startRide'] != true &&
                booking!['isBookingConfirmed'] != 2;
            if (!isScheduledNotConfirmed) {
              createPath();
            }
          }
          // }
        }
        // Map<String, dynamic>? foundMap = event.docs.where((map) => ((map.data() as Map<String, dynamic>)['checked']) == true, orElse: () => null)

        getUnreadCount(); //function code commented
      } else {
        // 🔧 FIX: Protéger contre les snapshots vides transitoires.
        // Firestore peut émettre un premier snapshot vide juste après la
        // souscription (avant que l'écriture locale soit propagée côté
        // serveur, surtout sur réseau lent). Sans cette garde, un booking
        // qui vient d'être créé est immédiatement archivé par checkAndReset(),
        // alors que le doc existe bien dans Firestore.
        // On ignore l'événement vide si le booking local a moins de 30s.
        if (booking != null && booking!['requestTime'] is Timestamp) {
          final int ageSeconds = Timestamp.now().seconds -
              (booking!['requestTime'] as Timestamp).seconds;
          if (ageSeconds < 30) {
            myCustomPrintStatement(
                '⚠️ Snapshot vide ignoré — booking ${booking!['id']} trop jeune (${ageSeconds}s)');
            return;
          }
        }
        checkAndReset();
      }
    });
  }

  /// Apply booking status coming from FCM data push (data-only notification)
  /// Expected keys in [data]:
  ///  - 'bookingId' or 'booking_id'
  ///  - 'status' or 'booking_status' (e.g., 'DRIVER_ACCEPTED', 'DRIVER_ASSIGNED', ...)
  void applyBookingStatusFromPush(Map<dynamic, dynamic> data) async {
    try {
      myCustomPrintStatement('🔥 === PUSH NOTIFICATION DEBUG START ===');
      myCustomPrintStatement('🔥 Raw push data: $data');
      myCustomPrintStatement(
          '🔥 Current booking: ${booking != null ? booking!['id'] : 'NULL'}');
      myCustomPrintStatement('🔥 Current screen: $currentStep');
      myCustomPrintStatement('🔥 User cancelled manually: $_userCancelledManually');

      // 🔧 FIX CRITIQUE: Si l'utilisateur a annulé manuellement, ignorer la push notification
      // Cela empêche un chauffeur d'accepter une course que l'utilisateur a déjà annulée
      if (_userCancelledManually) {
        myCustomPrintStatement('🛑 PUSH IGNORÉE: L\'utilisateur a annulé manuellement la course');
        myCustomPrintStatement('🔥 === PUSH NOTIFICATION DEBUG END (USER CANCELLED) ===');
        return;
      }

      final String? bookingId =
          (data['bookingId'] ?? data['booking_id'])?.toString();
      final dynamic statusRaw = data['status'] ?? data['booking_status'];
      final String? driverId = data['acceptedBy'] ?? data['driver_id'];

      // Handle driver acceptance notifications even without existing booking
      if (statusRaw != null &&
          (statusRaw.toString() == 'DRIVER_ACCEPTED' ||
              statusRaw.toString() == 'ACCEPTED')) {
        myCustomPrintStatement(
            '🚗 Driver acceptance detected, creating booking context if needed');

        // Try to restore full booking data if none exists
        if (booking == null) {
          bool foundBooking = false;

          if (bookingId != null) {
            myCustomPrintStatement(
                '🔍 Searching for booking $bookingId in scheduledBookingsList (${scheduledBookingsList.length} items)');

            // D'abord chercher dans la liste locale
            for (var scheduledBooking in scheduledBookingsList) {
              if (scheduledBooking['id'] == bookingId) {
                booking = Map<String, dynamic>.from(scheduledBooking);
                booking!['status'] = BookingStatusType.ACCEPTED.value;
                booking!['acceptedBy'] = driverId;
                booking!['isDriverAssigned'] = true;
                booking!['_fromPushNotification'] = true;
                booking!['_pushTransitionTime'] =
                    DateTime.now().millisecondsSinceEpoch;
                foundBooking = true;
                myCustomPrintStatement(
                    '✅ Restored scheduled booking from list: ${booking!['id']}, isSchedule=${booking!['isSchedule']}');
                break;
              }
            }

            // Si pas trouvé dans la liste, chercher directement dans Firebase
            if (!foundBooking) {
              myCustomPrintStatement(
                  '⚠️ Booking not in list, fetching from Firebase...');
              try {
                var doc =
                    await FirestoreServices.bookingRequest.doc(bookingId).get();
                if (doc.exists) {
                  var data = doc.data() as Map<String, dynamic>?;
                  if (data != null) {
                    // 🔧 FIX: Vérifier si le booking a été annulé par le rider
                    final cancelledBy = data['cancelledBy'];
                    final status = data['status'];
                    // Accepte 'customer' (legacy) et 'rider' (canonique post-normalisation 2026-04-19)
                    if (cancelledBy == 'customer' ||
                        cancelledBy == 'rider' ||
                        status == BookingStatusType.CANCELLED.value ||
                        status == BookingStatusType.CANCELLED_BY_RIDER.value) {
                      myCustomPrintStatement(
                          '🛑 Booking $bookingId was cancelled by rider - ignoring push notification');
                      return;
                    }

                    booking = Map<String, dynamic>.from(data);
                    booking!['status'] = BookingStatusType.ACCEPTED.value;
                    booking!['acceptedBy'] = driverId;
                    booking!['isDriverAssigned'] = true;
                    booking!['_fromPushNotification'] = true;
                    booking!['_pushTransitionTime'] =
                        DateTime.now().millisecondsSinceEpoch;
                    foundBooking = true;
                    myCustomPrintStatement(
                        '✅ Restored booking from Firebase: ${booking!['id']}, isSchedule=${booking!['isSchedule']}');
                  }
                }
              } catch (e) {
                myCustomPrintStatement(
                    '❌ Error fetching booking from Firebase: $e');
              }
            }
          } else if (scheduledBookingsList.isNotEmpty) {
            myCustomPrintStatement(
                '🔍 bookingId is null but we have ${scheduledBookingsList.length} scheduled bookings - checking for accepted ones');

            // Check each scheduled booking in Firebase to see if it was accepted
            for (var scheduledBooking in scheduledBookingsList) {
              try {
                myCustomPrintStatement(
                    '🔍 Checking scheduled booking ${scheduledBooking['id']} in Firebase...');
                var doc = await FirestoreServices.bookingRequest
                    .doc(scheduledBooking['id'])
                    .get();
                if (doc.exists) {
                  var firebaseData = doc.data() as Map<String, dynamic>?;
                  if (firebaseData != null && firebaseData['status'] != null) {
                    int firebaseStatus = firebaseData['status'];
                    myCustomPrintStatement(
                        '📊 Scheduled booking ${scheduledBooking['id']} has status: $firebaseStatus (ACCEPTED=${BookingStatusType.ACCEPTED.value})');

                    // If this scheduled booking was accepted
                    if (firebaseStatus >= BookingStatusType.ACCEPTED.value) {
                      booking = Map<String, dynamic>.from(firebaseData);
                      booking!['acceptedBy'] =
                          driverId ?? booking!['acceptedBy'];
                      booking!['isDriverAssigned'] = true;
                      booking!['_fromPushNotification'] = true;
                      booking!['_pushTransitionTime'] =
                          DateTime.now().millisecondsSinceEpoch;
                      foundBooking = true;
                      myCustomPrintStatement(
                          '✅ Found accepted scheduled booking: ${booking!['id']}, status=${booking!['status']}, isSchedule=${booking!['isSchedule']}');
                      break;
                    }
                  }
                } else {
                  myCustomPrintStatement(
                      '⚠️ Scheduled booking ${scheduledBooking['id']} not found in Firebase');
                }
              } catch (e) {
                myCustomPrintStatement(
                    '❌ Error checking scheduled booking ${scheduledBooking['id']}: $e');
              }
            }

            if (foundBooking) {
              myCustomPrintStatement(
                  '🎯 Successfully restored scheduled booking from Firebase query');
            } else {
              myCustomPrintStatement(
                  '⚠️ No accepted scheduled bookings found in Firebase');
            }
          } else {
            // 🔧 FIX: bookingId est null ET scheduledBookingsList est vide
            // Chercher directement dans Firestore un booking accepté ou avec startRide=true
            myCustomPrintStatement(
                '🔍 bookingId is null AND scheduledBookingsList is empty - searching Firestore directly...');
            try {
              // Chercher un booking accepté ou planifié avec chauffeur assigné
              var querySnapshot = await FirestoreServices.bookingRequest
                  .where('requestBy', isEqualTo: userData.value?.id)
                  .where('status', isLessThan: BookingStatusType.CANCELLED.value)
                  .orderBy('status', descending: true)
                  .limit(5)
                  .get();

              for (var doc in querySnapshot.docs) {
                var firebaseData = doc.data() as Map<String, dynamic>;
                int status = firebaseData['status'] ?? 0;
                bool hasDriver = firebaseData['acceptedBy'] != null &&
                    firebaseData['acceptedBy'].toString().isNotEmpty;
                bool startRide = firebaseData['startRide'] == true;

                myCustomPrintStatement(
                    '📊 Found booking ${firebaseData['id']}: status=$status, hasDriver=$hasDriver, startRide=$startRide');

                // Prioriser les bookings avec status >= ACCEPTED ou avec startRide=true
                if (status >= BookingStatusType.ACCEPTED.value ||
                    startRide ||
                    hasDriver) {
                  booking = Map<String, dynamic>.from(firebaseData);
                  booking!['acceptedBy'] = driverId ?? booking!['acceptedBy'];
                  booking!['isDriverAssigned'] = true;
                  booking!['_fromPushNotification'] = true;
                  booking!['_pushTransitionTime'] =
                      DateTime.now().millisecondsSinceEpoch;
                  foundBooking = true;
                  myCustomPrintStatement(
                      '✅ Found active booking from Firestore: ${booking!['id']}, status=${booking!['status']}, isSchedule=${booking!['isSchedule']}, startRide=${booking!['startRide']}');
                  break;
                }
              }

              if (!foundBooking) {
                myCustomPrintStatement(
                    '⚠️ No active bookings found in Firestore for user');
              }
            } catch (e) {
              myCustomPrintStatement(
                  '❌ Error searching Firestore for active booking: $e');
            }
          }

          // En dernier recours, créer un booking minimal avec isSchedule
          if (!foundBooking) {
            // Si on a un bookingId, essayer une dernière fois de le récupérer depuis Firebase
            if (bookingId != null) {
              try {
                myCustomPrintStatement(
                    '🔍 Last attempt: Fetching booking $bookingId directly from Firebase...');
                var doc =
                    await FirestoreServices.bookingRequest.doc(bookingId).get();
                if (doc.exists) {
                  var firebaseData = doc.data() as Map<String, dynamic>?;
                  if (firebaseData != null) {
                    // 🔧 FIX: Vérifier si le booking a été annulé par le rider
                    final cancelledBy = firebaseData['cancelledBy'];
                    final status = firebaseData['status'];
                    // Accepte 'customer' (legacy) et 'rider' (canonique post-normalisation 2026-04-19)
                    if (cancelledBy == 'customer' ||
                        cancelledBy == 'rider' ||
                        status == BookingStatusType.CANCELLED.value ||
                        status == BookingStatusType.CANCELLED_BY_RIDER.value) {
                      myCustomPrintStatement(
                          '🛑 Booking $bookingId was cancelled by rider (last attempt) - ignoring push notification');
                      return;
                    }

                    booking = Map<String, dynamic>.from(firebaseData);
                    booking!['_fromPushNotification'] = true;
                    booking!['_pushTransitionTime'] =
                        DateTime.now().millisecondsSinceEpoch;
                    foundBooking = true;
                    myCustomPrintStatement(
                        '✅ Successfully fetched complete booking from Firebase: ${booking!['id']}, acceptedBy=${booking!['acceptedBy']}');
                  }
                }
              } catch (e) {
                myCustomPrintStatement(
                    '❌ Error in last attempt to fetch booking: $e');
              }
            }

            // Si toujours pas trouvé, créer un booking minimal
            if (!foundBooking) {
              booking = <String, dynamic>{
                'id': bookingId ??
                    'temp_${DateTime.now().millisecondsSinceEpoch}',
                'status': BookingStatusType.ACCEPTED.value,
                'acceptedBy': driverId,
                'isDriverAssigned': true,
                'isSchedule':
                    data['isSchedule'] ?? data['is_scheduled'] ?? false,
                'startRide':
                    false, // Important : par défaut false pour les bookings temporaires
                '_fromPushNotification': true,
                '_pushTransitionTime': DateTime.now().millisecondsSinceEpoch,
                '_temporaryBooking': true, // Marquer comme temporaire
              };
              myCustomPrintStatement(
                  '📦 Created minimal booking from push: ${booking!['id']}, isSchedule=${booking!['isSchedule']}, startRide=${booking!['startRide']}');
            }
          }
        }
      }

      if (statusRaw == null) {
        myCustomPrintStatement('⚠️ applyBookingStatusFromPush: missing status');
        myCustomPrintStatement(
            '🔥 === PUSH NOTIFICATION DEBUG END (EARLY RETURN) ===');
        return;
      }

      myCustomPrintStatement(
          '📨 Push notification received: bookingId=$bookingId, status=$statusRaw');
      myCustomPrintStatement('🔥 Driver ID: $driverId');

      // CRITICAL FIX: Don't create fake bookings for push notifications
      // If no current booking exists, try to find scheduled bookings first
      if (booking == null) {
        myCustomPrintStatement(
            '🛑 CRITICAL: No active booking found for push notification');

        // Try to find a scheduled booking that matches this notification
        bool foundScheduledBooking = false;
        if (bookingId != null) {
          for (var scheduledBooking in scheduledBookingsList) {
            if (scheduledBooking['id'] == bookingId) {
              myCustomPrintStatement(
                  '✅ Found matching scheduled booking: $bookingId');
              booking = Map<String, dynamic>.from(scheduledBooking);
              foundScheduledBooking = true;
              break;
            }
          }
        }

        if (!foundScheduledBooking) {
          myCustomPrintStatement('   No matching scheduled booking found in local list');

          // 🔧 FIX: Si bookingId est fourni, chercher dans Firestore
          // Cela permet de restaurer le booking quand l'app était en arrière-plan
          if (bookingId != null && bookingId.isNotEmpty) {
            myCustomPrintStatement('🔍 Searching for booking $bookingId in Firestore...');
            try {
              var bookingDoc = await FirestoreServices.bookingRequest.doc(bookingId).get();
              if (bookingDoc.exists) {
                var bookingData = bookingDoc.data() as Map<String, dynamic>;

                // Vérifier que ce booking appartient à l'utilisateur actuel
                if (bookingData['requestBy'] == userData.value?.id) {
                  myCustomPrintStatement('✅ Found booking in Firestore: $bookingId');
                  booking = Map<String, dynamic>.from(bookingData);
                  foundScheduledBooking = true;

                  // Sauvegarder localement pour persistance
                  DevFestPreferences prefs = DevFestPreferences();
                  await prefs.saveActiveBooking(bookingData);

                  // Restaurer pickLocation et dropLocation
                  if (bookingData['pickLat'] != null && bookingData['pickLng'] != null) {
                    pickLocation = {
                      'lat': bookingData['pickLat'],
                      'lng': bookingData['pickLng'],
                      'address': bookingData['pickAddress'] ?? '',
                    };
                  }
                  if (bookingData['dropLat'] != null && bookingData['dropLng'] != null) {
                    dropLocation = {
                      'lat': bookingData['dropLat'],
                      'lng': bookingData['dropLng'],
                      'address': bookingData['dropAddress'] ?? '',
                    };
                  }
                } else {
                  myCustomPrintStatement('⚠️ Booking $bookingId does not belong to current user');
                }
              } else {
                myCustomPrintStatement('⚠️ Booking $bookingId not found in Firestore');
              }
            } catch (e) {
              myCustomPrintStatement('❌ Error fetching booking from Firestore: $e');
            }
          } else {
            // 🔧 FIX: Si pas de bookingId, chercher le booking actif de l'utilisateur dans Firestore
            myCustomPrintStatement('🔍 No bookingId provided, searching for active booking in Firestore...');
            try {
              // D'abord chercher les bookings avec status >= ACCEPTED
              var querySnapshot = await FirestoreServices.bookingRequest
                  .where('requestBy', isEqualTo: userData.value?.id)
                  .where('status', isGreaterThanOrEqualTo: BookingStatusType.ACCEPTED.value)
                  .where('status', isLessThanOrEqualTo: BookingStatusType.DESTINATION_REACHED.value)
                  .limit(1)
                  .get();

              if (querySnapshot.docs.isNotEmpty) {
                var bookingData = querySnapshot.docs.first.data() as Map<String, dynamic>;
                myCustomPrintStatement('✅ Found active booking in Firestore: ${bookingData['id']}');
                booking = Map<String, dynamic>.from(bookingData);
                foundScheduledBooking = true;
              } else {
                // 🔧 FIX: Si pas trouvé, chercher les bookings planifiés avec startRide=true ou acceptedBy non null
                myCustomPrintStatement('🔍 No accepted booking found, checking scheduled bookings with startRide=true or acceptedBy...');

                var scheduledQuery = await FirestoreServices.bookingRequest
                    .where('requestBy', isEqualTo: userData.value?.id)
                    .where('isSchedule', isEqualTo: true)
                    .where('status', isLessThan: BookingStatusType.CANCELLED.value)
                    .orderBy('status')
                    .orderBy('scheduleTime', descending: true)
                    .limit(5)
                    .get();

                for (var doc in scheduledQuery.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  // Prioriser les bookings avec startRide=true ou acceptedBy non null
                  if (data['startRide'] == true ||
                      (data['acceptedBy'] != null && data['acceptedBy'].toString().isNotEmpty)) {
                    myCustomPrintStatement('✅ Found scheduled booking with driver assigned: ${data['id']}, startRide=${data['startRide']}, acceptedBy=${data['acceptedBy']}');
                    booking = Map<String, dynamic>.from(data);
                    foundScheduledBooking = true;
                    break;
                  }
                }

                if (!foundScheduledBooking) {
                  myCustomPrintStatement('⚠️ No active or scheduled booking found in Firestore for user');
                }
              }

              if (foundScheduledBooking && booking != null) {
                // Sauvegarder localement pour persistance
                DevFestPreferences prefs = DevFestPreferences();
                await prefs.saveActiveBooking(Map<String, dynamic>.from(booking!));

                // Restaurer pickLocation et dropLocation
                if (booking!['pickLat'] != null && booking!['pickLng'] != null) {
                  pickLocation = {
                    'lat': booking!['pickLat'],
                    'lng': booking!['pickLng'],
                    'address': booking!['pickAddress'] ?? '',
                  };
                }
                if (booking!['dropLat'] != null && booking!['dropLng'] != null) {
                  dropLocation = {
                    'lat': booking!['dropLat'],
                    'lng': booking!['dropLng'],
                    'address': booking!['dropAddress'] ?? '',
                  };
                }
              }
            } catch (e) {
              myCustomPrintStatement('❌ Error searching for active booking: $e');
            }
          }
        }

        if (!foundScheduledBooking) {
          myCustomPrintStatement(
              '   This could be a stale notification or for a different session');
          myCustomPrintStatement(
              '   Ignoring push notification to prevent fake transitions');
          myCustomPrintStatement(
              '🔥 === PUSH NOTIFICATION DEBUG END (NO BOOKING) ===');
          return; // Don't process push notifications without active booking
        }
      }

      // Set booking id from push if missing
      if (bookingId != null) {
        booking!['id'] = bookingId;
      }

      // Map backend status string to internal enum/int value when applicable
      final statusStr = statusRaw.toString();
      final int? mapped = _mapStatusStringToEnumValue(statusStr);
      final int newStatus = mapped ?? BookingStatusType.ACCEPTED.value;

      // Store previous status to detect changes
      final int? previousStatus = booking!['status'];
      booking!['status'] = newStatus;

      // Add driver information if available
      if (driverId != null) {
        booking!['acceptedBy'] = driverId;
        booking!['isDriverAssigned'] = true;
        myCustomPrintStatement('🚗 Driver assigned: $driverId');
      }

      // Populate essential booking fields from push notification data or defaults
      // These fields are required by the DriverOnWay widget to render properly
      booking!['ride_price_to_pay'] ??=
          data['ride_price_to_pay'] ?? data['price'] ?? '0';
      booking!['paymentMethod'] ??=
          data['paymentMethod'] ?? data['payment_method'] ?? 'cash';
      booking!['pickLat'] ??= data['pickLat'] ?? data['pickup_lat'] ?? 0.0;
      booking!['pickLng'] ??= data['pickLng'] ?? data['pickup_lng'] ?? 0.0;
      booking!['dropLat'] ??= data['dropLat'] ?? data['drop_lat'] ?? 0.0;
      booking!['dropLng'] ??= data['dropLng'] ?? data['drop_lng'] ?? 0.0;
      booking!['pickAddress'] ??=
          data['pickAddress'] ?? data['pickup_address'] ?? 'Adresse de prise en charge';
      booking!['dropAddress'] ??=
          data['dropAddress'] ?? data['drop_address'] ?? 'Destination';
      booking!['vehicle'] ??=
          data['vehicle'] ?? data['vehicle_type'] ?? 'standard';

      myCustomPrintStatement(
          '📋 Booking fields populated: price=${booking!['ride_price_to_pay']}, payment=${booking!['paymentMethod']}');

      myCustomPrintStatement(
          '🔄 Status update: $previousStatus -> $newStatus for booking $bookingId');

      // Handle status transitions - CRITICAL SECTION
      if (newStatus == BookingStatusType.CANCELLED.value) {
        // Ride was cancelled (by driver or system)
        myCustomPrintStatement('❌ Ride cancelled notification received!');

        // CRITIQUE: Sauvegarder les infos d'annulation AVANT clearAllTripData
        final String? cancelledBy = data['cancelledBy'] ?? booking?['cancelledBy'];
        myCustomPrintStatement('🔍 Cancellation source: $cancelledBy');

        // 🔧 FIX: Vérifier si la course existe encore dans Firestore (réassignable)
        // Si oui, c'est un désistement du chauffeur, pas une annulation définitive
        bool isReassignable = false;
        if (bookingId != null && bookingId.isNotEmpty) {
          try {
            final bookingDoc = await FirestoreServices.bookingRequest.doc(bookingId).get();
            if (bookingDoc.exists) {
              final bookingData = bookingDoc.data() as Map<String, dynamic>?;
              // La course existe encore et acceptedBy est null/vide → réassignable
              if (bookingData != null &&
                  (bookingData['acceptedBy'] == null || bookingData['acceptedBy'] == '')) {
                isReassignable = true;
                myCustomPrintStatement('🔄 Course encore dans Firestore avec acceptedBy=null → réassignable');
              }
            }
          } catch (e) {
            myCustomPrintStatement('⚠️ Erreur vérification réassignabilité: $e');
          }
        }

        if (isReassignable) {
          // C'est un désistement du chauffeur, la course peut être réassignée
          bool isScheduledBooking = booking?['isSchedule'] == true;

          if (isScheduledBooking) {
            // 🔧 FIX: Pour les courses planifiées, gérer selon l'état actuel
            myCustomPrintStatement('🔄 Driver withdrew from SCHEDULED booking (push) - currentStep: $currentStep');

            // Capturer le nom du chauffeur AVANT de le réinitialiser
            final String withdrawnDriverName = acceptedDriver?.fullName ?? '';

            // Activer le flag pour bloquer pendingRequestFunctionality
            _scheduledBookingAwaitingReassignment = true;

            // Mettre à jour uniquement les données locales
            booking!['acceptedBy'] = null;
            acceptedDriver = null;

            // 🔧 FIX: Si on était sur driverOnWay (le chauffeur avait confirmé), revenir à setYourDestination
            // car l'écran driverOnWay a besoin des infos chauffeur pour fonctionner
            if (currentStep == CustomTripType.driverOnWay) {
              myCustomPrintStatement('🔄 Retour à setYourDestination car le chauffeur s\'est désisté pendant driverOnWay (push)');
              currentStep = CustomTripType.setYourDestination;
              // Réinitialiser startRide localement car le chauffeur s'est désisté
              booking!['startRide'] = false;
              notifyListeners();
            }

            // Afficher une SnackBar pour informer l'utilisateur
            Future.microtask(() {
              try {
                if (MyGlobalKeys.navigatorKey.currentContext != null) {
                  String message;
                  if (withdrawnDriverName.isNotEmpty) {
                    message = translate('driverUnavailableNewAssignment')
                        .replaceAll('{driverName}', withdrawnDriverName);
                  } else {
                    message = translate('driverWithdrewSearchingNew');
                  }

                  ScaffoldMessenger.of(MyGlobalKeys.navigatorKey.currentContext!)
                      .showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                myCustomPrintStatement('⚠️ Could not show driver withdrew notification: $e');
              }
            });

            return; // Sortir de la fonction sans rien faire de plus
          }

          myCustomPrintStatement('🔄 Driver withdrew from IMMEDIATE booking - going to requestForRide');

          // Capturer le nom du chauffeur AVANT de le réinitialiser
          final String withdrawnDriverName = acceptedDriver?.fullName ?? '';

          // Mettre à jour le booking local avec les données fraîches
          booking!['acceptedBy'] = null;
          acceptedDriver = null;

          // Retourner à l'écran approprié pour les courses immédiates uniquement
          currentStep = CustomTripType.requestForRide;
          notifyListeners();

          // Afficher le message uniquement pour les courses immédiates
          Future.microtask(() {
            try {
              if (MyGlobalKeys.navigatorKey.currentContext != null &&
                  !_userCancelledManually) {
                // Utiliser le message personnalisé avec le nom du chauffeur si disponible
                String message;
                if (withdrawnDriverName.isNotEmpty) {
                  message = translate('driverUnavailableNewAssignment')
                      .replaceAll('{driverName}', withdrawnDriverName);
                } else {
                  message = translate('driverWithdrewSearchingNew');
                }

                ScaffoldMessenger.of(MyGlobalKeys.navigatorKey.currentContext!)
                    .showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              _userCancelledManually = false;
              MyGlobalKeys.homePageKey.currentState
                  ?.updateBottomSheetHeight(milliseconds: 100);
            } catch (e) {
              myCustomPrintStatement('⚠️ Could not show driver withdrew notification: $e');
            }
          });
        } else {
          // Annulation définitive - purger les données
          myCustomPrintStatement('❌ Ride definitively cancelled! Resetting to initial state');

          // CRITIQUE: Purge complète des données de trip pour éviter les rebuilds infinis
          await clearAllTripData();
          myCustomPrintStatement('✅ clearAllTripData() terminé - booking supprimé de la mémoire');

          // Reset state
          currentStep = CustomTripType.setYourDestination;
          myCustomPrintStatement('From: (previous step) → To: ${currentStep.toString().split('.').last}');

          // Reset navigation bar visibility
          try {
            final navigationProvider = Provider.of<NavigationProvider>(
                MyGlobalKeys.navigatorKey.currentContext!,
                listen: false);
            navigationProvider.setNavigationBarVisibility(true);
          } catch (e) {
            myCustomPrintStatement(
                '⚠️ Could not reset navigation bar visibility: $e');
          }

          // Update UI (clearAllTripData already called notifyListeners, but safe to call again)
          notifyListeners();

          // Show cancellation notification based on who cancelled (sauf si l'utilisateur a annulé manuellement)
          Future.microtask(() {
            try {
              if (MyGlobalKeys.navigatorKey.currentContext != null &&
                  !_userCancelledManually) {
                // Determine if cancellation was by user or driver
                // Accepte 'customer' (legacy) et 'rider' (canonique post-normalisation 2026-04-19)
                String cancellationMessage;
                if (cancelledBy == 'customer' || cancelledBy == 'rider') {
                  cancellationMessage = translate('Trip was cancelled by you');
                } else {
                  cancellationMessage = translate('Trip was cancelled by driver');
                }

                ScaffoldMessenger.of(MyGlobalKeys.navigatorKey.currentContext!)
                    .showSnackBar(
                  SnackBar(
                    content: Text(cancellationMessage),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              // Réinitialiser le flag après utilisation
              _userCancelledManually = false;
              MyGlobalKeys.homePageKey.currentState
                  ?.updateBottomSheetHeight(milliseconds: 100);
            } catch (e) {
              myCustomPrintStatement(
                  '⚠️ Could not show cancellation notification: $e');
            }
          });
        }
      } else if (newStatus >= BookingStatusType.ACCEPTED.value) {
        // Driver has accepted the ride
        if (previousStatus == null ||
            previousStatus < BookingStatusType.ACCEPTED.value) {
          myCustomPrintStatement(
              '✅ Driver accepted! Checking if should transition to driverOnWay state');

          // 🔧 FIX: Pour les courses planifiées, ne transitionner vers driverOnWay
          // que si startRide=true (le chauffeur a démarré, pas juste confirmé)
          bool isScheduledBooking = booking!['isSchedule'] == true;
          bool startRideIsTrue = booking!['startRide'] == true;

          if (isScheduledBooking && !startRideIsTrue) {
            // Course planifiée: le chauffeur a CONFIRMÉ mais pas DÉMARRÉ
            // Ne pas transitionner vers driverOnWay
            myCustomPrintStatement(
                '📅 Course planifiée confirmée (startRide=false) - pas de transition vers driverOnWay');
            // Juste mettre à jour les données et notifier
            booking!['_fromPushNotification'] = true;
            notifyListeners();
            return; // Ne pas continuer avec le flow driverOnWay
          }

          myCustomPrintStatement(
              '🚗 Transitioning to driverOnWay - isScheduled: $isScheduledBooking, status: $newStatus');
          _safeSetDriverOnWay(
              source: 'applyBookingStatusFromPush-transition');

          // Mark that this came from push to prevent stream override
          booking!['_fromPushNotification'] = true;
          booking!['_pushTransitionTime'] =
              DateTime.now().millisecondsSinceEpoch;

          // Update UI immediately BEFORE async operations
          notifyListeners();

          // Update bottom sheet height immediately
          Future.microtask(() {
            try {
              MyGlobalKeys.homePageKey.currentState
                  ?.updateBottomSheetHeight(milliseconds: 100);
            } catch (e) {
              myCustomPrintStatement(
                  '⚠️ Could not update bottom sheet height: $e');
            }
          });

          // Trigger the acceptance flow asynchronously but don't let it change the screen
          Future.microtask(() async {
            try {
              myCustomPrintStatement('🔄 Starting driver acceptance flow...');

              // Ensure we still have the correct screen state
              if (currentStep != CustomTripType.driverOnWay) {
                myCustomPrintStatement(
                    '⚠️ Screen state changed during async, forcing back to driverOnWay');
                _safeSetDriverOnWay(
                    source: 'applyBookingStatusFromPush-async-correction');
                notifyListeners();
              }

              await afterAcceptFunctionality();
              myCustomPrintStatement('✅ Driver acceptance flow completed');
            } catch (e) {
              myCustomPrintStatement('❌ Error in afterAcceptFunctionality: $e');
            }
          });
        } else {
          // Status update for already accepted ride
          myCustomPrintStatement('🔄 Updating already accepted ride status');

          // Apply same logic for status updates
          bool isScheduledBooking = booking!['isSchedule'] == true;
          bool rideHasStarted =
              newStatus >= BookingStatusType.RIDE_STARTED.value;
          bool startRideIsTrue = booking!['startRide'] == true;
          bool isTemporaryBooking = booking!['_temporaryBooking'] == true;

          // 🔧 FIX: Pour les courses planifiées, ne transitionner vers driverOnWay
          // que si startRide=true (le chauffeur a démarré la course, pas juste confirmé)
          bool shouldTransition;
          if (isTemporaryBooking) {
            // Les bookings temporaires ne doivent jamais déclencher de transition automatique
            shouldTransition = false;
          } else if (isScheduledBooking && !startRideIsTrue) {
            // Course planifiée: le chauffeur a CONFIRMÉ mais pas DÉMARRÉ
            // Ne pas transitionner vers driverOnWay, rester sur l'écran d'accueil
            shouldTransition = false;
            myCustomPrintStatement(
                '📅 Course planifiée confirmée (startRide=false) - pas de transition vers driverOnWay');
          } else {
            // Courses immédiates OU planifiées avec startRide=true: transitionner
            shouldTransition = true;
          }

          myCustomPrintStatement(
              '🔍 Push status update - isScheduled: $isScheduledBooking, isTemporary: $isTemporaryBooking, rideStarted: $rideHasStarted, startRide: $startRideIsTrue, shouldTransition: $shouldTransition');

          if (shouldTransition) {
            myCustomPrintStatement(
                '🚗 Status update - transitioning to driverOnWay (isScheduled: $isScheduledBooking)');
            _safeSetDriverOnWay(
                source: 'applyBookingStatusFromPush-status-update');
          } else {
            myCustomPrintStatement(
                '⏸️ Status update - not transitioning (temporary or scheduled without startRide)');
          }
        }
      }

      // Final UI update
      notifyListeners();

      myCustomPrintStatement(
          '✅ applyBookingStatusFromPush completed: id=$bookingId status=$statusStr -> $newStatus, currentStep=$currentStep');
    } catch (e) {
      myCustomPrintStatement('❌ applyBookingStatusFromPush error: $e');
    }
  }

  /// Convert backend status strings to internal enum/int values if your app uses numeric enums
  int? _mapStatusStringToEnumValue(String status) {
    try {
      if (status == 'PENDING_REQUEST')
        return BookingStatusType.PENDING_REQUEST.value;
      if (status == 'ACCEPTED') return BookingStatusType.ACCEPTED.value;
      if (status == 'DRIVER_ACCEPTED')
        return BookingStatusType.ACCEPTED.value; // Map to ACCEPTED
      if (status == 'DRIVER_ASSIGNED')
        return BookingStatusType.ACCEPTED.value; // Map to ACCEPTED
      if (status == 'DRIVER_REACHED')
        return BookingStatusType.DRIVER_REACHED.value;
      if (status == 'RIDE_STARTED' || status == 'TRIP_STARTED')
        return BookingStatusType.RIDE_STARTED.value;
      if (status == 'RIDE_COMPLETE' || status == 'RIDE_COMPLETED' || status == 'TRIP_COMPLETED')
        return BookingStatusType.RIDE_COMPLETE.value;
      if (status == 'TRIP_CANCELLED' || status == 'RIDE_CANCELLED')
        return BookingStatusType.CANCELLED.value; // Map to CANCELLED
    } catch (_) {}
    return null; // Unknown or already the correct type/string handled by UI
  }

  scheduledBookingListener() async {
    // Guard contre userData null
    if (userData.value == null) {
      myCustomPrintStatement('⚠️ scheduledBookingListener: userData null, skip');
      return;
    }

    scheduledBookingStream = FirestoreServices.bookingRequest
        .where('requestBy', isEqualTo: userData.value!.id)
        .where('status', whereIn: [
          BookingStatusType.PENDING_REQUEST.value,
          BookingStatusType.ACCEPTED.value
        ])
        .where('isSchedule', isEqualTo: true)
        .orderBy('scheduleTime', descending: false)
        .snapshots();
    scheduledBookingStreamSub = scheduledBookingStream!.listen((event) async {
      scheduledBookingsList.clear();

      if (event.docs.isNotEmpty) {
        myCustomPrintStatement(
            "scheduled booking called---------new-------------${event.docs.first.id}");
        for (var i = 0; i < event.docs.length; i++) {
          var bookingData = event.docs[i].data() as Map;

          scheduledBookingsList.add(bookingData);
        }
      }
      notifyListeners();
    });
  }

  disposeScheduledBookingListener() {
    scheduledBookingStreamSub!.cancel();
    myCustomPrintStatement("scheduled booking lisner disposed");
  }

  /// Démarre un listener spécifique sur le booking actif pour détecter sa suppression
  /// Utilisé pour le paiement cash : quand le driver confirme le paiement, il supprime le booking
  void _startActiveBookingDeletionListener() {
    if (booking == null) {
      myCustomPrintStatement("⚠️ Impossible de démarrer le listener : booking null");
      return;
    }

    // Annuler le listener précédent s'il existe
    _activeBookingListener?.cancel();

    String bookingId = booking!['id'];
    myCustomPrintStatement(
        "🎧 Démarrage du listener de suppression pour booking: $bookingId");

    // Écouter les changements sur ce document spécifique
    _activeBookingListener = FirestoreServices.bookingRequest
        .doc(bookingId)
        .snapshots()
        .listen((snapshot) {
      myCustomPrintStatement(
          "📡 Listener booking actif - exists: ${snapshot.exists}, bookingId: $bookingId");

      // Si le document n'existe plus, le driver a confirmé le paiement
      if (!snapshot.exists) {
        myCustomPrintStatement(
            "🎉 BOOKING SUPPRIMÉ DÉTECTÉ ! Le driver a confirmé le paiement cash.");
        myCustomPrintStatement(
            "   → Navigation vers l'écran de notation...");

        // Annuler ce listener
        _activeBookingListener?.cancel();
        _activeBookingListener = null;

        // Déclencher checkAndReset() qui naviguera vers RateUsScreen
        checkAndReset();
      }
    }, onError: (error) {
      myCustomPrintStatement("❌ Erreur dans le listener booking actif: $error");
    });
  }

  /// Arrête le listener de suppression du booking actif
  void _stopActiveBookingDeletionListener() {
    if (_activeBookingListener != null) {
      _activeBookingListener!.cancel();
      _activeBookingListener = null;
      myCustomPrintStatement("🛑 Listener de suppression du booking arrêté");
    }
  }

  checkAndReset() async {
    myCustomPrintStatement(
        "mizan--------------------------------booking deleted due to complete/cancel/2 minute pending");
    myCustomPrintStatement('booking not = null');
    if (booking != null) {
      if (booking!['status'] == BookingStatusType.PENDING_REQUEST.value) {
        myCustomPrintStatement(
            'mizan----------------booking deleting--------------------${booking!['id']}---');
        await FirestoreServices.bookingRequest.doc(booking!['id']).delete();
        // Note: Le message "noDriverFound" est déjà affiché dans createRequest()
        // quand aucun chauffeur n'est trouvé. Ne pas l'afficher ici car checkAndReset()
        // peut être appelé pour d'autres raisons (timeout, nettoyage, etc.)
      }
      MyGlobalKeys.homePageKey.currentState?.updateBottomSheetHeight();
      if (booking?['status'] == BookingStatusType.RIDE_COMPLETE.value) {
        myCustomPrintStatement(
            'mizan---------------dleted after ride complete--------------------${booking!['id']}---');
        Map b = {
          "booking_id": booking!['id'],
          "userId": acceptedDriver!.id,
          "profile": acceptedDriver!.profileImage,
          "name": acceptedDriver!.fullName,
          "review_count": acceptedDriver!.totalReveiwCount,
          "rating": acceptedDriver!.averageRating,
          "deviceId": acceptedDriver!.deviceIdList,
          "preferedLanguage": acceptedDriver!.preferedLanguage
        };
        myCustomLogStatements("no booking exists--before ${currentStep}");
        if (currentStep == CustomTripType.orangeMoneyPayment) {
          popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
        }
        push(
            context: MyGlobalKeys.navigatorKey.currentContext!,
            screen: RateUsScreen(booking: b));

        // Traiter les points de fidélité après une course terminée
        _processLoyaltyPoints();
      }
    }

    myCustomPrintStatement("no booking exists--before reset all------------");
    resetAll();
  }

  // Future<void> completeRide({bool cancleRide = false}) async {
  //   Map<String, dynamic> data = {};
  //   data['status'] = BookingStatusType.RIDE_COMPLETE.value;
  //   data['total_distance'] = double.parse(
  //       calculateDistanceByArray(booking!['coveredPath']).toStringAsFixed(2));
  //   data['waiting_time_charge'] =
  //       (double.parse(booking!['waiting_time_rate_per_min'].toString()) *
  //               double.parse((booking!['waiting_time_in_min'] ?? 0).toString()))
  //           .toStringAsFixed(1);
  //   data['ride_amount'] =
  //       (double.parse(booking!['vehicle_price_per_km'].toString()) *
  //               data['total_distance'])
  //           .toStringAsFixed(1);
  //   data['endTime'] = Timestamp.now();
  //   data['total_duration'] = (data['endTime'].toDate())
  //       .difference(booking!['startedTime'].toDate())
  //       .inMinutes;
  //   data['total_amount'] = booking!["price_approx"].toString();
  //   // (double.parse(booking!['vehicle_base_price'].toString()) +
  //   //         double.parse(data['ride_amount'].toString()) +
  //   //         double.parse(
  //   //               data['total_duration'].toString(),
  //   //             ) *
  //   //             double.parse(
  //   //                 (booking!['vehicle_price_per_min'] ?? 0).toString()))
  //   //     .toStringAsFixed(1);
  //   // (double.parse(data['ride_amount']) * booking!['surcharge'] +
  //   //         booking!['vehicle_base_price'] * booking!['surcharge'] +
  //   //         double.parse(data['waiting_time_charge']))
  //   //     .toStringAsFixed(1);

  //   data['admin_commission_in_per'] = "0";
  //   data['admin_commission'] = "0";
  //   // data['driver_earning'] = (double.parse(data['total_amount']) -
  //   //         double.parse(data['admin_commission']))
  //   //     .toStringAsFixed(1);
  //   data['ride_status'] = cancleRide ? "Cancelled" : "Completed";
  //   if (cancleRide) {
  //     data['ride_cancelled_by'] = "Rider";
  //   }
  //   // data!['id'] = FirestoreServices.bookingHistory.doc().id;
  //   // booking!['id'] = FirestoreServices.bookingHistory.doc().id;
  //   FirestoreServices.bookingRequest.doc(booking!['id']).update(data);
  //   if (cancleRide) {
  //   } else {
  //     FirebasePushNotifications.sendPushNotifications(
  //       deviceIds: userData.value!.deviceIdList,
  //       data: {
  //         'screen': 'ride_completed',
  //       },
  //       body: translate(
  //         "yourRideHasCompleted",
  //       ),
  //       title: translate(
  //         "rideCompleted",
  //       ),
  //       userId: userData.value!.id,
  //     );
  //   }
  // }

  resetAll() {
    var mapProvider = Provider.of<GoogleMapProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false);
    booking = null;

    // 🔧 FIX: Annuler le timer de retry pendingRequest pour éviter la recréation de la course
    _pendingRequestRetryTimer?.cancel();
    _pendingRequestRetryTimer = null;

    // Supprimer la sauvegarde locale
    DevFestPreferences prefs = DevFestPreferences();
    prefs.clearActiveBooking();

    // Arrêter le listener de suppression du booking actif
    _stopActiveBookingDeletionListener();

    rideScheduledTime = null;
    firstTimeAtApp = true;
    firstTimeBookingAtApp = true;

    // approxDistance=0;
    currentStep = CustomTripType.setYourDestination;
    myCustomPrintStatement(
        "current screne----------------------------$currentStep");

    // Arrêter le booking stream listener pour éviter la restauration automatique
    if (_bookingStreamSubscription != null) {
      _bookingStreamSubscription!.cancel();
      _bookingStreamSubscription = null;
      bookingStream = null;
      myCustomPrintStatement('🛑 Booking stream annulé dans resetAll()');
    }

    pickLocation = null;
    dropLocation = null;
    showCancelButton = true;

    // Nettoyer complètement toutes les polylines et l'état de la carte
    mapProvider.clearAllPolylines();
    mapProvider.hideMarkers();
    acceptedDriver = null;

    // Réinitialiser les variables de zoom adaptatif
    _lastDriverToPickupDistance = null;
    _lastAdaptiveZoomUpdate = null;

    selectedVehicle = null;
    selectedPromoCode = null;
    paymentMethodDiscountAmount = 0;
    paymentMethodDiscountPercentage = 0;

    // Nettoyer les données de partage en temps réel
    _cleanupLiveShareOnRideComplete();

    mapProvider.controller!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
          target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
          zoom: 13.80,
          bearing: 0,
          tilt: 0),
    ));
    notifyListeners();
    mapProvider.notifyListeners();
    if (MyGlobalKeys.homePageKey.currentState != null) {
      MyGlobalKeys.homePageKey.currentState!.updateBottomSheetHeight();
    }
  }

  /// Reset tout SAUF les données des courses planifiées
  /// Cette méthode est utilisée après la création d'une course planifiée
  /// pour nettoyer l'interface tout en gardant le listener actif
  resetAllExceptScheduled() {
    var mapProvider = Provider.of<GoogleMapProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false);

    // IMPORTANT: On doit mettre booking à null pour que le listener
    // puisse détecter la course transformée comme une nouvelle course
    booking = null;
    // NE PAS réinitialiser bookingStream - garde le listener actif
    // NE PAS vider scheduledBookingsList - garde la liste des courses planifiées

    // Arrêter le listener de suppression du booking actif
    _stopActiveBookingDeletionListener();

    rideScheduledTime = null;
    firstTimeAtApp = true;
    firstTimeBookingAtApp = true;

    // approxDistance=0;
    currentStep = CustomTripType.setYourDestination;
    myCustomPrintStatement(
        "resetAllExceptScheduled - keeping scheduled booking data");

    pickLocation = null;
    dropLocation = null;
    showCancelButton = true;

    // Nettoyer complètement toutes les polylines et l'état de la carte
    mapProvider.clearAllPolylines();
    mapProvider.hideMarkers();
    acceptedDriver = null;

    // Réinitialiser les variables de zoom adaptatif
    _lastDriverToPickupDistance = null;
    _lastAdaptiveZoomUpdate = null;

    selectedVehicle = null;
    selectedPromoCode = null;
    paymentMethodDiscountAmount = 0;
    paymentMethodDiscountPercentage = 0;

    // Nettoyer les données de partage en temps réel
    _cleanupLiveShareOnRideComplete();

    mapProvider.controller!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
          target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
          zoom: 13.80,
          bearing: 0,
          tilt: 0),
    ));
    notifyListeners();
    mapProvider.notifyListeners();
    if (MyGlobalKeys.homePageKey.currentState != null) {
      MyGlobalKeys.homePageKey.currentState!.updateBottomSheetHeight();
    }
  }

  getUnreadCount() {
    // booking!['unreadCount'] = 0;
    //
    // if (booking!['chats'] != null) {
    //     if (booking!['chats'].length > 0) {
    //         for (int i = 0; i < booking!['chats'].length; i++) {
    //             if (booking!['chats'][i]['sender'] != userData!.id) {
    //                 if (booking!['chats'][i]['read_by_receiver'] == false) {
    //                     booking!['unreadCount']++;
    //                 }
    //             }
    //         }
    //     }
    // }
  }

  Future pendingRequestFunctionality() async {
    myCustomPrintStatement("pending request functionality------------");

    // 🔧 FIX: Ne rien faire si une course planifiée attend un nouveau chauffeur
    if (_scheduledBookingAwaitingReassignment) {
      myCustomPrintStatement('🛑 pendingRequestFunctionality BLOQUÉ - course planifiée attend un nouveau chauffeur');
      return;
    }

    int currentTimeSecs = Timestamp.now().seconds;
    int deleteRequestedTimeSecs =
        (booking!['requestTime'] as Timestamp).seconds + 30;
    int maxWaitTimeToAccept = deleteRequestedTimeSecs - currentTimeSecs;
    // myCustomPrintStatement('dkdsfjd  ${difference}  ... ${difference<30 } .... ${booking!['acceptedBy']==null}');
    myCustomPrintStatement(
        "request delete time if not accepted - $deleteRequestedTimeSecs ------ seconds to wait - $maxWaitTimeToAccept ");
    if (maxWaitTimeToAccept <= 30) {
      // 🔧 FIX: Ne pas changer d'écran si on est déjà sur requestForRide
      // Cela évite les "sauts" de l'UI lors du redémarrage des notifications séquentielles
      if (currentStep != CustomTripType.requestForRide) {
        setScreen(CustomTripType.requestForRide);
        notifyListeners();
      }
      myCustomPrintStatement('timer delay calling for $maxWaitTimeToAccept seconds');

      // 🔧 FIX: Annuler le timer précédent s'il existe
      _pendingRequestRetryTimer?.cancel();

      // 🔧 FIX: Utiliser un Timer annulable au lieu de Future.delayed
      // Ce timer sera annulé si l'utilisateur annule manuellement la course
      _pendingRequestRetryTimer = Timer(Duration(seconds: maxWaitTimeToAccept), () async {
        // 🔧 FIX: Vérifier que l'utilisateur n'a pas annulé manuellement
        if (_userCancelledManually) {
          myCustomPrintStatement('🛑 Timer retry annulé - utilisateur a annulé manuellement');
          return;
        }

        if (booking?['status'] == BookingStatusType.PENDING_REQUEST.value) {
          myCustomPrintStatement('🔄 Timer retry: recréation de la demande de course...');
          pickLocation = {
            "lat": booking!['pickLat'],
            "lng": booking!['pickLng'],
            "address": booking!['pickAddress'] ?? 'Adresse de prise en charge',
          };
          dropLocation = {
            "lat": booking!['dropLat'],
            "lng": booking!['dropLng'],
            "address": booking!['dropAddress'] ?? 'Destination',
          };
          createRequest(
              vehicleDetails: vehicleMap[booking!["vehicle"]]!,
              paymentMethod: booking!["paymentMethod"],
              pickupLocation: pickLocation,
              dropLocation: dropLocation!,
              isScheduled: booking?['isSchedule'] ?? false,
              scheduleTime: (booking!["scheduleTime"] as Timestamp).toDate(),
              promocodeDetails: booking?['promocodeDetails'],
              bookingId: booking!['id']);
        }
      });
    } else {
      myCustomPrintStatement("delete directoly----");
      await FirestoreServices.bookingRequest.doc(booking!['id']).delete();
      checkAndReset();
    }
  }

  /// 🔄 Met en pause la recherche de chauffeur quand l'app passe en arrière-plan
  /// Appelée depuis HomeScreen.didChangeAppLifecycleState quand state == paused/inactive
  Future<void> pauseDriverSearch() async {
    // Vérifier si on est en recherche active (PENDING_REQUEST ou requestForRide)
    if (booking == null) {
      myCustomPrintStatement('⏸️ pauseDriverSearch: Pas de booking actif - ignoré');
      return;
    }

    int status = booking!['status'] ?? -1;
    bool isSearching = status == BookingStatusType.PENDING_REQUEST.value &&
        currentStep == CustomTripType.requestForRide;

    if (!isSearching) {
      myCustomPrintStatement('⏸️ pauseDriverSearch: Pas en recherche active (status=$status, step=$currentStep) - ignoré');
      return;
    }

    myCustomPrintStatement('⏸️ PAUSE RECHERCHE CHAUFFEUR');
    myCustomPrintStatement('   Booking ID: ${booking!['id']}');
    myCustomPrintStatement('   Status: $status');

    // Sauvegarder l'état actuel pour pouvoir reprendre
    _pausedSearchData = {
      'bookingId': booking!['id'],
      'vehicleId': booking!['vehicle'],
      'paymentMethod': booking!['paymentMethod'],
      'pickLocation': pickLocation,
      'dropLocation': dropLocation,
      'isSchedule': booking!['isSchedule'] ?? false,
      'scheduleTime': booking!['scheduleTime'],
      'promocodeDetails': booking!['promocodeDetails'],
      'pausedAt': DateTime.now().millisecondsSinceEpoch,
    };

    // Annuler les timers de recherche
    _pendingRequestRetryTimer?.cancel();
    _pendingRequestRetryTimer = null;
    _sequentialNotificationTimer?.cancel();
    _sequentialNotificationTimer = null;

    // Supprimer le booking de Firestore pour arrêter la recherche côté serveur
    try {
      await FirestoreServices.bookingRequest.doc(booking!['id']).delete();
      myCustomPrintStatement('🗑️ Booking supprimé de Firestore (recherche pausée)');
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur suppression booking: $e');
    }

    // Marquer comme pausé
    _isSearchPaused = true;
    _searchPausedAt = DateTime.now();

    // NE PAS reset le booking local - on garde les données pour l'affichage
    // Mais on change l'écran pour montrer l'état pausé
    notifyListeners();

    myCustomPrintStatement('✅ Recherche mise en pause avec succès');
  }

  /// 🔄 Reprend la recherche de chauffeur après confirmation utilisateur
  Future<bool> resumeDriverSearch() async {
    if (!_isSearchPaused || _pausedSearchData == null) {
      myCustomPrintStatement('▶️ resumeDriverSearch: Pas de recherche pausée - ignoré');
      return false;
    }

    myCustomPrintStatement('▶️ REPRISE RECHERCHE CHAUFFEUR');
    myCustomPrintStatement('   Données pausées: $_pausedSearchData');

    try {
      // Restaurer les locations
      pickLocation = _pausedSearchData!['pickLocation'];
      dropLocation = _pausedSearchData!['dropLocation'];

      // Récupérer le véhicule
      String vehicleId = _pausedSearchData!['vehicleId'];
      VehicleModal? vehicle = vehicleMap[vehicleId];

      if (vehicle == null) {
        myCustomPrintStatement('❌ Véhicule non trouvé: $vehicleId');
        cancelPausedSearch();
        return false;
      }

      // Recréer la demande
      bool success = await createRequest(
        vehicleDetails: vehicle,
        paymentMethod: _pausedSearchData!['paymentMethod'],
        pickupLocation: pickLocation,
        dropLocation: dropLocation!,
        isScheduled: _pausedSearchData!['isSchedule'] ?? false,
        scheduleTime: _pausedSearchData!['scheduleTime'] != null
            ? (_pausedSearchData!['scheduleTime'] as Timestamp).toDate()
            : null,
        promocodeDetails: _pausedSearchData!['promocodeDetails'],
      );

      if (success) {
        // Nettoyer l'état de pause
        _clearPausedState();
        myCustomPrintStatement('✅ Recherche reprise avec succès');
        return true;
      } else {
        myCustomPrintStatement('❌ Échec de la reprise de recherche');
        return false;
      }
    } catch (e) {
      myCustomPrintStatement('❌ Erreur reprise recherche: $e');
      return false;
    }
  }

  /// 🔄 Annule définitivement la recherche pausée
  void cancelPausedSearch() {
    myCustomPrintStatement('❌ ANNULATION RECHERCHE PAUSÉE');

    _clearPausedState();

    // Reset complet
    resetAll();

    myCustomPrintStatement('✅ Recherche pausée annulée');
  }

  /// Nettoie l'état de pause
  void _clearPausedState() {
    _isSearchPaused = false;
    _searchPausedAt = null;
    _pausedSearchData = null;
    notifyListeners();
  }

  /// Vérifie si la recherche pausée a expiré (plus de 10 minutes)
  bool isPausedSearchExpired() {
    if (!_isSearchPaused || _searchPausedAt == null) return false;

    Duration pauseDuration = DateTime.now().difference(_searchPausedAt!);
    bool expired = pauseDuration.inMinutes > 10;

    if (expired) {
      myCustomPrintStatement('⏰ Recherche pausée expirée après ${pauseDuration.inMinutes} minutes');
    }

    return expired;
  }

  Future afterAcceptFunctionality() async {
    myCustomPrintStatement(
        '🔄 afterAcceptFunctionality called - current screen: $currentStep');

    // Annuler le timer de notification séquentielle car une booking a été acceptée
    _cancelSequentialNotificationTimer();

    // Check if this was triggered by a push notification to avoid screen conflicts
    bool fromPushNotification = booking!['_fromPushNotification'] == true;

    if (booking!['status'] == BookingStatusType.ACCEPTED.value &&
        firstTimeBookingAtApp) {
      showSateftyAlertWidget = true;
      firstTimeBookingAtApp = false;
      notifyListeners();
    }

    // 🔧 FIX: Toujours transitionner vers driverOnWay quand un chauffeur accepte
    // Que ce soit une course planifiée ou immédiate, l'utilisateur doit voir le flow de course
    bool isScheduledBooking = booking!['isSchedule'] == true;
    bool rideHasStarted =
        booking!['status'] >= BookingStatusType.RIDE_STARTED.value;

    myCustomPrintStatement(
        '📱 afterAcceptFunctionality - isScheduled: $isScheduledBooking, rideStarted: $rideHasStarted, fromPush: $fromPushNotification');

    // Guard: ne pas re-déclencher setScreen si on est déjà sur driverOnWay
    if (currentStep == CustomTripType.driverOnWay) {
      myCustomPrintStatement(
          '⏭️ afterAcceptFunctionality: déjà sur driverOnWay - skip setScreen');
    } else if (!fromPushNotification) {
      myCustomPrintStatement(
          '📱 Setting screen to driverOnWay from afterAcceptFunctionality - isScheduled: $isScheduledBooking');
      setScreen(CustomTripType.driverOnWay);
    } else {
      myCustomPrintStatement(
          '🚫 Screen already set by push notification, ensuring correct state');
      _safeSetDriverOnWay(source: 'afterAcceptFunctionality-correction');
      notifyListeners();
    }

    myCustomPrintStatement(
        'accepted by -------------------------------------------${booking!['id']} ${booking!['acceptedBy']}');
    myCustomPrintStatement(
        '🔍 Booking details: status=${booking!['status']}, isSchedule=${booking!['isSchedule']}, startRide=${booking!['startRide']}');

    // Si acceptedBy est null, essayer de récupérer les données complètes depuis Firebase
    if (booking!['acceptedBy'] == null && booking!['id'] != null) {
      myCustomPrintStatement(
          '⚠️ acceptedBy is null, fetching complete booking from Firebase...');
      try {
        var doc = await FirestoreServices.bookingRequest.doc(booking!['id']).get()
            .timeout(const Duration(seconds: 10), onTimeout: () {
          myCustomPrintStatement('⏰ Timeout lors de la récupération du booking');
          throw TimeoutException('Booking fetch timeout');
        });
        if (doc.exists) {
          var firebaseData = doc.data() as Map<String, dynamic>?;
          if (firebaseData != null) {
            booking = Map<String, dynamic>.from(firebaseData);
            myCustomPrintStatement(
                '✅ Booking data refreshed from Firebase - acceptedBy: ${booking!['acceptedBy']}');
          }
        }
      } catch (e) {
        myCustomPrintStatement('❌ Error fetching booking from Firebase: $e');
      }
    }

    // Vérifier encore une fois si acceptedBy existe maintenant
    if (booking!['acceptedBy'] == null) {
      myCustomPrintStatement(
          '❌ No acceptedBy field in booking - cannot fetch driver details');
      return;
    }

    if (acceptedDriver == null) {
      myCustomPrintStatement('🔍 Fetching driver details...');

      try {
        // Ajouter un timeout pour éviter le blocage infini
        var m = await FirestoreServices.users.doc(booking!['acceptedBy']).get()
            .timeout(const Duration(seconds: 10), onTimeout: () {
          myCustomPrintStatement('⏰ Timeout lors de la récupération du driver');
          throw TimeoutException('Driver fetch timeout');
        });

        if (m.exists) {
          acceptedDriver = DriverModal.fromJson(m.data() as Map);

          // acceptedDriver!['distance_by_driver'] = (getDistance(
          //     acceptedDriver!['currentLat'],
          //     acceptedDriver!['currentLng'],
          //     booking!['pickLat'],
          //     booking!['pickLng']));
          selectedVehicle = vehicleMap[acceptedDriver!.vehicleType];

          // Notifier l'UI IMMÉDIATEMENT avant de charger la carte
          notifyListeners();

          // Forcer la mise à jour de l'UI pour afficher les infos du driver
          if (MyGlobalKeys.homePageKey.currentState != null) {
            MyGlobalKeys.homePageKey.currentState!.updateBottomSheetHeight(milliseconds: 50);
          }

          if (booking!['status'] <= BookingStatusType.RIDE_STARTED.value) {
            createPath();
            // NE PAS AWAIT - Laisser le tracking démarrer en arrière-plan
            // pour ne pas bloquer l'affichage de l'interface
            startRideTracking().catchError((e) {
              myCustomPrintStatement('⚠️ Erreur startRideTracking: $e');
            });
          }

          // Note: removeOtherDriverMarkers() est appelé automatiquement dans le stream des drivers
          // MyGlobalKeys.homePageKey.currentState!.removeOtherDriverMarkers();
          myCustomPrintStatement(
              '✅ Driver details loaded: ${acceptedDriver!.fullName}');

          // Enrichir et sauvegarder le booking avec les infos du driver (en arrière-plan)
          if (booking != null) {
            Future.microtask(() async {
              try {
                Map<String, dynamic> enrichedBooking =
                    Map<String, dynamic>.from(booking!);
                enrichedBooking['driverName'] = acceptedDriver!.fullName;
                enrichedBooking['driverPhone'] = acceptedDriver!.phone;
                enrichedBooking['driverPhoto'] = acceptedDriver!.profileImage;
                enrichedBooking['driverVehicleNumber'] =
                    acceptedDriver!.vehicleData?.licenseNumber ?? '';

                // Sauvegarder localement pour persistance
                DevFestPreferences prefs = DevFestPreferences();
                await prefs.saveActiveBooking(enrichedBooking);
                myCustomPrintStatement(
                    '💾 Booking enrichi et sauvegardé avec infos driver');
              } catch (e) {
                myCustomPrintStatement('⚠️ Erreur sauvegarde booking: $e');
              }
            });
          }
        }
      } catch (e) {
        myCustomPrintStatement('❌ Erreur chargement driver: $e');
        // Même en cas d'erreur, notifier pour ne pas bloquer l'UI
        notifyListeners();

        // Afficher un message à l'utilisateur
        showSnackbar('Erreur de connexion. Veuillez réessayer.');
        return;
      }

      notifyListeners();
    } else {
      myCustomPrintStatement(
          'ℹ️ Driver details already available: ${acceptedDriver!.fullName}');

      // Même si le driver est déjà disponible, sauvegarder le booking enrichi
      if (booking != null && acceptedDriver != null) {
        Map<String, dynamic> enrichedBooking =
            Map<String, dynamic>.from(booking!);
        enrichedBooking['driverName'] = acceptedDriver!.fullName;
        enrichedBooking['driverPhone'] = acceptedDriver!.phone;
        enrichedBooking['driverPhoto'] = acceptedDriver!.profileImage;
        enrichedBooking['driverVehicleNumber'] =
            acceptedDriver!.vehicleData?.licenseNumber ?? '';

        // Sauvegarder localement pour persistance
        DevFestPreferences prefs = DevFestPreferences();
        await prefs.saveActiveBooking(enrichedBooking);
        myCustomPrintStatement(
            '💾 Booking enrichi et sauvegardé avec infos driver existantes');
      }
    }

    double newD = getDistance(acceptedDriver!.currentLat!,
        acceptedDriver!.currentLng!, booking!['pickLat'], booking!['pickLng']);
    myCustomPrintStatement("distance changed---------$newD--------$distance");
    if (newD != distance) {
      distance = newD;
      notifyListeners();
    }

    if (showSateftyAlertWidget) {
      Future.delayed(const Duration(seconds: 5), () {
        showSateftyAlertWidget = false;
        notifyListeners();
      });
    }

    myCustomPrintStatement(
        '✅ afterAcceptFunctionality completed - final screen: $currentStep');
  }

  setBookingStreamInner() async {
    myCustomPrintStatement(
        "🔄 setBookingStreamInner called - booking status: ${booking!['status']}, currentStep: $currentStep");

    // CRITICAL: Don't override if we're already on driverOnWay state due to recent acceptance
    // EXCEPTION: Allow processing for RIDE_COMPLETE to trigger payment flow
    // EXCEPTION: Allow processing if acceptedDriver is null (need to load driver data)
    if (currentStep == CustomTripType.driverOnWay &&
        booking!['acceptedBy'] != null &&
        acceptedDriver != null &&
        booking!['status'] != BookingStatusType.RIDE_COMPLETE.value &&
        booking!['status'] != BookingStatusType.DESTINATION_REACHED.value) {
      myCustomPrintStatement(
          '⚠️ Skipping setBookingStreamInner - already on driverOnWay with accepted driver (status: ${booking!['status']})');
      return;
    }

    // Si on est sur driverOnWay mais acceptedDriver est null, on doit charger les données
    if (currentStep == CustomTripType.driverOnWay &&
        booking!['acceptedBy'] != null &&
        acceptedDriver == null) {
      myCustomPrintStatement(
          '🔄 setBookingStreamInner: On driverOnWay but acceptedDriver is null - loading driver data...');
    }

    if (booking!['status'] == BookingStatusType.RIDE_COMPLETE.value) {
      GoogleMapProvider mapInstan = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);
      mapInstan.polyLines.clear();
      mapInstan.polyLines.clear();
      mapInstan.markers.removeWhere((key, value) => key == "drop");
      mapInstan.markers.removeWhere((key, value) => key == "pickup");
      mapInstan.notifyListeners();

      // Traiter les points de fidélité dès que le statut RIDE_COMPLETE est détecté
      _processLoyaltyPoints();
    }
    if (booking!['status'] == BookingStatusType.PENDING_REQUEST.value) {
      // 🔧 FIX: Pour les courses programmées qui attendent un nouveau chauffeur après désistement,
      // NE PAS appeler pendingRequestFunctionality() car la course existe déjà dans Firestore.
      // On reste sur l'écran actuel et on attend qu'un nouveau chauffeur accepte.
      if (_scheduledBookingAwaitingReassignment) {
        myCustomPrintStatement(
            '⏳ Scheduled booking awaiting reassignment - NOT calling pendingRequestFunctionality');
      } else {
        await pendingRequestFunctionality();
      }
    } else if (booking!['status'] >= BookingStatusType.ACCEPTED.value) {
      await afterAcceptFunctionality();
    }

    // Affichage systématique du paiement pour DESTINATION_REACHED ou RIDE_COMPLETE
    // Supprimer la condition firstTimeAtApp pour garantir l'affichage
    // Déclencher le paiement si :
    // - Course terminée (RIDE_COMPLETE ou DESTINATION_REACHED)
    // - Paiement non-cash
    // - Pas de paymentStatusSummary OU paiement échoué (status = 'failed')
    // - Pas déjà sur un écran de paiement mobile money
    // Vérifier si paymentStatusSummary permet de déclencher le paiement:
    // - null (pas encore de paiement)
    // - Map vide {} (initialisé mais pas de données)
    // - status null ou 'failed' (paiement non complété ou échoué)
    final paymentSummary = booking!['paymentStatusSummary'];
    bool paymentNotCompleted = paymentSummary == null ||
        (paymentSummary is Map && paymentSummary.isEmpty) ||
        paymentSummary['status'] == null ||
        paymentSummary['status'] == 'failed';

    bool shouldTriggerPayment =
        (booking!['status'] == BookingStatusType.RIDE_COMPLETE.value ||
                booking!['status'] ==
                    BookingStatusType.DESTINATION_REACHED.value) &&
            booking!['paymentMethod'] != PaymentMethodType.cash.value &&
            paymentNotCompleted &&
            currentStep != CustomTripType.paymentMobileConfirm &&
            currentStep != CustomTripType.orangeMoneyPayment;

    if (shouldTriggerPayment) {
      String paymentStatus =
          booking!['paymentStatusSummary']?['status'] ?? 'null';
      myCustomPrintStatement(
          "💳 Triggering payment interface - status: ${booking!['status']}, payment method: ${booking!['paymentMethod']}, paymentStatus: $paymentStatus");
      redirectToOnlinePaymentPage();
    } else if (booking!['status'] == BookingStatusType.RIDE_COMPLETE.value ||
        booking!['status'] == BookingStatusType.DESTINATION_REACHED.value) {
      // Debug: Log pourquoi le paiement n'est pas déclenché
      myCustomPrintStatement(
          "⚠️ Payment NOT triggered - status: ${booking!['status']}, "
          "paymentMethod: ${booking!['paymentMethod']} (cash=${PaymentMethodType.cash.value}), "
          "paymentSummary: $paymentSummary, "
          "paymentNotCompleted: $paymentNotCompleted, "
          "currentStep: $currentStep");
    }

    // Si la course est terminée et que le paiement est en cash (par exemple suite à annulation d'un paiement mobile)
    // et que nous ne sommes pas déjà sur l'écran de fin de course, revenir à l'écran driverOnWay
    if ((booking!['status'] == BookingStatusType.RIDE_COMPLETE.value ||
            booking!['status'] ==
                BookingStatusType.DESTINATION_REACHED.value) &&
        booking!['paymentMethod'] == PaymentMethodType.cash.value &&
        currentStep != CustomTripType.driverOnWay) {
      myCustomPrintStatement(
          "💰 Course terminée avec paiement cash - Affichage écran de fin de course");
      setScreen(CustomTripType.driverOnWay);

      // 🆕 DÉMARRER LE LISTENER pour détecter quand le booking est supprimé par le driver
      _startActiveBookingDeletionListener();
    }

    if (booking!['status'] == BookingStatusType.RIDE_COMPLETE.value &&
        firstTimeAtApp &&
        booking!['paymentStatusSummary'] != null &&
        booking!['paymentMethod'] != PaymentMethodType.cash.value &&
        booking!['paymentStatusSummary']['paymentType'] ==
            PaymentMethodType.orangeMoney.value) {
      setScreen(CustomTripType.orangeMoneyPayment);
      OrangeMoneyPaymentGatewayProvider orange =
          Provider.of<OrangeMoneyPaymentGatewayProvider>(
              MyGlobalKeys.navigatorKey.currentContext!,
              listen: false);
      orange.acessToken = booking!['paymentStatusSummary']['accessToken'];
      orange.orderId = booking!['paymentStatusSummary']['orderId'];
      orange.payToken = booking!['paymentStatusSummary']['payToken'];
      orange.paymentUrl = booking!['paymentStatusSummary']['paymentUrl'];
      orange.checkTranscationStatus(
          amount: booking!['ride_price_to_pay'].toString());
      firstTimeAtApp = false;
      loadingOnPayButton = true;
    } else if (booking!['status'] == BookingStatusType.RIDE_COMPLETE.value &&
        firstTimeAtApp &&
        booking!['paymentMethod'] != PaymentMethodType.cash.value &&
        booking!['paymentStatusSummary'] != null &&
        booking!['paymentStatusSummary']['paymentType'] ==
            PaymentMethodType.airtelMoney.value &&
        booking!['paymentStatusSummary']['status'] != "TS") {
      AirtelMoneyPaymentGatewayProvider airtelProv =
          Provider.of<AirtelMoneyPaymentGatewayProvider>(
              MyGlobalKeys.navigatorKey.currentContext!,
              listen: false);
      airtelProv.acessToken = booking!['paymentStatusSummary']['accessToken'];
      airtelProv.transactionID =
          booking!['paymentStatusSummary']['transactionID'];
      airtelProv.checkPaymentStatus = true;
      airtelProv.checkTranscationStatus();
    } else if (booking!['status'] == BookingStatusType.RIDE_COMPLETE.value &&
        firstTimeAtApp &&
        booking!['paymentMethod'] != PaymentMethodType.cash.value &&
        booking!['paymentStatusSummary'] != null &&
        booking!['paymentStatusSummary']['paymentType'] ==
            PaymentMethodType.telmaMvola.value &&
        booking!['paymentStatusSummary']['status'] == "pending") {
      TelmaMoneyPaymentGatewayProvider telmaPro =
          Provider.of<TelmaMoneyPaymentGatewayProvider>(
              MyGlobalKeys.navigatorKey.currentContext!,
              listen: false);
      telmaPro.acessToken = booking!['paymentStatusSummary']['accessToken'];
      telmaPro.correlationID =
          booking!['paymentStatusSummary']['correlationID'];
      telmaPro.serverCorrelationId =
          booking!['paymentStatusSummary']['serverCorrelationId'];
      firstTimeAtApp = false;
      loadingOnPayButton = true;
      telmaPro.checkPaymentStatus = true;
      telmaPro.checkTranscationStatus();
    }
    if (booking!['status'] >= BookingStatusType.RIDE_STARTED.value &&
        booking!['status'] < BookingStatusType.RIDE_COMPLETE.value) {
      DateTime requestTime = (booking!['startedTime'] ??
              // ignore: unnecessary_cast
              Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(minutes: 5)))
                  as Timestamp)
          .toDate();
      myCustomPrintStatement(
          "converted Duration requestTime $requestTime ${DateTime.now()}");
      int convertedDuration =
          (300 - (DateTime.now().difference(requestTime).inMinutes * 60))
              .toInt();
      myCustomPrintStatement("converted Duration $convertedDuration");
      if (!convertedDuration.isNegative) {
        showCancelButton = false;
        Future.delayed(
            Duration(
                seconds: convertedDuration.isNegative ? 1 : convertedDuration),
            () {
          showCancelButton = true;
          notifyListeners();
        });
      } else {
        showCancelButton = true;
      }
    }
    // Null-safe check pour éviter l'erreur si la page n'est pas encore montée
    if (MyGlobalKeys.homePageKey.currentState != null) {
      MyGlobalKeys.homePageKey.currentState!
          .updateBottomSheetHeight(milliseconds: 400);
      MyGlobalKeys.homePageKey.currentState!
          .updateBottomSheetHeight(milliseconds: 500);
    }
  }

  cancelRideWithBooking({required String reason, required Map cancelAnotherRide}) async {
    // Analytics tracking pour annulation
    AnalyticsService.logRideCancelled(
      rideId: cancelAnotherRide['id'] ?? 'unknown',
      reason: reason,
      cancelledBy: 'rider',
    );

    DriverModal? driverDetails;
    if (booking != null && cancelAnotherRide['id'] == booking!['id']) {
      driverDetails = acceptedDriver;
    } else {
      var m = await FirestoreServices.users
          .doc(cancelAnotherRide['acceptedBy'])
          .get();
      if (m.exists) {
        driverDetails = DriverModal.fromJson(m.data() as Map);
      }
    }
    showModalBottomSheet(
        context: MyGlobalKeys.navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          popPage(context: context);
                        },
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: SubHeadingText(
                          translate("Cancel Ride?"),
                          fontSize: 20,
                          textAlign: TextAlign.center,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    ],
                  ),
                  const Divider(),
                  ParagraphText(
                    cancelAnotherRide['status'] >=
                            BookingStatusType.ACCEPTED.value
                        ? translate("Cancel ride with (DRIVERFIRSTNAME) ?")
                            .replaceFirst(
                                "(DRIVERFIRSTNAME)", driverDetails!.firstName)
                        : translate("Are you sure you want to cancel?"),
                    fontSize: 18,
                    textAlign: TextAlign.start,
                    fontWeight: FontWeight.w500,
                  ),
                  vSizedBox,
                  ParagraphText(
                    cancelAnotherRide['status'] >=
                            BookingStatusType.ACCEPTED.value
                        ? translate("Your driver is on the way.")
                        : translate(
                            "This is taking longer than expected. Your driver should arrive within 10 minutes. If you cancel now, you'll need to start a new request."),
                    fontSize: 14,
                    textAlign: TextAlign.start,
                    fontWeight: FontWeight.w400,
                  ),
                  vSizedBox,
                  RoundEdgedButton(
                      text: translate('YES, CANCEL'),
                      width: double.infinity,
                      onTap: () async {
                        showLoading();

                        // Marquer que l'utilisateur annule manuellement
                        _userCancelledManually = true;

                        // 🔧 FIX: Annuler IMMÉDIATEMENT tous les timers de notification
                        // pour éviter que les chauffeurs continuent à être notifiés
                        _cancelSequentialNotificationTimer();
                        _pendingRequestRetryTimer?.cancel();
                        _pendingRequestRetryTimer = null;
                        myCustomPrintStatement('🛑 Timers annulés lors de l\'annulation manuelle');

                        // Canonical value: 'rider' (pas 'customer'). Le driverapp check
                        // 'rider' (trip_chat_screen.dart:153) et le dashboard normalise les
                        // deux valeurs en "Passager" à la lecture (Controller.php:128).
                        cancelAnotherRide['cancelledBy'] = 'rider';
                        cancelAnotherRide['cancelledByUserId'] =
                            userData.value!.id;
                        cancelAnotherRide['reason'] = reason;

                        if (cancelAnotherRide['status'] >=
                            BookingStatusType.RIDE_STARTED.value) {
                            // Cours déjà démarrée - marquer comme complète avec annulation
                            try {
                              await FirestoreServices.bookingRequest
                                  .doc(cancelAnotherRide['id'])
                                  .update({
                                'status': BookingStatusType.RIDE_COMPLETE.value,
                                'cancelledBy': 'rider',
                                'cancelledByUserId': userData.value!.id,
                                'reason': reason,
                                'endTime': Timestamp.now(),
                                'total_distance': double.parse(
                                    calculateDistanceByArray(
                                            cancelAnotherRide['coveredPath'])
                                        .toStringAsFixed(2)),
                                'total_duration': Timestamp.now()
                                    .toDate()
                                    .difference(
                                        cancelAnotherRide['startedTime'].toDate())
                                    .inMinutes
                              });

                              // Fermer immédiatement la popup d'annulation
                              popPage(
                                  context:
                                      MyGlobalKeys.navigatorKey.currentContext!);

                              // Mettre à jour l'état local du booking pour déclencher l'affichage de paiement
                              if (booking != null &&
                                  cancelAnotherRide['id'] == booking!['id']) {
                                booking!['status'] =
                                    BookingStatusType.RIDE_COMPLETE.value;
                                booking!['cancelledBy'] = 'rider';
                                booking!['endTime'] = Timestamp.now();
                                notifyListeners();
                              }

                              // Envoyer la notification au chauffeur (de manière asynchrone)
                              if (driverDetails != null) {
                                String notificationText =
                                    "${translateToSpecificLangaue(key: "rideCancelledByCustomer", languageCode: driverDetails.preferedLanguage)} ${userData.value!.firstName}.";
                                FirebasePushNotifications.sendPushNotifications(
                                  deviceIds: driverDetails.deviceIdList,
                                  data: {
                                    'screen': 'ride_cancelled',
                                  },
                                  body: notificationText,
                                  userId: driverDetails.id,
                                  isOnline: driverDetails.isOnline,
                                  title: translateToSpecificLangaue(
                                    key: "rideCancelled",
                                    languageCode: driverDetails.preferedLanguage,
                                  ),
                                );
                              }
                            } catch (e) {
                              myCustomPrintStatement(
                                  '❌ Erreur annulation course démarrée: $e');
                              // Fermer quand même le loader et les popups
                              try {
                                popPage(
                                    context:
                                        MyGlobalKeys.navigatorKey.currentContext!);
                              } catch (_) {}
                            } finally {
                              hideLoading();
                            }
                          } else if (cancelAnotherRide['status'] <
                              BookingStatusType.RIDE_STARTED.value) {
                          // DEBUG - Traçage pour DRIVER_REACHED
                          myCustomPrintStatement(
                              '🔴 ANNULATION DEBUG - Status: ${cancelAnotherRide['status']} (DRIVER_REACHED=2)');
                          myCustomPrintStatement(
                              '🔴 Current booking ID: ${booking?['id']}');
                          myCustomPrintStatement(
                              '🔴 Cancel booking ID: ${cancelAnotherRide['id']}');
                          myCustomPrintStatement(
                              '🔴 Current step avant annulation: $currentStep');

                          try {
                            // 1. FERMER IMMEDIATEMENT les dialogs pour éviter le blocage
                            if (Navigator.of(
                                    MyGlobalKeys.navigatorKey.currentContext!)
                                .canPop()) {
                              Navigator.of(
                                      MyGlobalKeys.navigatorKey.currentContext!)
                                  .pop();
                            }
                            if (Navigator.of(
                                    MyGlobalKeys.navigatorKey.currentContext!)
                                .canPop()) {
                              Navigator.of(
                                      MyGlobalKeys.navigatorKey.currentContext!)
                                  .pop();
                            }

                            // 2. ARRÊTER LE STREAM IMMÉDIATEMENT pour éviter la réassignation
                            bookingStream = null;

                            // 3. SUPPRIMER DE FIRESTORE AVANT de réinitialiser l'état local
                            try {
                              myCustomPrintStatement('📡 Suppression Firestore du booking...');

                              // Ajouter les infos d'annulation au booking
                              cancelAnotherRide['status'] = BookingStatusType.CANCELLED_BY_RIDER.value;
                              cancelAnotherRide['cancelledBy'] = 'rider';
                              cancelAnotherRide['cancellationReason'] = reason;
                              cancelAnotherRide['cancelledAt'] = FieldValue.serverTimestamp();

                              // Sauvegarder dans cancelledBooking
                              await FirestoreServices.cancelledBooking
                                  .doc(cancelAnotherRide['id'])
                                  .set(Map<String, dynamic>.from(cancelAnotherRide))
                                  .timeout(const Duration(seconds: 10));

                              myCustomPrintStatement('✅ Booking migré vers cancelledBooking');

                              // Supprimer de bookingRequest
                              await FirestoreServices.bookingRequest
                                  .doc(cancelAnotherRide['id'])
                                  .delete()
                                  .timeout(const Duration(seconds: 10));

                              myCustomPrintStatement('✅ Booking supprimé de bookingRequest');

                              // Retirer de la liste locale
                              myCurrentBookings.removeWhere((element) =>
                                  element['id'] == cancelAnotherRide['id']);

                              // Gérer les courses planifiées
                              if (cancelAnotherRide['isSchedule'] == true) {
                                await BookingServiceScheduler()
                                    .deleteScheduledJob(
                                        bookingId: cancelAnotherRide['id']);
                              }
                            } catch (e) {
                              myCustomPrintStatement('❌ Erreur suppression Firestore: $e');
                              // Continuer quand même pour débloquer l'UI
                            }

                            // 4. RÉINITIALISER L'ÉTAT LOCAL APRÈS la suppression Firestore
                            _userCancelledManually = true; // Éviter les messages parasites
                            await clearAllTripData();
                            setScreen(CustomTripType.setYourDestination);

                            myCustomPrintStatement(
                                '🔴 Current step après reset: $currentStep');

                            // 5. Reset navigation bar visibility
                            try {
                              final navigationProvider =
                                  Provider.of<NavigationProvider>(
                                      MyGlobalKeys.navigatorKey.currentContext!,
                                      listen: false);
                              navigationProvider
                                  .setNavigationBarVisibility(true);
                            } catch (e) {
                              myCustomPrintStatement(
                                  '⚠️ Could not reset navigation bar visibility: $e');
                            }

                            // Réinitialiser le flag après un délai
                            Future.delayed(const Duration(seconds: 2), () {
                              _userCancelledManually = false;
                            });

                            // 6. NOTIFICATION AU CHAUFFEUR en arrière-plan (ne bloque pas)
                            Future.microtask(() async {
                              try {
                                if (driverDetails != null) {
                                  String notificationText =
                                      "${translateToSpecificLangaue(key: "rideCancelledByCustomer", languageCode: driverDetails.preferedLanguage)} ${userData.value!.firstName}.";
                                  FirebasePushNotifications
                                      .sendPushNotifications(
                                    deviceIds: driverDetails.deviceIdList,
                                    data: {
                                      'screen': 'ride_cancelled',
                                    },
                                    body: notificationText,
                                    userId: driverDetails.id,
                                    isOnline: driverDetails.isOnline,
                                    title: translateToSpecificLangaue(
                                      key: "rideCancelled",
                                      languageCode:
                                          driverDetails.preferedLanguage,
                                    ),
                                  );
                                }

                                myCustomPrintStatement(
                                    '🔴 ANNULATION - Toutes les opérations terminées avec succès');
                              } catch (e) {
                                myCustomPrintStatement(
                                    '🔴 ERREUR dans les opérations en arrière-plan: $e');
                              }
                            });

                            // 5. METTRE À JOUR LE BOTTOM SHEET après un petit délai
                            Future.delayed(const Duration(milliseconds: 150),
                                () {
                              try {
                                if (MyGlobalKeys.homePageKey.currentState !=
                                    null) {
                                  MyGlobalKeys.homePageKey.currentState!
                                      .updateBottomSheetHeight();
                                  myCustomPrintStatement(
                                      '🔴 Bottom sheet height mis à jour');
                                }
                              } catch (e) {
                                myCustomPrintStatement(
                                    '🔴 Erreur mise à jour bottom sheet: $e');
                              }
                            });

                            myCustomPrintStatement(
                                '🔴 ANNULATION DRIVER_REACHED - Interface réinitialisée avec succès');
                          } catch (e) {
                            myCustomPrintStatement(
                                '🔴 ERREUR CRITIQUE dans l\'annulation DRIVER_REACHED: $e');

                            // Arrêter le stream pour éviter la réassignation
                            bookingStream = null;

                            // Forcer le retour à l'écran d'accueil en cas d'erreur critique
                            currentStep = CustomTripType.setYourDestination;
                            booking = null;
                            acceptedDriver = null;
                            selectedVehicle = null;
                            notifyListeners();
                          } finally {
                            // CRITIQUE : Fermer le loader dans TOUS les cas
                            hideLoading();
                            myCustomPrintStatement('🔴 Loader fermé (finally)');
                          }
                        }
                      }),
                  if (cancelAnotherRide['status'] >=
                      BookingStatusType.ACCEPTED.value)
                    RoundEdgedButton(
                      text: translate("Call the driver"),
                      width: double.infinity,
                      color: MyColors.blackColor,
                      textColor: MyColors.whiteColor,
                      onTap: () async {
                        var url =
                            "tel: ${driverDetails!.countryCode}${driverDetails.phone.startsWith("0") ? driverDetails.phone.substring(1) : driverDetails.phone}";
                        if (await canLaunch(url)) {
                          await launch(url);
                        }
                        popPage(
                            context: MyGlobalKeys.navigatorKey.currentContext!);
                        popPage(
                            context: MyGlobalKeys.navigatorKey.currentContext!);
                      },
                    ),
                  RoundEdgedButton(
                    text: cancelAnotherRide['status'] >=
                            BookingStatusType.ACCEPTED.value
                        ? translate("NO")
                        : translate("Keep Searching"),
                    width: double.infinity,
                    color: MyColors.blackColor50,
                    textColor: MyColors.whiteColor,
                    onTap: () {
                      popPage(
                          context: MyGlobalKeys.navigatorKey.currentContext!);
                      popPage(
                          context: MyGlobalKeys.navigatorKey.currentContext!);
                    },
                  ),
                ],
              ),
            ),
          );
        });
    // await showCommonAlertDailog(MyGlobalKeys.navigatorKey.currentContext!,
    //     // imageUrl: MyImagesUrl.logoutIcon,
    //     successIcon: false,
    //     headingText: translate("areYouSure"),
    //     message: translate("youWantCancleRide"),
    //     actions: [
    //       Row(
    //         mainAxisAlignment: MainAxisAlignment.center,
    //         children: [
    //           RoundEdgedButton(
    //             text: translate("no"),
    //             color: MyColors.whiteThemeColor(),
    //             textColor: MyColors.blackThemeColor(),
    //             width: 100,
    //             height: 40,
    //             onTap: () {
    //               popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
    //             },
    //           ),
    //           hSizedBox2,
    //           RoundEdgedButton(
    //               text: translate('yes'),
    //               width: 100,
    //               height: 40,
    //               onTap: () async {
    //                 showLoading();
    //                 // if(await can)
    //                 // cancelledReason['cancelledBy']
    //                 // var data = {
    //                 //     "cancelledBy": "customer",
    //                 // };
    //                 cancelAnotherRide['cancelledBy'] = 'customer';
    //                 cancelAnotherRide['cancelledByUserId'] = userData.value!.id;
    //                 cancelAnotherRide['reason'] = reason;
    //                 if (cancelAnotherRide['status'] >=
    //                     BookingStatusType.RIDE_STARTED.value) {
    //                   await FirestoreServices.bookingRequest
    //                       .doc(cancelAnotherRide['id'])
    //                       .update({
    //                     'status': BookingStatusType.RIDE_COMPLETE.value,
    //                     'cancelledBy': 'customer',
    //                     'cancelledByUserId': userData.value!.id,
    //                     'reason': reason,
    //                     'endTime': Timestamp.now(),
    //                     'total_distance': double.parse(calculateDistanceByArray(
    //                             cancelAnotherRide['coveredPath'])
    //                         .toStringAsFixed(2)),
    //                     'total_duration': Timestamp.now()
    //                         .toDate()
    //                         .difference(
    //                             cancelAnotherRide['startedTime'].toDate())
    //                         .inMinutes
    //                   });
    //                   if (driverDetails != null) {
    //                     String notificationText =
    //                         "${translateToSpecificLangaue(key: "rideCancelledByCustomer", languageCode: driverDetails.preferedLanguage)} ${userData.value!.firstName}.";
    //                     FirebasePushNotifications.sendPushNotifications(
    //                       deviceIds: driverDetails.deviceIdList,
    //                       data: {
    //                         'screen': 'ride_cancelled',
    //                       },
    //                       body: notificationText,
    //                       userId: driverDetails.id,
    //                       isOnline: driverDetails.isOnline,
    //                       title: translateToSpecificLangaue(
    //                         key: "rideCancelled",
    //                         languageCode: driverDetails.preferedLanguage,
    //                       ),
    //                     );
    //                     popPage(
    //                         context: MyGlobalKeys.navigatorKey.currentContext!);
    //                   }
    //                 } else if (cancelAnotherRide['status'] <=
    //                     BookingStatusType.RIDE_STARTED.value) {
    //                   myCustomPrintStatement(
    //                       "driver list of devices $driverDetails");
    //                   if (driverDetails != null) {
    //                     String notificationText =
    //                         "${translateToSpecificLangaue(key: "rideCancelledByCustomer", languageCode: driverDetails.preferedLanguage)} ${userData.value!.firstName}.";
    //                     FirebasePushNotifications.sendPushNotifications(
    //                       deviceIds: driverDetails.deviceIdList,
    //                       data: {
    //                         'screen': 'ride_cancelled',
    //                       },
    //                       body: notificationText,
    //                       userId: driverDetails.id,
    //                       isOnline: driverDetails.isOnline,
    //                       title: translateToSpecificLangaue(
    //                         key: "rideCancelled",
    //                         languageCode: driverDetails.preferedLanguage,
    //                       ),
    //                     );
    //                   }
    //                   await FirestoreServices.cancelledBooking
    //                       .doc(cancelAnotherRide['id'])
    //                       .set(cancelAnotherRide);
    //                   await FirestoreServices.bookingRequest
    //                       .doc(cancelAnotherRide['id'])
    //                       .delete();
    //                   myCurrentBookings.removeWhere((element) =>
    //                       element['id'] == cancelAnotherRide['id']);
    //                   if (cancelAnotherRide['isSchedule'] == true) {
    //                     await BookingServiceScheduler().deleteScheduledJob(
    //                         bookingId: cancelAnotherRide['id']);
    //                   }

    //                   popPage(
    //                       context: MyGlobalKeys.navigatorKey.currentContext!);
    //                   popPage(
    //                       context: MyGlobalKeys.navigatorKey.currentContext!);
    //                   hideLoading();
    //                   MyGlobalKeys.homePageKey.currentState!
    //                       .updateBottomSheetHeight();
    //                   checkAndReset();
    //                 }
    //               }),
    //           hSizedBox,
    //         ],
    //       ),
    //     ]);
  }

  /// ⚡ OPTIMISÉ: Traitement du paiement en ligne avec parallélisation
  /// Réduit le temps de traitement de ~10-15s à ~2-3s
  onlinePaymentDone({required Map paymentInfo}) async {
    myCustomPrintStatement(
        '🔶 PAYMENT_OPTIM: onlinePaymentDone started - paymentInfo: ${paymentInfo['paymentType']}');

    final stopwatch = Stopwatch()..start();

    // ═══════════════════════════════════════════════════════════════════════
    // PHASE 1: Afficher le dialogue de succès (3s) - OBLIGATOIRE pour UX
    // ═══════════════════════════════════════════════════════════════════════
    await paymentRecivedSuccessFullDailog();
    myCustomPrintStatement('🔶 PAYMENT_OPTIM: Dialog completed in ${stopwatch.elapsedMilliseconds}ms');

    // ═══════════════════════════════════════════════════════════════════════
    // PHASE 2: Préparer les données AVANT d'afficher le loader
    // ═══════════════════════════════════════════════════════════════════════

    // Sauvegarder les données pour RateUsScreen IMMÉDIATEMENT
    // Car booking/acceptedDriver peuvent être reset par le listener Firestore
    final String bookingId = booking!['id'];
    final String driverId = booking!['acceptedBy'];
    final Map rateUsData = {
      "booking_id": bookingId,
      "userId": acceptedDriver!.id,
      "profile": acceptedDriver!.profileImage,
      "name": acceptedDriver!.fullName,
      "review_count": acceptedDriver!.totalReveiwCount,
      "rating": acceptedDriver!.averageRating,
      "deviceId": acceptedDriver!.deviceIdList,
      "preferedLanguage": acceptedDriver!.preferedLanguage
    };

    // Calculer les montants
    double extraAmount = 0;
    if (booking!['paymentMethod'] != PaymentMethodType.cash.value) {
      extraAmount += double.parse(booking!['ride_price_to_pay'] ?? 0.toString());
    }
    if (double.parse(booking!['ride_extra_discount'] ?? 0.toString()) > 0) {
      extraAmount += double.parse(booking!['ride_extra_discount'] ?? 0.toString());
    }
    if (double.parse(booking!['ride_discount_price'] ?? 0.toString()) > 0) {
      extraAmount += double.parse(booking!['ride_discount_price'] ?? 0.toString());
    }
    if ((booking!['ride_promocode_discount'] ?? 0) > 0) {
      extraAmount += booking!['ride_promocode_discount'] ?? 0;
    }

    final double cashCommissionAmount =
        double.parse(booking!['ride_price_commission'].toString()) +
            double.parse(booking!['ride_bonus_price_commission'].toString());

    // Copier le booking pour les opérations en arrière-plan
    final Map<String, dynamic> bookingCopy = Map<String, dynamic>.from(booking!);
    bookingCopy['paymentStatusSummary'] = paymentInfo;

    // Bypass PDF pour tous les paiements mobile money (génération en arrière-plan plus tard)
    bookingCopy['rider_invoice'] = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    bookingCopy['driver_invoice'] = 'pending_${DateTime.now().millisecondsSinceEpoch}';

    myCustomPrintStatement('🔶 PAYMENT_OPTIM: Data prepared in ${stopwatch.elapsedMilliseconds}ms');

    // ═══════════════════════════════════════════════════════════════════════
    // PHASE 3: Opérations Firestore CRITIQUES en parallèle
    // ═══════════════════════════════════════════════════════════════════════
    await showLoading();

    try {
      // Récupérer les détails du chauffeur (nécessaire pour les calculs)
      final driverDoc = await FirestoreServices.users.doc(driverId).get();
      final DriverModal driverDetails = DriverModal.fromJson(driverDoc.data() as Map);
      final double walletAmount = driverDetails.balance;

      myCustomPrintStatement('🔶 PAYMENT_OPTIM: Driver fetched in ${stopwatch.elapsedMilliseconds}ms');

      // ⚡ PARALLÉLISER les opérations Firestore indépendantes
      final List<Future> parallelOperations = [];

      // 1. Mettre à jour le paymentStatusSummary (CRITIQUE - driver app attend ça)
      parallelOperations.add(
        FirestoreServices.bookingRequest.doc(bookingId).update({
          'paymentStatusSummary': paymentInfo,
        })
      );

      // 2. Sauvegarder dans bookingHistory
      parallelOperations.add(
        FirestoreServices.bookingHistory.doc(bookingId).set(bookingCopy)
      );

      // 3. Mettre à jour le solde du chauffeur (si applicable)
      if (extraAmount > 0) {
        parallelOperations.add(
          FirestoreServices.users.doc(driverId).update({
            'balance': FieldValue.increment(extraAmount)
          })
        );
        parallelOperations.add(
          FirestoreServices.users
              .doc(driverId)
              .collection('wallet_history')
              .doc()
              .set({
            "bookingRef": bookingId,
            "amount": extraAmount,
            "action": "credit",
            "time": DateTime.now(),
            "text": "${translateToSpecificLangaue(key: "The amount has been credited to your account for booking ID", languageCode: driverDetails.preferedLanguage)} #$bookingId",
          })
        );
      }

      // 4. Déduire la commission (si applicable)
      if (cashCommissionAmount > 0) {
        if (walletAmount >= cashCommissionAmount) {
          parallelOperations.add(
            FirestoreServices.users.doc(driverId).update({
              'balance': FieldValue.increment(cashCommissionAmount * -1)
            })
          );
          parallelOperations.add(
            FirestoreServices.users
                .doc(driverId)
                .collection('wallet_history')
                .doc()
                .set({
              "bookingRef": bookingId,
              "amount": cashCommissionAmount.toString(),
              "text": translateToSpecificLangaue(
                  key: "admin commission deducted",
                  languageCode: driverDetails.preferedLanguage),
              "action": "debit",
              "time": DateTime.now()
            })
          );
        } else {
          parallelOperations.add(
            FirestoreServices.users.doc(driverId).update({
              'balance': walletAmount - cashCommissionAmount
            })
          );
        }
      }

      // ⚡ Exécuter TOUTES les opérations en parallèle
      await Future.wait(parallelOperations);
      myCustomPrintStatement('🔶 PAYMENT_OPTIM: Parallel Firestore ops completed in ${stopwatch.elapsedMilliseconds}ms');

      // ═══════════════════════════════════════════════════════════════════════
      // PHASE 4: Court délai pour sync driver app, puis suppression
      // ═══════════════════════════════════════════════════════════════════════
      // Réduit de 1500ms à 500ms - le paymentStatusSummary est déjà envoyé
      await Future.delayed(const Duration(milliseconds: 500));

      // Supprimer le booking
      await FirestoreServices.bookingRequest.doc(bookingId).delete();
      myCustomPrintStatement('🔶 PAYMENT_OPTIM: Booking deleted in ${stopwatch.elapsedMilliseconds}ms');

    } catch (e) {
      myCustomPrintStatement('🔶 PAYMENT_OPTIM: Error during Firestore operations: $e');
      // Continuer vers RateUsScreen même en cas d'erreur partielle
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PHASE 5: Navigation IMMÉDIATE vers RateUsScreen
    // ═══════════════════════════════════════════════════════════════════════
    await hideLoading();

    // Effacer le cache local
    DevFestPreferences prefs = DevFestPreferences();
    await prefs.clearActiveBooking();

    // Traiter les points de fidélité en arrière-plan (non-bloquant)
    _processLoyaltyPoints();

    myCustomPrintStatement('🔶 PAYMENT_OPTIM: Total time: ${stopwatch.elapsedMilliseconds}ms - Navigating to RateUsScreen');
    stopwatch.stop();

    // Naviguer vers l'écran de notation
    push(
        context: MyGlobalKeys.navigatorKey.currentContext!,
        screen: RateUsScreen(booking: rateUsData));

    // Reset tout après navigation (sans await)
    resetAll();

    // ═══════════════════════════════════════════════════════════════════════
    // PHASE 6: Génération PDF en ARRIÈRE-PLAN (non-bloquant)
    // ═══════════════════════════════════════════════════════════════════════
    _generateAndUploadInvoicesInBackground(
      bookingId: bookingId,
      bookingCopy: bookingCopy,
      driverId: driverId,
    );

    myCustomPrintStatement('🔶 PAYMENT_OPTIM: onlinePaymentDone completed!');
  }

  /// Génère et upload les factures PDF en arrière-plan (non-bloquant)
  Future<void> _generateAndUploadInvoicesInBackground({
    required String bookingId,
    required Map<String, dynamic> bookingCopy,
    required String driverId,
  }) async {
    try {
      myCustomPrintStatement('🔶 PDF_BACKGROUND: Starting invoice generation...');

      // Récupérer les données nécessaires
      final driverDoc = await FirestoreServices.users.doc(driverId).get();
      if (!driverDoc.exists) return;
      final DriverModal driverDetails = DriverModal.fromJson(driverDoc.data() as Map);

      // Générer le PDF client
      Uint8List uint8list = await generateCustomerInvoice(
          bookingDetails: bookingCopy,
          customerDetails: userData.value!,
          driverData: driverDetails);
      final dir = await getApplicationDocumentsDirectory();
      var file = File(
          "${dir.path.split("app_flutter").first}${userData.value!.id.substring(0, 4)}2${DateTime.now().microsecondsSinceEpoch}.pdf");
      file.writeAsBytesSync(uint8list);
      String riderInvoiceUrl = await FirestoreServices.uploadFile(
        file,
        'invoice',
        showloader: false,
      );

      // Générer le PDF chauffeur
      Uint8List uint8listDriver = await generateDriverInvoice(
          bookingDetails: bookingCopy, driverData: driverDetails);
      var fileDriver = File(
          "${dir.path.split("app_flutter").first}${userData.value!.id.substring(0, 4)}1${DateTime.now().microsecondsSinceEpoch}.pdf");
      fileDriver.writeAsBytesSync(uint8listDriver);
      String driverInvoiceUrl = await FirestoreServices.uploadFile(
        fileDriver,
        'invoice',
        showloader: false,
      );

      // Mettre à jour bookingHistory avec les URLs des factures
      await FirestoreServices.bookingHistory.doc(bookingId).update({
        'rider_invoice': riderInvoiceUrl,
        'driver_invoice': driverInvoiceUrl,
      });

      myCustomPrintStatement('🔶 PDF_BACKGROUND: Invoices generated and uploaded successfully');
    } catch (e) {
      myCustomPrintStatement('🔶 PDF_BACKGROUND: Error generating invoices (non-critical): $e');
      // Les factures peuvent être régénérées plus tard si nécessaire
    }
  }

  redirectToOnlinePaymentPage() {
    myCustomPrintStatement(
        "Redirect to online payment page function ***********");

    // Arrêter l'animation de l'itinéraire pour éviter les rebuilds excessifs
    final mapProvider = Provider.of<GoogleMapProvider>(
      MyGlobalKeys.navigatorKey.currentContext!,
      listen: false,
    );
    mapProvider.stopRouteAnimation();

    if (PaymentMethodTypeExtension.fromValue(booking!['paymentMethod']) ==
        PaymentMethodType.airtelMoney) {
      setScreen(CustomTripType.paymentMobileConfirm);
      setPaymentConfirmMobileNumber(PaymentMethodType.airtelMoney);
    } else if (PaymentMethodTypeExtension.fromValue(
            booking!['paymentMethod']) ==
        PaymentMethodType.telmaMvola) {
      setScreen(CustomTripType.paymentMobileConfirm);
      setPaymentConfirmMobileNumber(PaymentMethodType.telmaMvola);
    } else if (PaymentMethodTypeExtension.fromValue(
            booking!['paymentMethod']) ==
        PaymentMethodType.orangeMoney) {
      setScreen(CustomTripType.orangeMoneyPayment);
      Provider.of<OrangeMoneyPaymentGatewayProvider>(
              MyGlobalKeys.navigatorKey.currentContext!,
              listen: false)
          .generatePaymentRequest(
        amount: booking!['ride_price_to_pay'].toString(),
      );
    } else if (PaymentMethodTypeExtension.fromValue(
            booking!['paymentMethod']) ==
        PaymentMethodType.wallet) {
      // Vérifier que la fonctionnalité portefeuille est activée
      if (!FeatureToggleService.instance.isDigitalWalletEnabled()) {
        myCustomPrintStatement(
            "Digital wallet is disabled, cannot process wallet payment");
        showSnackbar("Le portefeuille numérique n'est pas disponible");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }
      // Traitement du paiement wallet
      _processWalletPayment();
    } else if (PaymentMethodTypeExtension.fromValue(
            booking!['paymentMethod']) ==
        PaymentMethodType.creditCard) {
      // Vérifier que le paiement par carte bancaire est activé
      if (!FeatureToggleService.instance.isCreditCardPaymentEnabled()) {
        myCustomPrintStatement(
            "Credit card payment is disabled, cannot process card payment");
        showSnackbar("Le paiement par carte bancaire n'est pas disponible");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }
      // Traitement du paiement par carte bancaire (à implémenter si nécessaire)
      myCustomPrintStatement(
          "Credit card payment processing - not yet implemented");
      showSnackbar("Paiement par carte bancaire en cours de développement");
      loadingOnPayButton = false;
      notifyListeners();
    }
  }

  /// Traite le paiement via portefeuille Misy
  Future<void> _processWalletPayment() async {
    try {
      myCustomPrintStatement(
          "Processing wallet payment for booking: ${booking!['id']}");

      // Afficher l'indicateur de chargement
      loadingOnPayButton = true;
      notifyListeners();

      // Récupérer le WalletProvider
      WalletProvider? walletProvider;
      try {
        walletProvider = Provider.of<WalletProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);
      } catch (e) {
        myCustomPrintStatement("Error getting WalletProvider: $e");
        showSnackbar("Erreur d'initialisation du portefeuille");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }

      // Valider les données du booking
      if (booking!['ride_price_to_pay'] == null) {
        myCustomPrintStatement("Error: ride_price_to_pay is null");
        showSnackbar("Erreur: montant du trajet non défini");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }

      double amount;
      try {
        amount = double.parse(booking!['ride_price_to_pay'].toString());
      } catch (e) {
        myCustomPrintStatement(
            "Error parsing amount: ${booking!['ride_price_to_pay']} - $e");
        showSnackbar("Erreur: montant invalide");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }

      String userId = userData.value!.id;
      String tripId = booking!['id'];

      // Vérifications de sécurité
      if (amount <= 0) {
        myCustomPrintStatement("Error: Invalid amount: $amount");
        showSnackbar("Erreur: montant invalide");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }

      if (userId.isEmpty || tripId.isEmpty) {
        myCustomPrintStatement(
            "Error: Invalid userId ($userId) or tripId ($tripId)");
        showSnackbar("Erreur: données utilisateur invalides");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }

      // Vérifier une dernière fois le solde
      if (!walletProvider.hasSufficientBalance(amount)) {
        myCustomPrintStatement(
            "Insufficient wallet balance: ${walletProvider.balance} < $amount");
        showSnackbar(
            "Solde insuffisant: ${walletProvider.formattedBalance}. Montant requis: ${amount.toStringAsFixed(0)} MGA");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }

      myCustomPrintStatement(
          "Starting wallet debit: $amount MGA for trip $tripId");

      myCustomPrintStatement(
          "🔶 WALLET_DEBUG: Starting payment process for $amount MGA");

      // Marquer immédiatement le paiement comme "en cours" pour empêcher les appels multiples
      // (même logique que mobile money avec generatePaymentRequest)
      Map<String, dynamic> walletPaymentStatus = {
        'paymentType': PaymentMethodType.wallet.value,
        'status': 'processing',
        'timestamp': DateTime.now().toIso8601String(),
        'amount': amount.toString(),
        'method': 'wallet_debit',
        'transaction_id': 'wallet_${DateTime.now().millisecondsSinceEpoch}',
      };

      myCustomPrintStatement(
          "🔶 WALLET_DEBUG: Created payment status object with transaction_id: ${walletPaymentStatus['transaction_id']}");

      try {
        // Mettre à jour Firebase AVANT le débit (protection contre appels multiples)
        await FirestoreServices.bookingRequest.doc(booking!['id']).update({
          'paymentStatusSummary': walletPaymentStatus,
        });
        myCustomPrintStatement(
            "🔶 WALLET_DEBUG: PaymentStatusSummary updated to 'processing' in Firebase - multiple calls now blocked");
      } catch (e) {
        myCustomPrintStatement("Error updating paymentStatusSummary: $e");
        showSnackbar("Erreur lors de la mise à jour du statut de paiement");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }

      // Effectuer le débit du portefeuille avec timeout
      myCustomPrintStatement(
          "🔶 WALLET_DEBUG: Calling walletProvider.debitWallet...");
      bool paymentSuccess = false;
      try {
        paymentSuccess = await walletProvider.debitWallet(
          userId: userId,
          amount: amount,
          tripId: tripId,
          description: "Paiement trajet #$tripId",
          metadata: {
            'booking_id': tripId,
            'driver_id': booking!['acceptedBy'],
            'pickup_address': booking!['pickAddress'],
            'drop_address': booking!['dropAddress'],
            'payment_method': 'wallet',
            'amount': amount.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        ).timeout(const Duration(seconds: 30)); // Timeout de 30 secondes
        myCustomPrintStatement(
            "🔶 WALLET_DEBUG: debitWallet returned: $paymentSuccess");
      } on TimeoutException {
        myCustomPrintStatement("Wallet payment timeout");

        // Marquer comme échoué due au timeout
        try {
          await FirestoreServices.bookingRequest.doc(booking!['id']).update({
            'paymentStatusSummary.status': 'failed',
            'paymentStatusSummary.error': 'Payment timeout',
            'paymentStatusSummary.failedAt': DateTime.now().toIso8601String(),
          });
        } catch (updateError) {
          myCustomPrintStatement("Error updating timeout status: $updateError");
        }

        showSnackbar(
            "Délai d'attente dépassé. Veuillez vérifier votre connexion.");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      } catch (e) {
        myCustomPrintStatement("Error during wallet debit: $e");

        // Marquer comme échoué due à l'erreur
        try {
          await FirestoreServices.bookingRequest.doc(booking!['id']).update({
            'paymentStatusSummary.status': 'failed',
            'paymentStatusSummary.error': 'Payment error: ${e.toString()}',
            'paymentStatusSummary.failedAt': DateTime.now().toIso8601String(),
          });
        } catch (updateError) {
          myCustomPrintStatement("Error updating error status: $updateError");
        }

        showSnackbar("Erreur lors du débit du portefeuille: ${e.toString()}");
        loadingOnPayButton = false;
        notifyListeners();
        return;
      }

      myCustomPrintStatement(
          "🔶 WALLET_DEBUG: Checking paymentSuccess result: $paymentSuccess");

      if (paymentSuccess) {
        myCustomPrintStatement(
            "🔶 WALLET_DEBUG: Payment SUCCESS - processing completion");

        // Mettre à jour le statut à 'completed' et ajouter les infos finales
        walletPaymentStatus['status'] = 'completed';
        walletPaymentStatus['wallet_balance_after'] =
            walletProvider.balance.toString();

        try {
          // Mettre à jour le statut à 'completed' dans Firebase AVANT onlinePaymentDone
          await FirestoreServices.bookingRequest.doc(booking!['id']).update({
            'paymentStatusSummary': walletPaymentStatus,
          });
          myCustomPrintStatement(
              "🔶 WALLET_DEBUG: PaymentStatusSummary updated to 'completed' in Firebase");

          // Appeler onlinePaymentDone avec les informations du portefeuille
          myCustomPrintStatement(
              "🔶 WALLET_DEBUG: Calling onlinePaymentDone...");
          await onlinePaymentDone(paymentInfo: walletPaymentStatus);
          myCustomPrintStatement(
              "🔶 WALLET_DEBUG: onlinePaymentDone completed - payment process finished");
        } catch (e) {
          myCustomPrintStatement(
              "🔶 WALLET_DEBUG: ERROR in onlinePaymentDone: $e");
          showSnackbar(
              "Paiement effectué mais erreur de finalisation: ${e.toString()}");
        }
      } else {
        myCustomPrintStatement(
            "🔶 WALLET_DEBUG: Payment FAILED - debitWallet returned false");

        // Marquer le paiement comme échoué dans Firebase pour permettre une nouvelle tentative
        try {
          await FirestoreServices.bookingRequest.doc(booking!['id']).update({
            'paymentStatusSummary.status': 'failed',
            'paymentStatusSummary.error':
                'Insufficient balance or payment failed',
            'paymentStatusSummary.failedAt': DateTime.now().toIso8601String(),
          });
          myCustomPrintStatement(
              "🔶 WALLET_DEBUG: PaymentStatusSummary marked as failed in Firebase - user can retry");
        } catch (e) {
          myCustomPrintStatement("Error updating failed payment status: $e");
        }

        showSnackbar(
            "Échec du paiement. Veuillez vérifier votre solde et réessayer.");
        loadingOnPayButton = false;
        notifyListeners();
      }
    } catch (e) {
      myCustomPrintStatement("Unexpected error in wallet payment: $e");

      // Marquer comme échoué due à l'erreur inattendue
      try {
        await FirestoreServices.bookingRequest.doc(booking!['id']).update({
          'paymentStatusSummary.status': 'failed',
          'paymentStatusSummary.error': 'Unexpected error: ${e.toString()}',
          'paymentStatusSummary.failedAt': DateTime.now().toIso8601String(),
        });
      } catch (updateError) {
        myCustomPrintStatement(
            "Error updating unexpected error status: $updateError");
      }

      showSnackbar("Erreur inattendue lors du paiement: ${e.toString()}");
      loadingOnPayButton = false;
      notifyListeners();
    } finally {
      // S'assurer que le loading est toujours réinitialisé
      if (loadingOnPayButton) {
        loadingOnPayButton = false;
        notifyListeners();
      }
    }
  }

  /// Génère un token aléatoirement (24 caractères)
  String _generateShareToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random();
    return String.fromCharCodes(Iterable.generate(
        24, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  /// Crée ou récupère le lien de partage en temps réel pour la course actuelle
  Future<String?> createOrGetLiveShareLink() async {
    try {
      if (booking == null) {
        myCustomPrintStatement(
            "❌ Aucune course active pour créer un lien de partage");
        return null;
      }

      String rideId = booking!['id'];
      DocumentReference rideRef = FirestoreServices.bookingRequest.doc(rideId);

      // Vérifier si un token existe déjà
      DocumentSnapshot rideSnapshot = await rideRef.get();
      if (!rideSnapshot.exists) {
        myCustomPrintStatement("❌ Course non trouvée: $rideId");
        return null;
      }

      Map<String, dynamic> rideData =
          rideSnapshot.data() as Map<String, dynamic>;

      String shareToken;
      bool tokenExists = rideData.containsKey('shareToken') &&
          rideData.containsKey('shareEnabled') &&
          rideData['shareEnabled'] == true;

      if (tokenExists) {
        // Réutiliser le token existant
        shareToken = rideData['shareToken'];
        myCustomPrintStatement(
            "🔄 Réutilisation du token existant: $shareToken");
      } else {
        // Créer un nouveau token avec expiration (24h)
        shareToken = _generateShareToken();
        final expiresAt = DateTime.now().add(const Duration(hours: 24));
        await rideRef.update({
          'shareToken': shareToken,
          'shareEnabled': true,
          'shareCreatedAt': FieldValue.serverTimestamp(),
          'shareExpiresAt': Timestamp.fromDate(expiresAt),
        });
        myCustomPrintStatement("✅ Nouveau token créé: $shareToken (expire le $expiresAt)");
      }

      String shareLink = 'https://misy-app.com/live?ride=$rideId&t=$shareToken';
      myCustomPrintStatement("🔗 Lien de partage généré: $shareLink");

      return shareLink;
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur lors de la création du lien de partage: $e");
      return null;
    }
  }

  /// Partage la course en direct par SMS
  Future<void> shareLiveBySms() async {
    try {
      if (booking == null) {
        showSnackbar("Aucune course active à partager");
        return;
      }

      // Créer ou récupérer le lien de partage
      String? shareLink = await createOrGetLiveShareLink();
      if (shareLink == null) {
        showSnackbar("Impossible de créer le lien de partage");
        return;
      }

      // Texte du SMS prérempli
      String smsText = "Suis ma course en direct sur l'application Misy. "
          "Télécharge l'application et suis-moi en direct : $shareLink";

      // Encoder le texte pour l'URL
      String encodedText = Uri.encodeComponent(smsText);

      // URL du SMS
      String smsUrl = "sms:?body=$encodedText";

      // Essayer d'ouvrir l'application Messages
      bool canLaunchSms = await canLaunch(smsUrl);
      if (canLaunchSms) {
        bool launched = await launch(smsUrl);
        if (launched) {
          myCustomPrintStatement("✅ Application Messages ouverte avec succès");
          showSnackbar("SMS prérempli ouvert dans Messages");
        } else {
          myCustomPrintStatement(
              "❌ Échec du lancement de l'application Messages");
          _showShareLinkFallback(shareLink);
        }
      } else {
        myCustomPrintStatement("❌ Impossible d'ouvrir l'application Messages");
        _showShareLinkFallback(shareLink);
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors du partage par SMS: $e");
      showSnackbar("Erreur lors de l'ouverture des Messages");
    }
  }

  /// Affiche le lien de partage en fallback si SMS échoue
  void _showShareLinkFallback(String shareLink) {
    showModalBottomSheet(
      context: MyGlobalKeys.navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.share, size: 48, color: MyColors.primaryColor),
              vSizedBox2,
              SubHeadingText(
                "Partager votre course",
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              vSizedBox,
              ParagraphText(
                "Copiez ce lien et envoyez-le à un proche pour qu'il suive votre course en temps réel :",
                textAlign: TextAlign.center,
              ),
              vSizedBox,
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  shareLink,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              vSizedBox2,
              RoundEdgedButton(
                text: "Copier le lien",
                onTap: () {
                  Clipboard.setData(ClipboardData(text: shareLink));
                  popPage(context: context);
                  showSnackbar("Lien copié !");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Partage la course en direct par WhatsApp
  Future<void> shareByWhatsApp() async {
    try {
      if (booking == null) {
        showSnackbar("Aucune course active à partager");
        return;
      }

      String? shareLink = await createOrGetLiveShareLink();
      if (shareLink == null) {
        showSnackbar("Impossible de créer le lien de partage");
        return;
      }

      String message = "Suis ma course en direct sur Misy ! $shareLink";
      String encodedMessage = Uri.encodeComponent(message);
      String whatsappUrl = "https://wa.me/?text=$encodedMessage";

      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl),
            mode: LaunchMode.externalApplication);
        myCustomPrintStatement("✅ WhatsApp ouvert avec succès");
      } else {
        myCustomPrintStatement("❌ WhatsApp non disponible");
        showSnackbar("WhatsApp n'est pas installé");
        _showShareLinkFallback(shareLink);
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors du partage WhatsApp: $e");
      showSnackbar("Erreur lors du partage");
    }
  }

  /// Partage la course via le menu système natif
  Future<void> shareGeneric() async {
    try {
      if (booking == null) {
        showSnackbar("Aucune course active à partager");
        return;
      }

      String? shareLink = await createOrGetLiveShareLink();
      if (shareLink == null) {
        showSnackbar("Impossible de créer le lien de partage");
        return;
      }

      String message = "Suis ma course en direct sur Misy ! $shareLink";
      await Share.share(message, subject: 'Ma course Misy en direct');
      myCustomPrintStatement("✅ Menu de partage ouvert");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors du partage: $e");
      showSnackbar("Erreur lors du partage");
    }
  }

  /// Attache un listener en lecture seule pour suivre une course partagée
  Future<bool> attachReadOnlyLiveShare(String rideId, String token) async {
    try {
      myCustomPrintStatement(
          "🔗 Tentative de connexion au partage: ride=$rideId, token=$token");

      DocumentReference rideRef = FirestoreServices.bookingRequest.doc(rideId);
      DocumentSnapshot rideSnapshot = await rideRef.get();

      if (!rideSnapshot.exists) {
        myCustomPrintStatement("❌ Course non trouvée: $rideId");
        return false;
      }

      Map<String, dynamic> rideData =
          rideSnapshot.data() as Map<String, dynamic>;

      // Vérifier la sécurité
      bool isValidShare = rideData.containsKey('shareToken') &&
          rideData.containsKey('shareEnabled') &&
          rideData['shareEnabled'] == true &&
          rideData['shareToken'] == token;

      if (!isValidShare) {
        myCustomPrintStatement("❌ Token invalide ou partage désactivé");
        return false;
      }

      // 🛡️ Sauvegarder la session pour permettre le retour via le bouton bouclier
      _pendingLiveShareRideId = rideId;
      _pendingLiveShareToken = token;
      _liveShareDismissedByUser = false; // Réinitialiser le flag
      // Récupérer l'expiration depuis les données de la course (24h par défaut)
      if (rideData['shareExpiresAt'] != null) {
        final expiresAt = rideData['shareExpiresAt'];
        if (expiresAt is Timestamp) {
          _pendingLiveShareExpiresAt = expiresAt.toDate();
        }
      } else {
        _pendingLiveShareExpiresAt = DateTime.now().add(const Duration(hours: 24));
      }
      myCustomPrintStatement("🛡️ Session sauvegardée pour retour: rideId=$rideId, expires=$_pendingLiveShareExpiresAt");

      // Détacher tout listener précédent
      await detachReadOnlyLiveShare();

      // Incrémenter le compteur de viewers actifs
      await rideRef.update({
        'activeViewers': FieldValue.increment(1),
      });
      _currentLiveShareRideId = rideId; // Sauvegarder pour décrémenter plus tard

      // Attacher le nouveau listener
      _liveShareStreamSubscription = rideRef.snapshots().listen(
        (DocumentSnapshot snapshot) {
          if (snapshot.exists) {
            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

            // Vérifier que le partage est toujours actif
            if (data['shareEnabled'] == true && data['shareToken'] == token) {
              final oldStatus = _currentLiveShareData?['status'];
              final newStatus = data['status'];
              _currentLiveShareData = data;
              _isLiveShareActive = true;
              notifyListeners();

              // Log détaillé du statut
              if (oldStatus != newStatus) {
                myCustomPrintStatement("📊 [TripProvider] Statut changé: $oldStatus → $newStatus");
              }
              myCustomPrintStatement("📍 Données de partage mises à jour (statut: $newStatus)");
            } else {
              // Partage désactivé
              myCustomPrintStatement("⚠️ Partage désactivé par l'utilisateur");
              detachReadOnlyLiveShare();
            }
          } else {
            // Course terminée ou supprimée
            myCustomPrintStatement("ℹ️ Course terminée");
            detachReadOnlyLiveShare();
          }
        },
        onError: (error) {
          myCustomPrintStatement("❌ Erreur dans le stream de partage: $error");
          detachReadOnlyLiveShare();
        },
      );

      _isLiveShareActive = true;
      _currentLiveShareData = rideData;
      notifyListeners();

      myCustomPrintStatement("✅ Connexion au partage réussie");
      return true;
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors de la connexion au partage: $e");
      return false;
    }
  }

  /// Détache le listener de partage en lecture seule
  Future<void> detachReadOnlyLiveShare() async {
    try {
      if (_liveShareStreamSubscription != null) {
        await _liveShareStreamSubscription!.cancel();
        _liveShareStreamSubscription = null;
      }

      // Décrémenter le compteur de viewers actifs
      if (_currentLiveShareRideId != null) {
        try {
          await FirestoreServices.bookingRequest.doc(_currentLiveShareRideId).update({
            'activeViewers': FieldValue.increment(-1),
          });
          myCustomPrintStatement("👁️ Viewer count décrémenté pour $_currentLiveShareRideId");
        } catch (e) {
          myCustomPrintStatement("⚠️ Erreur décrémentation viewer: $e");
        }
        _currentLiveShareRideId = null;
      }

      _isLiveShareActive = false;
      _currentLiveShareData = null;
      notifyListeners();

      myCustomPrintStatement("🔌 Connexion au partage fermée");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors de la fermeture du partage: $e");
    }
  }

  /// 🛡️ Ferme définitivement la session de partage (bouton "Fermer" cliqué)
  /// Appelé quand l'utilisateur ne veut plus voir le bouton bouclier
  void dismissPendingLiveShare() {
    _liveShareDismissedByUser = true;
    _pendingLiveShareRideId = null;
    _pendingLiveShareToken = null;
    _pendingLiveShareExpiresAt = null;
    notifyListeners();
    myCustomPrintStatement("🛡️ Session de partage fermée par l'utilisateur");
  }

  /// Arrête le partage d'une course (côté émetteur)
  Future<void> stopLiveShare() async {
    try {
      if (booking == null) {
        myCustomPrintStatement(
            "❌ Aucune course active pour arrêter le partage");
        return;
      }

      String rideId = booking!['id'];
      await FirestoreServices.bookingRequest.doc(rideId).update({
        'shareEnabled': false,
        'shareToken': FieldValue.delete(),
        'shareCreatedAt': FieldValue.delete(),
      });

      myCustomPrintStatement("✅ Partage de la course arrêté");
      showSnackbar("Partage arrêté");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors de l'arrêt du partage: $e");
      showSnackbar("Erreur lors de l'arrêt du partage");
    }
  }

  /// Nettoie les données de partage à la fin de la course
  Future<void> _cleanupLiveShareOnRideComplete() async {
    try {
      if (booking != null && booking!['shareEnabled'] == true) {
        await stopLiveShare();
      }
      await detachReadOnlyLiveShare();
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors du nettoyage du partage: $e");
    }
  }

  /// Récupère les informations publiques du chauffeur via la couche Provider/Service
  Future<Map<String, dynamic>?> fetchDriverPublicData(String driverId) async {
    try {
      final doc = await FirestoreServices.users.doc(driverId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data;
      }
    } catch (e) {
      myCustomPrintStatement("❌ fetchDriverPublicData error: $e");
    }
    return null;
  }

  // === MÉTHODES POUR LA NOTIFICATION SÉQUENTIELLE ===

  /// Démarre le timer séquentiel pour un booking donné
  void _startSequentialNotificationTimer(String bookingId, {int? customTimeout}) {
    if (!globalSettings.enableSequentialNotification) {
      myCustomPrintStatement(
          'Sequential notification disabled, skipping timer');
      return;
    }

    // Annuler le timer précédent s'il existe
    _sequentialNotificationTimer?.cancel();

    // Utiliser le timeout personnalisé ou celui de la config Firebase
    int actualTimeout = customTimeout ?? globalSettings.sequentialNotificationTimeout;

    myCustomPrintStatement(
        'Starting sequential timer for booking: $bookingId (timeout: ${actualTimeout}s)');

    _sequentialNotificationTimer = Timer(
        Duration(seconds: actualTimeout),
        () => _handleSequentialTimeout(bookingId));
  }

  /// Gère le timeout du timer séquentiel
  void _handleSequentialTimeout(String bookingId) async {
    try {
      myCustomPrintStatement(
          'Sequential notification timeout for booking: $bookingId');

      // Vérifier si la booking existe encore et n'est pas acceptée
      var bookingDoc =
          await FirestoreServices.bookingRequest.doc(bookingId).get();

      if (!bookingDoc.exists) {
        myCustomPrintStatement('Booking not found during timeout: $bookingId');
        return;
      }

      Map bookingData = bookingDoc.data() as Map;

      // Vérifier que la booking est toujours en attente
      if (bookingData['status'] == BookingStatusType.PENDING_REQUEST.value) {
        // Vérifier si tous les chauffeurs ont déjà été notifiés
        List<String> allDriverIds = List<String>.from(bookingData['sequentialDriversList'] ?? []);
        int currentIndex = bookingData['currentNotifiedDriverIndex'] ?? 0;
        int nextIndex = currentIndex + 1;

        if (nextIndex >= allDriverIds.length) {
          // Tous les chauffeurs ont été notifiés dans ce cycle
          myCustomPrintStatement(
              '📢 All drivers notified for booking: $bookingId (cycle complete)');

          // 🔧 FIX: Au lieu d'annuler, on attend 30 secondes puis on recommence la boucle
          // La recherche continue indéfiniment jusqu'à acceptation ou annulation par l'user

          // Vérifier si on est en période d'attente (entre deux cycles)
          bool isWaitingPeriod = bookingData['allDriversNotifiedWaiting'] == true;

          if (!isWaitingPeriod) {
            // Fin d'un cycle de notifications - démarrer la période d'attente de 30s
            myCustomPrintStatement(
                '⏳ Cycle complete - waiting 30s before restarting from first driver...');

            // Marquer qu'on est en période d'attente
            await FirestoreServices.bookingRequest.doc(bookingId).update({
              'allDriversNotifiedWaiting': true,
              'allDriversNotifiedTime': Timestamp.now(),
            });

            // Attendre 30 secondes avant de recommencer
            const int waitingPeriodBetweenCycles = 30;
            _startSequentialNotificationTimer(bookingId, customTimeout: waitingPeriodBetweenCycles);
            return;
          }

          // Période d'attente terminée - recommencer depuis le premier chauffeur
          myCustomPrintStatement(
              '🔄 Waiting period complete - restarting notification cycle from first driver');

          // Réinitialiser l'index et le flag d'attente pour recommencer
          await FirestoreServices.bookingRequest.doc(bookingId).update({
            'currentNotifiedDriverIndex': 0,
            'allDriversNotifiedWaiting': false,
            'notificationCycleCount': (bookingData['notificationCycleCount'] ?? 0) + 1,
          });

          // Notifier le premier chauffeur à nouveau
          await FirestoreServices.notifyNextDriverInSequence(bookingId);

          // Redémarrer le timer avec le timeout normal
          _startSequentialNotificationTimer(bookingId);
          return;
        }

        myCustomPrintStatement('Booking still pending, notifying next driver (index: $nextIndex)');

        // Passer au chauffeur suivant
        await FirestoreServices.notifyNextDriverInSequence(bookingId);

        // Redémarrer le timer pour le prochain chauffeur
        _startSequentialNotificationTimer(bookingId);
      } else {
        myCustomPrintStatement(
            'Booking status changed (${bookingData['status']}), stopping sequential timer');
      }
    } catch (e) {
      myCustomPrintStatement("Error in sequential timeout handler: $e");
    }
  }

  /// Annule le timer séquentiel (appelé quand une booking est acceptée)
  void _cancelSequentialNotificationTimer() {
    if (_sequentialNotificationTimer != null) {
      myCustomPrintStatement('Cancelling sequential notification timer');
      _sequentialNotificationTimer?.cancel();
      _sequentialNotificationTimer = null;
    }
  }

  /// Met à jour la position du driver en temps réel sur la carte avec zoom adaptatif
  Future<void> updateDriverLocationOnMap() async {
    try {
      if (acceptedDriver?.currentLat == null ||
          acceptedDriver?.currentLng == null) {
        return;
      }

      final mapProvider = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);

      if (!mapProvider.markers.containsKey('driver_vehicle')) {
        await addDriverVehicleMarker();
      }

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 🚗 MISE À JOUR DE LA POSITION DU DRIVER SUR LA CARTE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      if (booking != null && booking!['status'] != null) {
        if (booking!['status'] >= BookingStatusType.ACCEPTED.value &&
            booking!['status'] < BookingStatusType.RIDE_STARTED.value) {
          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          // 🚗 ÉTAPE "CHAUFFEUR EN CHEMIN" (driverOnWay) - Status 1 ou 2
          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          // Zoom adaptatif en temps réel : réajuster la caméra quand la distance change

          if (pickLocation != null) {
            final currentDistance = getDistance(
              acceptedDriver!.currentLat!,
              acceptedDriver!.currentLng!,
              pickLocation!['lat'],
              pickLocation!['lng'],
            );

            bool shouldUpdateZoom = false;
            final now = DateTime.now();

            // Vérifier si le cooldown est passé (3 secondes)
            if (_lastAdaptiveZoomUpdate == null ||
                now.difference(_lastAdaptiveZoomUpdate!) > _adaptiveZoomCooldown) {
              // Vérifier si la distance a changé significativement (15%)
              if (_lastDriverToPickupDistance == null) {
                shouldUpdateZoom = true; // Premier appel
              } else {
                final distanceChange =
                    (currentDistance - _lastDriverToPickupDistance!).abs();
                final changePercent =
                    distanceChange / _lastDriverToPickupDistance!;
                if (changePercent > _adaptiveZoomDistanceChangeThreshold) {
                  shouldUpdateZoom = true;
                  myCustomPrintStatement(
                      '📊 Distance changée de ${(changePercent * 100).toStringAsFixed(1)}% → Réajustement du zoom');
                }
              }
            }

            if (shouldUpdateZoom) {
              _lastDriverToPickupDistance = currentDistance;
              _lastAdaptiveZoomUpdate = now;

              // Retracer l'itinéraire depuis la position actuelle puis réajuster le zoom
              // Cela garantit que la polyline montre le trajet RESTANT, pas le trajet initial
              Future.microtask(() async {
                myCustomPrintStatement(
                    '🔄 Retraçage de l\'itinéraire depuis la position actuelle du chauffeur');
                await createPath();
                // createPath() appelle déjà _fitDriverRouteAboveBottomSheet() à la ligne 1786
                // donc pas besoin de l'appeler à nouveau
              });
            }
          }
        } else if (booking!['status'] >= BookingStatusType.RIDE_STARTED.value) {
          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          // 🏁 COURSE EN COURS (rideOngoing) - Status 3+
          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          // NOTE: createPath() appelle déjà _applyAdaptiveZoomForRideInProgress()
          // donc on n'appelle PAS updateRideTrackingWithDynamicZoom() pour éviter
          // un double centrage qui cause un "saut" de caméra
          await createPath();
        }
      }

      myCustomPrintStatement(
          '🚗 Position du driver mise à jour avec zoom adaptatif: ${acceptedDriver!.currentLat}, ${acceptedDriver!.currentLng}');
    } catch (e) {
      myCustomPrintStatement(
          '❌ Erreur lors de la mise à jour de la position du driver: $e');
    }
  }

  /// Ajoute le marqueur du véhicule du driver sur la carte avec l'image de la catégorie depuis Firestore
  Future<void> addDriverVehicleMarker() async {
    try {
      if (acceptedDriver?.currentLat == null ||
          acceptedDriver?.currentLng == null) {
        myCustomPrintStatement(
            '⚠️ Position du driver non disponible pour le marqueur');
        return;
      }

      final mapProvider = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);

      mapProvider.ensureDriverVehicleMarkerVisible();

      // Éviter un doublon avec l'ancien marker du driver (clé = id du driver)
      final driverMarkerId = acceptedDriver!.id;
      if (mapProvider.markers.containsKey(driverMarkerId)) {
        mapProvider.markers.remove(driverMarkerId);
      }

      String vehicleMarkerUrl = MyImagesUrl.carHomeIcon; // Par défaut
      bool isAsset = true; // Par défaut, utiliser les assets locaux
      String vehicleCategory = "unknown";

      // Utiliser l'image du marker depuis les données de la catégorie de véhicule
      if (selectedVehicle?.marker != null &&
          selectedVehicle!.marker.isNotEmpty) {
        vehicleMarkerUrl = selectedVehicle!.marker;
        isAsset = false; // URL réseau depuis Firestore
        vehicleCategory = selectedVehicle!.name;
        myCustomPrintStatement(
            '🚗 Utilisation de l\'image de catégorie véhicule "$vehicleCategory": ${selectedVehicle!.marker}');
      } else {
        // Fallback: essayer d'utiliser les données vehicleType du driver
        if (acceptedDriver?.vehicleData?.vehicleType != null) {
          Map vehicleTypeData = acceptedDriver!.vehicleData!.vehicleType;
          if (vehicleTypeData['marker'] != null &&
              vehicleTypeData['marker'].toString().isNotEmpty) {
            vehicleMarkerUrl = vehicleTypeData['marker'].toString();
            isAsset = false;
            vehicleCategory =
                vehicleTypeData['name']?.toString() ?? "type_from_driver";
            myCustomPrintStatement(
                '🚗 Utilisation de l\'image depuis vehicleType du driver "$vehicleCategory": ${vehicleTypeData['marker']}');
          } else {
            myCustomPrintStatement(
                '⚠️ Pas d\'image marker trouvée dans vehicleType, utilisation de l\'asset par défaut');
          }
        } else {
          myCustomPrintStatement(
              '⚠️ Pas de données vehicleType disponibles, utilisation de l\'asset par défaut');
        }
      }

      BitmapDescriptor? markerDescriptor;
      try {
        markerDescriptor = await mapProvider.getCachedMarkerDescriptor(
          vehicleMarkerUrl,
          isAsset: isAsset,
        );
      } catch (e) {
        myCustomPrintStatement(
            '⚠️ Impossible de charger le marker depuis ${isAsset ? "l\'asset" : "l\'URL"} $vehicleMarkerUrl: $e');
      }

      // Créer/mettre à jour le marqueur du driver avec l'image appropriée
      await mapProvider.createUpdateMarker(
        'driver_vehicle',
        LatLng(acceptedDriver!.currentLat!, acceptedDriver!.currentLng!),
        url: markerDescriptor == null ? vehicleMarkerUrl : null,
        isAsset: isAsset,
        oldLocation: _getDriverOldLocation(),
        animateToCenter: false,
        rotate: true,
        smoothTransition: true,
        customMarker: markerDescriptor,
      );

      myCustomPrintStatement(
          '✅ Marqueur du véhicule driver "$vehicleCategory" ajouté/mis à jour avec ${isAsset ? "asset" : "URL réseau"}: $vehicleMarkerUrl');
    } catch (e) {
      myCustomPrintStatement(
          '❌ Erreur lors de l\'ajout du marqueur du driver: $e');
      // En cas d'erreur, essayer d'ajouter un marqueur par défaut
      try {
        final mapProvider = Provider.of<GoogleMapProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);
        mapProvider.ensureDriverVehicleMarkerVisible();
        BitmapDescriptor? fallbackDescriptor;
        try {
          fallbackDescriptor = await mapProvider.getCachedMarkerDescriptor(
            MyImagesUrl.carHomeIcon,
            isAsset: true,
          );
        } catch (_) {}
        await mapProvider.createUpdateMarker(
          'driver_vehicle',
          LatLng(acceptedDriver!.currentLat!, acceptedDriver!.currentLng!),
          url: fallbackDescriptor == null ? MyImagesUrl.carHomeIcon : null,
          isAsset: true,
          oldLocation: _getDriverOldLocation(),
          animateToCenter: false,
          rotate: true,
          smoothTransition: true,
          customMarker: fallbackDescriptor,
        );
        myCustomPrintStatement('🔄 Marqueur de fallback ajouté avec succès');
      } catch (fallbackError) {
        myCustomPrintStatement(
            '❌ Erreur lors de l\'ajout du marqueur de fallback: $fallbackError');
      }
    }
  }

  LatLng? _getDriverOldLocation() {
    if (acceptedDriver == null) return null;
    final double? oldLat = acceptedDriver!.oldLat;
    final double? oldLng = acceptedDriver!.oldLng;
    if (oldLat == null ||
        oldLng == null ||
        (oldLat == 0 && oldLng == 0) ||
        oldLat.isNaN ||
        oldLng.isNaN) {
      return null;
    }
    return LatLng(oldLat, oldLng);
  }

  bool _hasDriverMovedSignificantly({double thresholdMeters = 5.0}) {
    if (acceptedDriver?.currentLat == null ||
        acceptedDriver?.currentLng == null) {
      return false;
    }

    final LatLng current =
        LatLng(acceptedDriver!.currentLat!, acceptedDriver!.currentLng!);
    final LatLng? previous = _getDriverOldLocation();

    if (previous == null) {
      return true;
    }

    final double movementKm = getDistance(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );

    final double movementMeters = movementKm * 1000;
    return movementMeters >= thresholdMeters;
  }

  int _computeDistanceBand(double distanceKm) {
    if (distanceKm > 6) return 5;
    if (distanceKm > 3) return 4;
    if (distanceKm > 1.5) return 3;
    if (distanceKm > 0.8) return 2;
    if (distanceKm > 0.3) return 1;
    return 0;
  }

  bool _shouldRefitCamera({
    required bool bandChanged,
    required bool cooldownActive,
    required double zoomDifference,
  }) {
    if (bandChanged) return true;
    return !cooldownActive && zoomDifference >= 0.8;
  }

  /// Démarre le suivi en temps réel de la course avec zoom adaptatif initial
  Future<void> startRideTracking() async {
    if (booking != null && acceptedDriver != null) {
      _lastZoomLevel = null;
      _lastZoomUpdate = null;
      _lastDistanceBand = null;
      _hasInitialRideStartedFit = false; // Reset pour forcer le centrage au passage à RIDE_STARTED
      // S'assurer que l'itinéraire est affiché
      createPath();

      try {
        final mapProvider = Provider.of<GoogleMapProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);
        mapProvider.clearDriverPreviewPath();
      } catch (_) {}

      // Démarrer l'écoute en temps réel de la position du driver
      startDriverLocationTracking();

      // Attendre que createPath() finisse son recentrage initial avant d'appliquer le zoom adaptatif
      await Future.delayed(const Duration(milliseconds: 200));

      // Appliquer immédiatement le zoom adaptatif initial
      await updateRideTrackingWithDynamicZoom();

      // Démarrer l'écoute des mises à jour en temps réel du driver
      myCustomPrintStatement(
          '🎯 Suivi en temps réel de la course démarré avec tracking GPS et zoom adaptatif');
    }
  }

  /// Arrête le suivi en temps réel de la course
  void stopRideTracking() {
    final mapProvider = Provider.of<GoogleMapProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false);

    // Arrêter l'écoute de la position du driver
    stopDriverLocationTracking();
    _cancelExtrapolationTimer();
    _stopDriverMotionTicker();
    _driverMotionHistory.clear();
    _driverAverageVelocity = null;
    _smoothedDriverPosition = null;
    _lastMarkerUpdateTime = null;

    // Supprimer le marqueur du driver
    mapProvider.markers.removeWhere((key, value) => key == "driver_vehicle");
    mapProvider.clearDriverVehicleSnapshot();
    mapProvider.clearDriverPreviewPath();

    // Effacer les polylines
    mapProvider.polyLines.clear();
    mapProvider.coveredPolylineCoordinates.clear();

    mapProvider.notifyListeners();

    _lastZoomLevel = null;
    _lastZoomUpdate = null;
    _lastDistanceBand = null;
    _hasInitialRideStartedFit = false; // Reset pour la prochaine course

    // Réinitialiser les variables de zoom adaptatif
    _lastDriverToPickupDistance = null;
    _lastAdaptiveZoomUpdate = null;

    myCustomPrintStatement('🛑 Suivi en temps réel de la course arrêté');
  }

  /// Démarre l'écoute en temps réel de la position du driver
  void startDriverLocationTracking() {
    if (acceptedDriver == null) {
      myCustomPrintStatement(
          '⚠️ Pas de driver accepté pour démarrer le tracking');
      return;
    }

    // Arrêter tout listener précédent
    stopDriverLocationTracking();

    try {
      myCustomPrintStatement(
          '🎯 Démarrage du tracking de position pour driver: ${acceptedDriver!.id}');

      _driverLocationStreamSub = FirestoreServices.users
          .doc(acceptedDriver!.id)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
        try {
          if (snapshot.exists) {
            var driverData = snapshot.data() as Map<String, dynamic>?;
            if (driverData != null) {
              _updateDriverLocationFromFirestore(driverData);
            }
          }
        } catch (e) {
          myCustomPrintStatement(
              '❌ Erreur lors de la mise à jour des données driver: $e');
        }
      });

      myCustomPrintStatement('✅ Driver location tracking démarré');
    } catch (e) {
      myCustomPrintStatement(
          '❌ Erreur lors du démarrage du tracking driver: $e');
    }
  }

  /// Arrête l'écoute en temps réel de la position du driver
  void stopDriverLocationTracking() {
    if (_driverLocationStreamSub != null) {
      _driverLocationStreamSub!.cancel();
      _driverLocationStreamSub = null;
      myCustomPrintStatement('🛑 Driver location tracking arrêté');
    }
  }

  /// Met à jour les données du driver avec les nouvelles données de Firestore
  void _updateDriverLocationFromFirestore(Map<String, dynamic> driverData) {
    try {
      if (acceptedDriver == null) return;

      final mapProvider = Provider.of<GoogleMapProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);
      mapProvider.ensureDriverVehicleMarkerVisible();

      // Extraire les nouvelles coordonnées
      double? newLat =
          double.tryParse((driverData['currentLat'] ?? 0).toString());
      double? newLng =
          double.tryParse((driverData['currentLng'] ?? 0).toString());

      if (newLat == null || newLng == null || newLat == 0 || newLng == 0) {
        myCustomPrintStatement(
            '⚠️ Coordonnées driver invalides: lat=$newLat, lng=$newLng');
        return;
      }

      final DateTime now = DateTime.now();

      const double minDelta = 0.000001;
      final double? previousLat = acceptedDriver!.currentLat;
      final double? previousLng = acceptedDriver!.currentLng;

      final bool positionChanged = previousLat == null ||
          previousLng == null ||
          (newLat - previousLat).abs() > minDelta ||
          (newLng - previousLng).abs() > minDelta;

      if (!positionChanged) {
        _lastFirestoreDriverUpdate = now;
        _scheduleExtrapolationTimer();
        return;
      }

      _lastFirestoreDriverUpdate = now;

      // Mettre à jour les anciennes coordonnées
      acceptedDriver!.oldLat = previousLat;
      acceptedDriver!.oldLng = previousLng;

      // Mettre à jour les nouvelles coordonnées (valeur brute)
      acceptedDriver!.currentLat = newLat;
      acceptedDriver!.currentLng = newLng;

      myCustomPrintStatement(
          '📍 Position driver mise à jour: ($newLat, $newLng)');

      _handleDriverMotionSample(LatLng(newLat, newLng), now);
      _handleRouteDeviation(mapProvider);

      // Si la position a changé et que nous sommes en course, mettre à jour la carte
      if (booking != null &&
          booking!['status'] >= BookingStatusType.ACCEPTED.value &&
          booking!['status'] < BookingStatusType.RIDE_COMPLETE.value) {
        // Mettre à jour la position du marker et le zoom (de manière asynchrone)
        Future.microtask(() => updateDriverLocationOnMap());

        // Calculer la nouvelle distance
        if (pickLocation != null) {
          double newDistance = getDistance(
              acceptedDriver!.currentLat!,
              acceptedDriver!.currentLng!,
              pickLocation!['lat'],
              pickLocation!['lng']);

          if (newDistance != distance) {
            distance = newDistance;
            myCustomPrintStatement(
                '📏 Distance mise à jour: ${distance?.toStringAsFixed(3)}km');
          }
        }

        // Notifier les listeners pour mettre à jour l'UI
        notifyListeners();
      }
    } catch (e) {
      myCustomPrintStatement(
          '❌ Erreur lors de la mise à jour de la position driver: $e');
    }
  }

  /// Calcule le niveau de zoom optimal basé sur la distance entre deux points
  double calculateOptimalZoom(double distanceInKm) {
    // Niveaux de zoom adaptatifs selon la distance
    if (distanceInKm <= 0.1) {
      return 18.0; // Très proche - zoom maximum
    } else if (distanceInKm <= 0.3) {
      return 17.0; // Proche - zoom élevé
    } else if (distanceInKm <= 0.5) {
      return 16.0; // Assez proche - zoom moyen-élevé
    } else if (distanceInKm <= 1.0) {
      return 15.0; // Moyen - zoom standard
    } else if (distanceInKm <= 2.0) {
      return 14.0; // Un peu loin - zoom moyen-faible
    } else if (distanceInKm <= 5.0) {
      return 13.0; // Loin - zoom faible
    } else if (distanceInKm <= 10.0) {
      return 12.0; // Très loin - zoom très faible
    } else {
      return 11.0; // Extrêmement loin - zoom minimal
    }
  }

  /// Centre et zoome la carte pour suivre la course avec zoom adaptatif
  Future<double?> followDriverWithAdaptiveZoom({
    bool adjustZoom = true,
    double? forcedDistance,
    double? forcedZoom,
  }) async {
    try {
      if (acceptedDriver?.currentLat == null ||
          acceptedDriver?.currentLng == null ||
          booking == null ||
          pickLocation == null) {
        myCustomPrintStatement(
            '⚠️ Données insuffisantes pour le suivi adaptatif');
        return null;
      }

      final context = MyGlobalKeys.navigatorKey.currentContext;
      if (context == null) {
        myCustomPrintStatement('⚠️ Contexte null pour le suivi adaptatif');
        return null;
      }

      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);

      // Calculer la distance entre le driver et le point de prise en charge
      final double distanceToPickup = forcedDistance ??
          getDistance(acceptedDriver!.currentLat!, acceptedDriver!.currentLng!,
              pickLocation!['lat'], pickLocation!['lng']);

      // Calculer le zoom optimal basé sur la distance
      final double targetZoom =
          forcedZoom ?? calculateOptimalZoom(distanceToPickup);

      final bottomSheetRatio = _getBottomSheetRatioForTracking();
      final driverPoint =
          LatLng(acceptedDriver!.currentLat!, acceptedDriver!.currentLng!);
      final pickupPoint = LatLng(pickLocation!['lat'], pickLocation!['lng']);

      final fitPoints = <LatLng>[driverPoint, pickupPoint];
      if (mapProvider.polylineCoordinates.isNotEmpty) {
        fitPoints.add(mapProvider.polylineCoordinates.first);
        fitPoints.add(mapProvider.polylineCoordinates.last);
      }

      // Le point fantôme n'est plus nécessaire car IOSMapFix gère maintenant
      // le bottomSheetRatio de manière précise et agressive
      // (déplacement du centre vers le haut + réduction du zoom)

      bool zoomApplied = false;
      bool usedFitBounds = false;
      double? resultingZoom;
      final bool hasMeaningfulMovement =
          _hasDriverMovedSignificantly(thresholdMeters: 6.0);
      final focusPoint = LatLng(
        (driverPoint.latitude + pickupPoint.latitude) / 2,
        (driverPoint.longitude + pickupPoint.longitude) / 2,
      );

      if (adjustZoom && hasMeaningfulMovement) {
        try {
          await IOSMapFix.safeFitBounds(
            controller: mapProvider.controller!,
            points: fitPoints,
            bottomSheetRatio: bottomSheetRatio,
            debugSource: 'driverTracking-driverOnWay',
          );
          zoomApplied = true;
          usedFitBounds = true;
          resultingZoom = targetZoom;
        } catch (e) {
          myCustomPrintStatement(
              '⚠️ Fit bounds échoué, fallback centrage direct: $e');
          await mapProvider.animateToNewTarget(
            focusPoint.latitude,
            focusPoint.longitude,
            zoom: targetZoom,
            bearing: 0.0,
          );
          zoomApplied = true;
          resultingZoom = targetZoom;
        }
      } else if (adjustZoom) {
        myCustomPrintStatement(
            '🚦 Zoom adaptatif ignoré (aucun mouvement significatif détecté)');
      }

      if (!zoomApplied && hasMeaningfulMovement) {
        await mapProvider.animateToNewTarget(
          focusPoint.latitude,
          focusPoint.longitude,
          preserveZoom: true,
        );
        myCustomPrintStatement(
            '↔️ Suivi driver sans changer le zoom: ${distanceToPickup.toStringAsFixed(3)}km');
      } else if (zoomApplied) {
        myCustomPrintStatement(
            '✅ Zoom adaptatif appliqué: ${distanceToPickup.toStringAsFixed(3)}km → zoom $targetZoom');
      } else {
        myCustomPrintStatement(
            '🚦 Suivi driver sans recentrage (aucun mouvement)');
      }

      if (!usedFitBounds && hasMeaningfulMovement) {
        Future.microtask(() {
          mapProvider.centerMapToAbsolutePosition(
            referencePosition: focusPoint,
            bottomSheetHeightRatio: bottomSheetRatio,
            screenHeight: MediaQuery.of(context).size.height,
          );
        });
      }

      if (!hasMeaningfulMovement && _lastZoomLevel == null) {
        _lastZoomLevel = targetZoom;
      }

      return (usedFitBounds && resultingZoom != null && hasMeaningfulMovement)
          ? resultingZoom
          : null;
    } catch (e) {
      myCustomPrintStatement('❌ Erreur lors du suivi adaptatif: $e');
      return null;
    }
  }

  /// Met à jour le suivi avec zoom dynamique basé sur l'état de la course (optimisé)
  Future<void> updateRideTrackingWithDynamicZoom() async {
    try {
      if (acceptedDriver?.currentLat == null ||
          acceptedDriver?.currentLng == null ||
          booking == null) {
        return;
      }

      final status = booking!['status'] ?? -1;

      // Pendant "driver on way" : NE PAS animer la caméra automatiquement
      // car cela interfère avec l'animation fluide du marker gérée par le ticker.
      // Le positionnement initial est déjà fait par createPath() dans startRideTracking().

      // Une fois la course démarrée : suivre vers la destination
      if (status >= BookingStatusType.RIDE_STARTED.value &&
          dropLocation != null) {
        // 🎯 Forcer le centrage initial la première fois qu'on passe à RIDE_STARTED
        if (!_hasInitialRideStartedFit) {
          _hasInitialRideStartedFit = true;
          myCustomPrintStatement('🎯 Premier centrage RIDE_STARTED - forçage du fit');
          await _applyAdaptiveZoomForRideInProgress();
        } else {
          await _followToDestinationWithOptimizedZoom(DateTime.now());
        }
      }
    } catch (e) {
      myCustomPrintStatement('❌ Erreur lors du suivi dynamique: $e');
    }
  }

  Future<void> _fitDriverRouteAboveBottomSheet() async {
    try {
      if (acceptedDriver?.currentLat == null ||
          acceptedDriver?.currentLng == null ||
          pickLocation == null ||
          dropLocation == null) {
        return;
      }

      final context = MyGlobalKeys.navigatorKey.currentContext;
      if (context == null) {
        return;
      }

      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);
      if (mapProvider.controller == null) {
        myCustomPrintStatement(
            '⚠️ _fitDriverRouteAboveBottomSheet: Contrôleur null');
        return;
      }

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 🔍 UTILISER UNIQUEMENT LA POLYLINE (qui contient déjà tous les points)
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // polylineCoordinates contient déjà l'itinéraire complet driver → pickup
      // retourné par OSRM via getPolilyine()

      myCustomPrintStatement(
          '🔍 DEBUG: polylineCoordinates contient ${mapProvider.polylineCoordinates.length} points');

      if (mapProvider.polylineCoordinates.isEmpty) {
        myCustomPrintStatement(
            '⚠️ _fitDriverRouteAboveBottomSheet: polylineCoordinates vide, fallback sur driver + pickup');

        // Fallback si la polyline n'est pas encore chargée
        final driverPoint =
            LatLng(acceptedDriver!.currentLat!, acceptedDriver!.currentLng!);
        final pickupPoint = LatLng(pickLocation!['lat'], pickLocation!['lng']);

        final fallbackPoints = <LatLng>[driverPoint, pickupPoint];

        const double driverOnWayBottomSheetRatio = 0.55;

        await MapUtils.centerPolylineInVisibleArea(
          controller: mapProvider.controller!,
          routePoints: fallbackPoints,
          context: context,
          bottomViewRatio: driverOnWayBottomSheetRatio,
          paddingPercent: 0.15,
        );
        return;
      }

      // ✅ Utiliser directement polylineCoordinates qui contient TOUS les points
      final points = mapProvider.polylineCoordinates;

      // Utiliser la hauteur réelle du bottom sheet pendant "driver on way" (55%)
      const double driverOnWayBottomSheetRatio = 0.55;

      myCustomPrintStatement(
          '📍 _fitDriverRouteAboveBottomSheet: Centrage sur ${points.length} points de la polyline avec bottomSheetRatio=$driverOnWayBottomSheetRatio');

      // ✨ NOUVELLE MÉTHODE : MapUtils.centerPolylineInVisibleArea()
      // Cette méthode calcule le rectangle englobant de la polyline
      // et centre ce rectangle parfaitement dans la zone visible au-dessus du bottom sheet
      // en décalant le centre de la caméra vers le nord
      await MapUtils.centerPolylineInVisibleArea(
        controller: mapProvider.controller!,
        routePoints: points,
        context: context,
        bottomViewRatio: driverOnWayBottomSheetRatio,
        paddingPercent: 0.15, // 15% de padding autour du rectangle
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          myCustomPrintStatement(
              '⏰ Timeout _fitDriverRouteAboveBottomSheet - continuant sans recentrage');
        },
      );

      // Initialiser/mettre à jour la distance pour le zoom adaptatif
      final double currentDistance = getDistance(
        acceptedDriver!.currentLat!,
        acceptedDriver!.currentLng!,
        pickLocation!['lat'],
        pickLocation!['lng'],
      );
      _lastDriverToPickupDistance = currentDistance;
      _lastAdaptiveZoomUpdate = DateTime.now();

      myCustomPrintStatement(
          '📊 Distance initiale driver→pickup: ${currentDistance.toStringAsFixed(2)}km');
    } catch (e) {
      myCustomPrintStatement('⚠️ _fitDriverRouteAboveBottomSheet fallback: $e');
      try {
        final mapProvider = Provider.of<GoogleMapProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);
        final double centerLat =
            (acceptedDriver!.currentLat! + pickLocation!['lat']) / 2;
        final double centerLng =
            (acceptedDriver!.currentLng! + pickLocation!['lng']) / 2;
        await mapProvider.animateToNewTarget(
          centerLat,
          centerLng,
          zoom: 15.0,
          bearing: 0.0,
        );
      } catch (_) {}
    }
  }

  /// Suivi optimisé vers la destination
  Future<void> _followToDestinationWithOptimizedZoom(DateTime now) async {
    double distanceToDestination = getDistance(
        acceptedDriver!.currentLat!,
        acceptedDriver!.currentLng!,
        dropLocation!['lat'],
        dropLocation!['lng']);

    final context = MyGlobalKeys.navigatorKey.currentContext;
    if (context == null) {
      myCustomPrintStatement('⚠️ Contexte null pour le suivi destination');
      return;
    }

    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);

    final double optimalZoom = _calculateZoomForDistance(distanceToDestination);
    final int currentBand = _computeDistanceBand(distanceToDestination);
    final double zoomDifference = _lastZoomLevel != null
        ? (optimalZoom - _lastZoomLevel!).abs()
        : double.infinity;
    final bool cooldownActive = _lastZoomUpdate != null &&
        now.difference(_lastZoomUpdate!) < _zoomUpdateCooldown;
    final bool bandChanged =
        _lastDistanceBand == null || currentBand != _lastDistanceBand;
    final bool shouldAdjustZoom = _shouldRefitCamera(
      bandChanged: bandChanged,
      cooldownActive: cooldownActive,
      zoomDifference: zoomDifference,
    );

    final bottomSheetRatio = _getBottomSheetRatioForTracking();
    final driverPoint =
        LatLng(acceptedDriver!.currentLat!, acceptedDriver!.currentLng!);
    final destinationPoint = LatLng(dropLocation!['lat'], dropLocation!['lng']);

    final points = <LatLng>[driverPoint, destinationPoint];
    if (mapProvider.polylineCoordinates.isNotEmpty) {
      points.add(mapProvider.polylineCoordinates.first);
      points.add(mapProvider.polylineCoordinates.last);
    }

    // Le point fantôme n'est plus nécessaire car IOSMapFix gère maintenant
    // le bottomSheetRatio de manière précise et agressive
    // (déplacement du centre vers le haut + réduction du zoom)

    bool zoomApplied = false;
    bool usedFitBounds = false;
    double? resultingZoom;
    final bool hasMeaningfulMovement =
        _hasDriverMovedSignificantly(thresholdMeters: 8.0);
    final focusPoint = LatLng(
      (driverPoint.latitude + destinationPoint.latitude) / 2,
      (driverPoint.longitude + destinationPoint.longitude) / 2,
    );

    if (shouldAdjustZoom && hasMeaningfulMovement) {
      try {
        await IOSMapFix.safeFitBounds(
          controller: mapProvider.controller!,
          points: points,
          bottomSheetRatio: bottomSheetRatio,
          debugSource: 'driverTracking-destination',
        );
        zoomApplied = true;
        usedFitBounds = true;
        resultingZoom = optimalZoom;
      } catch (e) {
        myCustomPrintStatement(
            '❌ Fit bounds destination échoué, fallback centrage direct: $e');
        await mapProvider.animateToNewTarget(
          focusPoint.latitude,
          focusPoint.longitude,
          zoom: optimalZoom,
          bearing: 0.0,
        );
        zoomApplied = true;
        resultingZoom = optimalZoom;
      }
    } else if (shouldAdjustZoom) {
      myCustomPrintStatement(
          '🚦 Zoom destination ignoré (aucun mouvement significatif détecté)');
    }

    if (!zoomApplied && hasMeaningfulMovement) {
      await mapProvider.animateToNewTarget(
        focusPoint.latitude,
        focusPoint.longitude,
        preserveZoom: true,
      );
      myCustomPrintStatement(
          '↔️ Suivi destination sans ajuster le zoom: ${distanceToDestination.toStringAsFixed(3)}km');
    } else if (zoomApplied) {
      myCustomPrintStatement(
          '🎯 Suivi course en cours - zoom ajusté: ${distanceToDestination.toStringAsFixed(3)}km');
    } else {
      myCustomPrintStatement(
          '🚦 Suivi destination sans recentrage (aucun mouvement)');
    }

    if (!usedFitBounds && hasMeaningfulMovement) {
      Future.microtask(() {
        mapProvider.centerMapToAbsolutePosition(
          referencePosition: focusPoint,
          bottomSheetHeightRatio: bottomSheetRatio,
          screenHeight: MediaQuery.of(context).size.height,
        );
      });
    }

    _lastDistanceBand = currentBand;
    if (resultingZoom != null && hasMeaningfulMovement) {
      _lastZoomLevel = resultingZoom;
    } else if (!hasMeaningfulMovement && _lastZoomLevel == null) {
      _lastZoomLevel = optimalZoom;
    }
    _lastZoomUpdate = now;
  }

  /// Calcule le niveau de zoom approprié pour afficher le chauffeur et la destination
  double _calculateZoomForDistance(double distanceInKm) {
    // Niveaux de zoom adaptatifs pour afficher chauffeur et destination
    if (distanceInKm <= 0.3) {
      return 16.0; // Très proche - zoom élevé pour voir les détails
    } else if (distanceInKm <= 0.8) {
      return 15.0; // Proche - zoom moyen-élevé
    } else if (distanceInKm <= 1.5) {
      return 14.0; // Moyen - zoom standard
    } else if (distanceInKm <= 3.0) {
      return 13.0; // Un peu loin - zoom moyen-faible
    } else if (distanceInKm <= 6.0) {
      return 12.0; // Loin - zoom faible
    } else if (distanceInKm <= 12.0) {
      return 11.0; // Très loin - zoom très faible
    } else {
      return 10.0; // Extrêmement loin - zoom minimal
    }
  }

  /// Calcule le padding adaptatif pour le suivi de course
  double _getAdaptivePaddingForTracking() {
    // Obtenir la hauteur de l'écran
    final size = MediaQuery.of(MyGlobalKeys.navigatorKey.currentContext!).size;
    final screenHeight = size.height;

    // Estimer la hauteur du bottom sheet (environ 30-40% de l'écran pendant la course)
    final bottomSheetHeight = screenHeight * 0.35;

    // Padding de base pour les côtés et le haut
    const double basePadding = 100.0;

    // Padding adaptatif pour le bas (tenir compte du bottom sheet)
    final bottomPadding = bottomSheetHeight + 50;

    // Retourner le padding le plus important pour s'assurer que tout est visible
    return math.max(basePadding, bottomPadding);
  }

  void _ensureDriverMotionTicker() {
    if (_driverMotionTicker == null) {
      _driverMotionTicker = Ticker(_onDriverMotionTick);
    }
    if (!(_driverMotionTicker!.isActive)) {
      _driverMotionTicker!.start();
    }
  }

  void _stopDriverMotionTicker() {
    if (_driverMotionTicker != null) {
      _driverMotionTicker!.stop();
      _driverMotionTicker!.dispose();
      _driverMotionTicker = null;
    }
  }

  void _scheduleExtrapolationTimer() {
    _driverExtrapolationTimer?.cancel();
    _driverExtrapolationTimer =
        Timer(_driverExtrapolationTrigger, _startDriverExtrapolation);
  }

  void _cancelExtrapolationTimer() {
    _driverExtrapolationTimer?.cancel();
    _driverExtrapolationTimer = null;
  }

  LatLng _applyComplementaryFilter(LatLng rawPosition) {
    if (_smoothedDriverPosition == null) {
      return rawPosition;
    }

    const double alpha = 0.65; // Higher alpha -> more weight on new data
    final double filteredLat = alpha * rawPosition.latitude +
        (1 - alpha) * _smoothedDriverPosition!.latitude;
    final double filteredLng = alpha * rawPosition.longitude +
        (1 - alpha) * _smoothedDriverPosition!.longitude;
    return LatLng(filteredLat, filteredLng);
  }

  /// Processes a fresh GPS sample received from Firestore.
  /// Applies a complementary filter, stores the sample history,
  /// prepares the interpolation segment and resets extrapolation state.
  void _handleDriverMotionSample(LatLng rawPosition, DateTime timestamp) {
    final LatLng filteredPosition = _applyComplementaryFilter(rawPosition);
    _lastFirestoreDriverUpdate = timestamp;
    _driverExtrapolationStartTime = null;
    _isDriverExtrapolating = false;
    _scheduleExtrapolationTimer();

    _driverMotionHistory.add(
      _DriverMotionSample(position: filteredPosition, timestamp: timestamp),
    );
    if (_driverMotionHistory.length > 5) {
      _driverMotionHistory.removeAt(0);
    }

    final LatLng startPosition = (_smoothedDriverPosition != null)
        ? _smoothedDriverPosition!
        : filteredPosition;

    Duration duration = _driverInterpolationDuration;
    if (_driverMotionHistory.length > 1) {
      final previousSample =
          _driverMotionHistory[_driverMotionHistory.length - 2];
      duration = timestamp.difference(previousSample.timestamp);
    }

    if (duration.isNegative) {
      duration = Duration(milliseconds: duration.inMilliseconds.abs());
    }

    if (duration.inMilliseconds.abs() < 200) {
      duration = const Duration(milliseconds: 200);
    } else if (duration.inMilliseconds > 4000) {
      duration = const Duration(milliseconds: 4000);
    }

    _driverAverageVelocity = _computeAverageVelocity();

    _startDriverInterpolation(
      start: startPosition,
      target: filteredPosition,
      duration: duration,
      isExtrapolation: false,
    );
  }

  /// Computes an average velocity vector (in degrees per second)
  /// using the last few samples. Returns null if the movement is insufficient.
  ui.Offset? _computeAverageVelocity() {
    if (_driverMotionHistory.length < 2) {
      return null;
    }
    double sumLatPerSec = 0.0;
    double sumLngPerSec = 0.0;
    int segments = 0;

    final int startIndex = math.max(0, _driverMotionHistory.length - 4);
    for (int i = startIndex + 1; i < _driverMotionHistory.length; i++) {
      final current = _driverMotionHistory[i];
      final previous = _driverMotionHistory[i - 1];
      final double seconds =
          current.timestamp.difference(previous.timestamp).inMilliseconds /
              1000.0;
      if (seconds <= 0) {
        continue;
      }
      final double latPerSec =
          (current.position.latitude - previous.position.latitude) / seconds;
      final double lngPerSec =
          (current.position.longitude - previous.position.longitude) / seconds;
      sumLatPerSec += latPerSec;
      sumLngPerSec += lngPerSec;
      segments++;
    }

    if (segments == 0) {
      return null;
    }

    return ui.Offset(sumLatPerSec / segments, sumLngPerSec / segments);
  }

  void resetDriverTrackingForHome() {
    _stopDriverMotionTicker();
    _cancelExtrapolationTimer();
    _driverMotionHistory.clear();
    _smoothedDriverPosition = null;
    _driverAverageVelocity = null;
    _driverInterpolationStartPosition = null;
    _driverInterpolationTargetPosition = null;
    _driverInterpolationStartTime = null;
    _driverInterpolationDuration = const Duration(milliseconds: 1200);
    _isDriverExtrapolating = false;
    _driverExtrapolationStartTime = null;
    _lastRouteRefresh = null;
    _lastDeviationPosition = null;
    _consecutiveDeviationSamples = 0;
    _lastZoomLevel = null;
  }

  double? _doubleFromDynamic(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  /// Initializes a new interpolation segment between [start] and [target].
  /// When [isExtrapolation] is true, the motion controller will keep projecting
  /// forward until a real GPS update is received or the max extrapolation
  /// duration is exceeded.
  void _startDriverInterpolation({
    required LatLng start,
    required LatLng target,
    required Duration duration,
    required bool isExtrapolation,
  }) {
    _driverInterpolationStartPosition = start;
    _driverInterpolationTargetPosition = target;
    _driverInterpolationStartTime = DateTime.now();
    _driverInterpolationDuration = duration;
    _isDriverExtrapolating = isExtrapolation;
    if (isExtrapolation && _driverExtrapolationStartTime == null) {
      _driverExtrapolationStartTime = DateTime.now();
    }
    _ensureDriverMotionTicker();
  }

  /// Starts a short extrapolation segment when Firestore stops sending
  /// fresh samples. The extrapolation reuses the last known average velocity.
  void _startDriverExtrapolation() {
    if (_isDriverExtrapolating) {
      return;
    }

    final ui.Offset? velocity =
        _driverAverageVelocity ?? _computeAverageVelocity();
    if (velocity == null) {
      return;
    }

    LatLng? anchorPosition = _smoothedDriverPosition;

    anchorPosition ??= (_driverMotionHistory.isNotEmpty)
        ? _driverMotionHistory.last.position
        : null;

    if (anchorPosition == null) {
      return;
    }

    final LatLng projectedTarget = LatLng(
      anchorPosition.latitude +
          velocity.dx * _driverExtrapolationSegment.inSeconds,
      anchorPosition.longitude +
          velocity.dy * _driverExtrapolationSegment.inSeconds,
    );

    _driverAverageVelocity = velocity;

    _startDriverInterpolation(
      start: anchorPosition,
      target: projectedTarget,
      duration: _driverExtrapolationSegment,
      isExtrapolation: true,
    );
  }

  /// Evaluates the current driver position against the displayed polyline and
  /// triggers a lightweight OSRM recalculation when the vehicle consistently
  /// deviates from the suggested route.
  void _handleRouteDeviation(GoogleMapProvider mapProvider) {
    if (mapProvider.polylineCoordinates.length < 2) {
      _consecutiveDeviationSamples = 0;
      _lastDeviationPosition = null;
      return;
    }

    LatLng? currentPosition = _smoothedDriverPosition;
    if (currentPosition == null &&
        acceptedDriver?.currentLat != null &&
        acceptedDriver?.currentLng != null) {
      currentPosition =
          LatLng(acceptedDriver!.currentLat!, acceptedDriver!.currentLng!);
    }

    if (currentPosition == null) {
      return;
    }

    final double? deviationMeters =
        mapProvider.distanceToPolyline(currentPosition);
    if (deviationMeters == null) {
      return;
    }

    if (deviationMeters < _routeDeviationThresholdMeters) {
      if (_consecutiveDeviationSamples != 0 || _lastDeviationPosition != null) {
        _consecutiveDeviationSamples = 0;
        _lastDeviationPosition = null;
      }
      return;
    }

    double travelledSinceDeviation = _minimumDeviationMovementMeters;
    if (_lastDeviationPosition != null) {
      travelledSinceDeviation = getDistance(
            _lastDeviationPosition!.latitude,
            _lastDeviationPosition!.longitude,
            currentPosition.latitude,
            currentPosition.longitude,
          ) *
          1000;
    }

    if (travelledSinceDeviation < _minimumDeviationMovementMeters) {
      return;
    }

    _consecutiveDeviationSamples += 1;
    _lastDeviationPosition = currentPosition;

    if (_consecutiveDeviationSamples < _requiredDeviationSamples) {
      return;
    }

    final DateTime now = DateTime.now();
    if (_lastRouteRefresh != null &&
        now.difference(_lastRouteRefresh!) < _routeRefreshCooldown) {
      return;
    }

    double? destinationLat;
    double? destinationLng;
    int bookingStatus = 0;
    if (booking != null && booking!['status'] != null) {
      final dynamic rawStatus = booking!['status'];
      if (rawStatus is int) {
        bookingStatus = rawStatus;
      } else {
        bookingStatus = int.tryParse(rawStatus.toString()) ?? 0;
      }
    }

    if (bookingStatus < BookingStatusType.RIDE_STARTED.value) {
      destinationLat = _doubleFromDynamic(pickLocation?['lat']);
      destinationLng = _doubleFromDynamic(pickLocation?['lng']);
    } else {
      destinationLat = _doubleFromDynamic(dropLocation?['lat']);
      destinationLng = _doubleFromDynamic(dropLocation?['lng']);
    }

    if (destinationLat == null || destinationLng == null) {
      return;
    }

    mapProvider.getPolilyine(
      currentPosition.latitude,
      currentPosition.longitude,
      destinationLat,
      destinationLng,
      topPaddingPercentage: 0.1,
    );

    _lastRouteRefresh = now;
    _consecutiveDeviationSamples = 0;
    _lastDeviationPosition = currentPosition;

    myCustomPrintStatement(
        '🧭 Route recalculation triggered (booking=${booking?['id']}, deviation=${deviationMeters.toStringAsFixed(1)}m)');
  }

  /// Tick handler driving the interpolation/extrapolation. Each tick computes
  /// the eased intermediate position, updates map visuals and chains the next
  /// extrapolation segment when required.
  void _onDriverMotionTick(Duration elapsed) {
    if (_driverInterpolationStartPosition == null ||
        _driverInterpolationTargetPosition == null ||
        _driverInterpolationStartTime == null ||
        _driverInterpolationDuration.inMilliseconds == 0) {
      return;
    }

    final DateTime now = DateTime.now();
    double progress =
        now.difference(_driverInterpolationStartTime!).inMilliseconds /
            _driverInterpolationDuration.inMilliseconds;

    bool finished = false;
    if (progress >= 1.0) {
      progress = 1.0;
      finished = true;
    } else if (progress < 0.0) {
      progress = 0.0;
    }

    final double eased = Curves.easeInOut.transform(progress);
    final double currentLat = ui.lerpDouble(
          _driverInterpolationStartPosition!.latitude,
          _driverInterpolationTargetPosition!.latitude,
          eased,
        ) ??
        _driverInterpolationTargetPosition!.latitude;
    final double currentLng = ui.lerpDouble(
          _driverInterpolationStartPosition!.longitude,
          _driverInterpolationTargetPosition!.longitude,
          eased,
        ) ??
        _driverInterpolationTargetPosition!.longitude;

    final LatLng currentPosition = LatLng(currentLat, currentLng);
    // Réduire la fréquence de notifyListeners pour éviter trop de reconstructions
    // Ne notifier que lorsque l'interpolation est terminée ou tous les 20% de progression
    bool shouldNotify = finished || progress == 0.0 || (progress * 100).round() % 20 == 0;
    _applySmoothedDriverPosition(
      currentPosition,
      notifyListenersFlag: shouldNotify,
    );

    if (!finished) {
      return;
    }

    _driverInterpolationStartPosition = currentPosition;
    _driverInterpolationStartTime = now;

    if (_isDriverExtrapolating) {
      if (_driverExtrapolationStartTime != null &&
          now.difference(_driverExtrapolationStartTime!) >=
              _driverExtrapolationMax) {
        _isDriverExtrapolating = false;
        _driverInterpolationTargetPosition = null;
        _driverInterpolationStartTime = null;
        _stopDriverMotionTicker();
        return;
      }

      final ui.Offset? velocity = _driverAverageVelocity;
      if (velocity == null) {
        _isDriverExtrapolating = false;
        _driverInterpolationTargetPosition = null;
        _driverInterpolationStartTime = null;
        _stopDriverMotionTicker();
        return;
      }

      final LatLng nextTarget = LatLng(
        currentPosition.latitude +
            velocity.dx * _driverExtrapolationSegment.inSeconds,
        currentPosition.longitude +
            velocity.dy * _driverExtrapolationSegment.inSeconds,
      );

      _driverInterpolationTargetPosition = nextTarget;
      _driverInterpolationDuration = _driverExtrapolationSegment;
    } else {
      _driverInterpolationTargetPosition = null;
      _driverInterpolationStartTime = null;
      _driverMotionTicker?.stop();
    }
  }

  /// Stores and broadcasts the current smoothed driver position.
  /// Also updates the marker, preview polyline and gently notifies listeners.
  void _applySmoothedDriverPosition(LatLng position,
      {bool notifyListenersFlag = true}) {
    final LatLng? previous = _smoothedDriverPosition;
    _smoothedDriverPosition = position;

    if (acceptedDriver != null) {
      acceptedDriver!.currentLat = position.latitude;
      acceptedDriver!.currentLng = position.longitude;
    }

    final BuildContext? context = MyGlobalKeys.navigatorKey.currentContext;
    if (context != null) {
      try {
        final mapProvider =
            Provider.of<GoogleMapProvider>(context, listen: false);
        _updateDriverMarkerVisual(mapProvider, position,
            previousPosition: previous);
        mapProvider.updateDriverPreviewPath(position);
      } catch (e) {
        myCustomPrintStatement('❌ Error updating driver visuals: $e');
      }
    }

    _applyZoomForDriverApproach(position);

    if (notifyListenersFlag) {
      notifyListeners();
    }
  }

  void _applyZoomForDriverApproach(LatLng position) {
    // Zoom adaptatif avec COOLDOWN LONG (60s) pour ne pas interférer avec l'animation du marker
    // Permet d'ajuster progressivement le zoom quand le driver se rapproche/éloigne du pickup
    // Aide l'utilisateur à visualiser l'avancement du chauffeur

    if (currentStep != CustomTripType.driverOnWay || booking == null) {
      return;
    }

    final dynamic rawStatus = booking!['status'];
    int status = 0;
    if (rawStatus is int) {
      status = rawStatus;
    } else if (rawStatus != null) {
      status = int.tryParse(rawStatus.toString()) ?? 0;
    }

    // Seulement pour l'étape "driver on way" (pas ride started)
    if (status >= BookingStatusType.RIDE_STARTED.value) {
      return;
    }

    if (pickLocation == null) {
      return;
    }

    // Calculer la distance actuelle driver→pickup
    final double currentDistance = getDistance(
      position.latitude,
      position.longitude,
      pickLocation!['lat'],
      pickLocation!['lng'],
    );

    // Première fois : initialiser sans recentrer
    if (_lastDriverToPickupDistance == null) {
      _lastDriverToPickupDistance = currentDistance;
      _lastAdaptiveZoomUpdate = DateTime.now();
      myCustomPrintStatement(
          '📍 Distance initiale driver→pickup: ${currentDistance.toStringAsFixed(2)}km');
      return;
    }

    // Vérifier le cooldown de 60 secondes pour éviter les recentrages trop fréquents
    final DateTime now = DateTime.now();
    if (_lastAdaptiveZoomUpdate != null &&
        now.difference(_lastAdaptiveZoomUpdate!) < _adaptiveZoomCooldown) {
      return;
    }

    // Calculer le changement de distance en pourcentage
    final double distanceChange =
        (_lastDriverToPickupDistance! - currentDistance).abs();
    final double changePercentage = distanceChange / _lastDriverToPickupDistance!;

    // Si le changement est supérieur au seuil (20%), recentrer et zoomer
    if (changePercentage >= _adaptiveZoomDistanceChangeThreshold) {
      myCustomPrintStatement(
          '🔍 Adaptive zoom triggered: distance changed by ${(changePercentage * 100).toStringAsFixed(1)}% '
          '(${_lastDriverToPickupDistance!.toStringAsFixed(2)}km → ${currentDistance.toStringAsFixed(2)}km)');

      _lastDriverToPickupDistance = currentDistance;
      _lastAdaptiveZoomUpdate = now;

      // Recentrer l'itinéraire complet avec zoom adaptatif
      // Cooldown de 60s garantit que ça n'interfère pas avec l'animation à 60fps
      Future.microtask(() => _fitDriverRouteAboveBottomSheet());
    }

    /* Code désactivé - remplacé par le système ci-dessus
    final double targetZoom =
        calculateOptimalZoom(distanceKm).clamp(13.0, 18.0);

    if (_lastZoomLevel != null && (_lastZoomLevel! - targetZoom).abs() < 0.05) {
      return;
    }

    final BuildContext? context = MyGlobalKeys.navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    try {
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);
      mapProvider.zoomTo(targetZoom);
      _lastZoomLevel = targetZoom;
      _lastZoomUpdate = DateTime.now();
    } catch (e) {
      myCustomPrintStatement('⚠️ Zoom adaptation error: $e');
    }
    */
  }

  /// Updates the driver marker without recreating it, ensuring heading and
  /// visibility stay in sync with the smoothed position.
  void _updateDriverMarkerVisual(
    GoogleMapProvider mapProvider,
    LatLng position, {
    LatLng? previousPosition,
  }) {
    final DateTime now = DateTime.now();
    if (_lastMarkerUpdateTime != null &&
        now.difference(_lastMarkerUpdateTime!) <
            const Duration(milliseconds: 60)) {
      return;
    }
    _lastMarkerUpdateTime = now;

    final Marker? existingMarker = mapProvider.markers['driver_vehicle'];

    if (existingMarker == null) {
      Future.microtask(() async {
        await addDriverVehicleMarker();
        _updateDriverMarkerVisual(mapProvider, position,
            previousPosition: previousPosition);
      });
      return;
    }

    final LatLng baseline = previousPosition ?? existingMarker.position;

    double rotation = existingMarker.rotation;
    if (baseline.latitude != position.latitude ||
        baseline.longitude != position.longitude) {
      try {
        rotation = mapProvider.bearingBetween(baseline, position);
      } catch (_) {}
    }

    mapProvider.markers['driver_vehicle'] = existingMarker.copyWith(
      visibleParam: true,
      positionParam: position,
      rotationParam: rotation,
    );
    mapProvider.notifyListeners();
  }

  @override
  void dispose() {
    _sequentialNotificationTimer?.cancel();
    stopDriverLocationTracking();
    _cancelExtrapolationTimer();
    _stopDriverMotionTicker();
    super.dispose();
  }
}
