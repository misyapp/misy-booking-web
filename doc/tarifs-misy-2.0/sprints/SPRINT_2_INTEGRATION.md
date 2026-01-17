# Sprint 2 : Intégration et Sélecteur de Système
**Durée** : Semaine 3 (5 jours ouvrés)  
**Objectif** : Intégrer le nouveau système avec capacité de bascule transparente via feature flag

## 🎯 Objectif du Sprint

Créer l'infrastructure de sélection entre ancien et nouveau système de tarification, avec intégration transparente dans le `TripProvider` existant. L'utilisateur ne doit voir aucune différence.

## 📋 Livrables Attendus

- ✅ Sélecteur de système avec logique de feature flag
- ✅ TripProvider refactorisé pour utiliser le sélecteur
- ✅ Outils de debug internes pour comparaison
- ✅ Tests d'intégration complets
- ✅ Interface utilisateur strictement identique

## 🏗️ Tâches Détaillées

### Tâche 1 : Sélecteur de système (2 jours)

**Responsable** : Développeur Senior  
**Fichier à créer** : `lib/services/pricing/pricing_system_selector.dart`

#### 1.1 Implémentation du sélecteur
```dart
class PricingSystemSelector {
  static IPricingService? _currentService;
  
  /// Récupère le service de pricing approprié selon la configuration
  static Future<IPricingService> getPricingService() async {
    if (_currentService != null) {
      return _currentService!;
    }
    
    try {
      final config = await PricingConfigService.getConfig();
      
      if (config.enableNewPricingSystem) {
        myCustomPrintStatement('Using PricingServiceV2');
        _currentService = PricingServiceV2();
      } else {
        myCustomPrintStatement('Using PricingServiceLegacy');
        _currentService = PricingServiceLegacy();
      }
      
      return _currentService!;
    } catch (e) {
      // Fallback automatique vers l'ancien système
      myCustomPrintStatement('Error loading pricing config, falling back to legacy: $e');
      _currentService = PricingServiceLegacy();
      return _currentService!;
    }
  }
  
  /// Force le rechargement du service (pour tests uniquement)
  @visibleForTesting
  static void resetService() {
    _currentService = null;
  }
  
  /// Récupère le service actuel sans rechargement
  static IPricingService? getCurrentService() {
    return _currentService;
  }
}
```

#### 1.2 Logique de fallback robuste
- **Erreur Firestore** → Fallback automatique vers legacy
- **Configuration invalide** → Fallback avec log d'erreur
- **Timeout** → Fallback avec retry en arrière-plan
- **Service indisponible** → Maintien du dernier service valide

**Tests unitaires** :
- Sélection service v2 quand flag = true
- Sélection service legacy quand flag = false
- Fallback sur erreur de configuration
- Cache du service sélectionné
- Reset pour tests

---

### Tâche 2 : Migration TripProvider (2 jours)

**Responsable** : Développeur Frontend  
**Fichier à modifier** : `lib/provider/trip_provider.dart`

#### 2.1 Refactorisation de calculatePrice()

**Avant** (exemple actuel) :
```dart
// Dans trip_provider.dart - méthode actuelle
Future<void> calculatePrice() async {
  // Ancien calcul direct
  final price = _calculateLegacyPrice();
  estimatedPrice = price;
  notifyListeners();
}
```

**Après** (nouvelle implémentation) :
```dart
Future<void> calculatePrice() async {
  try {
    final pricingService = await PricingSystemSelector.getPricingService();
    
    final calculation = await pricingService.calculatePrice(
      vehicleCategory: selectedVehicleCategory,
      distance: routeDistance,
      requestTime: DateTime.now(),
      isScheduled: isScheduledRide,
      promoCode: appliedPromoCode,
    );
    
    // Interface utilisateur IDENTIQUE
    estimatedPrice = calculation.finalPrice;
    
    // Logs internes uniquement (pas visibles utilisateur)
    myCustomPrintStatement('Price calculated: ${calculation.finalPrice} (${calculation.pricingVersion})');
    
    notifyListeners();
  } catch (e) {
    myCustomPrintStatement('Pricing calculation error: $e');
    // Fallback vers calcul d'urgence si nécessaire
    estimatedPrice = _emergencyPriceCalculation();
    notifyListeners();
  }
}
```

#### 2.2 Maintien de l'interface exacte
- **estimatedPrice** : Même variable, même utilisation
- **notifyListeners()** : Même cycle de notification
- **Gestion d'erreurs** : Même comportement pour l'utilisateur
- **Variables publiques** : Aucun changement dans l'API du provider

#### 2.3 Ajout de propriétés internes (optionnel)
```dart
// Propriétés pour debugging interne uniquement
PriceCalculation? _lastCalculation;
String get currentPricingVersion => _lastCalculation?.pricingVersion ?? 'unknown';

// Getter pour outils de debug uniquement
@visibleForTesting
PriceCalculation? get lastPriceCalculation => _lastCalculation;
```

**Tests de régression** :
- Interface publique du TripProvider inchangée
- Même comportement pour tous les widgets existants
- Aucun changement dans l'UI
- Performance équivalente

---

### Tâche 3 : Outils de debug internes (2 jours)

**Responsable** : Développeur Frontend  
**Fichiers à créer** :
- `lib/widgets/pricing/price_comparison_widget.dart` (debug uniquement)
- `lib/services/pricing/pricing_debug_service.dart`

#### 3.1 Widget de comparaison (développeurs uniquement)
```dart
class PriceComparisonWidget extends StatelessWidget {
  final String vehicleCategory;
  final double distance;
  final DateTime requestTime;
  final bool isScheduled;
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, PriceCalculation>>(
      future: _compareServices(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final v1Price = snapshot.data!['v1']!;
        final v2Price = snapshot.data!['v2']!;
        final difference = v2Price.finalPrice - v1Price.finalPrice;
        
        return Card(
          child: Column(
            children: [
              Text('Comparaison Pricing (DEV ONLY)'),
              Text('V1: ${v1Price.finalPrice} MGA'),
              Text('V2: ${v2Price.finalPrice} MGA'),
              Text('Écart: ${difference.toStringAsFixed(0)} MGA'),
              Text('V2 Breakdown: ${v2Price.breakdown}'),
            ],
          ),
        );
      },
    );
  }
  
  Future<Map<String, PriceCalculation>> _compareServices() async {
    final v1Service = PricingServiceLegacy();
    final v2Service = PricingServiceV2();
    
    final v1Result = await v1Service.calculatePrice(/*...*/);
    final v2Result = await v2Service.calculatePrice(/*...*/);
    
    return {'v1': v1Result, 'v2': v2Result};
  }
}
```

#### 3.2 Service de debug
```dart
class PricingDebugService {
  static bool _debugEnabled = false;
  
  /// Active le mode debug (développement uniquement)
  static void enableDebug() {
    _debugEnabled = true;
  }
  
  /// Logs de comparaison v1 vs v2
  static Future<void> logPriceComparison({
    required String vehicleCategory,
    required double distance,
    required DateTime requestTime,
    required bool isScheduled,
  }) async {
    if (!_debugEnabled) return;
    
    try {
      final v1Service = PricingServiceLegacy();
      final v2Service = PricingServiceV2();
      
      final v1Result = await v1Service.calculatePrice(/*...*/);
      final v2Result = await v2Service.calculatePrice(/*...*/);
      
      final difference = v2Result.finalPrice - v1Result.finalPrice;
      final percentDiff = (difference / v1Result.finalPrice) * 100;
      
      myCustomPrintStatement('''
=== PRICE COMPARISON DEBUG ===
Category: $vehicleCategory
Distance: ${distance.toStringAsFixed(2)} km
V1 Price: ${v1Result.finalPrice} MGA
V2 Price: ${v2Result.finalPrice} MGA
Difference: ${difference.toStringAsFixed(0)} MGA (${percentDiff.toStringAsFixed(1)}%)
V2 Breakdown: ${v2Result.breakdown}
==============================
      ''');
    } catch (e) {
      myCustomPrintStatement('Debug comparison error: $e');
    }
  }
}
```

**Usage** : Ces outils ne sont jamais visibles aux utilisateurs finaux, uniquement pour l'équipe de développement.

---

### Tâche 4 : Tests d'intégration (1 jour)

**Responsable** : Développeur QA  
**Fichier à créer** : `test/integration/pricing_integration_test.dart`

#### 4.1 Tests de sélection de système
```dart
group('PricingSystemSelector Integration', () {
  test('should use V2 when flag is enabled', () async {
    // Setup config avec enableNewPricingSystem = true
    final service = await PricingSystemSelector.getPricingService();
    expect(service, isA<PricingServiceV2>());
  });
  
  test('should use Legacy when flag is disabled', () async {
    // Setup config avec enableNewPricingSystem = false
    final service = await PricingSystemSelector.getPricingService();
    expect(service, isA<PricingServiceLegacy>());
  });
  
  test('should fallback to Legacy on error', () async {
    // Simuler erreur Firestore
    final service = await PricingSystemSelector.getPricingService();
    expect(service, isA<PricingServiceLegacy>());
  });
});
```

#### 4.2 Tests TripProvider
```dart
group('TripProvider Integration', () {
  test('should maintain same interface with new pricing', () async {
    final provider = TripProvider();
    
    // Test avec nouveau système
    await provider.calculatePrice();
    
    // Vérifier que l'interface publique est identique
    expect(provider.estimatedPrice, isNotNull);
    expect(provider.estimatedPrice, greaterThan(0));
  });
  
  test('should handle pricing errors gracefully', () async {
    // Test gestion d'erreurs sans impact utilisateur
  });
});
```

#### 4.3 Tests de comparaison
```dart
group('Price Comparison Tests', () {
  test('should compare V1 vs V2 prices', () async {
    // Tests sur différents scénarios de pricing
    // Validation des écarts attendus
  });
});
```

## 🎛️ Configuration de Test

### Variables d'environnement
```dart
// Pour forcer l'utilisation de V2 en test
const bool FORCE_PRICING_V2 = true;

// Pour activer les logs de debug
const bool ENABLE_PRICING_DEBUG = true;
```

### Mock des services Firestore
Configuration de mocks pour tester les différents scénarios sans dépendre de Firestore.

## ⚠️ Points Critiques

### 🚫 Interdictions Absolues
- **Ne pas changer** l'interface utilisateur
- **Ne pas afficher** de widgets de comparaison aux utilisateurs
- **Ne pas modifier** le comportement visible du TripProvider
- **Ne pas ajouter** d'indicateurs de version dans l'UI

### ✅ Exigences Strictes
- Interface utilisateur **exactement identique**
- Performance **équivalente ou meilleure**
- Fallback **automatique et invisible**
- Logs **internes uniquement**

## 📊 Métriques de Succès

| Métrique | Cible | Validation |
|----------|-------|------------|
| Interface inchangée | 100% | Tests de régression UI |
| Performance | ≤ +10ms | Benchmarks de calcul |
| Robustesse fallback | 100% | Tests d'erreur |
| Transparence utilisateur | 100% | Tests utilisateur |

## 🧪 Plan de Tests

### Tests automatisés
- **Unit tests** : Sélecteur et intégration TripProvider
- **Integration tests** : Comportement avec vraies configs
- **Regression tests** : Interface utilisateur inchangée
- **Performance tests** : Temps de calcul acceptables

### Tests manuels
- **Flow utilisateur** : Réservation complète identique
- **Changement de configuration** : Bascule transparente
- **Gestion d'erreurs** : Comportement en cas de panne

## 📝 Checklist de Fin de Sprint

- [ ] PricingSystemSelector implémenté et testé
- [ ] TripProvider migré sans changer l'interface
- [ ] Outils de debug créés (internes uniquement)
- [ ] Tests d'intégration passent à 100%
- [ ] Aucun changement visible côté utilisateur
- [ ] Performance maintenue ou améliorée
- [ ] Gestion d'erreurs robuste
- [ ] Documentation technique mise à jour
- [ ] Validation par tests utilisateur
- [ ] Prêt pour phase de validation en Sprint 3

**Interface utilisateur : 0% de changement visible** ✅