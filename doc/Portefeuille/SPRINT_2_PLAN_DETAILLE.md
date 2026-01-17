# Sprint 2 - Plan Détaillé : Interface Utilisateur et Crédit de Portefeuille

## 📋 Vue d'ensemble du Sprint

### Objectif Principal
Développer l'interface utilisateur complète pour la gestion du portefeuille numérique et l'intégration des fonctionnalités de crédit via mobile money.

### Durée
**2 semaines** (10 jours ouvrés)

### Contexte Technique
- **Infrastructure Sprint 1** : ✅ Terminée (modèles, services, providers)
- **Architecture existante** : Provider pattern + Firebase + Design System Misy V2
- **Intégrations disponibles** : Airtel Money, Orange Money, Telma MVola

---

## 🎯 Objectifs SMART du Sprint

1. **Spécifique** : Créer l'interface utilisateur pour le portefeuille avec 4 écrans principaux
2. **Mesurable** : 100% des interfaces prévues + tests d'intégration réussis
3. **Atteignable** : Réutilise l'infrastructure existante du Sprint 1
4. **Relevant** : Permet aux utilisateurs de gérer leur portefeuille et créditer leur solde
5. **Temporel** : Livrable en 2 semaines avec démo fonctionnelle

---

## 📊 Répartition des Tâches par Semaine

### Semaine 1 : Refactorisation et Écrans Principaux
- **Jours 1-3** : Refactorisation MyWalletManagement + Widgets de base
- **Jours 4-5** : Écran de crédit WalletTopUpScreen

### Semaine 2 : Historique et Intégration Paiement
- **Jours 6-7** : Écran historique WalletHistoryScreen
- **Jours 8-10** : Intégration paiement trajet + tests + démo

---

## 🛠 Tâches Détaillées

### 1. Refactorisation Interface Portefeuille (3 jours)

#### 1.1 Moderniser MyWalletManagement (1.5 jour)
**Fichier** : `lib/pages/view_module/my_wallet_management.dart`

**Travail requis** :
- Intégrer `WalletProvider` au lieu de `SavedPaymentMethodProvider` 
- Ajouter affichage du solde en temps réel avec `Consumer<WalletProvider>`
- Remplacer la logique actuelle par la gestion du portefeuille
- Ajouter pull-to-refresh pour actualiser le solde
- Implémenter le Design System Misy V2 (couleurs coralPink, horizonBlue)

**Code à implémenter** :
```dart
// Structure mise à jour
Consumer<WalletProvider>(
  builder: (context, walletProvider, child) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => walletProvider.refreshWallet(userId),
        child: Column(
          children: [
            WalletBalanceWidget(wallet: walletProvider.wallet),
            WalletActionsSection(),
            RecentTransactionsPreview(),
          ],
        ),
      ),
    );
  },
)
```

**Critères d'acceptation** :
- ✅ Solde affiché en temps réel
- ✅ Pull-to-refresh fonctionnel
- ✅ Design System Misy V2 appliqué
- ✅ Navigation vers les sous-écrans

#### 1.2 Créer WalletBalanceWidget (0.75 jour)
**Fichier** : `lib/widget/wallet_balance_widget.dart`

**Fonctionnalités** :
- Affichage animé du solde principal
- Indicateur visuel pour solde faible (< 10,000 MGA)
- Support mode sombre/clair via `MyColors.whiteThemeColor()`
- Animation de transition lors des changements de solde

**Design** :
```dart
class WalletBalanceWidget extends StatelessWidget {
  final Wallet? wallet;
  final bool showActions;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MyColors.coralPink, MyColors.horizonBlue],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Solde principal avec animation
          AnimatedBuilder(...),
          // Indicateurs visuels
          StatusIndicators(),
        ],
      ),
    );
  }
}
```

#### 1.3 Créer WalletTransactionCard (0.75 jour)
**Fichier** : `lib/widget/wallet_transaction_card.dart`

**Fonctionnalités** :
- Affichage des transactions individuelles avec icônes
- Formatage des dates (ex: "Il y a 2h", "Hier", "15 Jan")
- Couleurs selon le type (vert pour crédit, rouge pour débit)
- Status badges (En cours, Réussi, Échec)

**Structure** :
```dart
class WalletTransactionCard extends StatelessWidget {
  final WalletTransaction transaction;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: TransactionIcon(source: transaction.source),
        title: Text(transaction.formattedDescription),
        subtitle: Text(formatTimestamp(transaction.timestamp)),
        trailing: Column(
          children: [
            Text(
              transaction.signedAmount > 0 ? '+' : '',
              style: TextStyle(
                color: transaction.type == TransactionType.credit 
                  ? MyColors.success : MyColors.error,
              ),
            ),
            StatusBadge(status: transaction.status),
          ],
        ),
      ),
    );
  }
}
```

### 2. Écran de Crédit du Portefeuille (3 jours)

#### 2.1 Créer WalletTopUpScreen (1.5 jour)
**Fichier** : `lib/pages/view_module/wallet_topup_screen.dart`

**Fonctionnalités** :
- Sélection montant prédéfini (5,000 / 10,000 / 25,000 / 50,000 MGA)
- Input personnalisé avec validation (min 100 MGA, max 1,000,000 MGA)
- Sélection méthode de paiement mobile money
- Affichage des frais éventuels
- Validation en temps réel de la capacité du portefeuille

**Architecture** :
```dart
class WalletTopUpScreen extends StatefulWidget {
  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  double selectedAmount = 0;
  PaymentMethodType? selectedPaymentMethod;
  TextEditingController customAmountController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: translate('creditWallet')),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          return Column(
            children: [
              CurrentBalanceDisplay(),
              PredefinedAmountsSection(),
              CustomAmountInput(),
              PaymentMethodSelector(),
              FeesDisplay(),
              ConfirmButton(),
            ],
          );
        },
      ),
    );
  }
}
```

#### 2.2 Intégrer avec providers de paiement existants (1 jour)
**Travail requis** :
- Modifier `AirtelMoneyPaymentGatewayProvider.paymentApiCall()` pour supporter le crédit de portefeuille
- Idem pour `OrangeMoneyPaymentGatewayProvider` et `TelmaMoneyPaymentGatewayProvider`
- Rediriger les succès vers `WalletProvider.creditWallet()`

**Flux d'intégration** :
```dart
// Dans WalletTopUpScreen
Future<void> _processTopUp() async {
  switch (selectedPaymentMethod) {
    case PaymentMethodType.airtelMoney:
      bool success = await Provider.of<AirtelMoneyPaymentGatewayProvider>(context, listen: false)
          .paymentApiCall(
            amount: selectedAmount,
            phoneNumber: userPhoneNumber,
            isWalletTopUp: true, // Nouveau paramètre
          );
      
      if (success) {
        await Provider.of<WalletProvider>(context, listen: false)
            .creditWallet(
              userId: currentUserId,
              amount: selectedAmount,
              source: PaymentSource.airtelMoney,
              referenceId: generatedReferenceId,
            );
      }
      break;
    // Idem pour autres providers
  }
}
```

#### 2.3 Bottom Sheet de confirmation (0.5 jour)
**Fichier** : `lib/bottom_sheet_widget/wallet_topup_confirmation.dart`

**Fonctionnalités** :
- Résumé de la transaction (montant, méthode, frais)
- Confirmation avant lancement du paiement
- Gestion des erreurs avec retry
- Loader pendant le traitement

### 3. Historique des Transactions (2 jours)

#### 3.1 Créer WalletHistoryScreen (1.5 jour)
**Fichier** : `lib/pages/view_module/wallet_history_screen.dart`

**Fonctionnalités** :
- Liste paginée des transactions avec `ListView.builder`
- Pull-to-refresh et infinite scroll
- Filtres par date (Aujourd'hui, Cette semaine, Ce mois)
- Filtres par type (Crédit, Débit, Tous)
- Barre de recherche par description

**Architecture** :
```dart
class WalletHistoryScreen extends StatefulWidget {
  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  TransactionType? filterType;
  DateRange? filterDate;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WalletProvider>(context, listen: false)
          .loadRecentTransactions(currentUserId);
    });
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels == 
        _scrollController.position.maxScrollExtent) {
      // Load more transactions
      Provider.of<WalletProvider>(context, listen: false)
          .loadMoreTransactions(currentUserId);
    }
  }
}
```

#### 3.2 Recherche et filtres (0.5 jour)
**Fonctionnalités** :
- Recherche en temps réel par description de transaction
- Filtres combinés (type + date)
- Reset des filtres
- Sauvegarde des préférences de filtre

### 4. Intégration Paiement Trajet (2 jours)

#### 4.1 Modifier select_payment_method_sheet.dart (1 jour)
**Travail requis** :
- Ajouter option "Portefeuille Misy" dans la liste des méthodes
- Afficher le solde disponible à côté de l'option
- Validation en temps réel du solde suffisant
- Désactivation de l'option si solde insuffisant

**Code à ajouter** :
```dart
// Dans SavedPaymentMethodProvider.allPaymentMethods
{
  'name': 'Portefeuille Misy',
  'image': MyImagesUrl.wallet,
  'paymentGatewayType': PaymentMethodType.misyWallet, // Nouveau type
  'disabled': false,
  'show': true,
  'subtitle': '${walletProvider.formattedBalance}', // Solde affiché
  'available': walletProvider.balance > 0,
}
```

#### 4.2 Intégrer dans le flux de paiement (1 jour)
**Fichier** : `lib/provider/trip_provider.dart` (modifications)

**Travail requis** :
- Ajouter support de `PaymentMethodType.misyWallet` dans `TripProvider`
- Implémenter la logique de débit automatique via `WalletProvider.debitWallet()`
- Gestion des cas d'échec (solde insuffisant, wallet inactif)

**Code à implémenter** :
```dart
// Dans TripProvider.completeTrip()
if (selectedPaymentMethod == PaymentMethodType.misyWallet) {
  WalletProvider walletProvider = Provider.of<WalletProvider>(context, listen: false);
  
  // Vérifier le solde suffisant
  if (!walletProvider.hasSufficientBalance(tripAmount)) {
    throw Exception('Solde insuffisant');
  }
  
  // Débiter le portefeuille
  bool success = await walletProvider.debitWallet(
    userId: currentUserId,
    amount: tripAmount,
    tripId: currentTripId,
    description: 'Paiement trajet ${currentTripId}',
  );
  
  if (!success) {
    throw Exception('Échec du paiement par portefeuille');
  }
  
  // Marquer le trajet comme payé
  await updateTripPaymentStatus(currentTripId, 'paid');
}
```

---

## 🎨 Standards de Design

### Design System Misy V2
- **Couleur principale** : `MyColors.coralPink` (#FF5357)
- **Couleur secondaire** : `MyColors.horizonBlue` (#286EF0)
- **Texte principal** : `MyColors.textPrimary` (#3C4858)
- **Arrondis** : 12-16px pour les cartes, 8px pour les boutons
- **Police** : Poppins-Regular (déjà défini)

### Conventions UX
- **Feedback visuel** : Animations de 300ms pour les transitions
- **États de chargement** : Utiliser `CustomLoader` existant
- **Messages d'erreur** : Via `showSnackBarWidget()` existant
- **Indicateurs de statut** : Couleurs sémantiques (success, warning, error)

---

## 🧪 Critères d'Acceptation Globaux

### Fonctionnalités Core
- [ ] Affichage du solde en temps réel sur tous les écrans
- [ ] Crédit de portefeuille via les 3 opérateurs mobiles
- [ ] Paiement de trajet via portefeuille
- [ ] Historique complet des transactions avec filtres
- [ ] Gestion des erreurs et des cas limites

### Performance
- [ ] Cache local fonctionnel (SharedPreferences)
- [ ] Temps de chargement < 2s pour les écrans
- [ ] Synchronisation temps réel avec Firestore
- [ ] Pagination efficace pour l'historique

### UX/UI
- [ ] Design System Misy V2 respecté
- [ ] Support mode sombre/clair
- [ ] Responsive sur toutes les tailles d'écran
- [ ] Feedback visuel pour toutes les actions

### Sécurité
- [ ] Validation côté client et serveur
- [ ] Gestion des timeouts de transaction
- [ ] Logs d'audit pour toutes les opérations
- [ ] Protection contre les doublons de transaction

---

## ⚠️ Risques et Mitigation

### Risques Techniques
1. **Latence Firestore** 
   - *Mitigation* : Cache local avec SharedPreferences
   - *Fallback* : Mode offline basique

2. **Échecs Mobile Money**
   - *Mitigation* : Retry automatique + timeout
   - *Fallback* : Status "pending" avec vérification manuelle

3. **Synchronisation temps réel**
   - *Mitigation* : Listeners Firestore + reconciliation périodique
   - *Fallback* : Refresh manuel

### Risques Fonctionnels
1. **Solde incohérent**
   - *Mitigation* : Transactions atomiques Firestore
   - *Monitoring* : Vérifications de cohérence quotidiennes

2. **Double débit**
   - *Mitigation* : IDs de transaction uniques + vérifications
   - *Rollback* : Mécanisme de remboursement automatique

---

## 📈 Métriques de Succès

### Métriques Techniques
- **Couverture de tests** : >80% pour les composants critiques
- **Performance** : <2s temps de chargement moyen
- **Uptime** : >99.5% disponibilité des APIs de paiement

### Métriques Produit
- **Adoption** : >50% des utilisateurs activent le portefeuille
- **Usage** : >70% des paiements de trajet via portefeuille après activation
- **Satisfaction** : <5% de tickets support liés au portefeuille

---

## 🚀 Plan de Déploiement

### Phase 1 : Tests Internes (Jour 9)
- Tests unitaires et d'intégration
- Vérification des 3 opérateurs mobile money
- Tests de charge sur 100 transactions simultanées

### Phase 2 : Beta Testing (Jour 10)
- Déploiement sur 50 utilisateurs beta
- Monitoring en temps réel des transactions
- Collecte de feedback UX

### Phase 3 : Production (Post-Sprint)
- Déploiement progressif par région
- Monitoring et alertes en continu
- Support client formé sur les nouvelles fonctionnalités

---

## 📋 Checklist de Démo

### Préparation
- [ ] Environnement de démo configuré
- [ ] Comptes de test pour les 3 opérateurs
- [ ] Scénarios de démonstration préparés
- [ ] Données de test cohérentes

### Scénarios de Démo
1. **Consultation du portefeuille** : Affichage solde + historique
2. **Crédit via Airtel Money** : Processus complet avec confirmation
3. **Paiement de trajet** : Sélection portefeuille + débit automatique
4. **Gestion des erreurs** : Solde insuffisant + retry

### Post-Démo
- [ ] Feedback collecté et documenté
- [ ] Actions correctives identifiées
- [ ] Planning Sprint 3 ajusté si nécessaire

---

## 🔗 Dépendances

### Prérequis Techniques
- ✅ Sprint 1 terminé (modèles, services, providers)
- ✅ Firebase configuré et opérationnel
- ✅ Providers de paiement mobile money fonctionnels
- ✅ Design System Misy V2 en place

### Dépendances Externes
- **APIs Mobile Money** : Stabilité des APIs Airtel, Orange, Telma
- **Firebase** : Pas de maintenance planifiée pendant le sprint
- **Équipe Backend** : Support pour résolution d'incidents

---

## 📞 Contacts et Support

### Équipe Technique
- **Lead Developer** : Responsable de l'architecture et intégrations
- **UI/UX Developer** : Implémentation des interfaces et animations
- **QA Engineer** : Tests et validation des flux de paiement

### Équipes Externes
- **Firebase Support** : Support technique Google
- **Mobile Money Partners** : Contacts techniques opérateurs
- **Product Owner** : Validation des critères d'acceptation

---

*Ce document constitue le plan de référence pour le Sprint 2. Il doit être mis à jour selon l'avancement et les découvertes techniques.*