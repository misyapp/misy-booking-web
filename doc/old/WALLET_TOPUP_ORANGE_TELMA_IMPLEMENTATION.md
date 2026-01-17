# Guide d'Implémentation - Top-up via Orange Money et Telma MVola

## Vue d'Ensemble

Ce document détaille l'implémentation des providers `WalletTopUpOrangeProvider` et `WalletTopUpTelmaProvider` pour les top-ups de portefeuille via Orange Money et Telma MVola. Ces providers suivent les protocoles API spécifiques de chaque opérateur mais partagent des concepts architecturaux communs.

---

# PARTIE I : Orange Money Provider

## Architecture du Provider

### Fichier Principal
- **Localisation** : `lib/provider/wallet_topup_orange_provider.dart`
- **Classe** : `WalletTopUpOrangeProvider extends ChangeNotifier`
- **Contexte** : `WalletTopUpOrangeContext` pour gérer les données de transaction

## Configuration API Orange

### URLs et Endpoints
```dart
final String _orangeMoneyBaseUrl = "https://api.orange.com/";

// Endpoints utilisés :
// 1. Token : POST https://api.orange.com/oauth/v3/token
// 2. WebPayment : POST https://api.orange.com/orange-money-webpay/mg/v1/webpayment
```

### Authentification
```dart
// Headers pour le token
var headers = {
  'Authorization': 'Basic ${paymentGateWaySecretKeys!.orangeMoneyApiSecretKey}',
  'Content-Type': 'application/x-www-form-urlencoded',
};

// Corps de la requête (form-encoded)
var body = {"grant_type": "client_credentials"};
```

### Clés de Configuration
- `paymentGateWaySecretKeys.orangeMoneyApiSecretKey` : Clé API Base64 encodée
- `paymentGateWaySecretKeys.orangeMoneyMerchantKey` : Clé marchande Orange

## Flux de Transaction Orange

### 1. Initiation du Top-up

```dart
Future<bool> initiateTopUp({
  required double amount,
  required String userId,
  required String internalTransactionId,
})
```

**Spécificité Orange :** Pas de numéro de téléphone requis, gestion via WebView.

### 2. Corps de la Requête WebPayment

```dart
Map<String, dynamic> body = {
  "merchant_key": paymentGateWaySecretKeys!.orangeMoneyMerchantKey,
  "currency": "MGA",
  "order_id": orderId, // UUID généré
  "amount": amount.toString(), // String requis par Orange
  "return_url": "http://myvirtualshop.webnode.es",
  "cancel_url": "http://myvirtualshop.webnode.es/txncncld/",
  "notif_url": "http://www.merchant-example2.org/notif",
  "lang": "fr",
  "reference": "Recharge Portefeuille Misy"
};
```

**Différences avec le paiement de courses :**
- ✅ `amount` : Utilise le montant du top-up directement (en string)
- ✅ `reference` : "Recharge Portefeuille Misy"
- ✅ `order_id` : UUID dédié au top-up

### 3. Gestion des Réponses Orange

#### Réponse de Succès (HTTP 201)
```json
{
  "pay_token": "token_abc123",
  "payment_url": "https://webpayment.orange.mg/...",
  "notif_token": "notif_xyz789"
}
```

**Actions :**
1. Sauvegarde des tokens
2. Ouverture de la WebView
3. Démarrage de la surveillance du statut

#### Réponse Alternative (HTTP 200)
Orange peut parfois retourner 200 au lieu de 201. Le provider gère les deux cas.

## Interface WebView Orange

### Ouverture de la WebView
```dart
await push(
  context: MyGlobalKeys.navigatorKey.currentContext!,
  screen: OpenPaymentWebview(
    webViewUrl: paymentUrl,
    onPaymentComplete: (success) {
      if (success) {
        _handlePaymentWebViewSuccess();
      } else {
        _handlePaymentWebViewFailure();
      }
    },
  ),
);
```

### Surveillance du Statut
```dart
// Vérification périodique toutes les 10 secondes
_statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
  await _checkTransactionStatus();
});

// Timeout après 10 minutes
Future.delayed(const Duration(minutes: 10), () {
  _stopStatusChecking();
  if (isProcessingPayment) {
    _handlePaymentTimeout();
  }
});
```

## Contexte de Transaction Orange

### Structure WalletTopUpOrangeContext

```dart
class WalletTopUpOrangeContext {
  final String userId;
  final double amount;
  final PaymentMethodType paymentMethod;
  final String transactionId; // ID interne Misy
  final String orderId; // UUID Orange
  final String? payToken;
  final String? paymentUrl;
  final String? notifyToken;
  final DateTime createdAt;
  
  // Méthode copyWith pour mises à jour
  WalletTopUpOrangeContext copyWith({...});
}
```

---

# PARTIE II : Telma MVola Provider

## Architecture du Provider

### Fichier Principal
- **Localisation** : `lib/provider/wallet_topup_telma_provider.dart`
- **Classe** : `WalletTopUpTelmaProvider extends ChangeNotifier`
- **Contexte** : `WalletTopUpTelmaContext` pour gérer les données de transaction

## Configuration API Telma

### URLs et Endpoints
```dart
final String _telmaMvolaMoneyBaseUrl = "https://api.mvola.mg/";

// Endpoints utilisés :
// 1. Token : POST https://api.mvola.mg/token
// 2. MerchantPay : POST https://api.mvola.mg/mvola/mm/transactions/type/merchantpay/1.0.0/
// 3. Status : GET https://api.mvola.mg/mvola/mm/transactions/type/merchantpay/1.0.0/{correlationID}
```

### Authentification
```dart
String uuid = generateUUID();
var headers = {
  'Authorization': 'Basic ${stringToBase64("${telmaConsumerKey}:${telmaConsumerSecretKey}")}',
  'Content-Type': 'application/x-www-form-urlencoded',
  'Cache-Control': 'no-cache'
};

// Corps avec scope device-specific
body: {
  'grant_type': 'client_credentials',
  "scope": "EXT_INT_MVOLA_SCOPE device_$uuid"
}
```

### Clés de Configuration
- `paymentGateWaySecretKeys.telmaConsumerKey` : Consumer Key Telma
- `paymentGateWaySecretKeys.telmaConsumerSecretKey` : Consumer Secret Telma
- `merchantPhoneNumber` : "0384219719" (numéro marchand fixe)

## Flux de Transaction Telma

### 1. Initiation du Top-up

```dart
Future<bool> initiateTopUp({
  required double amount,
  required String phoneNumberDebitParty,
  required String userId,
  required String internalTransactionId,
})
```

**Spécificité Telma :** Requiert le numéro de téléphone du débiteur.

### 2. Corps de la Requête MerchantPay

```dart
Map<String, dynamic> body = {
  "amount": double.parse(formatNearest(amount)).toInt().toString(),
  "currency": "Ar",
  "descriptionText": "Recharge Portefeuille Misy",
  "requestingOrganisationTransactionReference": "MISY_WALLET_${correlationID.substring(0, 8)}",
  "originalTransactionReference": "WALLET_TOPUP_${DateTime.now().millisecondsSinceEpoch}",
  "requestDate": "${DateFormat('yyyy-MM-ddTHH:mm:ss.SSS').format(DateTime.now())}Z",
  "debitParty": [
    {"key": "msisdn", "value": phoneNumberDebitParty}
  ],
  "creditParty": [
    {"key": "msisdn", "value": merchantPhoneNumber}
  ],
  "metadata": [
    {"key": "partnerName", "value": "Misy"},
    {"key": "fc", "value": "MGA"},
    {"key": "amountFc", "value": amount},
    {"key": "transactionType", "value": "wallet_topup"}
  ]
};
```

**Différences avec le paiement de courses :**
- ✅ `amount` : Formaté et converti en entier
- ✅ `descriptionText` : "Recharge Portefeuille Misy"
- ✅ `metadata.transactionType` : "wallet_topup"

### 3. Headers Spéciaux Telma

```dart
var headers = {
  'accept': '*/*',
  'Version': '1.0',
  'X-CorrelationID': correlationID, // UUID unique
  'UserLanguage': selectedLanguageNotifier.value['key'] == 'mg' || 
                  selectedLanguageNotifier.value['key'] == 'en' ? 'MG' : 'FR',
  'Cache-Control': 'no-cache',
  'Content-Type': 'application/json',
  'Authorization': 'Bearer $accessToken',
};
```

### 4. Gestion des Réponses Telma

#### Succès d'Initiation (HTTP 202)
```json
{
  "serverCorrelationId": "server_corr_123",
  "objectReference": "obj_ref_456",
  "status": "PENDING"
}
```

**Actions :**
1. Sauvegarde des IDs de corrélation
2. Démarrage de la vérification toutes les 10 secondes

#### Vérification du Statut
```json
// Succès final
{
  "status": "SUCCESSFUL",
  "transactionId": "telma_txn_789"
}

// Échec
{
  "status": "FAILED",
  "errorInformation": {
    "errorCode": "INSUFFICIENT_BALANCE",
    "errorDescription": "Solde insuffisant"
  }
}

// En cours
{
  "status": "PENDING"
}
```

## Contexte de Transaction Telma

### Structure WalletTopUpTelmaContext

```dart
class WalletTopUpTelmaContext {
  final String userId;
  final double amount;
  final PaymentMethodType paymentMethod;
  final String transactionId; // ID interne Misy
  final String correlationId; // UUID Telma
  final String? serverCorrelationId;
  final String? objectReferenceId;
  final String? phoneNumber;
  final DateTime createdAt;
  
  // Méthode copyWith pour mises à jour
  WalletTopUpTelmaContext copyWith({...});
}
```

---

# PARTIE III : Comparaison et Bonnes Pratiques

## Différences Clés entre Orange et Telma

### Orange Money
- **Interface** : WebView pour l'utilisateur
- **Vérification** : Basée sur callbacks WebView + polling
- **Numéro** : Pas requis (saisi dans la WebView)
- **Réponse** : Tokens pour WebView

### Telma MVola
- **Interface** : Confirmation directe sur téléphone
- **Vérification** : Polling API avec correlation IDs
- **Numéro** : Requis dans la requête
- **Réponse** : IDs de corrélation pour suivi

## Gestion d'Erreurs Commune

### Timeout de Transactions
```dart
// Orange : Timer avec timeout
Future.delayed(const Duration(minutes: 10), () {
  _stopStatusChecking();
  if (isProcessingPayment) {
    _handlePaymentTimeout();
  }
});

// Telma : Vérification d'expiration dans le contexte
bool get isExpired {
  return DateTime.now().difference(createdAt).inMinutes > 10;
}
```

### Gestion des Tokens Expirés
```dart
// Code commun pour les deux providers
if (response.statusCode == 401 || response.statusCode == 403) {
  await generateAccessToken();
  await _checkTransactionStatus(); // Retry
  return;
}
```

## Logging et Debug

### Structure de Logs Commune
```dart
// Orange
myCustomPrintStatement('WalletTopUpOrangeProvider: [Action]');

// Telma  
myCustomPrintStatement('WalletTopUpTelmaProvider: [Action]');

// Avec détails
myCustomPrintStatement('Sending Orange payment request: $body');
myCustomPrintStatement('Telma payment request accepted: $jsonResponse');
```

### Points de Log Critiques
1. **Initiation** : Montant et utilisateur
2. **Token** : Succès/échec de génération
3. **Requête** : Corps de requête (sanitisé)
4. **Réponse** : Statut et données importantes
5. **Callbacks** : Succès/échec final

## Tests et Validation

### Scénarios de Test Communs

#### Test de Succès Complet
```dart
// Données de test
amount: 5000.0
userId: "test_user"

// Orange : phoneNumber non requis
// Telma : phoneNumber: "0340123456"

// Résultat attendu pour les deux
- Token généré ✅
- Requête initiée ✅
- Utilisateur confirme ✅
- Portefeuille crédité ✅
```

#### Test d'Annulation Utilisateur
```dart
// Orange : Annulation dans WebView
- WebView fermée sans confirmation

// Telma : Pas de confirmation sur téléphone
- Timeout de 10 minutes atteint

// Résultat commun
- Transaction marquée comme échouée
- Contexte nettoyé
- UI réinitialisée
```

#### Test d'Erreur API
```dart
// Cas : Token invalide
- HTTP 401/403 reçu
- Régénération automatique du token
- Retry de la requête

// Cas : Paramètres invalides
- HTTP 400 reçu
- Message d'erreur spécifique affiché
- Transaction marquée comme échouée
```

## Métriques et Performance

### Temps de Réponse Typiques

#### Orange Money
- **Token** : 1-2 secondes
- **WebPayment** : 2-4 secondes
- **WebView** : 30-180 secondes (utilisateur)
- **Total** : 33-186 secondes

#### Telma MVola
- **Token** : 1-3 secondes
- **MerchantPay** : 3-6 secondes
- **Confirmation** : 10-120 secondes (utilisateur)
- **Total** : 14-129 secondes

### Taux de Succès Attendus
- **Orange** : 75-85% (WebView peut être fermée)
- **Telma** : 80-90% (confirmation directe plus fiable)

## Intégration avec le Système

### Appels depuis WalletTopUpCoordinatorProvider

```dart
// Orange
final orangeProvider = Provider.of<WalletTopUpOrangeProvider>(context, listen: false);
return await orangeProvider.initiateTopUp(
  amount: amount,
  userId: userId,
  internalTransactionId: transactionId,
);

// Telma
final telmaProvider = Provider.of<WalletTopUpTelmaProvider>(context, listen: false);
return await telmaProvider.initiateTopUp(
  amount: amount,
  phoneNumberDebitParty: phoneNumber,
  userId: userId,
  internalTransactionId: transactionId,
);
```

### Callbacks vers WalletPaymentIntegrationService

```dart
// Succès (structure identique)
await WalletPaymentIntegrationService.handlePaymentSuccess(
  transactionId: currentContext!.transactionId,
  externalTransactionId: providerSpecificId,
  paymentMethod: PaymentMethodType.orangeMoney, // ou telmaMvola
  additionalData: {
    // Données spécifiques au provider
  },
);
```

## Troubleshooting

### Problèmes Spécifiques Orange

#### WebView ne s'ouvre pas
**Cause** : URL de paiement invalide ou vide
**Solution** : Vérifier la génération du `payment_url`

#### Transaction bloquée après WebView
**Cause** : Callback de la WebView non reçu
**Solution** : Implémentation du timeout automatique

### Problèmes Spécifiques Telma

#### Erreur de correlation ID
**Cause** : UUID mal formé ou réutilisé
**Solution** : Génération d'UUID unique pour chaque transaction

#### Statut toujours PENDING
**Cause** : Utilisateur n'a pas confirmé sur MVola
**Solution** : Timeout automatique + message utilisateur

---

Cette implémentation double fournit une couverture complète des deux principaux opérateurs mobile money de Madagascar, avec des patterns consistants et une gestion d'erreur robuste pour chaque spécificité technique.