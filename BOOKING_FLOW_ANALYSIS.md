# Analyse du Flux de Réservation - Riderapp

## 1. FLUX COMPLET DE SÉLECTION D'ADRESSE

### Étapes principales (CustomTripType enum):
1. **setYourDestination** - Écran principal où l'utilisateur choisit un trajet
2. **choosePickupDropLocation** - Saisie des adresses pickup et drop
3. **selectScheduleTime** - Choix du créneau horaire (trajets planifiés uniquement)
4. **chooseVehicle** - Sélection du type de véhicule
5. **payment** - Sélection de la méthode de paiement
6. **selectAvailablePromocode** - Application d'un code promo
7. **confirmDestination** - Confirmation finale avant création du booking
8. **requestForRide** - État en attente d'acceptation du chauffeur
9. **driverOnWay** - Le chauffeur est en route vers vous
10. **orangeMoneyPayment, paymentMobileConfirm** - Écrans de paiement mobile

---

## 2. WIDGETS/BOTTOM SHEETS DE SAISIE D'ADRESSE

### Fichier: `/lib/bottom_sheet_widget/pickup_and_drop_location_sheet.dart`
**Classe:** `PickupAndDropLocation` (StatefulWidget)

#### Structure des données d'adresse:
```dart
Map pickupLocation = {
  "lat": double,           // Latitude (nullable initialement)
  "lng": double,           // Longitude (nullable initialement)
  "controller": TextEditingController(),  // Pour l'adresse texte
};

Map dropLocation = {
  "lat": double,           // Latitude (nullable initialement)
  "lng": double,           // Longitude (nullable initialement)
  "controller": TextEditingController(),  // Pour l'adresse texte
};
```

#### Fonctionnalités:
- Initialise avec la position actuelle de l'utilisateur (`currentPosition`, `currentFullAddress`)
- Tracking d'abandon avec timeline (timeout 60s)
- Suggestionnaires de localisation avec `getPlacePridiction()`
- Permet la sélection via deux modes:
  - Mode texte (saisie avec suggestions)
  - Mode carte (dragging du pin)

#### Callback:
```dart
onTap: (pickup, drop) async {
  tripProvider.pickLocation = pickup;  // {"lat": double, "lng": double, "address": string}
  tripProvider.dropLocation = drop;    // {"lat": double, "lng": double, "address": string}
  await tripProvider.createPath();
  tripProvider.setScreen(CustomTripType.chooseVehicle);
}
```

---

## 3. FLUX COMPLET: HOME_SCREEN → BOOKING CREATION

### Localisation: `/lib/pages/view_module/home_screen.dart`

#### Étape 1: Sélection de départ/destination
**Ligne 1140-1184:** Widget `PickupAndDropLocation`
```
home_screen.dart (CustomTripType.choosePickupDropLocation)
    ↓
PickupAndDropLocation bottom sheet
    ↓
Utilisateur saisit/sélectionne pickup → drop
    ↓
onTap callback déclenché avec:
  - pickup Map {lat, lng, address}
  - drop Map {lat, lng, address}
```

#### Étape 2: Sauvegarde dans TripProvider
**Ligne 1145-1146:**
```dart
tripProvider.pickLocation = pickup;
tripProvider.dropLocation = drop;
```

#### Étape 3: Création du trajet (calcul distance/route)
**Ligne 1173-1174:**
```dart
await tripProvider.createPath(topPaddingPercentage: 0.8);
  // Calcule route, distance, durée
```

#### Étape 4: Transition vers choix du véhicule
**Ligne 1175-1176:**
```dart
tripProvider.setScreen(CustomTripType.chooseVehicle);
  // Affiche ChooseVehicleSheet
```

#### Étape 5: Choix du véhicule
**Fichier:** `/lib/bottom_sheet_widget/choose_vehicle_sheet.dart`
- Utilisateur sélectionne type de véhicule
- `selectedVehicle` mis à jour dans TripProvider
- Navigation vers payment ou promo code

#### Étape 6: Confirmation finale
**Fichier:** `/lib/bottom_sheet_widget/confirm_destination.dart`
**Classe:** `ConfirmDestination` (StatefulWidget)

Affiche:
- Adresse pickup (affichage seul)
- Adresse drop (affichage seul)
- Prix estimé
- Détails du véhicule

**Bouton Confirm (Ligne 206-229):**
```dart
onTap: () async {
  showLoading();
  
  // Appel de la création du booking
  await tripProvider.createRequest(
    vehicleDetails: tripProvider.selectedVehicle!,
    paymentMethod: widget.paymentMethod.value,
    pickupLocation: tripProvider.pickLocation!,
    dropLocation: tripProvider.dropLocation!,
    scheduleTime: tripProvider.rideScheduledTime,
    isScheduled: tripProvider.rideScheduledTime != null,
    promocodeDetails: tripProvider.selectedPromoCode
  );
  
  tripProvider.setScreen(CustomTripType.requestForRide);
  hideLoading();
}
```

#### Étape 7: Création du booking en Firestore
**Fichier:** `/lib/provider/trip_provider.dart`
**Méthode:** `createRequest()` → `createBooking()`

Localisation: Ligne 2147 en avant

---

## 4. DONNÉES SAUVEGARDÉES DANS FIRESTORE

### Collection: `bookingRequest` ou `bookingHistory`

**Champs liés aux adresses:**

```dart
Map<String, dynamic> data = {
  // === ADRESSES ET COORDONNÉES ===
  "pickLat": double,               // Latitude du pickup (source: pickupLocation['lat'])
  "pickLng": double,               // Longitude du pickup (source: pickupLocation['lng'])
  "pickAddress": string,           // Adresse formatée du pickup (source: pickupLocation['address'])
  
  "dropLat": double,               // Latitude du drop
  "dropLng": double,               // Longitude du drop
  "dropAddress": string,           // Adresse du drop
  
  "city": string,                  // Ville de départ (source: pickupLocation['city'])
  
  // === DISTANCE ET ROUTE ===
  "distance_in_km_approx": string, // Distance approximée en km
  "currentRouteIndex": int,        // Index de la route actuelle (0 = pickup, 1 = drop)
  "coveredPath": List,             // Chemin couvert par le conducteur
  
  // === AUTRES CHAMPS CLÉS ===
  "id": string,                    // ID unique du booking
  "requestBy": string,             // ID de l'utilisateur
  "vehicle": string,               // ID du type de véhicule
  "paymentMethod": string,         // Méthode de paiement
  "requestTime": Timestamp,        // Heure de création
  "scheduleTime": Timestamp,       // Heure programmée (si planifié)
  "isSchedule": bool,              // Est-ce un trajet planifié?
  "isPreviousSchedule": bool,      // A été programmé avant?
  
  // === PRIX ===
  "total_ride_price": string,      // Prix total avant remises
  "ride_price_to_pay": string,     // Prix final à payer
  "ride_promocode_discount": double,
  "ride_extra_discount": string,
  "rideScheduledServiceFee": double,
  
  // === STATUT ===
  "ride_status": string,           // "Running"
  "status": int,                   // 0=demande, 1=acceptée, 2=en cours, etc
  "acceptedBy": string?,           // ID du conducteur qui a accepté (null initialement)
  "ride_cancelled_by": string,     // Qui a annulé la course
  
  // === OTP ET SÉCURITÉ ===
  "bookingOTP": string,            // Code OTP de la réservation
  
  // === TARIFICATION ===
  "vehicle_price_per_km": double,
  "vehicle_base_price": double,
  "vehicle_price_per_min": double,
  "waiting_time_rate_per_min": double,
};
```

**Pas de champ "flight_number" actuellement!**

---

## 5. STRUCTURE DES MAPS PICKUPLOCATION / DROPLOCATION

### Dans TripProvider (memory):
```dart
class TripProvider extends ChangeNotifier {
  Map? pickLocation;   // {lat, lng, address, city?, ...}
  Map? dropLocation;   // {lat, lng, address, city?, ...}
}
```

### Format minimal accepté:
```dart
{
  "lat": 18.8792,
  "lng": 47.5079,
  "address": "Ivato, Antananarivo, Madagascar"
}
```

### Champs optionnels:
- `city`: Ville dérivée de l'adresse
- `placeId`: Identifiant Google Places
- D'autres métadonnées selon le service de géocodage

---

## 6. DÉTECTION D'AÉROPORT - ÉTAT ACTUEL

### Résultat de recherche:
**AUCUNE détection d'aéroport existante**

Recherche effectuée pour:
- "airport"
- "aeroport"  
- "aéroport"

Résultats: 0 occurrences dans le code source

---

## 7. CAS D'USAGE POUR L'AJOUT DU CHAMP "FLIGHT_NUMBER"

### Scénarios de détection d'aéroport:
1. **Adresse contient "airport" / "aéroport" / "aéroport"**
2. **Adresse correspond à un aéroport connu** (ex: "Ivato", "Antananarivo International Airport")
3. **Utilisateur sélectionne "Aéroport" dans une catégorie spéciale**

### Où ajouter la logique:

#### Option 1: Dans PickupAndDropLocation (lors de la saisie)
- Détecter quand l'utilisateur saisit une adresse contenant "airport/aéroport"
- Afficher un champ de saisie supplémentaire pour le numéro de vol

#### Option 2: Dans ConfirmDestination (avant confirmation)
- Vérifier pickAddress et dropAddress
- Si l'une contient un aéroport, afficher le champ numéro de vol
- Obligation de remplir avant de confirmer

#### Option 3: Dans TripProvider.createBooking()
- Ajouter détection au moment du stockage
- Ajouter le champ `flight_number` au Map data si détecté

### Proposition d'intégration:

**Ajouter aux Maps pickLocation et dropLocation:**
```dart
Map pickLocation = {
  "lat": double,
  "lng": double,
  "address": string,
  "isAirport": bool,           // Nouveau: détecté automatiquement
  "flightNumber": string?,     // Nouveau: optionnel, rempli par utilisateur si aéroport
};
```

**Dans createBooking(), ajouter:**
```dart
"pickFlightNumber": pickupLocation?['flightNumber'] ?? "",
"dropFlightNumber": dropLocation?['flightNumber'] ?? "",
"pickIsAirport": pickupLocation?['isAirport'] ?? false,
"dropIsAirport": dropLocation?['isAirport'] ?? false,
```

---

## 8. FICHIERS CLÉS À MODIFIE

Pour ajouter le support du numéro de vol:

1. **`/lib/bottom_sheet_widget/pickup_and_drop_location_sheet.dart`**
   - Ajouter détection aéroport lors saisie
   - Ajouter champ de saisie conditionnelle pour flight_number

2. **`/lib/bottom_sheet_widget/confirm_destination.dart`**
   - Afficher le numéro de vol si aéroport détecté
   - Valider la saisie du flight number

3. **`/lib/provider/trip_provider.dart`**
   - Ajouter champs "flightNumber", "isAirport" aux Maps
   - Ajouter au Map data dans createBooking()
   - Créer méthode détection aéroport

4. **`/lib/services/firestore_services.dart`** (si besoin)
   - Index Firestore pour les requêtes filtrées par aéroport

---

## 9. REMARQUES IMPORTANTES

1. **Pas de modèle Location/Address** - Tout utilise des Maps dynamiques
2. **Adresses stockées comme texte brut** - `pickAddress` et `dropAddress` sont des strings
3. **Pas de géocodage inverse** - L'adresse fournie par l'utilisateur est stockée telle quelle
4. **Pas de validation d'adresse** - Les coordonnées et l'adresse peuvent ne pas matcher parfaitement
5. **Abandon tracking actif** - Il y a un système de tracking des abandons de saisie d'adresse
6. **Analytics intégré** - Chaque recherche est loggée avec distance KM

---

