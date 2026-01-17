# Projet : Implémentation Tarifs Misy 2.0

## 📋 Vue d'ensemble du projet

### Objectif
Remplacer le système de calcul de tarifs actuel par une nouvelle approche basée sur :
- Prix plancher jusqu'à 3 km
- Majorations pour embouteillages et courses longues
- Nouveaux tarifs de réservation
- Système d'arrondis au multiple de 500 MGA le plus proche

### Approche technique
**Migration progressive** avec système parallèle pour éviter les régressions et permettre un rollback si nécessaire.

---

## 🎯 Spécifications détaillées

### 1. Nouvelle logique de calcul

#### 1.1 Formule de base
```
Distance d < 3 km     : Prix = Prix plancher
Distance 3 ≤ d < 15   : Prix = prix_km × d  
Distance d ≥ 15       : Prix = prix_km × [15 + (d - 15) × 1.2]
```

#### 1.2 Tarifs par catégorie
| Catégorie  | Prix plancher | Prix/km |
|------------|---------------|---------|
| Taxi-moto  | 6000 MGA      | 2000    |
| Classic    | 8000 MGA      | 2750    |
| Confort    | 11000 MGA     | 3850    |
| 4x4        | 13000 MGA     | 4500    |
| Van        | 15000 MGA     | 5000    |

#### 1.3 Majorations (cumulatives)

**Embouteillages** (priorité 1) :
- Multiplicateur : ×1.4
- Créneaux : 7h00-9h59 et 16h00-18h59
- Application : `prix_base × 1.4`

**Courses longues** (priorité 2) :
- Déjà intégré dans la formule de base (seuil 15 km, majoration ×1.2)

#### 1.4 Réservation
- Surcoût fixe par catégorie : Taxi-moto (3600), Classic (5000), Confort (7000), 4x4 (8200), Van (9100)
- Temps d'avance : 10 minutes (paramétrable via Firestore)
- Application : `prix_final + surcoût_réservation`

#### 1.5 Codes promo
- Application après toutes les majorations
- Sur le prix final avant arrondi

#### 1.6 Arrondis
- Au multiple de 500 MGA le plus proche
- Application en dernier (après codes promo)

---

## 🏗️ Architecture technique

### 2. Nouveaux modèles de données

#### 2.1 Configuration Firestore
```dart
// Collection: setting/pricing_config_v2
class PricingConfigV2 {
  // Prix plancher par catégorie
  Map<String, double> floorPrices;
  
  // Prix par km par catégorie  
  Map<String, double> pricePerKm;
  
  // Seuil max pour prix plancher (défaut: 3 km)
  double floorPriceThreshold;
  
  // Configuration embouteillages
  double trafficMultiplier;        // 1.4
  List<TrafficPeriod> trafficPeriods;
  
  // Configuration courses longues
  double longTripThreshold;        // 15 km
  double longTripMultiplier;       // 1.2
  
  // Configuration réservation
  Map<String, double> reservationSurcharge;
  int reservationAdvanceMinutes;   // 10
  
  // Système d'arrondis
  bool enableRounding;             // true
  int roundingStep;                // 500
  
  // Contrôle de migration
  bool enableNewPricingSystem;     // false initialement
  String version;                  // "2.0"
}

class TrafficPeriod {
  TimeOfDay startTime;            // 07:00
  TimeOfDay endTime;              // 09:59
  List<int> daysOfWeek;           // [1,2,3,4,5] = Lun-Ven
}
```

#### 2.2 Service de calcul v2
```dart
class PricingServiceV2 {
  // Calcul principal
  Future<PriceCalculation> calculatePrice({
    required String vehicleCategory,
    required double distance,
    required DateTime requestTime,
    required bool isScheduled,
    PromoCode? promoCode,
  });
  
  // Méthodes internes
  double _calculateBasePrice(String category, double distance);
  double _applyTrafficSurcharge(double basePrice, DateTime requestTime);
  double _applyReservationSurcharge(double price, String category, bool isScheduled);
  double _applyPromoCode(double price, PromoCode? promoCode);
  double _roundPrice(double price);
}

class PriceCalculation {
  double basePrice;               // Prix de base
  double trafficSurcharge;        // Majoration embouteillages
  double reservationSurcharge;    // Surcoût réservation
  double promoDiscount;           // Réduction promo
  double finalPrice;              // Prix final arrondi
  
  Map<String, dynamic> breakdown; // Détail des calculs
  String pricingVersion;          // "v2.0"
}
```

### 3. Migration et compatibilité

#### 3.1 Stratégie de déploiement
1. **Phase 1** : Développement système v2 en parallèle
2. **Phase 2** : Tests internes avec flag Firestore
3. **Phase 3** : Rollout progressif par pourcentage d'utilisateurs
4. **Phase 4** : Migration complète et suppression de l'ancien système

#### 3.2 Sélecteur de système
```dart
class PricingSystemSelector {
  static Future<IPricingService> getPricingService() async {
    final config = await FirestoreServices.getPricingConfig();
    
    if (config.enableNewPricingSystem) {
      return PricingServiceV2();
    }
    
    return PricingServiceLegacy(); // Système actuel
  }
}

abstract class IPricingService {
  Future<PriceCalculation> calculatePrice(...);
}
```

---

## 📁 Structure des fichiers

### 4. Nouveaux fichiers à créer

```
lib/
├── services/
│   ├── pricing/
│   │   ├── pricing_service_v2.dart
│   │   ├── pricing_service_legacy.dart
│   │   ├── pricing_system_selector.dart
│   │   └── pricing_config_service.dart
│   └── pricing_service.dart (interface)
├── models/
│   ├── pricing/
│   │   ├── pricing_config_v2.dart
│   │   ├── price_calculation.dart
│   │   ├── traffic_period.dart
│   │   └── pricing_breakdown.dart
├── utils/
│   └── price_utils.dart (arrondis, formatage)
└── widgets/
    └── pricing/
        ├── price_breakdown_widget.dart
        └── price_comparison_widget.dart (debug)
```

### 5. Fichiers à modifier

```
lib/provider/trip_provider.dart           → Utiliser nouveau service
lib/bottom_sheet_widget/choose_vehicle_sheet.dart → Affichage v2
lib/pages/view_module/booking_detail_screen.dart → Détails v2
```

---

## 🧪 Plan de tests

### 6. Tests unitaires
```dart
// test/services/pricing_service_v2_test.dart
group('PricingServiceV2', () {
  test('Prix plancher < 3km');
  test('Prix normal 3-15km');
  test('Prix courses longues >15km');
  test('Majoration embouteillages');
  test('Cumul majorations');
  test('Surcoût réservation');
  test('Application codes promo');
  test('Arrondis 500 MGA');
});
```

### 7. Tests d'intégration
- Comparaison ancien vs nouveau système
- Tests avec données réelles de production
- Validation des configurations Firestore

---

## 🚀 Planning de développement

### Sprint 1 (Semaine 1-2) : Fondations
- [ ] Créer modèles de données v2
- [ ] Implémenter PricingServiceV2 
- [ ] Configuration Firestore
- [ ] Tests unitaires

### Sprint 2 (Semaine 3) : Intégration
- [ ] Sélecteur de système
- [ ] Migration TripProvider
- [ ] Interface de debug/comparaison
- [ ] Tests d'intégration

### Sprint 3 (Semaine 4) : Interface utilisateur
- [ ] Mise à jour affichage prix
- [ ] Widget détail des calculs
- [ ] Gestion erreurs et fallback
- [ ] Tests end-to-end

### Sprint 4 (Semaine 5) : Déploiement
- [ ] Tests en production limitée
- [ ] Monitoring et métriques
- [ ] Documentation finale
- [ ] Formation équipe

---

## ⚡ Points d'attention

### 8. Risques et mitigation

**Risque** : Différences de prix importantes vs ancien système
**Mitigation** : Widget de comparaison en développement, rollout progressif

**Risque** : Configuration Firestore corrompue
**Mitigation** : Validation des données, fallback vers ancien système

**Risque** : Performance (nouveaux calculs plus complexes)
**Mitigation** : Cache des configurations, optimisation des calculs

### 9. Monitoring requis
- Métriques de performance des calculs
- Comparaisons ancien vs nouveau système
- Erreurs de configuration Firestore
- Adoption du nouveau système

---

## 🔧 Configuration initiale Firestore

```json
{
  "app_settings": {
    "pricing_config_v2": {
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
  }
}
```

---

**Responsable technique** : Équipe développement  
**Validation** : Direction technique  
**Déploiement** : DevOps  

*Document créé le : 27 juillet 2025*
