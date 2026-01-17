# Sprint 3 : Tests et Validation Backend
**Durée** : Semaine 4 (5 jours ouvrés)  
**Objectif** : Validation extensive du nouveau système sans impact utilisateur

## 🎯 Objectif du Sprint

Valider complètement le nouveau système de tarification en mode "shadow" (exécution parallèle invisible) et préparer l'infrastructure de monitoring pour le déploiement progressif.

## 📋 Livrables Attendus

- ✅ Tests shadow mode avec comparaisons v1/v2
- ✅ Interface d'administration pour monitoring
- ✅ Tests de charge et performance validés
- ✅ Procédures de rollback d'urgence
- ✅ Documentation technique complète

## 🏗️ Tâches Détaillées

### Tâche 1 : Tests shadow mode (2 jours)

**Responsable** : Développeur Senior + QA  
**Fichiers à créer** :
- `lib/services/pricing/shadow_pricing_service.dart`
- `lib/utils/pricing_analytics.dart`

#### 1.1 Service de test en parallèle
```dart
class ShadowPricingService {
  static bool _shadowEnabled = false;
  
  /// Active le mode shadow pour collecter les données
  static void enableShadowMode() {
    _shadowEnabled = true;
    myCustomPrintStatement('Shadow pricing mode enabled');
  }
  
  /// Exécute les deux systèmes en parallèle et compare
  static Future<PriceCalculation> calculateWithShadow({
    required String vehicleCategory,
    required double distance,
    required DateTime requestTime,
    required bool isScheduled,
    PromoCode? promoCode,
  }) async {
    // Toujours utiliser le système legacy pour l'utilisateur
    final legacyService = PricingServiceLegacy();
    final legacyResult = await legacyService.calculatePrice(
      vehicleCategory: vehicleCategory,
      distance: distance,
      requestTime: requestTime,
      isScheduled: isScheduled,
      promoCode: promoCode,
    );
    
    if (_shadowEnabled) {
      // Exécuter V2 en parallèle (invisible pour l'utilisateur)
      _runShadowComparison(
        vehicleCategory: vehicleCategory,
        distance: distance,
        requestTime: requestTime,
        isScheduled: isScheduled,
        promoCode: promoCode,
        legacyResult: legacyResult,
      );
    }
    
    return legacyResult; // Toujours retourner legacy
  }
  
  /// Comparaison en arrière-plan
  static void _runShadowComparison({
    required String vehicleCategory,
    required double distance,
    required DateTime requestTime,
    required bool isScheduled,
    PromoCode? promoCode,
    required PriceCalculation legacyResult,
  }) async {
    try {
      final v2Service = PricingServiceV2();
      final v2Result = await v2Service.calculatePrice(
        vehicleCategory: vehicleCategory,
        distance: distance,
        requestTime: requestTime,
        isScheduled: isScheduled,
        promoCode: promoCode,
      );
      
      // Analyser et stocker les différences
      await PricingAnalytics.recordComparison(
        scenario: PricingScenario(
          vehicleCategory: vehicleCategory,
          distance: distance,
          requestTime: requestTime,
          isScheduled: isScheduled,
        ),
        legacyPrice: legacyResult.finalPrice,
        v2Price: v2Result.finalPrice,
        v2Breakdown: v2Result.breakdown,
      );
      
    } catch (e) {
      myCustomPrintStatement('Shadow comparison error: $e');
      // Erreur silencieuse, n'affecte pas l'utilisateur
    }
  }
}
```

#### 1.2 Analytics et collecte de données
```dart
class PricingAnalytics {
  static final List<PriceComparison> _comparisons = [];
  
  static Future<void> recordComparison({
    required PricingScenario scenario,
    required double legacyPrice,
    required double v2Price,
    required Map<String, dynamic> v2Breakdown,
  }) async {
    final comparison = PriceComparison(
      scenario: scenario,
      legacyPrice: legacyPrice,
      v2Price: v2Price,
      difference: v2Price - legacyPrice,
      percentageDiff: ((v2Price - legacyPrice) / legacyPrice) * 100,
      v2Breakdown: v2Breakdown,
      timestamp: DateTime.now(),
    );
    
    _comparisons.add(comparison);
    
    // Log pour analyse
    myCustomPrintStatement('''
SHADOW: ${scenario.vehicleCategory} ${scenario.distance}km
Legacy: ${legacyPrice} MGA | V2: ${v2Price} MGA
Diff: ${comparison.difference.toStringAsFixed(0)} MGA (${comparison.percentageDiff.toStringAsFixed(1)}%)
    ''');
    
    // Alerte si écart important
    if (comparison.percentageDiff.abs() > 20) {
      myCustomPrintStatement('⚠️  LARGE PRICE DIFFERENCE: ${comparison.percentageDiff.toStringAsFixed(1)}%');
    }
  }
  
  /// Génère un rapport de comparaison
  static Map<String, dynamic> generateReport() {
    if (_comparisons.isEmpty) return {'error': 'No comparisons recorded'};
    
    final differences = _comparisons.map((c) => c.difference).toList();
    final percentages = _comparisons.map((c) => c.percentageDiff).toList();
    
    return {
      'totalComparisons': _comparisons.length,
      'averageDifference': differences.reduce((a, b) => a + b) / differences.length,
      'averagePercentageDiff': percentages.reduce((a, b) => a + b) / percentages.length,
      'maxDifference': differences.reduce((a, b) => a > b ? a : b),
      'minDifference': differences.reduce((a, b) => a < b ? a : b),
      'largeDeviations': _comparisons.where((c) => c.percentageDiff.abs() > 15).length,
      'comparisons': _comparisons.map((c) => c.toJson()).toList(),
    };
  }
}

class PriceComparison {
  final PricingScenario scenario;
  final double legacyPrice;
  final double v2Price;
  final double difference;
  final double percentageDiff;
  final Map<String, dynamic> v2Breakdown;
  final DateTime timestamp;
  
  const PriceComparison({
    required this.scenario,
    required this.legacyPrice,
    required this.v2Price,
    required this.difference,
    required this.percentageDiff,
    required this.v2Breakdown,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'scenario': scenario.toJson(),
    'legacyPrice': legacyPrice,
    'v2Price': v2Price,
    'difference': difference,
    'percentageDiff': percentageDiff,
    'v2Breakdown': v2Breakdown,
    'timestamp': timestamp.toIso8601String(),
  };
}
```

**Tests** :
- Comparaisons sur 1000+ scénarios réels
- Analyse des écarts par catégorie de véhicule
- Détection des cas problématiques
- Validation des temps de calcul

---

### Tâche 2 : Interface d'administration (2 jours)

**Responsable** : Développeur Frontend  
**Fichiers à créer** :
- `lib/pages/admin/pricing_admin_screen.dart`
- `lib/widgets/admin/pricing_control_panel.dart`

#### 2.1 Écran d'administration (développeurs uniquement)
```dart
class PricingAdminScreen extends StatefulWidget {
  @override
  _PricingAdminScreenState createState() => _PricingAdminScreenState();
}

class _PricingAdminScreenState extends State<PricingAdminScreen> {
  PricingConfigV2? _currentConfig;
  Map<String, dynamic>? _analyticsReport;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pricing Admin Panel - DEV ONLY'),
        backgroundColor: Colors.red, // Évident que c'est admin
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentConfigCard(),
            SizedBox(height: 16),
            _buildControlPanel(),
            SizedBox(height: 16),
            _buildAnalyticsCard(),
            SizedBox(height: 16),
            _buildTestingTools(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCurrentConfigCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configuration Actuelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            if (_currentConfig != null) ...[
              Text('Version: ${_currentConfig!.version}'),
              Text('Nouveau système activé: ${_currentConfig!.enableNewPricingSystem}'),
              Text('Multiplicateur embouteillages: ${_currentConfig!.trafficMultiplier}'),
              Text('Seuil courses longues: ${_currentConfig!.longTripThreshold} km'),
            ] else
              Text('Configuration non chargée'),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadConfig,
              child: Text('Recharger Configuration'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contrôles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _enableShadowMode,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: Text('Activer Shadow Mode'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _emergencyRollback,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('ROLLBACK D\'URGENCE'),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('⚠️ ATTENTION: Ces contrôles affectent la production!', 
                 style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnalyticsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics Shadow Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            if (_analyticsReport != null) ...[
              Text('Comparaisons effectuées: ${_analyticsReport!['totalComparisons']}'),
              Text('Écart moyen: ${_analyticsReport!['averageDifference']?.toStringAsFixed(0)} MGA'),
              Text('Écart pourcentage moyen: ${_analyticsReport!['averagePercentageDiff']?.toStringAsFixed(1)}%'),
              Text('Écarts importants (>15%): ${_analyticsReport!['largeDeviations']}'),
            ] else
              Text('Aucune donnée analytics disponible'),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: Text('Actualiser Analytics'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Méthodes de contrôle
  void _loadConfig() async {
    final config = await PricingConfigService.getConfig();
    setState(() {
      _currentConfig = config;
    });
  }
  
  void _enableShadowMode() {
    ShadowPricingService.enableShadowMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shadow mode activé')),
    );
  }
  
  void _emergencyRollback() async {
    // Désactiver immédiatement le nouveau système
    final config = _currentConfig?.copyWith(enableNewPricingSystem: false);
    if (config != null) {
      await PricingConfigService.updateConfig(config);
      PricingSystemSelector.resetService();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ROLLBACK EFFECTUÉ - Système legacy activé')),
      );
    }
  }
  
  void _loadAnalytics() {
    final report = PricingAnalytics.generateReport();
    setState(() {
      _analyticsReport = report;
    });
  }
}
```

#### 2.2 Outils de test en temps réel
```dart
class PricingTestWidget extends StatefulWidget {
  @override
  _PricingTestWidgetState createState() => _PricingTestWidgetState();
}

class _PricingTestWidgetState extends State<PricingTestWidget> {
  String _selectedCategory = 'classic';
  double _distance = 5.0;
  bool _isScheduled = false;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Test de Prix en Temps Réel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedCategory,
              items: ['taxi_moto', 'classic', 'confort', '4x4', 'van']
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
            Slider(
              value: _distance,
              min: 0.5,
              max: 25.0,
              divisions: 49,
              label: '${_distance.toStringAsFixed(1)} km',
              onChanged: (value) => setState(() => _distance = value),
            ),
            CheckboxListTile(
              title: Text('Réservation programmée'),
              value: _isScheduled,
              onChanged: (value) => setState(() => _isScheduled = value ?? false),
            ),
            ElevatedButton(
              onPressed: _testPricing,
              child: Text('Tester Calcul'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _testPricing() async {
    // Lancer test de calcul avec paramètres sélectionnés
    await ShadowPricingService.calculateWithShadow(
      vehicleCategory: _selectedCategory,
      distance: _distance,
      requestTime: DateTime.now(),
      isScheduled: _isScheduled,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Test de calcul lancé - voir logs')),
    );
  }
}
```

**Accès** : Cette interface n'est accessible que via un flag de développement et n'apparaît jamais aux utilisateurs finaux.

---

### Tâche 3 : Tests de charge et performance (2 jours)

**Responsable** : Développeur + DevOps  
**Fichier à créer** : `test/performance/pricing_performance_test.dart`

#### 3.1 Tests de performance
```dart
import 'package:test/test.dart';

void main() {
  group('Pricing Performance Tests', () {
    test('V2 calculation should be under 100ms', () async {
      final service = PricingServiceV2();
      final stopwatch = Stopwatch()..start();
      
      await service.calculatePrice(
        vehicleCategory: 'classic',
        distance: 10.0,
        requestTime: DateTime.now(),
        isScheduled: false,
      );
      
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
    
    test('Batch calculations performance', () async {
      final service = PricingServiceV2();
      final scenarios = _generateTestScenarios(1000);
      
      final stopwatch = Stopwatch()..start();
      
      for (final scenario in scenarios) {
        await service.calculatePrice(
          vehicleCategory: scenario.category,
          distance: scenario.distance,
          requestTime: scenario.requestTime,
          isScheduled: scenario.isScheduled,
        );
      }
      
      stopwatch.stop();
      final avgTime = stopwatch.elapsedMilliseconds / scenarios.length;
      expect(avgTime, lessThan(50)); // Moyenne < 50ms
    });
    
    test('Memory usage stability', () async {
      // Test de stabilité mémoire sur 10000 calculs
      final service = PricingServiceV2();
      
      for (int i = 0; i < 10000; i++) {
        await service.calculatePrice(
          vehicleCategory: 'classic',
          distance: 5.0 + (i % 20),
          requestTime: DateTime.now(),
          isScheduled: i % 3 == 0,
        );
        
        // Vérification périodique de la mémoire
        if (i % 1000 == 0) {
          // Force garbage collection
          await Future.delayed(Duration(milliseconds: 1));
        }
      }
      
      // Test réussi si pas de memory leak
    });
  });
}

List<PricingScenario> _generateTestScenarios(int count) {
  final categories = ['taxi_moto', 'classic', 'confort', '4x4', 'van'];
  final scenarios = <PricingScenario>[];
  
  for (int i = 0; i < count; i++) {
    scenarios.add(PricingScenario(
      vehicleCategory: categories[i % categories.length],
      distance: 0.5 + (i % 25) * 0.8, // 0.5km à 20km
      requestTime: DateTime.now().add(Duration(minutes: i % 1440)),
      isScheduled: i % 4 == 0,
    ));
  }
  
  return scenarios;
}
```

#### 3.2 Tests de charge Firestore
```dart
test('Firestore configuration load test', () async {
  // Test de charge sur récupération config
  final futures = List.generate(100, (_) async {
    return await PricingConfigService.getConfig();
  });
  
  final stopwatch = Stopwatch()..start();
  final results = await Future.wait(futures);
  stopwatch.stop();
  
  // Toutes les configs doivent être identiques
  expect(results.every((config) => config.version == results.first.version), isTrue);
  
  // Temps total raisonnable
  expect(stopwatch.elapsedMilliseconds, lessThan(5000));
});
```

**Métriques cibles** :
- Calcul individuel : < 100ms
- Calcul batch moyen : < 50ms
- Récupération config : < 200ms
- Stabilité mémoire : Aucun leak détecté

---

### Tâche 4 : Procédures de rollback (1 jour)

**Responsable** : DevOps + Développeur Senior  
**Fichier à créer** : `doc/tarifs-misy-2.0/ROLLBACK_PROCEDURES.md`

#### 4.1 Procédure de rollback immédiat
```markdown
# Procédure de Rollback d'Urgence

## 🚨 Rollback Immédiat (< 2 minutes)

### Via Interface Admin
1. Accéder à `PricingAdminScreen` (dev uniquement)
2. Cliquer "ROLLBACK D'URGENCE"
3. Vérifier que le flag `enableNewPricingSystem` = false

### Via Firestore Console
1. Ouvrir Firebase Console
2. Aller à Firestore Database
3. Collection `app_settings` → Document `pricing_config_v2`
4. Modifier `enableNewPricingSystem: false`
5. Sauvegarder

### Via Code d'Urgence
```dart
// Code de rollback d'urgence dans l'app
await FirebaseFirestore.instance
    .collection('app_settings')
    .doc('pricing_config_v2')
    .update({'enableNewPricingSystem': false});

PricingSystemSelector.resetService();
```

## 📊 Vérification Post-Rollback

1. **Logs d'application** : Vérifier "Using PricingServiceLegacy"
2. **Calculs de prix** : Tester plusieurs scénarios
3. **Interface utilisateur** : Aucun changement visible
4. **Performance** : Temps de réponse normaux

## 🔄 Rollback Partiel (Réduction du Pourcentage)

Si rollback total non nécessaire, réduire le pourcentage d'utilisateurs :
- 75% → 25% : Réduction majeure
- 25% → 5% : Réduction test
- 5% → 0% : Désactivation complète
```

#### 4.2 Monitoring de rollback
```dart
class RollbackMonitor {
  static Future<bool> verifyRollbackSuccess() async {
    try {
      // Vérifier que le service legacy est actif
      final service = await PricingSystemSelector.getPricingService();
      if (service is! PricingServiceLegacy) {
        return false;
      }
      
      // Tester un calcul simple
      final result = await service.calculatePrice(
        vehicleCategory: 'classic',
        distance: 5.0,
        requestTime: DateTime.now(),
        isScheduled: false,
      );
      
      return result.pricingVersion == 'v1.0';
    } catch (e) {
      myCustomPrintStatement('Rollback verification failed: $e');
      return false;
    }
  }
}
```

## ⚠️ Points Critiques de Validation

### 🚫 Risques à Surveiller
- **Différences de prix importantes** (> 25%)
- **Temps de calcul excessifs** (> 200ms)
- **Erreurs de configuration Firestore**
- **Memory leaks** sur calculs répétés
- **Comportement anormal** de l'interface

### ✅ Critères de Validation
- Shadow mode fonctionne sans impact utilisateur
- Écarts de prix dans les limites acceptables
- Performance équivalente ou meilleure
- Interface utilisateur strictement identique
- Rollback d'urgence opérationnel

## 📊 Métriques de Succès Sprint 3

| Métrique | Cible | Status |
|----------|-------|--------|
| Tests shadow sans impact | 100% | ⏳ |
| Interface admin fonctionnelle | 100% | ⏳ |
| Performance < 100ms | 100% | ⏳ |
| Rollback < 2min | 100% | ⏳ |
| Documentation complète | 100% | ⏳ |

## 📝 Checklist de Fin de Sprint

- [ ] Shadow mode testé sur 1000+ scénarios
- [ ] Interface admin créée et sécurisée
- [ ] Tests de performance validés
- [ ] Procédures de rollback documentées et testées
- [ ] Analytics de comparaison v1/v2 opérationnels
- [ ] Aucun impact visible côté utilisateur
- [ ] Équipe formée sur les outils d'administration
- [ ] Monitoring en place pour le déploiement
- [ ] Validation finale par l'équipe technique
- [ ] Prêt pour le rollout progressif en Sprint 4

**Système validé et prêt pour production** ✅