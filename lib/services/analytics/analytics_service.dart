import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:rider_ride_hailing_app/contants/vehicle_categories.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;

  /// Anti-doublon par session. Réinitialisé à chaque cold-start de l'app.
  /// Trade-off : si l'app crash pendant une course acceptée et redémarre,
  /// on pourrait logger l'event une 2e fois. Acceptable pour analytics
  /// (vs coût d'un write Firestore par booking).
  static final Set<String> _loggedBookingIds = <String>{};


  // Initialisation
  static Future<void> initialize() async {
    try {
      myCustomPrintStatement('🔧 Analytics.initialize() - Début');
      
      _analytics = FirebaseAnalytics.instance;
      myCustomPrintStatement('🔧 FirebaseAnalytics.instance créé');
      
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      myCustomPrintStatement('🔧 FirebaseAnalyticsObserver créé');
      
      // Activer la collecte de données
      await _analytics!.setAnalyticsCollectionEnabled(true);
      myCustomPrintStatement('🔧 Analytics collection enabled');
      
      myCustomPrintStatement('✅ Firebase Analytics initialisé avec succès');
    } catch (e) {
      myCustomPrintStatement('❌ Erreur initialisation Analytics: $e');
      myCustomPrintStatement('🔍 Analytics Error type: ${e.runtimeType}');
      myCustomPrintStatement('🔍 Analytics Error details: ${e.toString()}');
    }
  }
  
  // Observer pour navigation
  static FirebaseAnalyticsObserver? get observer => _observer;
  
  // Setter pour user ID
  static Future<void> setUserId(String? userId) async {
    if (_analytics == null) return;
    await _analytics!.setUserId(id: userId);
  }
  
  // Propriétés utilisateur
  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (_analytics == null) return;
    await _analytics!.setUserProperty(name: name, value: value);
  }
  
  // === EVENTS GÉNÉRIQUES ===
  
  static Future<void> logEvent(
    String name, {
    Map<String, dynamic>? parameters,
  }) async {
    if (_analytics == null) return;
    
    try {
      // Nettoyer les paramètres (Firebase n'accepte que certains types)
      final cleanParams = _cleanParameters(parameters);
      
      await _analytics!.logEvent(
        name: name,
        parameters: cleanParams,
      );
      
      myCustomPrintStatement('📊 Event: $name | Params: $cleanParams');
    } catch (e) {
      myCustomPrintStatement('❌ Erreur log event $name: $e');
    }
  }
  
  // === EVENTS SPÉCIFIQUES MISY ===
  
  static Future<void> logAppOpened({
    required String? userId,
    String? appVersion,
  }) async {
    await logEvent('app_opened', parameters: {
      'user_id': userId ?? 'anonymous',
      'app_version': appVersion ?? 'unknown',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static Future<void> logUserLogin({
    required String method,
    required String userId,
  }) async {
    // Event standard Firebase
    await _analytics?.logLogin(loginMethod: method);
    
    // Event custom avec plus de détails
    await logEvent('user_logged_in', parameters: {
      'method': method,
      'user_id': userId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Set user ID pour tous les events futurs
    await setUserId(userId);
  }
  
  static Future<void> logUserRegistration({
    required String method,
    required String userId,
  }) async {
    // Event standard Firebase
    await _analytics?.logSignUp(signUpMethod: method);
    
    // Event custom
    await logEvent('user_registered', parameters: {
      'method': method,
      'user_id': userId,
    });
  }
  
  static Future<void> logRideTypeClicked({
    required String rideType, // 'immediate' ou 'scheduled'
    required String? userId,
  }) async {
    await logEvent('${rideType}_ride_clicked', parameters: {
      'user_id': userId ?? 'anonymous',
      'screen_name': 'home',
    });
  }
  
  static Future<void> logDestinationSearched({
    required String fromAddress,
    required String toAddress,
    double? distanceKm,
  }) async {
    await logEvent('destination_searched', parameters: {
      'from_address': _truncateString(fromAddress, 100),
      'to_address': _truncateString(toAddress, 100),
      if (distanceKm != null) 'distance_km': distanceKm,
    });
  }
  
  static Future<void> logPriceDisplayed({
    required double price,
    double? distanceKm,
    double? durationMin,
  }) async {
    await logEvent('price_displayed', parameters: {
      'price_amount': price,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (durationMin != null) 'duration_min': durationMin,
    });
  }
  
  static Future<void> logRideBooked({
    required String rideId,
    required double price,
    required String paymentMethod,
    double? distanceKm,
    String? pickupZone,
    int? waitTimeSeconds,
  }) async {
    await logEvent('ride_booked', parameters: {
      'ride_id': rideId,
      'price': price,
      'payment_method': paymentMethod,
      'currency': 'MGA',
      if (distanceKm != null) 'distance_km': distanceKm,
      if (pickupZone != null && pickupZone.isNotEmpty) 'pickup_zone': pickupZone,
      if (waitTimeSeconds != null) 'wait_time_seconds': waitTimeSeconds,
    });

    // Event standard e-commerce Firebase
    await _analytics?.logPurchase(
      currency: 'MGA',
      value: price,
      transactionId: rideId,
    );
  }

  /// Logue qu'un chauffeur a accepté une course (event courant + catégorisé
  /// moto/vtc). Source unique pour les conversions Meta Ads — appelé au
  /// passage `acceptedBy: null → non-null` côté trip_provider.
  ///
  /// Anti-doublon : un même `bookingId` est ignoré aux appels suivants
  /// dans la même session (Set en mémoire).
  static Future<void> logBookingConfirmedByDriver({
    required Map<String, dynamic> booking,
  }) async {
    final String rideId = (booking['id'] ?? '').toString();
    if (rideId.isEmpty) {
      myCustomPrintStatement(
          '⚠️ logBookingConfirmedByDriver: rideId vide, skip');
      return;
    }
    if (_loggedBookingIds.contains(rideId)) {
      if (kDebugMode) {
        debugPrint(
            '[Analytics] booking $rideId déjà loggé, skip (anti-doublon)');
      }
      return;
    }
    _loggedBookingIds.add(rideId);

    // Extraction des champs (tolérante au schéma — booking est un Map Firestore)
    final double priceAr = _toDouble(booking['total_ride_price']) ??
        _toDouble(booking['ride_price_to_pay']) ??
        0.0;
    final String paymentMethod = (booking['paymentMethod'] ?? '').toString();
    final double? distanceKm = _toDouble(booking['distance_in_km_approx']);
    final String pickupZone = (booking['commission_zone_name'] ?? '').toString();
    final int? waitTimeSeconds = _computeWaitSeconds(
      booking['requestTime'],
      booking['acceptedTime'],
    );

    // 1) Générique
    await logRideBooked(
      rideId: rideId,
      price: priceAr,
      paymentMethod: paymentMethod,
      distanceKm: distanceKm,
      pickupZone: pickupZone,
      waitTimeSeconds: waitTimeSeconds,
    );
    if (kDebugMode) {
      debugPrint(
          '[Analytics] ride_booked logged | bookingId=$rideId | price=$priceAr MGA');
    }

    // 2) Catégorisation moto/VTC
    final Map<String, dynamic>? selectedVehicle = booking['selectedVehicle'] is Map
        ? Map<String, dynamic>.from(booking['selectedVehicle'] as Map)
        : null;
    final String vehicleId = (selectedVehicle?['id'] ?? '').toString();
    final String vehicleName = (selectedVehicle?['name'] ?? '').toString();

    if (vehicleId.isEmpty && vehicleName.isEmpty) {
      return;
    }

    final bool isMoto =
        VehicleCategories.isMoto(id: vehicleId, name: vehicleName);
    // Exclusion explicite des livraisons (Colis) — pas de catégorie VTC pour ça.
    final bool isDelivery = vehicleName.toLowerCase().contains('colis');
    if (!isMoto && isDelivery) {
      return;
    }

    final String category = isMoto ? 'moto' : 'vtc';
    final String firebaseEventName =
        isMoto ? 'moto_ride_booked' : 'vtc_ride_booked';

    await logEvent(firebaseEventName, parameters: {
      'ride_id': rideId,
      'price_ar': priceAr,
      'currency': 'MGA',
      if (distanceKm != null) 'distance_km': distanceKm,
      if (pickupZone.isNotEmpty) 'pickup_zone': pickupZone,
      'payment_method': paymentMethod,
      if (waitTimeSeconds != null) 'wait_time_seconds': waitTimeSeconds,
      'vehicle_id': vehicleId,
      'vehicle_name': vehicleName,
    });
    if (kDebugMode) {
      debugPrint(
          '[Analytics] $firebaseEventName logged | bookingId=$rideId | category=$category | vehicle=$vehicleName');
    }
  }

  /// Logue le premier ouvrage de l'app — Firebase uniquement côté web
  /// (le SDK Meta App Events n'a pas de support web stable).
  static Future<void> logFirstOpen() async {
    try {
      await logEvent('first_open');
      myCustomPrintStatement('First open tracked (Firebase web)');
    } catch (e) {
      myCustomPrintStatement('Error tracking first open: $e');
    }
  }

  // Helpers privés pour logBookingConfirmedByDriver
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) {
      return double.tryParse(v);
    }
    return null;
  }

  static int? _computeWaitSeconds(dynamic requestTime, dynamic acceptedTime) {
    final DateTime? req = _toDateTime(requestTime);
    final DateTime? acc = _toDateTime(acceptedTime);
    if (req == null || acc == null) return null;
    final diff = acc.difference(req).inSeconds;
    return diff >= 0 ? diff : null;
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    // Firestore Timestamp côté Flutter
    try {
      final dyn = v as dynamic;
      final dt = dyn.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
  
  static Future<void> logRideCancelled({
    required String rideId,
    required String reason,
    required String cancelledBy, // 'rider' ou 'driver'
  }) async {
    await logEvent('ride_cancelled', parameters: {
      'ride_id': rideId,
      'cancellation_reason': reason,
      'cancelled_by': cancelledBy,
    });
  }
  
  static Future<void> logRideCompleted({
    required String rideId,
    required double finalPrice,
    int? rating,
    double? durationMin,
  }) async {
    await logEvent('ride_completed', parameters: {
      'ride_id': rideId,
      'final_price': finalPrice,
      if (rating != null) 'rating': rating,
      if (durationMin != null) 'duration_min': durationMin,
    });
  }
  
  static Future<void> logVehicleSelected({
    required String vehicleType,
    required String vehicleName,
    required double price,
    required bool isScheduled,
    String? userId,
  }) async {
    await logEvent('vehicle_selected', parameters: {
      'vehicle_type': vehicleType,
      'vehicle_name': vehicleName,
      'price': price,
      'is_scheduled': isScheduled ? 'true' : 'false',
      'user_id': userId ?? 'anonymous',
    });
  }
  
  static Future<void> logPaymentMethodSelected({
    required String paymentMethod,
    required double tripPrice,
    required bool hasPromo,
    String? userId,
  }) async {
    await logEvent('payment_method_selected', parameters: {
      'payment_method': paymentMethod,
      'trip_price': tripPrice,
      'has_promo': hasPromo ? 'true' : 'false',
      'user_id': userId ?? 'anonymous',
    });
  }
  
  static Future<void> logScheduledRideButtonClicked({
    String? userId,
  }) async {
    await logEvent('scheduled_ride_button_clicked', parameters: {
      'user_id': userId ?? 'anonymous',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  // === ÉVÉNEMENTS D'ABANDON ===
  
  static Future<void> logAddressSelectionAbandoned({
    required int timeSpentSeconds,
    required String reason,
    int? addressesSearched,
    String? partialAddress,
    String? userId,
  }) async {
    await logEvent('address_selection_abandoned', parameters: {
      'time_spent_seconds': timeSpentSeconds,
      'abandonment_reason': reason,
      if (addressesSearched != null) 'addresses_searched': addressesSearched,
      if (partialAddress != null && partialAddress.isNotEmpty) 'partial_address': _truncateString(partialAddress, 50),
      'user_id': userId ?? 'anonymous',
    });
  }
  
  static Future<void> logVehicleSelectionAbandoned({
    required int timeSpentSeconds,
    required String reason,
    double? cheapestPriceViewed,
    double? mostExpensivePriceViewed,
    int? vehiclesAvailable,
    String? userId,
  }) async {
    await logEvent('vehicle_selection_abandoned', parameters: {
      'time_spent_seconds': timeSpentSeconds,
      'abandonment_reason': reason,
      if (cheapestPriceViewed != null) 'cheapest_price_viewed': cheapestPriceViewed,
      if (mostExpensivePriceViewed != null) 'most_expensive_price_viewed': mostExpensivePriceViewed,
      if (vehiclesAvailable != null) 'vehicles_available': vehiclesAvailable,
      'user_id': userId ?? 'anonymous',
    });
  }
  
  static Future<void> logPaymentSelectionAbandoned({
    required int timeSpentSeconds,
    required String reason,
    required double tripPrice,
    int? paymentMethodsAvailable,
    String? availableMethods,
    String? userId,
  }) async {
    await logEvent('payment_selection_abandoned', parameters: {
      'time_spent_seconds': timeSpentSeconds,
      'abandonment_reason': reason,
      'trip_price': tripPrice,
      if (paymentMethodsAvailable != null) 'payment_methods_available': paymentMethodsAvailable,
      if (availableMethods != null) 'available_methods': availableMethods,
      'user_id': userId ?? 'anonymous',
    });
  }
  
  static Future<void> logConfirmationAbandoned({
    required int timeSpentSeconds,
    required String reason,
    required double tripPrice,
    required String paymentMethod,
    required String vehicleType,
    String? userId,
  }) async {
    await logEvent('confirmation_abandoned', parameters: {
      'time_spent_seconds': timeSpentSeconds,
      'abandonment_reason': reason,
      'trip_price': tripPrice,
      'payment_method': paymentMethod,
      'vehicle_type': vehicleType,
      'user_id': userId ?? 'anonymous',
    });
  }
  
  // === HELPERS ===
  
  static Map<String, Object> _cleanParameters(Map<String, dynamic>? params) {
    if (params == null) return {};
    
    final cleaned = <String, Object>{};
    params.forEach((key, value) {
      // Firebase n'accepte que string, int, double
      if (value == null) {
        return;
      } else if (value is String || value is int || value is double) {
        cleaned[key] = value;
      } else if (value is bool) {
        // Convertir bool en string pour Firebase Analytics
        cleaned[key] = value ? 'true' : 'false';
      } else {
        cleaned[key] = value.toString();
      }
    });
    
    return cleaned;
  }
  
  static String _truncateString(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
}