import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/modal/global_settings_modal.dart';
import 'package:rider_ride_hailing_app/modal/loyalty_config_modal.dart';
import 'package:rider_ride_hailing_app/modal/payment_gateway_secret_keys_modal.dart';
import 'package:rider_ride_hailing_app/modal/total_time_distance_modal.dart';
import 'package:rider_ride_hailing_app/modal/vehicle_modal.dart';
import 'package:rider_ride_hailing_app/models/pricing/pricing_config_v2.dart';

import '../modal/user_modal.dart';

Map<String, String> globalHeaders = {
  'Accept': 'text/json',
  'Content-Type': 'text/json'
};
// String googleMapApiKey = "AIzaSyBbcjTBakwdPpLeuQvb_5Fk6jY9oqXwOko";
String googleMapApiKey = "AIzaSyALcvZZmiEonxqzce2fYyZvqc9wiByYO3g";
ValueNotifier<String> selectedLanguage = ValueNotifier('English');
ValueNotifier<Locale> selectedLocale = ValueNotifier(const Locale('en'));
PaymentGatewaySecretKeyModal? paymentGateWaySecretKeys;
 ValueNotifier<PaymentMethodType?> selectPayMethod = ValueNotifier(null);

List languagesList = [
  {'key': 'en', 'value': 'English'},
  {'key': 'mg', 'value': 'Malagasy'},
  {'key': 'fr', 'value': 'French'},
  {'key': 'it', 'value': 'Italian'},
  {'key': 'pl', 'value': 'Polish'},
];
ValueNotifier<Map<String, dynamic>> selectedLanguageNotifier =
    ValueNotifier(languagesList[0]);
List<Map> vehicleListMap = [];
List<VehicleModal> vehicleListModal = [];
Map<String, VehicleModal> vehicleMap = {};
ValueNotifier<List> lastSearchSuggestion = ValueNotifier([]);

// Configuration du système de tarification V2
PricingConfigV2? pricingConfigV2;

// Configuration du système de fidélité
LoyaltyConfigModal? loyaltyConfig;
const double globalHorizontalPadding = 18;

// Distance minimale pour proposer un trajet (1h de marche ≈ 5 km à 5 km/h)
// En dessous de cette distance, afficher "aucun trajet disponible"
const double minDistanceForTrip = 5.0; // en kilomètres
ValueNotifier<UserModal?> userData = ValueNotifier(null);
String dummyUserImage =
    "https://firebasestorage.googleapis.com/v0/b/misy-95336.appspot.com/o/dummy_user_image.png?alt=media&token=1be6b364-ddb3-4723-89e7-6b656f064f05";
Map<String, dynamic> minVehicleDistance = {};
Map<String, LatLng> nearestVehicleLatLng = {};
ValueNotifier<Map<String, TotalTimeDistanceModal>> nearestDriverTime =
    ValueNotifier({});
// Flag pour bloquer la navigation automatique du listener pendant Google Sign-In
bool isGoogleSignInInProgress = false;
// Flag pour bloquer la navigation automatique du listener pendant Facebook Sign-In
bool isFacebookSignInInProgress = false;
// Flag pour bloquer la navigation automatique du listener pendant le logout/suppression de compte
bool isLogoutInProgress = false;

GlobalSettingsModal globalSettings = GlobalSettingsModal.fromJson({
  "admin_commission": 15.0,
  "location_live": true,
  "distance_limit_scheduled": 50,
  "distance_limit_now": 50,
  "min_radius": 25.0,
  "currency": "Ar",
  "id": "K4uBeiA9Oby4sSomAdHN",
  "min_withdrawal": 1500
});
ValueNotifier<TotalTimeDistanceModal> totalWilltake =
    ValueNotifier(TotalTimeDistanceModal(time: 0, distance: 0));

ValueNotifier<int> unreadCount = ValueNotifier(0);
ValueNotifier<int> unreadMessagesCount = ValueNotifier(0); // Compteur courrier
ValueNotifier<bool> sheetShowNoti = ValueNotifier(true);
ValueNotifier<bool> dropLocationPickerHideNoti = ValueNotifier(false);
ValueNotifier<bool> showHomePageMenuNoti = ValueNotifier(true);
ValueNotifier<bool> pickupLocationPickerHideNoti = ValueNotifier(false);

enum CustomTripType {
  setYourDestination,
  choosePickupDropLocation,
  selectScheduleTime,
  flightNumberEntry,
  chooseVehicle,
  payment,
  selectAvailablePromocode,
  orangeMoneyPayment,
  paymentMobileConfirm,
  confirmDestination,
  driverOnWay,
  requestForRide,
}
