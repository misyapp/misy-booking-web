# CODE SNIPPETS - Flux de Réservation

## 1. INITIALISATION DE LOCATION DANS PICKUP_AND_DROP_LOCATION_SHEET.DAR

**Fichier:** `/lib/bottom_sheet_widget/pickup_and_drop_location_sheet.dart`
**Ligne:** 43-112

```dart
// Structure des Maps locales
Map pickupLocation = {
  "lat": null,
  "lng": null,
  "controller": TextEditingController(),
};

Map dropLocation = {
  "lat": null,
  "lng": null,
  "controller": TextEditingController(),
};

// Initialisé au démarrage avec position actuelle
@override
void initState() {
  super.initState();
  pickupLocation['controller'].text = currentFullAddress ?? '';
  pickUpAddress.value = currentFullAddress ?? '';
  pickupLocation['lat'] = currentPosition!.latitude;
  pickupLocation['lng'] = currentPosition!.longitude;
}
```

---

## 2. CALLBACK ONTAL DANS HOME_SCREEN.DART

**Fichier:** `/lib/pages/view_module/home_screen.dart`
**Ligne:** 1140-1184

```dart
PickupAndDropLocation(
  key: MyGlobalKeys.chooseDropAndPickAddPageKey,
  onTap: (pickup, drop) async {
    try {
      showLoading();
      
      // Sauvegarde les Maps dans TripProvider
      tripProvider.pickLocation = pickup;  // {lat, lng, address, ...}
      tripProvider.dropLocation = drop;    // {lat, lng, address, ...}

      // Analytics
      AnalyticsService.logDestinationSearched(
        fromAddress: pickup['address'] ?? 'Unknown',
        toAddress: drop['address'] ?? 'Unknown',
        distanceKm: distance,
      );

      // Calcul du trajet
      await tripProvider.createPath(topPaddingPercentage: 0.8);
      
      // Transition vers choix du véhicule
      tripProvider.setScreen(CustomTripType.chooseVehicle);
      updateBottomSheetHeight();
      hideLoading();
    } catch (e) {
      hideLoading();
      print('Erreur lors de la création du trajet: $e');
    }
  },
)
```

---

## 3. CONSTRUCTION DES MAPS PICKUP/DROP DANS PICKUP_AND_DROP_LOCATION_SHEET.DAR

**Fichier:** `/lib/bottom_sheet_widget/pickup_and_drop_location_sheet.dart`
**Ligne:** 411-453

```dart
// Quand l'utilisateur confirme
var p = {
  "lat": pickupLocation['lat'],
  "lng": pickupLocation['lng'],
  "address": pickupLocation['controller'].text,
};

var d = {
  "lat": dropLocation['lat'],
  "lng": dropLocation['lng'],
  "address": dropLocation['controller'].text,
};

// Validation
if (p['lat'] != null && p['lng'] != null && 
    d['lat'] != null && d['lng'] != null) {
  
  // Sauvegarde en préférences locales
  await DevFestPreferences().setSearchSuggestion({
    "pickup": p,
    "drop": d
  });
  
  // Appel du callback
  widget.onTap(p, d);
}
```

---

## 4. CONFIRM_DESTINATION - APPEL DE CREATE_REQUEST

**Fichier:** `/lib/bottom_sheet_widget/confirm_destination.dart`
**Ligne:** 206-229

```dart
RoundEdgedButton(
  verticalMargin: 16,
  width: double.infinity,
  text: translate("Confirm"),
  onTap: () async {
    try {
      showLoading();
      
      myCustomPrintStatement(
        "booking is empty pickup location at confirm " +
        "${tripProvider.pickLocation} " +
        "drop location ${tripProvider.dropLocation} " +
        "${tripProvider.rideScheduledTime}"
      );

      // ÉTAPE CRUCIALE: création du booking
      await tripProvider.createRequest(
        vehicleDetails: tripProvider.selectedVehicle!,
        paymentMethod: widget.paymentMethod.value,
        pickupLocation: tripProvider.pickLocation!,  // Map {lat, lng, address}
        dropLocation: tripProvider.dropLocation!,    // Map {lat, lng, address}
        scheduleTime: tripProvider.rideScheduledTime,
        isScheduled: tripProvider.rideScheduledTime != null,
        promocodeDetails: tripProvider.selectedPromoCode
      );
      
      // Transition vers écran d'attente
      tripProvider.setScreen(CustomTripType.requestForRide);
      hideLoading();
    } catch (e) {
      hideLoading();
      myCustomPrintStatement("Erreur lors de la création de la demande: $e");
      showSnackbar(translate("Une erreur s'est produite. Veuillez réessayer."));
    }
  },
)
```

---

## 5. TRIP_PROVIDER.CREATEBOOKING - SAUVEGARDE FIRESTORE

**Fichier:** `/lib/provider/trip_provider.dart`
**Ligne:** 2147-2345

```dart
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
  
  // Création du Map de données
  Map<String, dynamic> data = {
    // === ADRESSES (sources: pickupLocation et dropLocation) ===
    "id": bookingId.isEmpty
        ? FirestoreServices.bookingHistory.doc().id
        : bookingId,
    "paymentMethod": paymentMethod,
    "requestBy": userData.value!.id,
    "vehicle": vehicleDetails.id,
    
    // === PICKUP LOCATION ===
    'city': pickupLocation!['city'],
    "pickLat": pickupLocation!['lat'],
    "pickLng": pickupLocation!['lng'],
    "pickAddress": pickupLocation!['address'],
    
    // === DROP LOCATION ===
    "dropLat": dropLocation!['lat'],
    "dropLng": dropLocation!['lng'],
    "dropAddress": dropLocation!['address'],
    
    // === AUTRES CHAMPS ===
    "isSchedule": isScheduled,
    "scheduleTime": Timestamp.fromDate(scheduleTime ?? DateTime.now()),
    "bookingOTP": generateOtp(),
    "ride_status": "Running",
    "distance_in_km_approx": totalWilltake.value.distance.toStringAsFixed(2),
    "currentRouteIndex": 0,
    "coveredPath": [],
    "ride_cancelled_by": "",
    "requestTime": Timestamp.now(),
    "acceptedBy": null,
    "status": 0,
    "total_ride_price": calculatePriceForVehicle(vehicleDetails).toStringAsFixed(2),
    // ... autres champs de prix, tarification, etc ...
  };
  
  // === SAUVEGARDE EN FIRESTORE ===
  if (bookingId.isEmpty) {
    await FirestoreServices.bookingRequest.doc(data['id']).set(data);
    booking = data;
  }
  
  // Store localement
  booking = data;
  notifyListeners();
}
```

---

## 6. STRUCTURE DES ENUMS CUSTOMTRIPTYPE

**Fichier:** `/lib/contants/global_data.dart`
**Ligne:** 75-87

```dart
enum CustomTripType {
  setYourDestination,              // Écran principal
  choosePickupDropLocation,        // Saisie adresses
  selectScheduleTime,              // Choix créneau (trajet programmé)
  chooseVehicle,                   // Choix du véhicule
  payment,                         // Choix paiement
  selectAvailablePromocode,        // Promo code
  orangeMoneyPayment,              // Écran paiement Orange
  paymentMobileConfirm,            // Confirmation mobile money
  confirmDestination,              // Confirmation AVANT création booking
  driverOnWay,                     // Trajet en cours
  requestForRide,                  // En attente acceptation
}
```

---

## 7. TRIP_PROVIDER - PROPRIÉTÉS CLÉS

**Fichier:** `/lib/provider/trip_provider.dart`
**Ligne:** 120-130

```dart
class TripProvider extends ChangeNotifier {
  CustomTripType? _currentStep = CustomTripType.setYourDestination;
  
  // === ADRESSES ===
  Map? pickLocation;           // {lat, lng, address, city?, controller}
  Map? dropLocation;           // {lat, lng, address, city?, controller}
  Map? booking;                // Booking sauvegardé en Firestore
  
  // === SÉLECTIONS ===
  VehicleModal? selectedVehicle;
  PromoCodeModal? selectedPromoCode;
  
  // === PAIEMENT ===
  double paymentMethodDiscountAmount = 0;
  double paymentMethodDiscountPercentage = 0;
  
  // === CONDUCTEUR ===
  DriverModal? acceptedDriver;
  
  // Getter pour l'étape actuelle
  CustomTripType? get currentStep => _currentStep;
  
  // Setter avec logging
  set currentStep(CustomTripType? newStep) {
    _currentStep = newStep;
    notifyListeners();
  }
}
```

---

## 8. FLOW COMPLET: HOME → CONFIRMATION → FIRESTORE

```
home_screen.dart (setYourDestination)
  ↓
Utilisateur clique "Où allez-vous?"
  ↓
PickupAndDropLocation bottom sheet affichée
  ↓
Utilisateur saisit/sélectionne pickup
  ↓
Utilisateur saisit/sélectionne drop
  ↓
Confirme les deux adresses
  ↓
Callback onTap(pickup Map, drop Map)
  ↓
tripProvider.pickLocation = pickup
tripProvider.dropLocation = drop
tripProvider.createPath()
tripProvider.setScreen(CustomTripType.chooseVehicle)
  ↓
ChooseVehicleSheet affichée
  ↓
Utilisateur sélectionne véhicule
  ↓
tripProvider.selectedVehicle = vehicle
  ↓
ConfirmDestination bottom sheet affichée
Affiche READ-ONLY: pickLocation['address'], dropLocation['address']
  ↓
Utilisateur clique "Confirm"
  ↓
tripProvider.createRequest(
  pickupLocation: tripProvider.pickLocation!,  // Map avec {lat, lng, address}
  dropLocation: tripProvider.dropLocation!,    // Map avec {lat, lng, address}
  vehicleDetails, paymentMethod, ...
)
  ↓
tripProvider.createBooking()
  ↓
Création Map<String, dynamic> data:
  "pickLat": pickLocation['lat']
  "pickLng": pickLocation['lng']
  "pickAddress": pickLocation['address']
  "dropLat": dropLocation['lat']
  "dropLng": dropLocation['lng']
  "dropAddress": dropLocation['address']
  ... + 40+ autres champs ...
  ↓
FirestoreServices.bookingRequest.doc(id).set(data)
  ↓
Sauvegarde en Firestore ✓
  ↓
tripProvider.setScreen(CustomTripType.requestForRide)
  ↓
RequestForRide sheet affichée
En attente d'acceptation du chauffeur...
```

---

## 9. FORMATS DE DONNÉES PASSÉES

### Structure d'une location passée au createRequest():

```dart
// Exemple réel
Map pickupLocation = {
  "lat": 18.8792,
  "lng": 47.5079,
  "address": "Ivato, Antananarivo, Madagascar",
  "city": "Antananarivo",
  "controller": TextEditingController(), // Pas sauvegardé en Firestore
};

Map dropLocation = {
  "lat": 18.8798,
  "lng": 47.5085,
  "address": "Analakely, Antananarivo, Madagascar",
  "controller": TextEditingController(),
};

// Structure en Firestore après sauvegarde:
{
  "pickLat": 18.8792,
  "pickLng": 47.5079,
  "pickAddress": "Ivato, Antananarivo, Madagascar",
  "city": "Antananarivo",
  
  "dropLat": 18.8798,
  "dropLng": 47.5085,
  "dropAddress": "Analakely, Antananarivo, Madagascar",
  // (pas de "dropCity" actuellement)
}
```

---

## 10. CHAMPS DE BOOKING COMPLETS EN FIRESTORE

```dart
// Voir createBooking() ligne 2163-2286
Map<String, dynamic> data = {
  // Identifiants
  "id": string,
  "requestBy": string,
  "vehicle": string,
  "acceptedBy": null,
  
  // Localisation
  "pickLat": double,
  "pickLng": double,
  "pickAddress": string,
  "city": string,
  "dropLat": double,
  "dropLng": double,
  "dropAddress": string,
  
  // Route
  "distance_in_km_approx": string,
  "currentRouteIndex": int,
  "coveredPath": List,
  
  // Timing
  "requestTime": Timestamp,
  "scheduleTime": Timestamp,
  "acceptedTime": null,
  "startedTime": null,
  "endTime": null,
  
  // Statut
  "ride_status": string,
  "status": int,
  "isSchedule": bool,
  "isPreviousSchedule": bool,
  "startRide": bool,
  
  // Paiement
  "paymentMethod": string,
  "total_ride_price": string,
  "ride_price_to_pay": string,
  "ride_driver_earning": string,
  
  // Tarification
  "vehicle_price_per_km": double,
  "vehicle_base_price": double,
  "vehicle_price_per_min": double,
  "waiting_time_rate_per_min": double,
  
  // Sécurité & Autres
  "bookingOTP": string,
  "rejectedBY": List,
  "chats": List,
  "ride_cancelled_by": string,
  
  // Promos & Réductions
  "promocodeDetails": Map?,
  "discount": double,
  "ride_promocode_discount": double,
  "ride_extra_discount": string,
};
```

