# Sprint 1 : Architecture et Fondations Backend
**Durée** : Semaines 1-2 (10 jours ouvrés)  
**Objectif** : Créer l'infrastructure du nouveau système de tarification v2 en parallèle de l'existant

## 🎯 Objectif du Sprint

Développer l'architecture backend complète du nouveau système de tarification sans affecter le système actuel. Le nouveau système sera développé mais restera désactivé.

## 📋 Livrables Attendus

- ✅ Modèles de données v2 complets et testés
- ✅ Service de calcul v2 avec toute la logique métier
- ✅ Configuration Firestore pour le nouveau système
- ✅ Wrapper du système legacy
- ✅ Suite de tests unitaires exhaustive

## 🏗️ Tâches Détaillées

### Tâche 1 : Modèles de données v2 (3 jours)

**Responsable** : Développeur Backend  
**Fichiers à créer** :
- `lib/models/pricing/pricing_config_v2.dart`
- `lib/models/pricing/price_calculation.dart`
- `lib/models/pricing/traffic_period.dart`

#### 1.1 Créer `PricingConfigV2`
```dart
class PricingConfigV2 {
  // Prix plancher par catégorie (taxi_moto, classic, confort, 4x4, van)
  final Map<String, double> floorPrices;
  
  // Prix par km par catégorie
  final Map<String, double> pricePerKm;
  
  // Seuil max pour prix plancher (3.0 km)
  final double floorPriceThreshold;
  
  // Configuration embouteillages
  final double trafficMultiplier;        // 1.4
  final List<TrafficPeriod> trafficPeriods;
  
  // Configuration courses longues
  final double longTripThreshold;        // 15.0 km
  final double longTripMultiplier;       // 1.2
  
  // Configuration réservation
  final Map<String, double> reservationSurcharge;
  final int reservationAdvanceMinutes;   // 10
  
  // Système d'arrondis
  final bool enableRounding;             // true
  final int roundingStep;                // 500
  
  // Contrôle de migration
  final bool enableNewPricingSystem;     // false initialement
  final String version;                  // "2.0"
}
```

#### 1.2 Créer `PriceCalculation`
```dart
class PriceCalculation {
  final double basePrice;               // Prix de base calculé
  final double trafficSurcharge;        // Majoration embouteillages (0 ou montant)
  final double reservationSurcharge;    // Surcoût réservation (0 ou montant)
  final double promoDiscount;           // Réduction promo (0 ou montant)
  final double finalPrice;              // Prix final arrondi
  
  final Map<String, dynamic> breakdown; // Détail interne des calculs
  final String pricingVersion;          // "v2.0"
  final DateTime calculatedAt;          // Timestamp du calcul
}
```

#### 1.3 Créer `TrafficPeriod`
```dart
class TrafficPeriod {
  final TimeOfDay startTime;            // Ex: 07:00
  final TimeOfDay endTime;              // Ex: 09:59
  final List<int> daysOfWeek;           // [1,2,3,4,5] = Lun-Ven
}
```

**Tests unitaires** :
- Validation des modèles avec données valides/invalides
- Sérialisation/désérialisation JSON
- Tests des propriétés calculées

---

### Tâche 2 : Service de calcul v2 (4 jours)

**Responsable** : Développeur Senior  
**Fichier à créer** : `lib/services/pricing/pricing_service_v2.dart`

#### 2.1 Interface commune
```dart
abstract class IPricingService {
  Future<PriceCalculation> calculatePrice({
    required String vehicleCategory,
    required double distance,
    required DateTime requestTime,
    required bool isScheduled,
    PromoCode? promoCode,
  });
}
```

#### 2.2 Implémentation PricingServiceV2
```dart
class PricingServiceV2 implements IPricingService {
  // Calcul principal selon spécifications
  @override
  Future<PriceCalculation> calculatePrice({...}) async {
    // 1. Récupération config Firestore
    // 2. Calcul prix de base
    // 3. Application majorations
    // 4. Application codes promo
    // 5. Arrondi final
  }
  
  // Méthodes privées pour chaque étape
  double _calculateBasePrice(String category, double distance);
  double _applyTrafficSurcharge(double basePrice, DateTime requestTime);
  double _applyReservationSurcharge(double price, String category, bool isScheduled);
  double _applyPromoCode(double price, PromoCode? promoCode);
  double _roundPrice(double price);
  bool _isTrafficHour(DateTime requestTime);
}
```

#### 2.3 Logique de calcul détaillée

**Prix de base** :
```dart
double _calculateBasePrice(String category, double distance) {
  final config = await _getConfig();
  final floorPrice = config.floorPrices[category]!;
  final pricePerKm = config.pricePerKm[category]!;
  
  if (distance < config.floorPriceThreshold) {
    return floorPrice;
  }
  
  if (distance < config.longTripThreshold) {
    return pricePerKm * distance;
  }
  
  // Distance >= 15 km : majoration 1.2 au-delà de 15 km
  final normalDistance = config.longTripThreshold;
  final extraDistance = distance - normalDistance;
  return pricePerKm * (normalDistance + extraDistance * config.longTripMultiplier);
}
```

**Majoration embouteillages** :
```dart
double _applyTrafficSurcharge(double basePrice, DateTime requestTime) {
  if (_isTrafficHour(requestTime)) {
    final config = await _getConfig();
    return basePrice * (config.trafficMultiplier - 1); // Majoration seule
  }
  return 0.0;
}
```

**Tests unitaires** :
- Calculs prix plancher (< 3 km)
- Calculs prix normal (3-15 km)  
- Calculs courses longues (> 15 km)
- Majorations embouteillages
- Surcoûts réservation
- Application codes promo
- Système d'arrondis
- Gestion erreurs et cas limites

---

### Tâche 3 : Configuration Firestore (2 jours)

**Responsable** : Développeur Backend  
**Fichier à créer** : `lib/services/pricing/pricing_config_service.dart`

#### 3.1 Service de configuration
```dart
class PricingConfigService {
  static const String _collectionPath = 'app_settings';
  static const String _documentId = 'pricing_config_v2';
  
  static Future<PricingConfigV2> getConfig() async {
    // Récupération depuis Firestore avec cache local
    // Validation des données
    // Fallback vers configuration par défaut
  }
  
  static Future<void> updateConfig(PricingConfigV2 config) async {
    // Mise à jour Firestore (admin uniquement)
    // Invalidation du cache
  }
}
```

#### 3.2 Configuration initiale Firestore
Document `app_settings/pricing_config_v2` :
```json
{
  "version": "2.0",
  "enableNewPricingSystem": false,
  "floorPrices": {
    "taxi_moto": 6000,
    "classic": 8000,
    "confort": 11000,
    "4x4": 13000,
    "van": 15000
  },
  "pricePerKm": {
    "taxi_moto": 2000,
    "classic": 2750,
    "confort": 3850,
    "4x4": 4500,
    "van": 5000
  },
  "floorPriceThreshold": 3.0,
  "trafficMultiplier": 1.4,
  "trafficPeriods": [
    {
      "startTime": "07:00",
      "endTime": "09:59", 
      "daysOfWeek": [1,2,3,4,5]
    },
    {
      "startTime": "16:00",
      "endTime": "18:59",
      "daysOfWeek": [1,2,3,4,5]
    }
  ],
  "longTripThreshold": 15.0,
  "longTripMultiplier": 1.2,
  "reservationSurcharge": {
    "taxi_moto": 3600,
    "classic": 5000,
    "confort": 7000,
    "4x4": 8200,
    "van": 9100
  },
  "reservationAdvanceMinutes": 10,
  "enableRounding": true,
  "roundingStep": 500
}
```

**Tests** :
- Récupération configuration valide
- Gestion configuration invalide/manquante
- Cache et invalidation
- Validation des données

---

### Tâche 4 : Wrapper système legacy (1 jour)

**Responsable** : Développeur Backend  
**Fichier à créer** : `lib/services/pricing/pricing_service_legacy.dart`

#### 4.1 Encapsulation de l'existant
```dart
class PricingServiceLegacy implements IPricingService {
  @override
  Future<PriceCalculation> calculatePrice({...}) async {
    // Appel à l'ancien système de calcul
    // Conversion du résultat vers PriceCalculation
    // Marquage version "v1.0"
  }
  
  // Méthodes d'adaptation aux anciennes fonctions
  double _callLegacyPriceCalculation(...);
  PriceCalculation _adaptLegacyResult(double oldPrice);
}
```

**Objectif** : Permettre l'utilisation de l'interface commune avec l'ancien système pendant la migration.

---

## 🧪 Plan de Tests

### Tests Unitaires (obligatoires)
- **Modèles** : Validation, sérialisation, cas limites
- **Service v2** : Tous les cas de calcul selon spécifications
- **Configuration** : Récupération, validation, fallback
- **Legacy wrapper** : Compatibilité avec ancien système

### Critères de Validation
- ✅ 100% des cas de calcul couverts
- ✅ Gestion d'erreurs robuste
- ✅ Performance : calculs < 100ms
- ✅ Aucun impact sur le système existant

## 📊 Métriques de Succès

| Métrique | Cible | Comment mesurer |
|----------|-------|-----------------|
| Couverture tests | > 95% | Tests unitaires |
| Performance calcul | < 100ms | Benchmarks |
| Validation config | 100% | Tests d'intégration |
| Aucun régression | 0 bug | Tests ancien système |

## 🚨 Points d'Attention

- **Ne pas modifier** le système de tarification actuel
- **Ne pas activer** le nouveau système (flag = false)
- **Tester exhaustivement** tous les cas de figure
- **Documenter** toute différence observée avec l'ancien système
- **Valider** que l'interface utilisateur reste inchangée

## 📝 Checklist de Fin de Sprint

- [ ] Tous les modèles créés et testés
- [ ] PricingServiceV2 implémenté et testé
- [ ] Configuration Firestore en place
- [ ] PricingServiceLegacy fonctionnel
- [ ] Tests unitaires passent à 100%
- [ ] Documentation technique à jour
- [ ] Aucun impact sur l'application existante
- [ ] Validation par code review

**Prêt pour Sprint 2** ✅