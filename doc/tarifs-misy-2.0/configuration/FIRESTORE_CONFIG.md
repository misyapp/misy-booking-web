# Configuration Firestore - Tarifs Misy 2.0

## 🎯 Vue d'ensemble

Ce document détaille la configuration Firestore nécessaire pour le nouveau système de tarification, avec les structures de données, exemples et procédures de gestion.

## 📂 Structure des Collections

### Collection Principale : `app_settings`

```
app_settings/
├── pricing_config_v2          # Configuration système de pricing v2
├── rollout_config             # Configuration du déploiement progressif
└── pricing_emergency_config   # Configuration de rollback d'urgence
```

## 🔧 Document : pricing_config_v2

**Chemin** : `app_settings/pricing_config_v2`  
**Utilisation** : Configuration principale du système de tarification v2

### Structure Complète

```json
{
  "version": "2.0",
  "enableNewPricingSystem": false,
  "lastUpdated": "2025-07-28T10:30:00Z",
  "updatedBy": "admin@misy.com",
  
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
      "daysOfWeek": [1, 2, 3, 4, 5],
      "description": "Embouteillages matinaux"
    },
    {
      "startTime": "16:00",
      "endTime": "18:59",
      "daysOfWeek": [1, 2, 3, 4, 5],
      "description": "Embouteillages en soirée"
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
  "roundingStep": 500,
  
  "metadata": {
    "createdAt": "2025-07-28T10:00:00Z",
    "environment": "production",
    "configVersion": "1.0"
  },
  
  "validation": {
    "maxPrice": 200000,
    "minPrice": 1000,
    "maxDistance": 100
  }
}
```

### Champs Obligatoires

| Champ | Type | Description | Validation |
|-------|------|-------------|------------|
| `version` | string | Version du système | = "2.0" |
| `enableNewPricingSystem` | boolean | Flag d'activation | true/false |
| `floorPrices` | object | Prix planchers par catégorie | > 0 pour chaque catégorie |
| `pricePerKm` | object | Prix au km par catégorie | > 0 pour chaque catégorie |
| `floorPriceThreshold` | number | Seuil prix plancher (km) | > 0, typiquement 3.0 |
| `trafficMultiplier` | number | Multiplicateur embouteillages | > 1.0, typiquement 1.4 |
| `longTripThreshold` | number | Seuil course longue (km) | > floorPriceThreshold |
| `longTripMultiplier` | number | Multiplicateur course longue | > 1.0, typiquement 1.2 |
| `reservationSurcharge` | object | Surcoût réservation par catégorie | ≥ 0 |
| `enableRounding` | boolean | Activation arrondis | true/false |
| `roundingStep` | number | Pas d'arrondi (MGA) | > 0, typiquement 500 |

## 📋 Document : rollout_config

**Chemin** : `app_settings/rollout_config`  
**Utilisation** : Gestion du déploiement progressif

### Structure

```json
{
  "pricing_v2_user_percentage": 0,
  "lastUpdated": "2025-07-28T10:30:00Z",
  "updatedBy": "admin@misy.com",
  "rolloutHistory": [
    {
      "percentage": 0,
      "timestamp": "2025-07-28T10:30:00Z",
      "reason": "Initial setup"
    }
  ],
  "rolloutPlan": {
    "phase1": { "percentage": 5, "duration": "24h", "criteria": "No errors" },
    "phase2": { "percentage": 25, "duration": "48h", "criteria": "Performance OK" },
    "phase3": { "percentage": 75, "duration": "48h", "criteria": "User feedback OK" },
    "phase4": { "percentage": 100, "duration": "permanent", "criteria": "Full migration" }
  }
}
```

## 🚨 Document : pricing_emergency_config

**Chemin** : `app_settings/pricing_emergency_config`  
**Utilisation** : Configuration de rollback d'urgence

### Structure

```json
{
  "emergencyRollbackEnabled": false,
  "emergencyContact": "dev-team@misy.com",
  "lastRollback": null,
  "rollbackHistory": [],
  "emergencySettings": {
    "forceV1": false,
    "disableNewCalculations": false,
    "maintenanceMode": false
  },
  "alertThresholds": {
    "errorRate": 2.0,
    "avgCalculationTime": 300,
    "priceDeviationPercent": 50
  }
}
```

## 🔒 Règles de Sécurité Firestore

### Règles de Base

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Configuration pricing - lecture pour tous, écriture admin seulement
    match /app_settings/{document} {
      allow read: if true; // Lecture publique pour l'app
      allow write: if request.auth != null 
        && request.auth.token.email.matches('.*@misy\\.com$')
        && request.auth.token.admin == true;
    }
    
    // Métriques de rollout - écriture limitée
    match /rollout_metrics/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Validation des Données

```javascript
// Règle de validation pour pricing_config_v2
match /app_settings/pricing_config_v2 {
  allow write: if request.auth != null 
    && request.auth.token.admin == true
    && validatePricingConfig(request.resource.data);
}

function validatePricingConfig(data) {
  return data.keys().hasAll(['version', 'enableNewPricingSystem', 'floorPrices'])
    && data.version == "2.0"
    && data.floorPriceThreshold > 0
    && data.longTripThreshold > data.floorPriceThreshold
    && data.trafficMultiplier > 1.0
    && data.roundingStep > 0;
}
```

## 🛠️ Scripts de Configuration

### Script d'Initialisation

```dart
// Script pour initialiser la configuration Firestore
Future<void> initializeFirestoreConfig() async {
  final firestore = FirebaseFirestore.instance;
  
  // Configuration pricing v2
  await firestore.collection('app_settings').doc('pricing_config_v2').set({
    'version': '2.0',
    'enableNewPricingSystem': false,
    'lastUpdated': FieldValue.serverTimestamp(),
    'updatedBy': 'initialization_script',
    
    'floorPrices': {
      'taxi_moto': 6000,
      'classic': 8000,
      'confort': 11000,
      '4x4': 13000,
      'van': 15000,
    },
    
    'pricePerKm': {
      'taxi_moto': 2000,
      'classic': 2750,
      'confort': 3850,
      '4x4': 4500,
      'van': 5000,
    },
    
    'floorPriceThreshold': 3.0,
    
    'trafficMultiplier': 1.4,
    'trafficPeriods': [
      {
        'startTime': '07:00',
        'endTime': '09:59',
        'daysOfWeek': [1, 2, 3, 4, 5],
        'description': 'Embouteillages matinaux',
      },
      {
        'startTime': '16:00',
        'endTime': '18:59',
        'daysOfWeek': [1, 2, 3, 4, 5],
        'description': 'Embouteillages en soirée',
      },
    ],
    
    'longTripThreshold': 15.0,
    'longTripMultiplier': 1.2,
    
    'reservationSurcharge': {
      'taxi_moto': 3600,
      'classic': 5000,
      'confort': 7000,
      '4x4': 8200,
      'van': 9100,
    },
    'reservationAdvanceMinutes': 10,
    
    'enableRounding': true,
    'roundingStep': 500,
    
    'metadata': {
      'createdAt': FieldValue.serverTimestamp(),
      'environment': 'production',
      'configVersion': '1.0',
    },
    
    'validation': {
      'maxPrice': 200000,
      'minPrice': 1000,
      'maxDistance': 100,
    },
  });
  
  // Configuration rollout
  await firestore.collection('app_settings').doc('rollout_config').set({
    'pricing_v2_user_percentage': 0,
    'lastUpdated': FieldValue.serverTimestamp(),
    'updatedBy': 'initialization_script',
    'rolloutHistory': [
      {
        'percentage': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'reason': 'Initial setup',
      }
    ],
  });
  
  // Configuration d'urgence
  await firestore.collection('app_settings').doc('pricing_emergency_config').set({
    'emergencyRollbackEnabled': false,
    'emergencyContact': 'dev-team@misy.com',
    'lastRollback': null,
    'rollbackHistory': [],
    'emergencySettings': {
      'forceV1': false,
      'disableNewCalculations': false,
      'maintenanceMode': false,
    },
    'alertThresholds': {
      'errorRate': 2.0,
      'avgCalculationTime': 300,
      'priceDeviationPercent': 50,
    },
  });
  
  print('Firestore configuration initialized successfully');
}
```

### Script de Validation

```dart
Future<bool> validateFirestoreConfig() async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Vérifier configuration pricing
    final pricingDoc = await firestore
        .collection('app_settings')
        .doc('pricing_config_v2')
        .get();
    
    if (!pricingDoc.exists) {
      print('ERROR: pricing_config_v2 document not found');
      return false;
    }
    
    final config = PricingConfigV2.fromJson(pricingDoc.data()!);
    if (!config.isValid()) {
      print('ERROR: Invalid pricing configuration');
      return false;
    }
    
    // Vérifier configuration rollout
    final rolloutDoc = await firestore
        .collection('app_settings')
        .doc('rollout_config')
        .get();
    
    if (!rolloutDoc.exists) {
      print('ERROR: rollout_config document not found');
      return false;
    }
    
    final rolloutData = rolloutDoc.data()!;
    final percentage = rolloutData['pricing_v2_user_percentage'] as int?;
    
    if (percentage == null || percentage < 0 || percentage > 100) {
      print('ERROR: Invalid rollout percentage: $percentage');
      return false;
    }
    
    print('Firestore configuration validation: SUCCESS');
    return true;
    
  } catch (e) {
    print('ERROR: Firestore validation failed: $e');
    return false;
  }
}
```

## 📊 Collection : rollout_metrics

**Utilisation** : Stockage des métriques de déploiement

### Structure de Document

```json
{
  "userId": "user123",
  "pricingVersion": "v2.0",
  "calculationTime": 45.2,
  "hadError": false,
  "timestamp": "2025-07-28T15:30:00Z",
  "vehicleCategory": "classic",
  "distance": 8.5,
  "finalPrice": 23000,
  "breakdown": {
    "basePrice": 23375,
    "trafficSurcharge": 0,
    "reservationSurcharge": 0,
    "promoDiscount": 0,
    "beforeRounding": 23375,
    "afterRounding": 23500
  }
}
```

## 🔄 Procédures de Gestion

### Mise à Jour de Configuration

```dart
Future<void> updatePricingConfig(Map<String, dynamic> updates) async {
  final firestore = FirebaseFirestore.instance;
  
  // Ajouter métadonnées de mise à jour
  updates['lastUpdated'] = FieldValue.serverTimestamp();
  updates['updatedBy'] = getCurrentAdminEmail();
  
  await firestore
      .collection('app_settings')
      .doc('pricing_config_v2')
      .update(updates);
  
  // Invalider le cache applicatif
  PricingConfigService.clearCache();
  
  print('Configuration updated: ${updates.keys.join(', ')}');
}
```

### Changement de Pourcentage Rollout

```dart
Future<void> updateRolloutPercentage(int newPercentage, String reason) async {
  if (newPercentage < 0 || newPercentage > 100) {
    throw ArgumentError('Percentage must be between 0 and 100');
  }
  
  final firestore = FirebaseFirestore.instance;
  final rolloutRef = firestore.collection('app_settings').doc('rollout_config');
  
  await firestore.runTransaction((transaction) async {
    final doc = await transaction.get(rolloutRef);
    final currentData = doc.data() ?? {};
    
    final history = List<Map<String, dynamic>>.from(
      currentData['rolloutHistory'] ?? []
    );
    
    // Ajouter à l'historique
    history.add({
      'percentage': newPercentage,
      'timestamp': FieldValue.serverTimestamp(),
      'reason': reason,
      'previousPercentage': currentData['pricing_v2_user_percentage'] ?? 0,
    });
    
    // Mettre à jour
    transaction.update(rolloutRef, {
      'pricing_v2_user_percentage': newPercentage,
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedBy': getCurrentAdminEmail(),
      'rolloutHistory': history,
    });
  });
  
  print('Rollout percentage updated to $newPercentage%: $reason');
}
```

### Rollback d'Urgence

```dart
Future<void> emergencyRollback(String reason) async {
  final firestore = FirebaseFirestore.instance;
  
  // Désactiver immédiatement le nouveau système
  await firestore.collection('app_settings').doc('pricing_config_v2').update({
    'enableNewPricingSystem': false,
    'lastUpdated': FieldValue.serverTimestamp(),
    'emergencyRollback': true,
    'rollbackReason': reason,
  });
  
  // Mettre le rollout à 0%
  await updateRolloutPercentage(0, 'EMERGENCY ROLLBACK: $reason');
  
  // Enregistrer dans l'historique d'urgence
  await firestore.collection('app_settings').doc('pricing_emergency_config').update({
    'lastRollback': FieldValue.serverTimestamp(),
    'rollbackHistory': FieldValue.arrayUnion([{
      'timestamp': FieldValue.serverTimestamp(),
      'reason': reason,
      'triggeredBy': getCurrentAdminEmail(),
    }]),
  });
  
  // Invalider tous les caches
  PricingSystemSelector.resetService();
  PricingConfigService.clearCache();
  
  print('EMERGENCY ROLLBACK EXECUTED: $reason');
}
```

## 📋 Checklist de Configuration

### Avant le Déploiement

- [ ] Document `pricing_config_v2` créé avec valeurs correctes
- [ ] Document `rollout_config` initialisé à 0%
- [ ] Document `pricing_emergency_config` configuré
- [ ] Règles de sécurité Firestore déployées
- [ ] Validation de configuration réussie
- [ ] Permissions admin configurées
- [ ] Monitoring des collections activé

### Pendant le Rollout

- [ ] Surveiller les métriques dans `rollout_metrics`
- [ ] Vérifier les erreurs dans les logs Firestore
- [ ] Contrôler l'évolution du pourcentage
- [ ] Tester les rollbacks en environnement de test
- [ ] Documenter chaque changement de pourcentage

### Après la Migration

- [ ] Nettoyer les documents temporaires
- [ ] Archiver l'historique de rollout
- [ ] Optimiser les règles de sécurité
- [ ] Mettre à jour la documentation
- [ ] Former l'équipe sur la maintenance

## 🔍 Monitoring et Alertes

### Requêtes de Monitoring

```dart
// Surveiller le taux d'erreur
Future<double> getErrorRate() async {
  final firestore = FirebaseFirestore.instance;
  final oneDayAgo = DateTime.now().subtract(Duration(days: 1));
  
  final snapshot = await firestore
      .collection('rollout_metrics')
      .where('timestamp', isGreaterThan: oneDayAgo)
      .get();
  
  if (snapshot.docs.isEmpty) return 0.0;
  
  final errorCount = snapshot.docs
      .where((doc) => doc.data()['hadError'] == true)
      .length;
  
  return (errorCount / snapshot.docs.length) * 100;
}

// Surveiller les temps de calcul
Future<double> getAverageCalculationTime() async {
  final firestore = FirebaseFirestore.instance;
  final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
  
  final snapshot = await firestore
      .collection('rollout_metrics')
      .where('timestamp', isGreaterThan: oneHourAgo)
      .where('pricingVersion', isEqualTo: 'v2.0')
      .get();
  
  if (snapshot.docs.isEmpty) return 0.0;
  
  final times = snapshot.docs
      .map((doc) => doc.data()['calculationTime'] as double)
      .toList();
  
  return times.reduce((a, b) => a + b) / times.length;
}
```

### Configuration d'Alertes

```dart
class FirestoreAlerts {
  static Future<void> checkAndAlert() async {
    final errorRate = await getErrorRate();
    final avgTime = await getAverageCalculationTime();
    
    // Alerte taux d'erreur
    if (errorRate > 2.0) {
      await sendAlert('HIGH_ERROR_RATE', 
          'Error rate: ${errorRate.toStringAsFixed(2)}%');
    }
    
    // Alerte performance
    if (avgTime > 300) {
      await sendAlert('SLOW_CALCULATIONS', 
          'Avg time: ${avgTime.toStringAsFixed(0)}ms');
    }
  }
  
  static Future<void> sendAlert(String type, String message) async {
    // Implémentation d'envoi d'alerte (email, Slack, etc.)
    print('ALERT [$type]: $message');
  }
}
```

---

**Documentation mise à jour** : 28 juillet 2025  
**Version** : 1.0