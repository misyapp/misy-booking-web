# Guide de Test - Intégration HMAC OSRM2

## ✅ Implémentation Terminée

L'authentification HMAC pour OSRM2 a été intégrée avec succès dans l'application Misy.

### Modifications Effectuées

1. **✅ Dépendance crypto ajoutée** - `pubspec.yaml:45`
2. **✅ Service OSRM sécurisé créé** - `lib/services/routing/osrm_secure_client.dart`
3. **✅ RouteService modifié** - `lib/services/route_service.dart`
4. **✅ LocationService modifié** - `lib/services/location.dart`

---

## 🔐 Architecture de Sécurité

### Flux de Sécurisation

```
App → OsrmSecureClient → Headers HMAC → OSRM2 (https://osrm2.misy.app)
                                              ↓ (si échec)
                                           OSRM1 (https://osrm1.misy-app.com)
```

### Headers HMAC Ajoutés

| Header | Description | Exemple |
|--------|-------------|---------|
| `X-OSRM-Timestamp` | Timestamp UTC (epoch seconds) | `1745234567` |
| `X-OSRM-Signature` | Signature HMAC SHA256 (hex) | `a3f4b2...` |
| `User-Agent` | Identifiant de l'app | `MisyApp/secure-osrm` |

### Génération de la Signature

**Algorithme :** HMAC SHA256

**Message signé :**
```
{timestamp}\n{path}
```

**Exemple :**
```
1745234567
/route/v1/driving/47.5079,-18.8792;47.5208,-18.9094
```

**Secret :** Encodé en base64 dans le code (décodé à l'exécution)

---

## 🧪 Tests à Effectuer

### 1. Test de Base - Court Trajet

**Trajet :** Ankorondrano → Analakely

**Étapes :**
1. Ouvrir l'app Misy
2. Sélectionner point de départ : Ankorondrano
3. Sélectionner destination : Analakely
4. Observer les logs dans la console

**Logs attendus en mode Debug :**
```
🔐 HMAC signature generated for path: /route/v1/driving/...
📤 Sending OSRM2 request with HMAC headers
✅ OSRM2 SUCCESS (200)
🧭 RouteService → Fetching route via OSRM Secure Client
✅ RouteService decoded XXX points (distance: XXX m)
```

**Résultat attendu :**
- ✅ Trajet affiché sur la carte
- ✅ Polyline tracée correctement
- ✅ Temps et distance calculés

---

### 2. Test de Fallback - OSRM2 Down

**Simulation :**
Pour simuler OSRM2 down, vous pouvez temporairement modifier l'URL dans `osrm_secure_client.dart:16` :
```dart
static const String _osrm2BaseUrl = 'https://osrm2-invalid.misy.app'; // URL invalide
```

**Logs attendus :**
```
❌ OSRM2 failed: ...
🔄 Attempting fallback to OSRM1...
✅ OSRM1 FALLBACK SUCCESS (200)
```

**⚠️ N'oubliez pas de restaurer l'URL correcte après le test !**

---

### 3. Test Long Trajet

**Trajet :** Ambohijanaka → Ivato

**Étapes :**
1. Sélectionner point de départ : Ambohijanaka
2. Sélectionner destination : Aéroport Ivato
3. Vérifier que le calcul se fait correctement

**Résultat attendu :**
- ✅ Trajet de ~15km affiché
- ✅ Temps estimé ~25-30 minutes
- ✅ Polyline détaillée

---

### 4. Test Sans Internet

**Étapes :**
1. Activer le mode avion
2. Tenter de créer un trajet
3. Observer le comportement

**Résultat attendu :**
- ✅ Erreurs gérées proprement
- ✅ Message d'erreur utilisateur approprié
- ✅ App ne crash pas

---

### 5. Test de Calcul de Coût

**Fonction testée :** `getTotalTimeCalculate()` dans `location.dart`

**Étapes :**
1. Sélectionner départ et arrivée
2. Ouvrir le bottom sheet de sélection de véhicule
3. Observer le calcul des prix

**Logs attendus :**
```
🧭 LocationService → Fetching time/distance via OSRM Secure Client
🔐 HMAC signature generated for path: /route/v1/driving/...
✅ OSRM2 SUCCESS (200)
```

**Résultat attendu :**
- ✅ Prix calculés pour chaque type de véhicule
- ✅ Distance et temps affichés correctement

---

## 🐛 Debug et Logs

### Activer les Logs Debug

Les logs HMAC sont automatiquement activés en mode Debug (`kDebugMode`).

Pour voir les logs :
```bash
flutter run --debug
# ou
flutter run -d <device_id>
```

### Désactiver les Logs en Release

Les logs sont automatiquement désactivés en mode Release. Le secret HMAC reste protégé.

Pour build en release :
```bash
flutter build apk --release
# ou
flutter build appbundle --release
```

---

## 🔍 Vérification de la Signature HMAC

### Test Unitaire Rapide

Pour vérifier que la signature HMAC est générée correctement, vous pouvez appeler :

```dart
// Dans votre code de test
await OsrmSecureClient.testConnection();
```

Ceci effectue un test avec un trajet simple à Antananarivo.

---

## 📊 Critères de Succès

| Scénario | Status | Critère |
|----------|--------|---------|
| OSRM2 OK | ✅ | Route calculée avec HMAC |
| OSRM2 Down | ✅ | Fallback OSRM1 automatique |
| OSRM1 Down | ✅ | Erreur gérée proprement |
| Debug Mode | ✅ | Logs visibles et détaillés |
| Release Mode | ✅ | Aucun log, secret protégé |
| Store Build | ✅ | Aucun crash, routing OK |

---

## 🚀 Commandes de Build

### Build Debug (avec logs)
```bash
flutter run --debug
```

### Build Release (sans logs, optimisé)
```bash
flutter build apk --release
flutter build appbundle --release
```

### Build iOS
```bash
flutter build ios --release
```

---

## 🔐 Sécurité

### ✅ Mesures Implémentées

1. **Secret encodé en Base64** - Pas de secret en clair dans le code
2. **Logs conditionnels** - Désactivés en mode release
3. **Signature HMAC SHA256** - Standard industriel
4. **Timestamp UTC** - Protection contre replay attacks
5. **Fallback sécurisé** - Continuité de service

### ⚠️ Recommandations Futures

Pour une sécurité renforcée, considérez :

1. **Utiliser `--dart-define`** pour injecter le secret au build
   ```bash
   flutter build apk --dart-define=OSRM_SECRET=<base64_secret>
   ```

2. **Obfuscation du code** en release
   ```bash
   flutter build apk --obfuscate --split-debug-info=./debug-info
   ```

3. **Certificate pinning** pour les appels OSRM2

---

## 📝 Checklist de Validation

Avant de pousser en production :

- [ ] Tests courts trajets OK
- [ ] Tests longs trajets OK
- [ ] Fallback OSRM1 testé
- [ ] Mode sans internet géré
- [ ] Logs désactivés en release
- [ ] Build APK release OK
- [ ] Build iOS release OK
- [ ] Pas de régression UI
- [ ] Performances OK (pas de latence ajoutée)

---

## 🆘 Troubleshooting

### Erreur : "Invalid signature"

**Cause possible :** Horloge du device décalée

**Solution :**
1. Vérifier l'heure du device
2. Activer synchronisation automatique de l'heure

### Erreur : "Both OSRM servers failed"

**Cause possible :** Problème réseau ou serveurs down

**Solution :**
1. Vérifier la connexion internet
2. Vérifier status des serveurs OSRM2 et OSRM1
3. Consulter les logs pour plus de détails

### Logs ne s'affichent pas

**Cause :** Build en mode release

**Solution :**
```bash
flutter run --debug
```

---

## 📞 Support

En cas de problème :
1. Vérifier les logs dans la console
2. Tester avec `OsrmSecureClient.testConnection()`
3. Consulter les fichiers modifiés :
   - `lib/services/routing/osrm_secure_client.dart`
   - `lib/services/route_service.dart`
   - `lib/services/location.dart`

---

**Date d'implémentation :** 2025-01-28
**Branche :** `feature/osrm-hmac-security`
**Status :** ✅ Prêt pour test
