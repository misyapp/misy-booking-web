# 📊 Firebase Analytics - Phase 1 : Implémentation Core
## Application Misy Rider

### 📋 Vue d'Ensemble

**Objectif Phase 1** : Implémenter le tracking analytics de base dans l'application Rider pour comprendre le comportement utilisateur et optimiser le funnel de conversion.

**Durée estimée** : 1 semaine
**Priorité** : HAUTE
**Impact attendu** : Visibilité immédiate sur l'usage réel de l'app

---

## 🎯 Events Prioritaires Phase 1

### Core Events (10 events essentiels)

| Event Name | Description | Paramètres | Point d'implémentation |
|------------|-------------|------------|------------------------|
| `app_opened` | Ouverture de l'app | `user_id`, `session_id`, `app_version` | main.dart |
| `user_logged_in` | Connexion réussie | `method` (phone/google/facebook), `user_id` | login_screen.dart |
| `user_registered` | Inscription complète | `method`, `user_id` | register_screen.dart |
| `immediate_ride_clicked` | Clic course immédiate | `user_id`, `screen_name` | home_screen.dart |
| `scheduled_ride_clicked` | Clic course planifiée | `user_id`, `screen_name` | home_screen.dart |
| `destination_searched` | Recherche destination | `from_address`, `to_address`, `distance_km` | search_destination.dart |
| `price_displayed` | Prix affiché | `price_amount`, `distance_km`, `duration_min` | request_for_ride.dart |
| `ride_booked` | Course réservée | `ride_id`, `price`, `payment_method` | request_for_ride.dart |
| `ride_cancelled` | Course annulée | `ride_id`, `cancellation_reason`, `cancelled_by` | trip_provider.dart |
| `ride_completed` | Course terminée | `ride_id`, `final_price`, `rating`, `duration_min` | trip_provider.dart |

---

## 🔧 Configuration Technique

### 1. Installation des dépendances

```yaml
# pubspec.yaml
dependencies:
  # Firebase Core (déjà présent)
  firebase_core: ^2.24.2
  
  # Ajouter Firebase Analytics
  firebase_analytics: ^10.8.0
```

### 2. Configuration native

#### Android (android/app/build.gradle)
```gradle
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-analytics'  # Déjà présent ✓
}
```

#### iOS (ios/Podfile)
```ruby
target 'Runner' do
  # Ajouter après les autres pods Firebase
  pod 'Firebase/Analytics'
  
  # Existant
  pod 'Firebase/Auth'
  use_frameworks!
  use_modular_headers!
end
```

---

## 💻 Implémentation Flutter

### 1. Service Analytics Principal

```dart
// lib/services/analytics/analytics_service.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;
  
  // Initialisation
  static Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      
      // Activer la collecte de données
      await _analytics!.setAnalyticsCollectionEnabled(true);
      
      myCustomPrintStatement('✅ Firebase Analytics initialisé');
    } catch (e) {
      myCustomPrintStatement('❌ Erreur initialisation Analytics: $e');
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
  
  // === HELPERS ===
  
  static Map<String, dynamic> _cleanParameters(Map<String, dynamic>? params) {
    if (params == null) return {};
    
    final cleaned = <String, dynamic>{};
    params.forEach((key, value) {
      // Firebase n'accepte que string, int, double, bool
      if (value == null) {
        return;
      } else if (value is String || value is int || value is double || value is bool) {
        cleaned[key] = value;
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
```

### 2. Intégration dans main.dart

```dart
// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation Firebase
  await Firebase.initializeApp();
  
  // Initialisation Analytics
  await AnalyticsService.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Log app opened
    _logAppOpened();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _logAppOpened();
    }
  }
  
  void _logAppOpened() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    
    await AnalyticsService.logAppOpened(
      userId: userId,
      appVersion: '2.0.0', // Récupérer depuis package_info_plus si besoin
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Ajouter l'observer pour le tracking automatique de navigation
      navigatorObservers: [
        if (AnalyticsService.observer != null) AnalyticsService.observer!,
      ],
      // ... reste du code
    );
  }
}
```

### 3. Intégration dans les écrans

#### Home Screen
```dart
// lib/pages/view_module/home_screen.dart

import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';

// Dans le widget du bouton course immédiate
RoundEdgedButton(
  text: 'Course immédiate',
  onPressed: () {
    // Analytics
    AnalyticsService.logRideTypeClicked(
      rideType: 'immediate',
      userId: authProvider.userData.value?.id,
    );
    
    // Navigation existante
    Navigator.pushNamed(context, SearchDestinationScreen.routeName);
  },
)

// Dans le widget du bouton course planifiée
RoundEdgedButton(
  text: 'Course planifiée',
  onPressed: () {
    // Analytics
    AnalyticsService.logRideTypeClicked(
      rideType: 'scheduled',
      userId: authProvider.userData.value?.id,
    );
    
    // Navigation existante
    Navigator.pushNamed(context, ScheduledRideScreen.routeName);
  },
)
```

#### Login Screen
```dart
// lib/pages/auth_module/login_screen.dart

import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';

// Après connexion réussie
void _handleLoginSuccess(UserCredential userCredential) async {
  // ... code existant
  
  // Analytics
  await AnalyticsService.logUserLogin(
    method: _loginMethod, // 'phone', 'google', 'facebook'
    userId: userCredential.user!.uid,
  );
  
  // Navigation
  Navigator.pushReplacementNamed(context, HomeScreen.routeName);
}
```

#### Search Destination
```dart
// lib/pages/view_module/search_destination.dart

import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';

// Quand la destination est confirmée
void _onDestinationConfirmed() async {
  // Calculer distance si possible
  double? distance;
  if (fromLatLng != null && toLatLng != null) {
    distance = Geolocator.distanceBetween(
      fromLatLng!.latitude,
      fromLatLng!.longitude,
      toLatLng!.latitude,
      toLatLng!.longitude,
    ) / 1000; // Convertir en km
  }
  
  // Analytics
  await AnalyticsService.logDestinationSearched(
    fromAddress: fromController.text,
    toAddress: toController.text,
    distanceKm: distance,
  );
  
  // Navigation existante
  Navigator.pushNamed(context, RequestForRide.routeName);
}
```

#### Request for Ride
```dart
// lib/pages/view_module/request_for_ride.dart

import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';

// Quand le prix est affiché
void _displayPrice(double price, double? distance, double? duration) {
  // Analytics
  AnalyticsService.logPriceDisplayed(
    price: price,
    distanceKm: distance,
    durationMin: duration,
  );
  
  // Affichage existant
  setState(() {
    estimatedPrice = price;
  });
}

// Quand la course est confirmée
void _confirmBooking() async {
  // ... code existant
  
  // Analytics
  await AnalyticsService.logRideBooked(
    rideId: generatedRideId,
    price: finalPrice,
    paymentMethod: selectedPaymentMethod,
  );
  
  // Navigation
  Navigator.pushNamed(context, TripScreen.routeName);
}
```

### 4. Intégration dans Trip Provider

```dart
// lib/provider/trip_provider.dart

import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';

class TripProvider extends ChangeNotifier {
  
  // Dans la méthode d'annulation
  Future<void> cancelRide(String reason) async {
    // ... code existant
    
    // Analytics
    await AnalyticsService.logRideCancelled(
      rideId: currentRideId,
      reason: reason,
      cancelledBy: 'rider',
    );
  }
  
  // Dans la méthode de fin de course
  Future<void> completeRide(int rating) async {
    // ... code existant
    
    // Calculer durée
    final duration = DateTime.now().difference(rideStartTime).inMinutes.toDouble();
    
    // Analytics
    await AnalyticsService.logRideCompleted(
      rideId: currentRideId,
      finalPrice: finalRidePrice,
      rating: rating,
      durationMin: duration,
    );
  }
}
```

---

## 📱 Test et Validation

### 1. Mode Debug (DebugView Firebase)

```bash
# Activer le mode debug pour Android
adb shell setprop debug.firebase.analytics.app com.misy.rider

# Pour iOS, ajouter l'argument dans Xcode
-FIRDebugEnabled
```

### 2. Vérification dans Firebase Console

1. Ouvrir [Firebase Console](https://console.firebase.google.com)
2. Sélectionner le projet Misy
3. Analytics → DebugView
4. Vérifier que les events apparaissent en temps réel

### 3. Events à valider

- [ ] `app_opened` - Au lancement
- [ ] `user_logged_in` - Après connexion
- [ ] `immediate_ride_clicked` - Clic bouton
- [ ] `destination_searched` - Recherche effectuée
- [ ] `price_displayed` - Prix affiché
- [ ] `ride_booked` - Réservation confirmée
- [ ] `ride_cancelled` - Annulation (si applicable)
- [ ] `ride_completed` - Course terminée

---

## 📊 Métriques à suivre (Firebase Console)

### Semaine 1 - Métriques de base
- **Utilisateurs actifs** : DAU, WAU, MAU
- **Sessions** : Nombre et durée moyenne
- **Engagement** : Pages vues par session
- **Rétention** : Taux de retour J1, J7

### Semaine 2 - Funnel de conversion
1. `immediate_ride_clicked` → Combien cliquent ?
2. `destination_searched` → Combien recherchent ?
3. `price_displayed` → Combien voient le prix ?
4. `ride_booked` → Combien réservent ?
5. `ride_completed` → Combien terminent ?

**Taux de conversion cible** : 
- Clic → Recherche : >80%
- Recherche → Prix : >90%
- Prix → Réservation : >40%
- Réservation → Completion : >95%

---

## 🚀 Commandes de déploiement

```bash
# Installation des dépendances
flutter pub get

# iOS - Mise à jour des pods
cd ios && pod install && cd ..

# Build et test
flutter analyze
flutter test

# Run en debug avec analytics
flutter run --dart-define=FIREBASE_ANALYTICS_DEBUG=true
```

---

## ⚠️ Points d'attention

1. **Privacy** : S'assurer que l'app respecte les politiques de confidentialité
2. **User ID** : Ne jamais logger d'informations personnelles sensibles
3. **Paramètres** : Limiter à 25 paramètres par event (limite Firebase)
4. **Naming** : Utiliser snake_case pour les noms d'events
5. **Volume** : Firebase gratuit = 10M events/mois

---

## 📈 Prochaines étapes (Phase 2)

Après validation de la Phase 1 :
- [ ] Ajouter events e-commerce avancés
- [ ] Implémenter user properties (segments)
- [ ] Configurer audiences personnalisées
- [ ] Setup conversion funnels détaillés
- [ ] Export vers BigQuery si besoin

---

## 📞 Support

**Documentation Firebase** : https://firebase.google.com/docs/analytics/get-started?platform=flutter
**Dashboard** : https://console.firebase.google.com/project/[PROJECT_ID]/analytics

---

**Statut** : 🟡 En attente d'implémentation
**Dernière mise à jour** : 03/09/2025
**Responsable** : Équipe Features