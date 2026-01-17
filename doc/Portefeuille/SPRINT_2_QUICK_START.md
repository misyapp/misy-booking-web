# 🚀 Sprint 2 - Guide de Démarrage Rapide

## ⚡ Mise en Route Immédiate

### 1. Vérification de l'Infrastructure (5 min)

```bash
# Vérifier que le Sprint 1 est bien en place
flutter pub get
dart run lib/scripts/check_wallet_infrastructure.dart

# Vérifier les modèles
grep -r "class Wallet" lib/models/
grep -r "class WalletTransaction" lib/models/
grep -r "class WalletProvider" lib/provider/
```

### 2. Architecture Existante à Connaître

```
lib/
├── models/
│   ├── wallet.dart              ✅ Prêt (Sprint 1)
│   └── wallet_transaction.dart  ✅ Prêt (Sprint 1)
├── provider/
│   └── wallet_provider.dart     ✅ Prêt (Sprint 1)
├── services/
│   └── wallet_service.dart      ✅ Prêt (Sprint 1)
└── pages/view_module/
    └── my_wallet_management.dart 🔄 À refactoriser
```

### 3. APIs Clés à Utiliser

```dart
// WalletProvider - État du portefeuille
Consumer<WalletProvider>(
  builder: (context, walletProvider, child) {
    return Text('${walletProvider.formattedBalance}');
  },
)

// WalletService - Opérations
await WalletService.creditWallet(
  userId: userId,
  amount: amount,
  source: PaymentSource.airtelMoney,
  referenceId: 'REF123',
);

// Modèles - Données
Wallet wallet = Wallet.createNew(userId);
WalletTransaction transaction = WalletTransactionHelper.createCreditTransaction(...);
```

---

## 📋 Checklist par Tâche

### Tâche 1: Refactorisation MyWalletManagement

**Avant de commencer** :
- [ ] Analyser `lib/pages/view_module/my_wallet_management.dart`
- [ ] Identifier les parties à conserver vs refactoriser
- [ ] Comprendre l'utilisation actuelle de `SavedPaymentMethodProvider`

**Étapes d'implémentation** :
1. [ ] Remplacer `SavedPaymentMethodProvider` par `WalletProvider`
2. [ ] Intégrer l'affichage du solde en temps réel
3. [ ] Ajouter la fonctionnalité pull-to-refresh
4. [ ] Appliquer le Design System Misy V2

**Code de démarrage** :
```dart
class _MyWalletManagementState extends State<MyWalletManagement> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      walletProvider.initializeWallet(currentUser.uid);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.backgroundLight,
      appBar: CustomAppBar(
        bgcolor: MyColors.backgroundContrast,
        title: translate('myWallet'),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          if (walletProvider.isLoading) {
            return Center(child: CustomLoader());
          }
          
          return RefreshIndicator(
            onRefresh: () => walletProvider.refreshWallet(currentUser.uid),
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  WalletBalanceWidget(wallet: walletProvider.wallet),
                  WalletActionsSection(),
                  RecentTransactionsSection(
                    transactions: walletProvider.transactions.take(5).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

### Tâche 2: WalletBalanceWidget

**Template de démarrage** :
```dart
// lib/widget/wallet_balance_widget.dart
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/models/wallet.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';

class WalletBalanceWidget extends StatelessWidget {
  final Wallet? wallet;
  final bool showActions;
  final VoidCallback? onTapCredit;
  final VoidCallback? onTapHistory;

  const WalletBalanceWidget({
    Key? key,
    this.wallet,
    this.showActions = true,
    this.onTapCredit,
    this.onTapHistory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MyColors.coralPink,
            MyColors.horizonBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MyColors.coralPink.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate('walletBalance'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 8),
          Text(
            wallet?.formattedBalance ?? '0 MGA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (wallet?.hasLowBalance ?? false)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MyColors.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MyColors.warning),
              ),
              child: Text(
                translate('lowBalanceWarning'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (showActions)
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.add_circle_outline,
                    label: translate('creditWallet'),
                    onTap: onTapCredit,
                  ),
                  SizedBox(width: 16),
                  _ActionButton(
                    icon: Icons.history,
                    label: translate('history'),
                    onTap: onTapHistory,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Tâche 3: WalletTransactionCard

**Template de démarrage** :
```dart
// lib/widget/wallet_transaction_card.dart
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';

class WalletTransactionCard extends StatelessWidget {
  final WalletTransaction transaction;
  final bool showFullDate;

  const WalletTransactionCard({
    Key? key,
    required this.transaction,
    this.showFullDate = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            _TransactionIcon(source: transaction.source, type: transaction.type),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.formattedDescription,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: MyColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTimestamp(transaction.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: MyColors.textSecondary,
                    ),
                  ),
                  if (transaction.tripId != null)
                    Text(
                      'Trajet #${transaction.tripId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: MyColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${transaction.signedAmount > 0 ? '+' : ''}${transaction.signedAmount.toStringAsFixed(0)} MGA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: transaction.type == TransactionType.credit
                        ? MyColors.success
                        : MyColors.error,
                  ),
                ),
                SizedBox(height: 4),
                _StatusBadge(status: transaction.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class _TransactionIcon extends StatelessWidget {
  final PaymentSource source;
  final TransactionType type;

  const _TransactionIcon({required this.source, required this.type});

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;

    switch (source) {
      case PaymentSource.airtelMoney:
        iconData = Icons.phone_android;
        iconColor = Colors.red;
        break;
      case PaymentSource.orangeMoney:
        iconData = Icons.phone_android;
        iconColor = Colors.orange;
        break;
      case PaymentSource.telmaMoney:
        iconData = Icons.phone_android;
        iconColor = Colors.blue;
        break;
      case PaymentSource.tripPayment:
        iconData = Icons.local_taxi;
        iconColor = MyColors.textSecondary;
        break;
      default:
        iconData = Icons.account_balance_wallet;
        iconColor = MyColors.textSecondary;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TransactionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case TransactionStatus.completed:
        color = MyColors.success;
        label = 'Réussi';
        break;
      case TransactionStatus.pending:
        color = MyColors.warning;
        label = 'En cours';
        break;
      case TransactionStatus.failed:
        color = MyColors.error;
        label = 'Échec';
        break;
      default:
        color = MyColors.textSecondary;
        label = 'Inconnu';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
```

---

## 🛠 Outils de Développement

### Extensions VSCode Recommandées
```json
{
  "recommendations": [
    "dart-code.flutter",
    "dart-code.dart-code",
    "ms-vscode.vscode-flutter",
    "bradlc.vscode-tailwindcss"
  ]
}
```

### Snippets Utiles
```dart
// Snippet pour Consumer WalletProvider
Consumer<WalletProvider>(
  builder: (context, walletProvider, child) {
    if (walletProvider.isLoading) {
      return Center(child: CustomLoader());
    }
    
    if (walletProvider.hasError) {
      return Center(
        child: Text(
          walletProvider.errorMessage ?? 'Erreur inconnue',
          style: TextStyle(color: MyColors.error),
        ),
      );
    }
    
    return ${1:YourWidget}();
  },
)

// Snippet pour navigation avec paramètres
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ${1:ScreenName}(
      ${2:parameter}: ${3:value},
    ),
  ),
);
```

### Scripts de Test Rapide
```bash
# Test des modèles
dart test test/wallet_models_test.dart

# Test des services
dart test test/wallet_service_test.dart

# Test d'intégration
flutter test integration_test/wallet_flow_test.dart

# Build de vérification
flutter build apk --debug
```

---

## 🔍 Debug et Troubleshooting

### Logs Importants
```dart
// Utiliser myCustomPrintStatement pour debug
myCustomPrintStatement('WalletProvider: ${walletProvider.debugState}');

// Logs de transaction
myCustomPrintStatement('Transaction: ${transaction.toJson()}');

// Logs d'erreur
myCustomPrintStatement('Error: $error');
```

### Vérifications Communes
```dart
// Vérifier l'état du provider
walletProvider.debugPrintState();

// Vérifier la validité d'une transaction
bool isValid = WalletTransactionHelper.isValidTransaction(transaction);

// Vérifier les contraintes du portefeuille
List<String> errors = WalletConstraints.validateWallet(wallet);
```

### Problèmes Fréquents

**1. Provider non initialisé**
```dart
// Solution: Toujours initialiser dans initState
WidgetsBinding.instance.addPostFrameCallback((_) {
  Provider.of<WalletProvider>(context, listen: false)
    .initializeWallet(userId);
});
```

**2. Erreur de cache**
```dart
// Solution: Vider le cache si nécessaire
await WalletService.clearAllCache();
```

**3. Problème de synchronisation**
```dart
// Solution: Forcer la synchronisation
await walletProvider.refreshWallet(userId);
```

---

## 📱 Test sur Devices

### Configuration de Test
```dart
// lib/config/test_config.dart
class TestConfig {
  static const bool isTestMode = true;
  static const String testUserId = 'test_user_123';
  static const double testBalance = 50000.0;
  
  static Map<String, dynamic> getMockWalletData() {
    return {
      'balance': testBalance,
      'isActive': true,
      'currency': 'MGA',
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
}
```

### Comptes de Test Mobile Money
```
Airtel Money Test:
- Numéro: +261340000001
- PIN: 1234

Orange Money Test:
- Numéro: +261320000001  
- PIN: 1234

Telma MVola Test:
- Numéro: +261330000001
- PIN: 1234
```

---

## 📞 Support et Contacts

### En cas de problème technique
1. **Vérifier les logs** avec `myCustomPrintStatement`
2. **Consulter la documentation** dans `/doc`
3. **Rechercher dans le code existant** des patterns similaires
4. **Tester sur un device réel** avant de reporter un bug

### Ressources Utiles
- **Architecture Technique** : `/ARCHITECTURE_TECHNIQUE.md`
- **Guide des Conventions** : `/DEVELOPMENT_RULES.md`
- **Plan complet Sprint 2** : `/SPRINT_2_PLAN_DETAILLE.md`
- **Code Review Checklist** : `/CODE_REVIEW_CHECKLIST.md`

---

*Ce guide est votre point de départ. Consultez le plan détaillé pour plus d'informations sur chaque tâche spécifique.*