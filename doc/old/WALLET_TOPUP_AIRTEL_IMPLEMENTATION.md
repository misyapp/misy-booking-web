# Guide d'Implémentation - Top-up via Airtel Money

## Vue d'Ensemble

Ce document détaille l'implémentation du provider `WalletTopUpAirtelProvider` pour les top-ups de portefeuille via Airtel Money. Le provider suit exactement le même protocole API que le provider de paiement de courses mais est adapté pour les opérations de portefeuille.

## Architecture du Provider

### Fichier Principal
- **Localisation** : `lib/provider/wallet_topup_airtel_provider.dart`
- **Classe** : `WalletTopUpAirtelProvider extends ChangeNotifier`
- **Contexte** : `WalletTopUpContext` pour gérer les données de transaction

## Configuration API

### URLs et Endpoints
```dart
final String _airtelMoneyBaseUrl = "https://openapi.airtel.africa/";

// Endpoints utilisés :
// 1. Token : POST https://openapi.airtel.africa/auth/oauth2/token
// 2. Paiement : POST https://openapi.airtel.africa/merchant/v1/payments/
// 3. Statut : GET https://openapi.airtel.africa/standard/v1/payments/{transactionID}
```

### Authentification
```dart
// Headers pour le token
var headers = {
  'Content-Type': 'application/json',
};

// Corps de la requête
var request = {
  "client_id": paymentGateWaySecretKeys!.airtelMoneyClientId,
  "client_secret": paymentGateWaySecretKeys!.airtelMoneyClientSecret,
  "grant_type": "client_credentials"
};
```

### Clés de Configuration
- `paymentGateWaySecretKeys.airtelMoneyClientId` : Client ID Airtel
- `paymentGateWaySecretKeys.airtelMoneyClientSecret` : Client Secret Airtel

## Flux de Transaction

### 1. Initiation du Top-up

```dart
Future<bool> initiateTopUp({
  required double amount,
  required String mobileNumber,
  required String userId,
  required String internalTransactionId,
})
```

**Étapes :**
1. Formatage du numéro de téléphone (suppression du 0 initial)
2. Génération du token d'accès
3. Création du contexte de transaction
4. Envoi de la requête de paiement
5. Démarrage de la vérification du statut

### 2. Corps de la Requête de Paiement

```dart
Map<String, dynamic> body = {
  "reference": "Recharge Portefeuille Misy",
  "subscriber": {
    "country": "MG",
    "currency": "MGA",
    "msisdn": mobileNumber // Sans le 0 initial
  },
  "transaction": {
    "amount": amount, // Montant exact du top-up
    "country": "MG",
    "currency": "MGA",
    "id": transactionID // UUID généré
  }
};
```

**Différences avec le paiement de courses :**
- ✅ `amount` : Utilise le montant du top-up directement
- ❌ ~~`trip_provider.booking['ride_price_to_pay']`~~ : Plus utilisé
- ✅ `reference` : "Recharge Portefeuille Misy" au lieu de "Pay For Ride"

### 3. Gestion des Réponses

#### Réponse de Succès (HTTP 200)
```json
{
  "status": {
    "result_code": "ESB000010",
    "success": true
  }
}
```

**Action :** Démarrage de la vérification du statut après 3 secondes.

#### Codes d'Erreur Spécifiques
```dart
Map<String, String> errorMessages = {
  "ESB000001": "Une erreur s'est produite. Veuillez faire une enquête de transaction.",
  "ESB000011": "La demande a échoué.",
  "ESB000033": "Longueur MSISDN invalide.",
  "ESB000036": "MSISDN invalide ou ne commence pas par 0.",
  // ... autres codes
};
```

## Vérification du Statut

### Endpoint de Vérification
```dart
Uri apiUrl = Uri.parse("${_airtelMoneyBaseUrl}standard/v1/payments/$transactionID");
```

### Headers Requis
```dart
var headers = {
  'X-Country': 'MG',
  'X-Currency': 'MGA',
  'Authorization': 'Bearer $accessToken',
};
```

### États de Transaction

#### Transaction Réussie (TF - Transaction Fulfilled)
```json
{
  "status": {
    "result_code": "ESB000010",
    "success": true
  },
  "data": {
    "transaction": {
      "status": "TF",
      "message": "Transaction successful",
      "airtel_money_id": "MP123456789"
    }
  }
}
```

**Action :** Appel de `_handlePaymentSuccess()`

#### Transaction Échouée (TS - Transaction Failed)
```json
{
  "data": {
    "transaction": {
      "status": "TS",
      "message": "Insufficient balance"
    }
  }
}
```

**Action :** Appel de `_handlePaymentFailure()`

#### Transaction en Cours (TIP - Transaction In Progress)
```json
{
  "data": {
    "transaction": {
      "status": "TIP"
    }
  }
}
```

**Action :** Nouvelle vérification après 8 secondes

## Gestion des Callbacks

### Succès de Paiement

```dart
Future<void> _handlePaymentSuccess(Map<String, dynamic> response) async {
  String airtelTransactionId = response['data']['transaction']['airtel_money_id'];
  
  // Nettoyer l'UI
  _cleanupPaymentProcess();
  
  // Appeler le service d'intégration
  await WalletPaymentIntegrationService.handlePaymentSuccess(
    transactionId: currentContext!.transactionId,
    externalTransactionId: airtelTransactionId,
    paymentMethod: PaymentMethodType.airtelMoney,
    additionalData: {
      'airtel_transaction_id': airtelTransactionId,
      'airtel_access_token': accessToken,
      'phone_number': currentContext!.phoneNumber,
    },
  );
}
```

### Échec de Paiement

```dart
Future<void> _handlePaymentFailure(String errorMessage) async {
  // Nettoyer l'UI
  _cleanupPaymentProcess();
  
  // Appeler le service d'intégration
  await WalletPaymentIntegrationService.handlePaymentFailure(
    transactionId: currentContext!.transactionId,
    paymentMethod: PaymentMethodType.airtelMoney,
    errorMessage: errorMessage,
  );
}
```

## Contexte de Transaction

### Structure WalletTopUpContext

```dart
class WalletTopUpContext {
  final String userId;
  final double amount;
  final PaymentMethodType paymentMethod;
  final String transactionId; // ID interne Misy
  final String externalTransactionId; // UUID Airtel
  final String? phoneNumber;
  final DateTime createdAt;
}
```

### Cycle de Vie
1. **Création** : Lors de l'initiation du top-up
2. **Utilisation** : Pendant les callbacks de statut
3. **Nettoyage** : Après succès, échec ou annulation

## Interface Utilisateur

### Loader de Paiement
```dart
if (!showPaymentLoader) {
  showPaymentLoader = true;
  showPaymentProccessLoader(
    onTap: () {
      _cancelTransaction(); // Annulation par l'utilisateur
    },
  );
}
```

### Messages Utilisateur
```dart
// Démarrage
showSnackbar("Demande de paiement envoyée. Veuillez confirmer sur votre téléphone.");

// Succès - géré par WalletPaymentIntegrationService
showSnackbar('Portefeuille crédité avec succès: 10,000 MGA');

// Échec
showSnackbar('[ESB000033] Longueur MSISDN invalide.');
```

## Sécurité et Validation

### Validation du Numéro de Téléphone
```dart
// Formatage automatique
if (mobileNumber.startsWith('0')) {
  mobileNumber = mobileNumber.substring(1);
}
```

**Formats acceptés :**
- Input : "0340123456" → Output : "340123456"
- Input : "340123456" → Output : "340123456" (pas de changement)

### Gestion des Tokens
```dart
// Renouvellement automatique en cas d'expiration
if (response.statusCode == 401 || response.statusCode == 403) {
  await generateAccessToken();
  await _checkTransactionStatus();
}
```

### Timeout et Expiration
- **Timeout de transaction** : 10 minutes
- **Intervalle de vérification** : 8 secondes
- **Nettoyage automatique** : Contexte supprimé après timeout

## Debug et Logging

### Points de Log Importants
```dart
// Initiation
myCustomPrintStatement('WalletTopUpAirtelProvider: Initiating top-up for $amount MGA');

// Token
myCustomPrintStatement("Airtel access token generated successfully");

// Requête paiement
myCustomPrintStatement('Sending Airtel payment request: $body');

// Vérification statut
myCustomPrintStatement("Checking Airtel transaction status: $transactionID");

// Résultat
myCustomPrintStatement('Airtel payment successful');
```

### Structure des Logs
```
[Timestamp] WalletTopUpAirtelProvider: [Action] - [Details]
```

## Tests et Validation

### Tests de Cas d'Usage

#### Test de Succès
```dart
// Données de test
amount: 10000.0
phoneNumber: "0340123456"
userId: "test_user_123"

// Résultat attendu
- Token généré avec succès
- Requête de paiement envoyée
- Statut TF reçu
- Portefeuille crédité
```

#### Test d'Échec - Numéro Invalide
```dart
// Données de test
phoneNumber: "123" // Trop court

// Résultat attendu
- Code ESB000033 retourné
- Message d'erreur affiché
- Transaction marquée comme échouée
```

#### Test d'Annulation
```dart
// Action utilisateur
- Clic sur "Annuler" dans le loader

// Résultat attendu
- Contexte nettoyé
- UI réinitialisée
- Message "Transaction annulée"
```

## Intégration avec le Système

### Appel depuis WalletTopUpCoordinatorProvider
```dart
final airtelProvider = Provider.of<WalletTopUpAirtelProvider>(context, listen: false);

return await airtelProvider.initiateTopUp(
  amount: amount,
  mobileNumber: phoneNumber,
  userId: userId,
  internalTransactionId: transactionId,
);
```

### Réponse vers WalletPaymentIntegrationService
```dart
// Succès
WalletPaymentIntegrationService.handlePaymentSuccess(
  transactionId: internalTransactionId,
  externalTransactionId: airtelTransactionId,
  paymentMethod: PaymentMethodType.airtelMoney,
);

// Échec
WalletPaymentIntegrationService.handlePaymentFailure(
  transactionId: internalTransactionId,
  paymentMethod: PaymentMethodType.airtelMoney,
  errorMessage: errorDescription,
);
```

## Troubleshooting

### Problèmes Courants

#### Erreur ESB000036 - MSISDN invalide
**Cause** : Numéro ne commence pas par 0 dans la validation Airtel
**Solution** : Utiliser le formatage automatique du provider

#### Transaction bloquée en TIP
**Cause** : Utilisateur n'a pas confirmé sur son téléphone
**Solution** : Attente automatique avec timeout de 10 minutes

#### Token 401/403
**Cause** : Token expiré ou clés invalides
**Solution** : Régénération automatique du token

### Métriques de Performance

#### Temps de Réponse Typiques
- **Génération token** : 1-3 secondes
- **Requête paiement** : 2-5 secondes
- **Vérification statut** : 1-2 secondes
- **Total (succès)** : 30-120 secondes (dépend de l'utilisateur)

#### Taux de Succès Attendus
- **Token** : >99% (problème réseau/clés)
- **Initiation** : >95% (validation numéro)
- **Confirmation** : 70-90% (dépend de l'utilisateur)

---

Ce provider Airtel Money fournit une implémentation robuste et complète pour les top-ups de portefeuille, réutilisant l'infrastructure API existante tout en maintenant une séparation claire avec les paiements de courses.