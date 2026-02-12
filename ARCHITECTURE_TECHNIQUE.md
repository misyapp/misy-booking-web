# Architecture Technique - Misy Ride Hailing App

## Vue d'ensemble

Misy est une application mobile de covoiturage développée en Flutter, permettant aux utilisateurs de réserver des trajets avec des conducteurs. L'application suit une architecture moderne basée sur le pattern Provider pour la gestion d'état et Firebase comme backend.

## Stack Technologique

### Frontend
- **Framework**: Flutter 3.x (Dart >= 3.4.4)
- **Gestion d'état**: Provider 6.1.1
- **Navigation**: Navigator 2.0 avec PageView
- **UI Components**: Material Design avec thème personnalisé

### Backend & Services
- **Backend**: Firebase Suite
  - Firebase Auth (authentification)
  - Cloud Firestore (base de données NoSQL)
  - Firebase Storage (stockage de fichiers)
  - Firebase Messaging (notifications push)
  - Firebase Realtime Database (données temps réel)
  - Cloud Functions (logique serveur)

### Intégrations Principales
- **Cartes**: Google Maps Flutter
- **Paiements**: Airtel Money, Orange Money, Telma MVola
- **Authentification**: Email/Password, Google Sign-In, Facebook Auth
- **Géolocalisation**: Geolocator, Geocoding

## Architecture du Projet

### Structure des Dossiers

```
lib/
├── main.dart                    # Point d'entrée de l'application
├── pages/                       # Écrans de l'application
│   ├── auth_module/            # Authentification et onboarding
│   └── view_module/            # Écrans principaux
├── provider/                    # Gestion d'état (Provider)
├── services/                    # Services externes et API
├── widget/                      # Composants UI réutilisables
├── modal/                       # Modèles de données
├── bottom_sheet_widget/         # Bottom sheets spécialisés
├── functions/                   # Fonctions utilitaires
├── contants/                    # Constantes et configuration
└── extensions/                  # Extensions Dart
```

### Couches Architecturales

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                      │
│         (Pages, Widgets, Bottom Sheets)         │
├─────────────────────────────────────────────────┤
│              Provider Layer                     │
│        (State Management & Business Logic)      │
├─────────────────────────────────────────────────┤
│               Service Layer                     │
│        (Firebase, APIs, Platform Services)      │
├─────────────────────────────────────────────────┤
│                Data Layer                       │
│        (Models, Repositories, Storage)          │
└─────────────────────────────────────────────────┘
```

## Navigation et Flux Utilisateur

### Navigation Principale

L'application utilise une navigation par onglets avec 3 écrans principaux :

1. **Accueil** (`HomeScreen`) - Carte et réservation
2. **Trajets** (`MyBookingScreen`) - Historique des courses
3. **Mon compte** (`EditProfileScreen`) - Profil utilisateur

### Architecture du HomeScreen

Le HomeScreen utilise une architecture hybride qui adapte l'interface selon l'étape :

- **Mode Accueil** : Bottom sheet moderne avec 3 niveaux (35%, 60%, 80%) et transitions fluides
- **Widgets Autonomes** : `PickupAndDropLocation` et `SceduleRideWithCustomeTime` s'affichent de manière indépendante avec leur propre gestion de hauteur
- **Mode Classique** : Bottom sheet fixe pour les autres étapes du flux

### Flux de Réservation

Le processus de réservation suit ces étapes :

```
1. setYourDestination       → Sélection du type de véhicule (bottom sheet moderne)
2. selectScheduleTime       → Planification (widget autonome)
3. choosePickupDropLocation → Choix des points (widget autonome)
4. chooseVehicle           → Confirmation du véhicule
5. payment                 → Sélection du mode de paiement
6. selectAvailablePromocode → Application de codes promo (optionnel)
7. confirmDestination      → Confirmation finale
8. requestForRide          → Recherche de conducteur
9. driverOnWay            → Conducteur en route
```

## Gestion d'État

### Pattern Provider

L'application utilise le pattern Provider avec `ChangeNotifier` pour la gestion d'état réactive.

#### Providers Principaux

1. **AuthProvider** (`CustomAuthProvider`)
   - Authentification utilisateur
   - Gestion du profil
   - Persistance de session

2. **TripProvider**
   - État de la réservation en cours
   - Calculs tarifaires
   - Suivi temps réel

3. **GoogleMapProvider**
   - État de la carte
   - Marqueurs et polylignes
   - Animations de caméra

4. **Payment Providers**
   - `AirtelMoneyPaymentGatewayProvider`
   - `OrangeMoneyPaymentGatewayProvider`
   - `TelmaMoneyPaymentGatewayProvider`
   - `SavedPaymentMethodProvider`

5. **Infrastructure Providers**
   - `AdminSettingsProvider` - Configuration globale
   - `InternetConnectivityProvider` - État réseau
   - `NotificationProvider` - Notifications in-app
   - `DarkThemeProvider` - Thème de l'application

### Flux de Données

```dart
// Exemple de flux typique
UI Widget → Provider.of<TripProvider>(context) → FirestoreServices → Firebase
                                                ↓
                                          notifyListeners()
                                                ↓
                                          UI Update
```

## Services et Intégrations

### Services Firebase

**FirestoreServices** centralise toutes les opérations Firestore :
- Collections principales :
  - `users` - Profils utilisateurs
  - `bookingRequest` - Demandes de course actives
  - `bookingHistory` - Historique des courses
  - `vehicleType` - Types de véhicules disponibles
  - `promocodes` - Codes promotionnels

### Service de Localisation

Gère la géolocalisation avec :
- Permissions GPS
- Stream de position en temps réel
- Calculs de distance
- Géocodage inverse

### Notifications Push

- FCM pour les notifications
- Topics : `all_devices`, `all_customers`
- Notifications locales pour les alertes in-app

## Transport en Commun (95 lignes taxi-be)

### Architecture des données
```
assets/transport_lines/
├── manifest.json              # Index des 95 lignes (couleurs, endpoints, asset_paths)
└── core/                      # 188 fichiers GeoJSON (aller + retour)
    ├── {line}_aller.geojson   # Tracé + arrêts direction aller
    └── {line}_retour.geojson  # Tracé + arrêts direction retour
```

### Sources des tracés
| Source | Fichiers | Méthode |
|--------|----------|---------|
| Originaux (bundled) | 42 | Données existantes road-snappées OSRM |
| OpenStreetMap | 76 | Overpass API → extraction géométrie → OSRM snap |
| Géocodés | 70 | Quartiers Antananarivo → OSRM routing |

### Services transport
- **`TransportLinesService`** — Chargement manifest + GeoJSON bundled
- **`TransportContributionService`** — Contributions utilisateur (Firestore)
- **`TransportLineColors._fixedColors`** — 96 couleurs hex uniques par ligne

### Mode édition collaboratif
- Flow Primus → Terminus (Google Places)
- Auto-calcul OSRM + phase affinage (midpoint handles + waypoints)
- Soumission anonyme avec prénom + description

### Scripts de données
| Script | Description |
|--------|-------------|
| `scripts/fetch_osm_transport_lines.py` | Extraction OSM Overpass API |
| `scripts/generate_missing_routes.py` | Géocodage + routage OSRM |
| `scripts/snap_routes_to_roads.py` | Recalage sur réseau routier |

## Composants UI Réutilisables

### Design System

L'application suit le design "Misy V2" avec :
- **Couleurs principales** :
  - Coral Pink : `#FF6B6B`
  - Horizon Blue : `#4ECDC4`
- **Typographie** : Police AzoSans-Medium
- **Composants** : Coins arrondis, ombres douces

### Widgets Principaux

1. **RoundEdgedButton** - Boutons principaux
2. **CustomDrawer** - Menu latéral
3. **InputTextFieldWidget** - Champs de saisie
4. **CustomLoader** - Indicateurs de chargement
5. **Bottom Sheets dynamiques** - Pour le flux de réservation

## Sécurité et Authentification

### Méthodes d'Authentification
- Email/Mot de passe avec bcrypt
- Google Sign-In
- Facebook Login
- Vérification par SMS/OTP

### Sécurité des Données
- Chiffrement des mots de passe
- Tokens Firebase Auth
- Règles Firestore pour l'accès aux données
- HTTPS pour toutes les communications

## Optimisations et Performance

### Optimisations Appliquées
- Images en cache avec `cached_network_image`
- Lazy loading des listes
- Persistance Firestore hors ligne
- Compression des images avant upload

### Gestion Hors Ligne
- Persistance Firestore activée
- Firebase Realtime Database en mode offline
- Cache local avec SharedPreferences

## Points d'Extension

### Ajout de Nouvelles Fonctionnalités

1. **Nouveau Provider** : Créer dans `/lib/provider/`
2. **Nouveau Service** : Ajouter dans `/lib/services/`
3. **Nouvelle Page** : Placer dans `/lib/pages/view_module/`
4. **Nouveau Widget** : Ajouter dans `/lib/widget/`

### Ajout d'un Nouveau Mode de Paiement

1. Créer un provider dans `/lib/provider/`
2. Implémenter l'interface de paiement
3. Ajouter dans `PaymentMethodType` enum
4. Mettre à jour l'UI dans les bottom sheets

## Configuration et Déploiement

### Variables d'Environnement
- Clés API dans `AdminSettingsProvider`
- Configuration Firebase dans `google-services.json` / `GoogleService-Info.plist`
- Secrets de paiement gérés via Firebase

### Build et Release
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## Maintenance et Évolution

### Conventions de Code
- Suivre les directives Dart/Flutter
- Utiliser les lints définis dans `analysis_options.yaml`
- Noms explicites pour les variables et fonctions
- Documentation des fonctions complexes

### Tests
- Tests unitaires pour les providers
- Tests d'intégration pour les flux critiques
- Tests de widgets pour les composants réutilisables

