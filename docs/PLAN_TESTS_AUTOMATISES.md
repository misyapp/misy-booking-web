# Plan d'Implémentation des Tests Automatisés - Misy Riderapp

**Date de création :** 30 Octobre 2025
**Statut :** 🔴 À implémenter
**Priorité :** CRITIQUE
**Équipe :** Features

---

## 📋 Table des Matières

1. [Problématique Identifiée](#-problématique-identifiée)
2. [Analyse des Risques](#-analyse-des-risques)
3. [Préconisations](#-préconisations)
4. [Plan d'Action Détaillé](#-plan-daction-détaillé)
5. [Guide de Mise en Application](#-guide-de-mise-en-application)
6. [Ressources et Références](#-ressources-et-références)

---

## 🚨 Problématique Identifiée

### État Actuel

**Constat :**
- ✅ Dépendances de test installées dans `pubspec.yaml` (`mockito`, `build_runner`, `integration_test`)
- ❌ **Aucun fichier de test présent** dans le projet
- ❌ Aucune automatisation des tests
- ❌ Tests manuels uniquement

**Impact :**
```
Workflow actuel :
1. Modification du code
2. Test manuel de chaque fonctionnalité (15-30 min)
3. Déploiement avec incertitude
4. Risque de bugs en production sur fonctionnalités critiques

Fonctionnalités à risque élevé :
- Calcul des prix (Pricing V2)
- Paiements mobile money (Airtel, Orange, Telma)
- Gestion du wallet
- Flow de réservation invité
```

### Pourquoi c'est Critique ?

**L'application manipule de l'argent** sans filet de sécurité automatisé :

1. **Pricing System V2** (`lib/services/pricing/pricing_service_v2.dart`)
   - Calculs complexes : surge, trafic, promo codes, frais planification
   - Bug potentiel = client surfacturé/sous-facturé

2. **Payment Gateways** (3 providers : Airtel, Orange, Telma)
   - Transactions financières réelles
   - Bug potentiel = argent perdu ou transaction non enregistrée

3. **Wallet Service** (`lib/services/wallet_service.dart`)
   - Gestion du solde utilisateur
   - Bug potentiel = débits/crédits incorrects

4. **Guest Mode** (nouvelle feature)
   - Conversion invité → utilisateur
   - Bug potentiel = perte de données de réservation

---

## ⚠️ Analyse des Risques

### Matrice de Risques (Sans Tests)

| Composant | Probabilité Bug | Impact | Risque Global |
|-----------|----------------|--------|---------------|
| Pricing V2 | 🟡 Moyen | 🔴 Critique | 🔴 ÉLEVÉ |
| Payment Gateways | 🟡 Moyen | 🔴 Critique | 🔴 ÉLEVÉ |
| Wallet Service | 🟡 Moyen | 🔴 Critique | 🔴 ÉLEVÉ |
| Guest Mode | 🟢 Faible | 🟡 Moyen | 🟡 MOYEN |
| Loyalty System | 🟢 Faible | 🟢 Faible | 🟢 FAIBLE |

### Scénarios de Bugs Réels Possibles

**Scénario 1 : Bug de Pricing**
```
Situation :
- Modification du calcul de surge pricing
- Oubli de cas limite : surge + promo code + heure planifiée
- Bug : surge appliqué 2 fois

Résultat sans tests :
❌ Détecté en production par un client
❌ Client facturé 15 000 Ar au lieu de 8 000 Ar
❌ Plainte client + remboursement + perte de confiance

Résultat avec tests :
✅ Test échoue immédiatement lors du développement
✅ Bug corrigé avant commit
✅ Zéro impact client
```

**Scénario 2 : Bug de Paiement**
```
Situation :
- Modification du provider Orange Money
- Erreur dans la gestion du callback de confirmation
- Bug : paiement validé côté Orange mais non enregistré dans l'app

Résultat sans tests :
❌ Client débité mais course non confirmée
❌ Support client submergé
❌ Remboursement manuel nécessaire
❌ Réputation endommagée

Résultat avec tests :
✅ Test d'intégration détecte l'anomalie
✅ Correction avant déploiement
✅ Zéro transaction perdue
```

---

## 💡 Préconisations

### Stratégie de Test Recommandée

**Approche Progressive en 3 Phases**

#### Phase 1 : Tests Critiques (URGENT - 3 jours) 🔴

**Objectif :** Sécuriser les fonctionnalités financières

**Couverture :**
- ✅ Pricing Service V2 (tests unitaires)
- ✅ Wallet Service (tests unitaires)
- ✅ Payment Gateway Providers (tests avec mocks)

**ROI immédiat :**
- Protection contre bugs financiers
- Confiance dans les calculs de prix
- Détection rapide des régressions

#### Phase 2 : Tests Fonctionnels (Important - 1 semaine) 🟡

**Objectif :** Sécuriser les flows métier

**Couverture :**
- ✅ Booking flow complet (tests d'intégration)
- ✅ Guest mode conversion (tests d'intégration)
- ✅ Loyalty system (tests unitaires)

**ROI :**
- Validation automatique des parcours utilisateur
- Détection des cas limites

#### Phase 3 : Tests UI & Coverage (Nice to have - Progressif) 🟢

**Objectif :** Atteindre 80%+ de couverture

**Couverture :**
- ✅ Widget tests pour bottom sheets
- ✅ Tests pour tous les providers
- ✅ Tests pour tous les services

**ROI long terme :**
- Refactoring sécurisé
- Maintenance facilitée
- Documentation vivante

---

## 📅 Plan d'Action Détaillé

### Phase 1 : Tests Critiques (3 jours - URGENT)

#### Jour 1 : Setup + Pricing Tests

**Matin : Configuration (2h)**
```bash
# 1. Créer la structure de tests
mkdir -p test/services/pricing
mkdir -p test/provider
mkdir -p test/integration
mkdir -p test/helpers

# 2. Créer les fichiers de configuration
touch test/helpers/test_helpers.dart
touch test/helpers/mock_data.dart
```

**Après-midi : Pricing Service V2 (4h)**

Créer : `test/services/pricing/pricing_service_v2_test.dart`

**Tests à implémenter :**
- [ ] Calcul prix de base (distance x tarif)
- [ ] Application surge pricing
- [ ] Périodes de trafic
- [ ] Codes promo (pourcentage et montant fixe)
- [ ] Frais de planification
- [ ] Minimum fare
- [ ] Cas limites (distance 0, prix négatif, etc.)
- [ ] Combinaisons (surge + promo + planification)

**Critères de succès :**
- ✅ Minimum 15 tests écrits
- ✅ Tous les tests passent
- ✅ Couverture > 80% du PricingServiceV2

#### Jour 2 : Wallet & Payment Tests

**Matin : Wallet Service (3h)**

Créer : `test/services/wallet_service_test.dart`

**Tests à implémenter :**
- [ ] Crédit de wallet
- [ ] Débit de wallet
- [ ] Solde insuffisant
- [ ] Cache (15 min de validité)
- [ ] Transactions concurrentes
- [ ] Gestion d'erreurs Firestore

**Après-midi : Payment Gateway Providers (3h)**

Créer : `test/provider/payment_gateway_provider_test.dart`

**Tests à implémenter :**
- [ ] Initiation de paiement
- [ ] Callback succès
- [ ] Callback échec
- [ ] Timeout
- [ ] Retry logic
- [ ] Enregistrement transaction

#### Jour 3 : Tests d'Intégration

**Journée complète : Booking Flow (6h)**

Créer : `test/integration/booking_flow_test.dart`

**Scénarios à tester :**
- [ ] Réservation complète (utilisateur authentifié)
- [ ] Réservation invité → authentification
- [ ] Application promo code
- [ ] Paiement wallet
- [ ] Paiement mobile money
- [ ] Annulation de réservation

---

### Phase 2 : Tests Fonctionnels (1 semaine)

#### Semaine 1 : Coverage des Providers & Services

**Lundi-Mardi : Guest Mode**
- `test/provider/guest_session_provider_test.dart`
- `test/services/guest_storage_service_test.dart`

**Mercredi-Jeudi : Loyalty System**
- `test/provider/loyalty_chest_provider_test.dart`
- `test/services/loyalty_service_test.dart`

**Vendredi : Other Critical Providers**
- `test/provider/trip_provider_test.dart`
- `test/provider/auth_provider_test.dart`

---

### Phase 3 : Tests UI & Couverture Complète (Progressif)

**À planifier selon disponibilité**

---

## 🛠️ Guide de Mise en Application

### Prompt pour l'Agent IA (Claude Code)

```markdown
# PROMPT : Implémentation Tests Automatisés - Phase 1

## Contexte
Je travaille sur l'application Misy (ride-hailing pour Madagascar).
Le projet n'a actuellement aucun test automatisé.

## Objectif
Implémenter les tests critiques pour les fonctionnalités financières
selon le plan défini dans `docs/PLAN_TESTS_AUTOMATISES.md`.

## Tâche Immédiate

### Phase 1 - Jour 1 : Pricing Service V2

**1. Setup Initial**
Créer la structure de tests et les helpers nécessaires :
- `test/helpers/test_helpers.dart` : Fonctions utilitaires
- `test/helpers/mock_data.dart` : Données de test réutilisables

**2. Tests Pricing Service V2**
Créer `test/services/pricing/pricing_service_v2_test.dart`

Implémenter des tests unitaires pour :
- Calcul de prix de base
- Surge pricing
- Périodes de trafic
- Codes promo
- Frais de planification
- Cas limites et combinaisons

**3. Configuration Mock**
Utiliser Mockito pour mocker :
- Firestore (PricingConfigService)
- Données de configuration (GlobalSettingsModal)

**Contraintes :**
- Suivre les conventions Dart/Flutter
- Utiliser `mockito` et `build_runner` déjà configurés
- Minimum 15 tests avec coverage > 80%
- Tous les tests doivent passer

**Fichier source à tester :**
`lib/services/pricing/pricing_service_v2.dart`

**Questions à clarifier :**
- Structure exacte de PricingConfigV2 ?
- Dépendances de PricingServiceV2 à mocker ?

Commence par lire le fichier source et propose une structure de tests.
```

---

### Checklist de Mise en Œuvre

**Avant de Commencer**
- [ ] Lire ce document entièrement
- [ ] Bloquer 3 jours dans le planning
- [ ] Préparer environnement de développement
- [ ] Vérifier que `fvm flutter test` fonctionne

**Phase 1 - Jour 1**
- [ ] Créer structure de dossiers `test/`
- [ ] Créer helpers et mock data
- [ ] Implémenter tests Pricing Service V2
- [ ] Exécuter tests : `fvm flutter test test/services/pricing/`
- [ ] Atteindre 80%+ coverage
- [ ] Commit : `test: add pricing service v2 unit tests`

**Phase 1 - Jour 2**
- [ ] Implémenter tests Wallet Service
- [ ] Implémenter tests Payment Providers
- [ ] Exécuter tous les tests : `fvm flutter test`
- [ ] Commit : `test: add wallet and payment gateway tests`

**Phase 1 - Jour 3**
- [ ] Implémenter tests d'intégration booking flow
- [ ] Exécuter suite complète
- [ ] Générer rapport de couverture
- [ ] Commit : `test: add booking flow integration tests`
- [ ] Mettre à jour ce document avec statut ✅

**Après Phase 1**
- [ ] Documenter learnings
- [ ] Planifier Phase 2
- [ ] Configurer CI/CD (optionnel)

---

## 📚 Ressources et Références

### Documentation Officielle

**Flutter Testing**
- Guide officiel : https://docs.flutter.dev/testing
- Unit tests : https://docs.flutter.dev/cookbook/testing/unit/introduction
- Integration tests : https://docs.flutter.dev/testing/integration-tests
- Mocking : https://docs.flutter.dev/cookbook/testing/unit/mocking

**Packages**
- Mockito : https://pub.dev/packages/mockito
- Integration Test : https://pub.dev/packages/integration_test
- Flutter Test : https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html

### Exemples de Code

**Structure de Test Unitaire**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Générer les mocks avec build_runner
@GenerateMocks([FirestoreServices, PricingConfigService])
import 'pricing_service_v2_test.mocks.dart';

void main() {
  group('PricingServiceV2', () {
    late PricingServiceV2 pricingService;
    late MockPricingConfigService mockConfigService;

    setUp(() {
      mockConfigService = MockPricingConfigService();
      pricingService = PricingServiceV2(configService: mockConfigService);
    });

    test('calcule le prix de base correctement', () {
      // Arrange
      final booking = createTestBooking(distance: 5.0);
      when(mockConfigService.getBasePricePerKm())
          .thenReturn(1000.0);

      // Act
      final result = pricingService.calculatePrice(booking);

      // Assert
      expect(result.basePrice, equals(5000.0));
    });
  });
}
```

**Structure de Test d'Intégration**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Booking Flow', () {
    testWidgets('utilisateur peut réserver une course complète',
        (WidgetTester tester) async {
      // Lancer l'app
      await tester.pumpWidget(MyApp());

      // Sélectionner destination
      await tester.tap(find.byKey(Key('destination_button')));
      await tester.pumpAndSettle();

      // Vérifier que le prix s'affiche
      expect(find.text('5 000 Ar'), findsOneWidget);
    });
  });
}
```

### Commandes Utiles

```bash
# Exécuter tous les tests
fvm flutter test

# Exécuter un fichier spécifique
fvm flutter test test/services/pricing/pricing_service_v2_test.dart

# Exécuter avec couverture
fvm flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Générer les mocks
fvm flutter pub run build_runner build

# Watch mode (re-run sur modification)
fvm flutter test --watch
```

---

## 📊 Métriques de Succès

### Phase 1 Terminée Avec Succès Si :

- ✅ **15+ tests** pour Pricing Service V2
- ✅ **10+ tests** pour Wallet Service
- ✅ **10+ tests** pour Payment Providers
- ✅ **5+ scénarios** d'intégration pour Booking Flow
- ✅ **100% des tests passent** (`fvm flutter test` vert)
- ✅ **Coverage > 70%** sur les composants critiques
- ✅ **Temps d'exécution < 2 minutes** pour la suite complète

### Indicateurs de Qualité

**Couverture de Code (Coverage)**
```
Cible Phase 1 :
- PricingServiceV2 : > 80%
- WalletService : > 75%
- PaymentProviders : > 70%
- Global : > 40% (normal au début)
```

**Vitesse d'Exécution**
```
Suite de tests Phase 1 : < 2 minutes
Tests unitaires : < 30 secondes
Tests d'intégration : < 1.5 minutes
```

---

## 🔄 Suivi et Mise à Jour

### Historique

| Date | Action | Statut |
|------|--------|--------|
| 30/10/2025 | Création du document | 📝 Planifié |
| ___ | Début Phase 1 | ⏳ En attente |
| ___ | Fin Phase 1 | ⏳ En attente |
| ___ | Début Phase 2 | ⏳ En attente |

### Prochaines Étapes

**Immédiat (Cette Semaine) :**
1. [ ] Valider ce plan avec l'équipe
2. [ ] Bloquer 3 jours dans le planning
3. [ ] Lancer Phase 1

**Court Terme (Ce Mois) :**
4. [ ] Compléter Phase 1
5. [ ] Planifier Phase 2
6. [ ] Former l'équipe aux tests

**Moyen Terme (Prochain Sprint) :**
7. [ ] Compléter Phase 2
8. [ ] Intégrer tests dans workflow Git
9. [ ] Configurer CI/CD

---

## 💬 Questions & Support

### Questions Fréquentes

**Q : Combien de temps ça va prendre vraiment ?**
R : Phase 1 = 3 jours pleins. Mais l'investissement se rentabilise dès la première régression évitée.

**Q : On peut faire ça progressivement en background ?**
R : Oui, mais les fonctionnalités financières (pricing, payments) sont URGENTES. Le reste peut être progressif.

**Q : Qui doit écrire les tests ?**
R : Équipe Features. L'agent IA (Claude Code) peut aider à générer la structure de base.

**Q : Ça va ralentir le développement ?**
R : Court terme : oui (+20% de temps). Long terme: non (économie sur le debug et la maintenance).

### Besoin d'Aide ?

**Utiliser l'agent IA :**
```
Copier-coller le "Prompt pour l'Agent IA" ci-dessus dans Claude Code
L'agent peut générer la structure de tests et les premiers tests
```

**Ressources externes :**
- Documentation Flutter Testing (officielle)
- Tutoriels sur YouTube : "Flutter Testing Tutorial"
- Stack Overflow : Tag `flutter-test`

---

## ✅ Validation

**Ce plan est validé et prêt à être exécuté.**

Pour démarrer l'implémentation :
1. Lire la section "Guide de Mise en Application"
2. Copier le "Prompt pour l'Agent IA" dans Claude Code
3. Suivre la checklist jour par jour

**Fichier de suivi associé :** À créer → `SUIVI_TESTS_AUTOMATISES.md`

---

**Document Version :** 1.0
**Dernière Mise à Jour :** 30 Octobre 2025
**Responsable :** Équipe Features
**Référence :** `ARCHITECTURE_TECHNIQUE.md`, `COLLABORATION_WORKFLOW.md`
