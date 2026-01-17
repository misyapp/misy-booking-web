# Suivi Projet - Intégration Numéro de Vol pour Courses Aéroport

## Informations Projet

- **Branche** : `feature/flight-number-integration`
- **Date de début** : 2025-11-05
- **Équipe** : Features (Backend + UI)
- **Statut** : 🟡 En planification
- **Version cible** : 2.2.0

## Objectif

Permettre aux utilisateurs de saisir un numéro de vol lors de réservations vers/depuis un aéroport. Le numéro de vol sera :
- Partagé avec le chauffeur pour les courses instantanées et programmées
- Cliquable pour ouvrir automatiquement les informations du vol (iOS/Android)

## Contexte Technique

### Projets Concernés
- **riderapp** : `/Users/stephane/StudioProjects/riderapp` (branche créée ✓)
- **driverapp** : `/Users/stephane/StudioProjects/driverapp` (branche créée ✓)

### Documentation de Référence
Analyse complète du flux de réservation disponible dans :
- `BOOKING_FLOW_EXECUTIVE_SUMMARY.txt`
- `BOOKING_FLOW_ANALYSIS.md`
- `BOOKING_FLOW_DIAGRAM.txt`
- `BOOKING_FLOW_CODE_SNIPPETS.md`

## Architecture de la Solution

### 1. Détection des Aéroports

**Méthode** : Détection basée sur l'adresse via mots-clés
```dart
// Nouvelle classe utilitaire
class AirportDetectionService {
  static bool isAirportAddress(String address) {
    final normalized = address.toLowerCase();
    return normalized.contains('aéroport') ||
           normalized.contains('aeroport') ||
           normalized.contains('airport') ||
           normalized.contains('ivato'); // Aéroport principal de Madagascar
  }
}
```

**Raison** : Aucune détection existante dans le code actuel

### 2. Structure des Données

#### A. En Mémoire (TripProvider)
```dart
// Extension des Maps existants
Map pickLocation = {
  "lat": double,
  "lng": double,
  "address": string,
  "city": string,
  "isAirport": bool,        // NOUVEAU
  "flightNumber": string?    // NOUVEAU
}

Map dropLocation = {
  "lat": double,
  "lng": double,
  "address": string,
  "isAirport": bool,        // NOUVEAU
  "flightNumber": string?    // NOUVEAU
}
```

#### B. Firestore (Collection: bookingRequest)
```javascript
{
  // Champs existants
  "pickLat": 18.8792,
  "pickLng": 47.5079,
  "pickAddress": "Aéroport Ivato...",
  "dropLat": 18.8798,
  "dropLng": 47.5085,
  "dropAddress": "Analakely...",

  // NOUVEAUX CHAMPS
  "pickIsAirport": true,
  "pickFlightNumber": "AF934",
  "dropIsAirport": false,
  "dropFlightNumber": null
}
```

### 3. Fonctionnalité de Clic sur Numéro de Vol

**Implémentation iOS/Android**

Les systèmes mobiles reconnaissent automatiquement les numéros de vol dans les widgets de texte si formatés correctement :

```dart
import 'package:url_launcher/url_launcher.dart';

class FlightNumberWidget extends StatelessWidget {
  final String flightNumber;

  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFlightInfo(),
      child: Text(
        flightNumber,
        style: TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _openFlightInfo() async {
    // iOS : Ouvre l'app de vol native
    // Android : Ouvre Google Flights ou app dédiée
    final url = 'https://www.google.com/search?q=flight+$flightNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
```

**Détection Automatique**
- iOS reconnaît automatiquement les formats : `AF934`, `AF 934`, `AIR FRANCE 934`
- Android utilise Google Flights pour la détection
- Fallback : Lien vers recherche Google

## Points d'Intégration

### RIDERAPP - 3 Points de Modification

#### Point 1 : Saisie du Numéro de Vol
**Fichier** : `lib/bottom_sheet_widget/pickup_and_drop_location_sheet.dart`

**Localisation** : Après la saisie de l'adresse

**Modifications** :
1. Ajouter détection d'aéroport en temps réel
2. Afficher champ TextField conditionnel "Numéro de vol (optionnel)"
3. Stocker dans `pickLocation`/`dropLocation` Map

```dart
// Pseudo-code
if (AirportDetectionService.isAirportAddress(pickupAddress)) {
  showFlightNumberInput(
    onChanged: (value) {
      pickLocation['flightNumber'] = value;
      pickLocation['isAirport'] = true;
    }
  );
}
```

#### Point 2 : Validation et Affichage
**Fichier** : `lib/bottom_sheet_widget/confirm_destination.dart`

**Localisation** : Ligne 206-229 (bouton CONFIRM)

**Modifications** :
1. Vérifier si aéroport détecté et numéro vide → afficher message info (non bloquant)
2. Afficher le numéro de vol dans le récapitulatif
3. Icône avion 🛫 ou 🛬 selon le sens

```dart
if (pickLocation['isAirport'] == true &&
    pickLocation['flightNumber'] != null) {
  displayFlightInfo(
    icon: '🛫',
    flightNumber: pickLocation['flightNumber']
  );
}
```

#### Point 3 : Sauvegarde Firestore
**Fichier** : `lib/provider/trip_provider.dart`

**Localisation** : Ligne 2147+ (méthode `createBooking()`)

**Modifications** :
Ajouter les nouveaux champs au Map `data` :

```dart
Map<String, dynamic> data = {
  // ... champs existants ...
  "pickIsAirport": pickupLocation?['isAirport'] ?? false,
  "pickFlightNumber": pickupLocation?['flightNumber'],
  "dropIsAirport": dropLocation?['isAirport'] ?? false,
  "dropFlightNumber": dropLocation?['flightNumber'],
};
```

### DRIVERAPP - 2 Points de Modification

#### Point 1 : Affichage dans les Détails de Course
**Fichier** : `lib/pages/view_module/booking_detail_screen.dart`

**Modifications** :
1. Lire les champs `pickFlightNumber` / `dropFlightNumber`
2. Afficher avec badge "Vol" si présent
3. Rendre cliquable avec `FlightNumberWidget`

```dart
if (booking['pickIsAirport'] == true &&
    booking['pickFlightNumber'] != null) {
  FlightNumberWidget(
    flightNumber: booking['pickFlightNumber'],
    direction: 'Départ',
  );
}
```

#### Point 2 : Notification Push
**Fichier** : `lib/services/firebase_push_notifications.dart`

**Modifications** :
Inclure le numéro de vol dans le message de notification :

```dart
String notificationBody = booking['pickFlightNumber'] != null
  ? "Course aéroport - Vol ${booking['pickFlightNumber']}"
  : "Nouvelle course";
```

## Plan de Développement

### Phase 1 : Riderapp (4-5h)
- [x] Créer branche `feature/flight-number-integration`
- [x] Créer `lib/services/airport_detection_service.dart`
- [x] Modifier `pickup_and_drop_location_sheet.dart` (saisie)
- [x] Modifier `confirm_destination.dart` (validation)
- [x] Modifier `trip_provider.dart` (sauvegarde Firestore)
- [x] Créer widget `lib/widget/flight_number_input.dart`
- [ ] Tests manuels iOS/Android

### Phase 2 : Driverapp (2-3h)
- [x] Créer branche `feature/flight-number-integration`
- [x] Créer widget `lib/widget/flight_number_widget.dart`
- [x] Modifier `booking_detail_screen.dart` (affichage)
- [x] Correction erreurs de compilation (MyColors, CustomText)
- [ ] Modifier notifications push
- [ ] Modifier `lib/widget/ride_tile.dart` (liste des courses)
- [ ] Tests avec riderapp

### Phase 3 : Tests et Documentation (1-2h)
- [ ] Tests end-to-end riderapp → driverapp
- [ ] Tests liens numéros de vol (iOS/Android)
- [ ] Screenshots pour documentation
- [ ] Mise à jour `CLAUDE.md` et `ARCHITECTURE_TECHNIQUE.md`

## Cas d'Usage

### Cas 1 : Course depuis l'Aéroport (Arrivée)
```
Utilisateur ouvre riderapp
├─> Pickup : "Aéroport International Ivato"
│   └─> Détection automatique → champ "Numéro de vol" apparaît
│   └─> Saisit "AF934"
├─> Drop : "Hôtel Carlton, Analakely"
└─> Confirmation
    └─> Affiche : 🛫 Vol AF934
    └─> Sauvegarde en Firestore

Chauffeur reçoit notification
├─> "Course aéroport - Vol AF934"
└─> Détails : peut cliquer sur AF934 → horaires de vol
```

### Cas 2 : Course vers l'Aéroport (Départ)
```
Utilisateur ouvre riderapp
├─> Pickup : "Résidence, Analamahitsy"
├─> Drop : "Aéroport International Ivato"
│   └─> Détection automatique → champ "Numéro de vol" apparaît
│   └─> Saisit "KQ255"
└─> Confirmation
    └─> Affiche : 🛬 Vol KQ255
```

### Cas 3 : Course Sans Aéroport
```
Utilisateur ouvre riderapp
├─> Pickup : "Analakely"
├─> Drop : "Behoririka"
└─> Aucun champ numéro de vol affiché
```

## Considérations UX

### Design du Champ
```
┌─────────────────────────────────┐
│  📍 Adresse de départ           │
│  Aéroport International Ivato   │
├─────────────────────────────────┤
│  ✈️ Numéro de vol (optionnel)   │
│  [ AF934                    ]   │
│  Ex: AF934, KQ255, ET917        │
└─────────────────────────────────┘
```

### Messages Utilisateur
- **Titre** : "Numéro de vol (optionnel)"
- **Placeholder** : "Ex: AF934, KQ255"
- **Info** : "Votre chauffeur pourra suivre votre vol en temps réel"

### Affichage Chauffeur
```
┌─────────────────────────────────┐
│  📍 Récupération                │
│  Aéroport International Ivato   │
│  🛫 Vol AF934  [Cliquer pour   │
│               voir horaires]    │
└─────────────────────────────────┘
```

## Tests à Effectuer

### Tests Fonctionnels
- [ ] Détection d'aéroport avec différentes variations d'adresse
- [ ] Saisie numéro de vol au pickup
- [ ] Saisie numéro de vol au drop
- [ ] Saisie aux deux endroits (pickup + drop = aéroport)
- [ ] Validation format numéro de vol
- [ ] Sauvegarde Firestore correcte
- [ ] Affichage dans driverapp
- [ ] Clic sur numéro de vol (iOS)
- [ ] Clic sur numéro de vol (Android)

### Tests de Non-Régression
- [ ] Course normale sans aéroport
- [ ] Course programmée avec numéro de vol
- [ ] Annulation de course avec numéro de vol
- [ ] Historique des courses

## Questions / Décisions

### Q1 : Format du numéro de vol
**Décision** : Accepter tout format libre
- `AF934`, `AF 934`, `AIR FRANCE 934` tous valides
- Pas de validation stricte (trop complexe avec toutes les compagnies)

### Q2 : Obligatoire ou optionnel ?
**Décision** : OPTIONNEL
- Ne pas bloquer la réservation si vide
- Message informatif uniquement

### Q3 : Départ ET arrivée à l'aéroport ?
**Décision** : Gérer les deux cas
- Transfert inter-terminal possible
- Afficher deux champs si les deux sont aéroports

### Q4 : Quels aéroports ?
**Décision** : Détection générique
- Mots-clés : "aéroport", "airport", "aeroport"
- Madagascar : "Ivato", "Nosy Be", "Toamasina"
- Extensible pour autres pays

## Risques et Mitigations

### Risque 1 : Faux positifs détection aéroport
**Impact** : Moyen
**Mitigation** :
- Liste de mots-clés spécifique
- Champ optionnel donc pas bloquant

### Risque 2 : Liens numéros de vol ne fonctionnent pas
**Impact** : Faible
**Mitigation** :
- Fallback vers recherche Google
- Toujours afficher le texte même si lien échoue

### Risque 3 : Performance (détection temps réel)
**Impact** : Très faible
**Mitigation** :
- Détection sur String simple (pas d'API)
- Exécution quasi instantanée

## Métriques de Succès

- [ ] 0 régressions sur flux de réservation normal
- [ ] Taux d'utilisation > 60% pour courses aéroport
- [ ] Taux de clic sur numéro de vol > 40%
- [ ] Temps d'attente chauffeurs réduit de 15% (grâce au suivi de vol)

## Ressources

### Documentation
- [url_launcher package](https://pub.dev/packages/url_launcher)
- [iOS Flight Data Detection](https://developer.apple.com/documentation/uikit/uidatadetectortype)
- [Android Intent Schemes](https://developer.chrome.com/docs/multidevice/android/intents/)

### Fichiers de Référence
- Analyse flux : `BOOKING_FLOW_EXECUTIVE_SUMMARY.txt`
- Diagrammes : `BOOKING_FLOW_DIAGRAM.txt`
- Code snippets : `BOOKING_FLOW_CODE_SNIPPETS.md`

## Changelog

### 2025-11-05 - Implémentation Complète

#### Riderapp ✅
- ✅ Création `lib/services/airport_detection_service.dart`
  - Détection automatique d'aéroport par mots-clés
  - Support multilingue (français, anglais)
  - Validation format numéro de vol
  - Génération URLs informations de vol

- ✅ Création `lib/widget/flight_number_input.dart`
  - Widget de saisie avec validation en temps réel
  - Détection automatique du type (arrivée/départ)
  - Mode compact et mode complet
  - Support émojis 🛬/🛫

- ✅ Modification `lib/bottom_sheet_widget/pickup_and_drop_location_sheet.dart`
  - Ajout champs `isAirport` et `flightNumber` aux Maps
  - Méthodes helper `_buildLocationMap()` et `_updateAirportDetection()`
  - Affichage conditionnel du widget FlightNumberInput
  - Détection en temps réel lors de la saisie d'adresse

- ✅ Modification `lib/bottom_sheet_widget/confirm_destination.dart`
  - Affichage des numéros de vol en lecture seule
  - Widget FlightNumberDisplay cliquable
  - Lancement URL pour informations de vol
  - Support pickup ET drop simultanément

- ✅ Modification `lib/provider/trip_provider.dart`
  - Ajout champs Firestore : `pickIsAirport`, `pickFlightNumber`, `dropIsAirport`, `dropFlightNumber`
  - Sauvegarde automatique dans `createBooking()` ligne 2183-2187
  - Rétrocompatible (champs optionnels)

#### Driverapp ✅
- ✅ Création `lib/widget/flight_number_widget.dart`
  - 3 variants : Full, Compact, NotificationBadge
  - Cliquable pour ouvrir infos vol
  - Design cohérent avec app
  - Support émojis et labels contextuels

- ✅ Modification `lib/pages/view_module/booking_detail_screen.dart`
  - Affichage conditionnel des numéros de vol
  - Intégration dans la vue des adresses
  - Support pickup ET drop
  - Widget interactif avec lancement URL

- ✅ Correction erreurs de compilation (commit `7b030bc`)
  - Remplacement `myColors.` → `MyColors.` (classe statique)
  - Correction propriétés couleur : `primary` → `primaryColor`, `lightCardBackground` → `whiteColor`
  - Remplacement `CustomText` → `ParagraphText` / `SubHeadingText`
  - Signature widget : paramètres nommés → paramètre positionnel

### 2025-11-05 - Planification
- ✅ Création branches riderapp et driverapp
- ✅ Analyse complète du flux de réservation
- ✅ Documentation technique créée

---

**Statut actuel** : ✅ Implémentation complète Phase 1 et Phase 2

**Prochaine étape** : Tests manuels iOS/Android et intégration notifications push (optionnel)
