# Documentation du Flux de Réservation - Riderapp

## Vue d'ensemble

Cette documentation couvre complètement le flux de réservation dans Riderapp, depuis la sélection des adresses pickup/drop jusqu'à la création du booking en Firestore.

Objectif principal: Comprendre comment ajouter un champ "numéro de vol" pour les courses aéroport.

---

## Fichiers de Documentation

### 1. **BOOKING_FLOW_EXECUTIVE_SUMMARY.txt** 📋 COMMENCER ICI
   - **Taille:** 11 KB (315 lignes)
   - **Public:** Tout le monde
   - **Contenu:**
     - Vue d'ensemble complète du flux
     - Points d'intégration recommandés (3 points clés)
     - Architecture technique
     - Prochaines étapes
     - Notes importantes
   
   **À lire en premier!** Donne 80% des informations en 20% du temps.

---

### 2. **BOOKING_FLOW_ANALYSIS.md** 🔍 ANALYSE DÉTAILLÉE
   - **Taille:** 10 KB (322 lignes)
   - **Public:** Développeurs
   - **Contenu:**
     - 1. Flux complet de sélection d'adresse (10 étapes)
     - 2. Widgets/bottom sheets impliqués
     - 3. Flux complet home_screen → booking creation
     - 4. Données sauvegardées en Firestore
     - 5. Structure des Maps pickLocation/dropLocation
     - 6. Détection d'aéroport - état actuel
     - 7. Cas d'usage pour le champ "flight_number"
     - 8. Fichiers clés à modifier
     - 9. Remarques importantes
   
   **Référence complète** pour implémenter la feature.

---

### 3. **BOOKING_FLOW_DIAGRAM.txt** 📊 DIAGRAMMES VISUELS
   - **Taille:** 9 KB (206 lignes)
   - **Public:** Tout le monde
   - **Contenu:**
     - Diagramme ASCII du flux complet
     - Structure Firestore avec exemples réels
     - Points d'intégration proposés (3 points)
   
   **Idéal pour** visualiser le flux rapidement.

---

### 4. **BOOKING_FLOW_CODE_SNIPPETS.md** 💻 CODE SOURCE
   - **Taille:** 11 KB
   - **Public:** Développeurs
   - **Contenu:**
     - 10 snippets de code réel du projet
     - Lignes précises du code source
     - Annotations des points clés
     - Formats de données avec exemples
   
   **Copier-coller ready** pour apprenants rapides.

---

## Guide de Lecture par Profil

### Pour le Product Manager
1. Lire **BOOKING_FLOW_EXECUTIVE_SUMMARY.txt** (5 min)
2. Voir diagramme dans **BOOKING_FLOW_DIAGRAM.txt** (2 min)

### Pour le Développeur Frontend
1. **BOOKING_FLOW_EXECUTIVE_SUMMARY.txt** (10 min)
2. **BOOKING_FLOW_ANALYSIS.md** - Section 2 & 3 (15 min)
3. **BOOKING_FLOW_CODE_SNIPPETS.md** - Snippets 1-4 & 8 (15 min)

### Pour le Développeur Backend/Firebase
1. **BOOKING_FLOW_EXECUTIVE_SUMMARY.txt** (10 min)
2. **BOOKING_FLOW_ANALYSIS.md** - Section 4 & 5 (15 min)
3. **BOOKING_FLOW_CODE_SNIPPETS.md** - Snippet 5 & 10 (10 min)

### Pour le Développeur Full-Stack (Implémentation)
1. **BOOKING_FLOW_EXECUTIVE_SUMMARY.txt** (10 min)
2. **BOOKING_FLOW_ANALYSIS.md** (30 min) - Tout lire
3. **BOOKING_FLOW_CODE_SNIPPETS.md** (20 min) - Tous les snippets
4. **BOOKING_FLOW_DIAGRAM.txt** (10 min) - Points d'intégration

---

## Résumé Clé

### 1. Flux Principal (8 étapes)
```
Home Screen
  ↓
PickupAndDropLocation (saisie adresses)
  ↓
TripProvider (sauvegarde temp)
  ↓
ChooseVehicleSheet (sélection)
  ↓
ConfirmDestination (confirmation)
  ↓
createRequest() / createBooking()
  ↓
Firestore (sauvegarde définitive)
  ↓
RequestForRide (attente)
```

### 2. Les 4 Widgets Critiques

| Widget | Fichier | Fonction | Données |
|--------|---------|----------|---------|
| PickupAndDropLocation | `pickup_and_drop_location_sheet.dart` | Saisie des adresses | Maps locales |
| ChooseVehicleSheet | `choose_vehicle_sheet.dart` | Choix véhicule | selectedVehicle |
| ConfirmDestination | `confirm_destination.dart` | Confirmation | pickLocation, dropLocation |
| RequestForRide | `request_for_ride.dart` | Attente | booking (Firestore) |

### 3. Points d'Intégration pour Flight Number

| Point | Fichier | Action |
|-------|---------|--------|
| 1 | pickup_and_drop_location_sheet.dart | Détecter aéroport + afficher champ |
| 2 | confirm_destination.dart | Valider flight number |
| 3 | trip_provider.dart (createBooking) | Sauvegarder en Firestore |

### 4. Champs Actuels Firestore

**Adresses:**
- pickLat, pickLng, pickAddress
- dropLat, dropLng, dropAddress
- city

**À ajouter pour aéroport:**
- pickFlightNumber, dropFlightNumber
- pickIsAirport, dropIsAirport

---

## État Actuel de la Détection d'Aéroport

**AUCUNE détection existante!**

Résultats de recherche:
- "airport" → 0 résultats ✗
- "aéroport" → 0 résultats ✗
- "aeroport" → 0 résultats ✗

→ La logique doit être implémentée de zéro.

---

## Architecture Technical Stack

- **Framework:** Flutter 3.x avec Dart >= 3.4.4
- **État:** Provider (ChangeNotifier)
- **Backend:** Firebase (Firestore, Auth)
- **Cartes:** Google Maps Flutter
- **Paiements:** Airtel Money, Orange Money, Telma MVola

---

## Fichiers Source Clés du Projet

### Flux d'Adresse
- `/lib/pages/view_module/home_screen.dart` (ligne 1140-1184)
- `/lib/bottom_sheet_widget/pickup_and_drop_location_sheet.dart`
- `/lib/bottom_sheet_widget/confirm_destination.dart` (ligne 206-229)
- `/lib/provider/trip_provider.dart` (ligne 2147+)

### Enum & Constants
- `/lib/contants/global_data.dart` (CustomTripType enum)

### Services
- `/lib/services/firestore_services.dart`
- `/lib/services/analytics/analytics_service.dart`

---

## Prochaines Étapes Recommandées

### Phase 1: Détection
- [ ] Créer service d'aéroports (`airports_service.dart`)
- [ ] Implémenter `isAirport(String address)` dans TripProvider
- [ ] Tester la détection

### Phase 2: UI Frontend
- [ ] Modifier PickupAndDropLocation pour afficher champ conditionnel
- [ ] Ajouter validation du format numéro de vol
- [ ] Afficher indication visuelle (icône avion)

### Phase 3: Confirmation & Stockage
- [ ] Modifier ConfirmDestination pour valider flight number
- [ ] Ajouter champs à createBooking()
- [ ] Créer Firestore index si nécessaire

### Phase 4: Affichage Driver
- [ ] Afficher numéro de vol dans RequestForRide
- [ ] Afficher dans DriverOnWay
- [ ] Afficher dans historique de course

---

## Questions Fréquentes

### Q: Où les adresses sont-elles saisies?
A: Dans `PickupAndDropLocation` bottom sheet. Voir BOOKING_FLOW_CODE_SNIPPETS.md - Snippet 1.

### Q: Comment les adresses sont passées au booking?
A: Via Maps {lat, lng, address}. Voir Snippet 3.

### Q: Où sont sauvegardées les adresses en Firestore?
A: Dans `createBooking()` ligne 2147+ de trip_provider.dart. Voir Snippet 5.

### Q: Faut-il modifier la structure des champs?
A: Oui, ajouter pickFlightNumber, dropFlightNumber, pickIsAirport, dropIsAirport.

### Q: Comment détecter un aéroport?
A: Vérifier si l'adresse contient "airport", "aéroport", ou correspond à un aéroport connu.

### Q: Qui doit remplir le numéro de vol?
A: L'utilisateur, uniquement si l'une des deux adresses est un aéroport.

---

## Métriques de Documentation

- **Total pages:** 4 documents + ce README
- **Total lignes:** ~1,200 lignes
- **Code snippets:** 10
- **Diagrammes:** 2
- **Fichiers source référencés:** 10+
- **Dépendance: Aucune** (documentation autonome)

---

## Changelog

- **2025-11-05:** Documentation créée
  - 4 fichiers de documentation
  - 10 code snippets
  - Analyse complète du flux
  - Diagrammes visuels

---

## Support & Questions

Pour des questions:
1. Consulter d'abord les 4 documents (lisez le bon doc pour votre profil)
2. Voir les code snippets correspondants
3. Consulter les fichiers source directs aux lignes indiquées

---

## Licence

Documentation du projet Riderapp - 2025
Utilisable à titre interne uniquement.

