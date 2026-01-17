import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;
  
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
  }) async {
    await logEvent('ride_booked', parameters: {
      'ride_id': rideId,
      'price': price,
      'payment_method': paymentMethod,
      'currency': 'MGA',
    });
    
    // Event standard e-commerce Firebase
    await _analytics?.logPurchase(
      currency: 'MGA',
      value: price,
      transactionId: rideId,
    );
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