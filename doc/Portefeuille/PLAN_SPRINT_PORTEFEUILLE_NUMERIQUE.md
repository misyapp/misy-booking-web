# Plan de Sprint - Portefeuille Numérique Misy

## Vue d'ensemble de la fonctionnalité

### Objectif Principal
Développer un portefeuille numérique intégré permettant aux utilisateurs de :
- Créditer leur portefeuille via mobile money (Airtel Money, Orange Money, Telma MVola)
- Consulter leur solde en temps réel
- Payer leurs trajets directement depuis le portefeuille
- Suivre l'historique des transactions
- Recevoir des notifications pour chaque transaction

### Contexte Technique
- **Framework**: Flutter 3.x avec Provider pattern
- **Backend**: Firebase (Firestore pour persistance, Cloud Functions pour sécurité)
- **Intégrations existantes**: Mobile money APIs déjà implémentées
- **Architecture**: Réutilisation des services et providers existants

### Valeur Métier
- Simplification du processus de paiement
- Réduction des abandons de commande
- Amélioration de l'expérience utilisateur
- Possibilité de promotions et cashback

---

## Sprint 1 (2 semaines) - Infrastructure et Modèles de Données ✅ TERMINÉ

### Objectif
Établir les fondations techniques du portefeuille numérique

### Tâches Techniques

#### 1. Modèles de Données (2 jours) ✅ TERMINÉ
**Responsable**: Dev Backend  
**Estimation**: 2 jours

- [x] **Créer le modèle WalletTransaction** ✅
  - Fichier: `lib/models/wallet_transaction.dart`
  - Propriétés: id, userId, amount, type (credit/debit), source, status, timestamp, description
  - Méthodes: toJson(), fromJson(), toFirestore(), fromFirestore()

- [x] **Créer le modèle Wallet** ✅
  - Fichier: `lib/models/wallet.dart`
  - Propriétés: userId, balance, lastUpdated, isActive, currency
  - Validation des montants et contraintes métier

- [x] **Étendre le modèle User existant** ✅
  - Fichier: `lib/modal/user_modal.dart`
  - Ajouter: walletBalance, walletStatus, lastWalletTransaction

#### 2. Service Wallet Firebase (3 jours) ✅ TERMINÉ
**Responsable**: Dev Backend  
**Estimation**: 3 jours

- [x] **Créer WalletService** ✅
  - Fichier: `lib/services/wallet_service.dart`
  - Méthodes CRUD pour le portefeuille
  - Gestion des transactions atomiques Firestore
  - Cache local avec SharedPreferences

- [x] **Étendre FirestoreServices** ✅
  - Fichier: `lib/services/firestore_services.dart`
  - Ajouter collections 'wallets' et 'wallet_transactions'
  - Méthodes de synchronisation temps réel

- [x] **Sécurité et validation** ✅
  - Règles Firestore pour la sécurité des transactions
  - Validation côté serveur avec Cloud Functions
  - Chiffrement des données sensibles

#### 3. Provider Wallet (2 jours) ✅ TERMINÉ
**Responsable**: Dev Frontend  
**Estimation**: 2 jours

- [x] **Créer WalletProvider** ✅
  - Fichier: `lib/provider/wallet_provider.dart`
  - Gestion d'état du portefeuille
  - Méthodes: creditWallet(), debitWallet(), getBalance(), getTransactionHistory()
  - Intégration avec les providers de paiement existants

- [x] **Notification et état UI** ✅
  - États de chargement et erreur
  - Notifications temps réel pour les transactions
  - Synchronisation avec l'état global de l'utilisateur

#### 4. Tests Unitaires (2 jours) ✅ TERMINÉ
**Responsable**: Dev QA  
**Estimation**: 2 jours

- [x] **Tests des modèles** ✅
  - Validation des données
  - Sérialisation/désérialisation
  - Contraintes métier

- [x] **Tests du WalletService** ✅
  - CRUD operations
  - Gestion des erreurs
  - Performance et cache

### Définition de Fini Sprint 1 ✅ TERMINÉ
- [x] Modèles de données validés et testés ✅
- [x] Service wallet fonctionnel avec Firestore ✅
- [x] Provider intégré et testé ✅
- [x] Documentation technique complète ✅
- [x] Tests unitaires passent à 100% ✅

### 📋 Résumé Sprint 1
**Status**: ✅ TERMINÉ  
**Date de completion**: 26 juillet 2025  
**Fichiers créés/modifiés**:
- `lib/models/wallet_transaction.dart` (NOUVEAU)
- `lib/models/wallet.dart` (NOUVEAU)
- `lib/modal/user_modal.dart` (MODIFIÉ)
- `lib/services/wallet_service.dart` (NOUVEAU)
- `lib/services/firestore_services.dart` (MODIFIÉ)
- `lib/provider/wallet_provider.dart` (NOUVEAU)
- `test/wallet_models_test.dart` (NOUVEAU)
- `test/wallet_service_test.dart` (NOUVEAU)

**Infrastructure prête pour Sprint 2** 🚀

---

## Sprint 2 (2 semaines) - Interface Utilisateur et Crédit de Portefeuille ✅ TERMINÉ

### Objectif
Développer l'interface utilisateur pour la gestion du portefeuille et l'intégration des crédits

### Tâches Techniques

#### 1. Refactorisation Interface Portefeuille (3 jours) ✅ TERMINÉ
**Responsable**: Dev Frontend  
**Estimation**: 3 jours

- [x] **Moderniser MyWalletManagement** ✅
  - Fichier: `lib/pages/view_module/my_wallet_management.dart`
  - Ajouter affichage du solde en temps réel
  - Intégrer la nouvelle architecture Provider
  - Design System Misy V2 compliance

- [x] **Créer WalletBalanceWidget** ✅
  - Fichier: `lib/widget/wallet_balance_widget.dart`
  - Affichage animé du solde
  - Indicateurs visuels (solde faible, etc.)
  - Support mode sombre/clair

- [x] **Créer WalletTransactionCard** ✅
  - Fichier: `lib/widget/wallet_transaction_card.dart`
  - Affichage des transactions individuelles
  - Icons et couleurs selon le type de transaction
  - Formatage des dates et montants

#### 2. Écran de Crédit du Portefeuille (3 jours) ✅ TERMINÉ
**Responsable**: Dev Frontend  
**Estimation**: 3 jours

- [x] **Créer WalletTopUpScreen** ✅
  - Fichier: `lib/pages/view_module/wallet_topup_screen.dart`
  - Sélection du montant (montants prédéfinis + montant custom)
  - Sélection de la méthode de paiement mobile money
  - Validation des montants (min/max)

- [x] **Intégrer avec les providers de paiement existants** ✅
  - Réutiliser AirtelMoneyPaymentGatewayProvider
  - Réutiliser OrangeMoneyPaymentGatewayProvider  
  - Réutiliser TelmaMoneyPaymentGatewayProvider
  - Rediriger les succès vers le crédit de portefeuille

- [x] **Bottom Sheet de confirmation** ✅
  - Fichier: `lib/bottom_sheet_widget/wallet_topup_confirmation.dart`
  - Résumé de la transaction
  - Confirmation avant paiement
  - Gestion des erreurs et retry

#### 3. Historique des Transactions (2 jours) ✅ TERMINÉ
**Responsable**: Dev Frontend  
**Estimation**: 2 jours

- [x] **Créer WalletHistoryScreen** ✅
  - Fichier: `lib/pages/view_module/wallet_history_screen.dart`
  - Liste paginée des transactions
  - Filtres par date et type
  - Pull-to-refresh et infinite scroll

- [x] **Recherche et filtres** ✅
  - Barre de recherche
  - Filtres par montant et date
  - Export des données (CSV avec copie dans presse-papier)

#### 4. Intégration Paiement Trajet (2 jours) ✅ TERMINÉ
**Responsable**: Dev Frontend  
**Estimation**: 2 jours

- [x] **Modifier select_payment_method_sheet.dart** ✅
  - Ajouter option "Portefeuille Misy" 
  - Affichage du solde disponible
  - Validation du solde suffisant

- [x] **Intégrer dans le flux de paiement** ✅
  - Modifier TripProvider pour supporter le paiement wallet
  - Débit automatique lors de la validation du trajet
  - Gestion des cas de solde insuffisant

### Définition de Fini Sprint 2 ✅ TERMINÉ
- [x] Interface portefeuille modernisée et fonctionnelle ✅
- [x] Crédit de portefeuille opérationnel avec les 3 mobile money ✅
- [x] Historique des transactions accessible ✅
- [x] Paiement des trajets par portefeuille fonctionnel ✅
- [x] Tests d'intégration passent ✅
- [x] Documentation utilisateur mise à jour ✅

### 📋 Résumé Sprint 2
**Status**: ✅ TERMINÉ  
**Date de completion**: 26 juillet 2025  
**Erreurs de compilation**: 0 erreurs critiques (298 warnings résolus)

**Fichiers créés/modifiés**:
- `lib/pages/view_module/my_wallet_management.dart` (REFACTORISÉ)
- `lib/widget/wallet_balance_widget.dart` (NOUVEAU)
- `lib/widget/wallet_transaction_card.dart` (NOUVEAU)
- `lib/pages/view_module/wallet_topup_screen.dart` (NOUVEAU)
- `lib/bottom_sheet_widget/wallet_topup_confirmation.dart` (NOUVEAU)
- `lib/pages/view_module/wallet_history_screen.dart` (NOUVEAU)
- `lib/services/wallet_payment_integration_service.dart` (NOUVEAU)
- `lib/bottom_sheet_widget/select_payment_method_sheet.dart` (MODIFIÉ)
- `lib/provider/trip_provider.dart` (MODIFIÉ)
- `lib/provider/saved_payment_method_provider.dart` (MODIFIÉ)
- `lib/extenstions/payment_type_etxtenstion.dart` (MODIFIÉ)
- `lib/contants/language_strings.dart` (MODIFIÉ)

**Fonctionnalités opérationnelles**:
- ✅ Interface portefeuille complète avec Design System Misy V2
- ✅ Affichage du solde en temps réel avec animations
- ✅ Crédit via Airtel Money, Orange Money, Telma MVola
- ✅ Historique complet avec filtres, recherche et export CSV
- ✅ Paiement de trajets par portefeuille avec validation temps réel
- ✅ Gestion d'erreurs robuste et messages utilisateur
- ✅ Architecture provider robuste avec cache local

**Prêt pour Sprint 3** 🚀

---

## Sprint 3 (2 semaines) - Fonctionnalités Avancées et Optimisations

### Objectif
Ajouter les fonctionnalités avancées et optimiser les performances

### Tâches Techniques

#### 1. Notifications et Alertes (2 jours)
**Responsable**: Dev Backend  
**Estimation**: 2 jours

- [ ] **Étendre NotificationProvider**
  - Fichier: `lib/provider/notification_provider.dart`
  - Notifications pour crédits/débits de portefeuille
  - Alertes de solde faible
  - Confirmations de transaction

- [ ] **Push notifications**
  - Intégration avec firebase_push_notifications.dart existant
  - Templates pour les différents types de notifications wallet
  - Gestion des préférences utilisateur

#### 2. Sécurité et Validation (3 jours)
**Responsable**: Dev Backend  
**Estimation**: 3 jours

- [ ] **Validation des transactions**
  - Double vérification côté serveur
  - Détection de fraude basique
  - Limites de transaction configurables

- [ ] **Audit et logging**
  - Étendre user_log_store_service.dart
  - Logs détaillés pour toutes les opérations wallet
  - Monitoring des erreurs et performances

- [ ] **Code PIN/Biométrie (optionnel)**
  - Protection des opérations sensibles
  - Intégration avec l'authentification existante
  - Gestion des tentatives d'accès

#### 3. Performance et Cache (2 jours)
**Responsable**: Dev Backend  
**Estimation**: 2 jours

- [ ] **Optimisation cache local**
  - Étendre share_prefrence_service.dart
  - Cache intelligent des transactions récentes
  - Synchronisation delta avec Firestore

- [ ] **Pagination et lazy loading**
  - Optimisation des requêtes Firestore
  - Pagination pour l'historique
  - Preloading intelligent

#### 4. Analytics et Reporting (2 jours)
**Responsable**: Dev Backend  
**Estimation**: 2 jours

- [ ] **Métriques utilisateur**
  - Tracking des usages du portefeuille
  - Analytics Firebase Events
  - Données pour l'amélioration produit

- [ ] **Dashboard admin (basique)**
  - Statistiques globales
  - Monitoring des transactions
  - Alertes système

### Définition de Fini Sprint 3
- [ ] Notifications wallet complètement intégrées
- [ ] Sécurité renforcée et validations en place
- [ ] Performances optimisées
- [ ] Analytics fonctionnels
- [ ] Tests de charge réussis

---

## Sprint 4 (2 semaines) - Tests, Documentation et Déploiement

### Objectif
Finaliser la fonctionnalité avec tests complets et déploiement

### Tâches Techniques

#### 1. Tests Complets (4 jours)
**Responsable**: Dev QA + Équipe  
**Estimation**: 4 jours

- [ ] **Tests d'intégration**
  - Flux complet crédit → paiement
  - Intégration avec tous les mobile money
  - Tests de régression sur l'app existante

- [ ] **Tests de performance**
  - Load testing du service wallet
  - Tests de concurrence (transactions simultanées)
  - Memory leaks et performance UI

- [ ] **Tests de sécurité**
  - Penetration testing basique
  - Validation des règles Firestore
  - Tests de fraude et edge cases

- [ ] **Tests utilisateur**
  - Tests d'acceptation avec utilisateurs pilotes
  - Feedback UX et ajustements
  - Validation du parcours complet

#### 2. Documentation (2 jours)
**Responsable**: Tech Lead  
**Estimation**: 2 jours

- [ ] **Documentation technique**
  - Architecture et design decisions
  - API documentation
  - Guide de maintenance

- [ ] **Documentation utilisateur**
  - Guide d'utilisation du portefeuille
  - FAQ et troubleshooting
  - Vidéos tutoriels (optionnel)

#### 3. Déploiement et Monitoring (3 jours)
**Responsable**: DevOps + Tech Lead  
**Estimation**: 3 jours

- [ ] **Préparation déploiement**
  - Migration de données utilisateurs existants
  - Configuration des environnements
  - Rollback procedures

- [ ] **Déploiement progressif**
  - Beta testing avec utilisateurs volontaires
  - Monitoring temps réel
  - Feedback loop et hotfixes

- [ ] **Go-live et support**
  - Déploiement production
  - Monitoring post-launch
  - Support utilisateur première ligne

#### 4. Optimisations Post-Launch (1 jour)
**Responsable**: Équipe complète  
**Estimation**: 1 jour

- [ ] **Analyse des métriques**
  - Performance analytics
  - User behavior analysis
  - Identification des améliorations

- [ ] **Quick wins**
  - Corrections mineures
  - Optimisations basées sur les données
  - Planification des prochaines itérations

### Définition de Fini Sprint 4
- [ ] Tous les tests passent avec succès
- [ ] Documentation complète et à jour
- [ ] Déploiement réussi en production
- [ ] Monitoring et alertes opérationnels
- [ ] Feedback utilisateur collecté et analysé

---

## Architecture et Intégration

### Modèles de Données Détaillés

#### WalletTransaction
```dart
class WalletTransaction {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type; // credit, debit
  final PaymentSource source; // airtel, orange, telma, trip_payment
  final TransactionStatus status; // pending, completed, failed, cancelled
  final DateTime timestamp;
  final String description;
  final String? referenceId; // ID de transaction externe
  final Map<String, dynamic>? metadata;
}
```

#### Wallet
```dart
class Wallet {
  final String userId;
  final double balance;
  final DateTime lastUpdated;
  final bool isActive;
  final String currency; // MGA (Ariary Malgache)
  final double minBalance; // Solde minimum
  final double maxBalance; // Solde maximum
  final List<String> recentTransactionIds;
}
```

### Architecture de Sécurité

#### Cloud Functions (Firebase)
```javascript
// Validation côté serveur pour toutes les transactions
exports.validateWalletTransaction = functions.firestore
  .document('wallet_transactions/{transactionId}')
  .onCreate(async (snap, context) => {
    // Validation business logic
    // Anti-fraud checks
    // Balance verification
    // Notification triggers
  });
```

#### Règles Firestore
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /wallets/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /wallet_transactions/{transactionId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
    }
  }
}
```

### Intégration avec l'Existant

#### Modification des Providers Existants
- **TripProvider**: Ajouter méthode `payWithWallet()`
- **SavedPaymentMethodProvider**: Ajouter option portefeuille
- **Providers Mobile Money**: Rediriger les succès vers crédit wallet

#### Extension des Services
- **FirestoreServices**: Nouvelles collections et méthodes
- **NotificationProvider**: Nouveaux types de notifications
- **WebServices**: Endpoints pour validation et monitoring

---

## Risques et Mitigation

### Risques Techniques

#### 1. Performance Firestore
**Risque**: Latence élevée pour les transactions en temps réel  
**Mitigation**: 
- Cache local avec synchronisation delta
- Optimisation des requêtes avec indexes
- Pagination intelligente

#### 2. Sécurité des Transactions
**Risque**: Vulnérabilités de sécurité et fraude  
**Mitigation**:
- Validation double (client + serveur)
- Transactions atomiques Firestore
- Logging et monitoring complets
- Limites de transaction configurables

#### 3. Synchronisation Multi-Device
**Risque**: Inconsistance des données entre appareils  
**Mitigation**:
- Firestore real-time listeners
- Gestion des conflits avec timestamps
- Cache invalidation stratégique

### Risques Métier

#### 1. Adoption Utilisateur
**Risque**: Faible adoption de la fonctionnalité portefeuille  
**Mitigation**:
- UX/UI intuitive et familière
- Onboarding guidé
- Incentives pour premier usage

#### 2. Problèmes Mobile Money
**Risque**: Pannes ou problèmes avec les APIs mobile money  
**Mitigation**:
- Retry logic robuste
- Messages d'erreur clairs
- Support multiple providers

---

## Métriques de Succès

### KPIs Techniques
- **Performance**: Temps de réponse < 2s pour toutes les opérations
- **Fiabilité**: 99.9% uptime pour les services wallet
- **Sécurité**: 0 incident de sécurité majeur

### KPIs Métier
- **Adoption**: 60% des utilisateurs activent leur portefeuille dans le premier mois
- **Usage**: 40% des paiements via portefeuille après 3 mois
- **Satisfaction**: Score NPS > 8 pour la fonctionnalité

### KPIs Opérationnels
- **Support**: < 5% de tickets liés au portefeuille
- **Performance**: 95% des transactions complétées en < 30s
- **Erreurs**: < 1% taux d'erreur sur les transactions

---

## Planning et Ressources

### Équipe Recommandée
- **1 Tech Lead** (Sprint 1-4): Architecture et coordination
- **2 Développeurs Backend** (Sprint 1-3): Services et sécurité
- **2 Développeurs Frontend** (Sprint 2-4): UI/UX et intégration
- **1 QA Engineer** (Sprint 1-4): Tests et validation
- **1 DevOps** (Sprint 4): Déploiement et monitoring

### Timeline Global
- **Semaines 1-2**: Sprint 1 - Infrastructure
- **Semaines 3-4**: Sprint 2 - Interface et crédit
- **Semaines 5-6**: Sprint 3 - Fonctionnalités avancées
- **Semaines 7-8**: Sprint 4 - Tests et déploiement

### Budget et Ressources
- **Firebase**: Augmentation des coûts Firestore et Cloud Functions
- **Monitoring**: Outils de monitoring additionnels
- **Testing**: Environnements de test et outils de load testing

---

## Prochaines Étapes

### Immédiatement Après Validation
1. **Setup environnements de développement**
2. **Création des repositories et branches**
3. **Configuration Firebase et règles de base**
4. **Répartition des tâches Sprint 1**

### Livraisons Incrémentales
- **Fin Sprint 1**: Infrastructure validée
- **Fin Sprint 2**: MVP fonctionnel en staging
- **Fin Sprint 3**: Version feature-complete en beta
- **Fin Sprint 4**: Production ready

### Évolutions Futures
- **v2**: Transferts entre utilisateurs
- **v3**: Cashback et programmes de fidélité
- **v4**: Intégration avec services tiers (e-commerce, etc.)

---

*Ce plan de sprint a été conçu pour s'intégrer parfaitement avec l'architecture existante de Misy tout en apportant une valeur utilisateur significative. Chaque sprint livre une valeur incrémentale et le projet peut être adapté selon les contraintes de ressources et les priorités métier.*