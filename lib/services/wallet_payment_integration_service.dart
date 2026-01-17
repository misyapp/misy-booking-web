import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/wallet.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_coordinator_provider.dart';
import 'package:rider_ride_hailing_app/services/wallet_service.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

/// Service d'intégration entre les providers de paiement mobile money
/// et le système de portefeuille numérique
/// 
/// Ce service adapte les providers existants pour supporter les top-ups
/// de portefeuille en plus des paiements de trajets
class WalletPaymentIntegrationService {
  
  /// Instance singleton
  static final WalletPaymentIntegrationService _instance = 
      WalletPaymentIntegrationService._internal();
  
  factory WalletPaymentIntegrationService() => _instance;
  
  WalletPaymentIntegrationService._internal();

  /// Contexte de données pour les transactions de portefeuille
  static Map<String, WalletTopUpContext> _currentWalletContext = {};

  /// Enregistre le contexte d'une transaction de top-up
  /// DOIT être appelé AVANT d'initier le paiement mobile money
  /// pour que handlePaymentSuccess() puisse créditer le wallet
  static void registerTransactionContext({
    required String transactionId,
    required String userId,
    required double amount,
    required PaymentMethodType paymentMethod,
    String? phoneNumber,
  }) {
    _currentWalletContext[transactionId] = WalletTopUpContext(
      userId: userId,
      amount: amount,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      phoneNumber: phoneNumber,
      createdAt: DateTime.now(),
    );
    myCustomPrintStatement('✅ WalletPaymentIntegrationService: Context registered for transaction $transactionId');
    myCustomPrintStatement('   UserId: $userId, Amount: $amount, Method: ${paymentMethod.value}');
  }

  /// Initie un top-up de portefeuille via mobile money
  /// Maintenant utilise le WalletTopUpCoordinatorProvider pour déléguer aux providers dédiés
  static Future<bool> initiateWalletTopUp({
    required double amount,
    required PaymentMethodType paymentMethod,
    required String userId,
    String? phoneNumber,
  }) async {
    try {
      myCustomPrintStatement('WalletPaymentIntegrationService: Initiating wallet top-up');
      myCustomPrintStatement('Amount: $amount, Method: ${paymentMethod.value}, User: $userId');

      // Valider les paramètres
      if (!WalletConstraints.isValidTransactionAmount(amount)) {
        throw Exception('Invalid transaction amount: $amount');
      }

      // Vérifier les limites du portefeuille
      Wallet? wallet = await WalletService.getWallet(userId);
      if (wallet != null && !wallet.canCredit(amount)) {
        throw Exception('Cannot credit wallet: would exceed maximum balance');
      }

      // Utiliser le coordinator provider pour gérer la transaction
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final coordinatorProvider = Provider.of<WalletTopUpCoordinatorProvider>(context, listen: false);
      
      return await coordinatorProvider.initiateTopUp(
        paymentMethod: paymentMethod,
        amount: amount,
        userId: userId,
        phoneNumber: phoneNumber,
      );
      
    } catch (e) {
      myCustomPrintStatement('Error initiating wallet top-up: $e');
      showSnackbar('Erreur lors du démarrage du paiement: $e');
      return false;
    }
  }

  /// Traite le top-up via Airtel Money (DEPRECATED)
  /// Cette méthode est conservée pour la compatibilité mais n'est plus utilisée
  /// Le traitement est maintenant géré par WalletTopUpAirtelProvider
  @deprecated
  static Future<bool> _processAirtelMoneyTopUp(double amount, String phoneNumber) async {
    myCustomPrintStatement('WARNING: _processAirtelMoneyTopUp is deprecated. Use WalletTopUpCoordinatorProvider instead.');
    return false;
  }

  /// Traite le top-up via Orange Money (DEPRECATED)
  /// Cette méthode est conservée pour la compatibilité mais n'est plus utilisée
  /// Le traitement est maintenant géré par WalletTopUpOrangeProvider
  @deprecated
  static Future<bool> _processOrangeMoneyTopUp(double amount) async {
    myCustomPrintStatement('WARNING: _processOrangeMoneyTopUp is deprecated. Use WalletTopUpCoordinatorProvider instead.');
    return false;
  }

  /// Traite le top-up via Telma Money (DEPRECATED)
  /// Cette méthode est conservée pour la compatibilité mais n'est plus utilisée
  /// Le traitement est maintenant géré par WalletTopUpTelmaProvider
  @deprecated
  static Future<bool> _processTelmaMoneyTopUp(double amount, String phoneNumber) async {
    myCustomPrintStatement('WARNING: _processTelmaMoneyTopUp is deprecated. Use WalletTopUpCoordinatorProvider instead.');
    return false;
  }

  /// Traite le top-up via Credit Card (DEPRECATED)
  /// Cette méthode est conservée pour la compatibilité mais n'est plus utilisée
  /// Le traitement est maintenant géré par WalletTopUpCoordinatorProvider
  @deprecated
  static Future<bool> _processCreditCardTopUp(double amount) async {
    myCustomPrintStatement('WARNING: _processCreditCardTopUp is deprecated. Use WalletTopUpCoordinatorProvider instead.');
    return false;
  }

  /// Configure un contexte de booking temporaire pour les providers existants (DEPRECATED)
  /// Cette méthode n'est plus utilisée car nous utilisons maintenant des providers dédiés
  @deprecated
  static Future<void> _setupTemporaryBookingContext(double amount) async {
    myCustomPrintStatement('WARNING: _setupTemporaryBookingContext is deprecated and no longer used.');
  }

  /// Gère la réussite d'un paiement mobile money pour wallet
  static Future<void> handlePaymentSuccess({
    required String transactionId,
    required String externalTransactionId,
    required PaymentMethodType paymentMethod,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      myCustomPrintStatement('🔍 handlePaymentSuccess called for transaction: $transactionId');
      myCustomPrintStatement('   Available contexts: ${_currentWalletContext.keys.toList()}');

      final context = _currentWalletContext[transactionId];
      if (context == null) {
        myCustomPrintStatement('❌ No wallet context found for transaction: $transactionId');
        myCustomPrintStatement('   This means the wallet will NOT be credited!');
        showSnackbar('Erreur: Contexte de transaction introuvable');
        return;
      }

      myCustomPrintStatement('✅ Context found - UserId: ${context.userId}, Amount: ${context.amount}');

      myCustomPrintStatement('Processing successful wallet payment: $transactionId');

      // Mapper la méthode de paiement à la source
      PaymentSource source;
      switch (paymentMethod) {
        case PaymentMethodType.airtelMoney:
          source = PaymentSource.airtelMoney;
          break;
        case PaymentMethodType.orangeMoney:
          source = PaymentSource.orangeMoney;
          break;
        case PaymentMethodType.telmaMvola:
          source = PaymentSource.telmaMoney;
          break;
        case PaymentMethodType.creditCard:
          source = PaymentSource.creditCard;
          break;
        default:
          source = PaymentSource.airtelMoney;
      }

      // Créer la transaction de crédit dans le portefeuille
      WalletTransaction? walletTransaction = await WalletService.creditWallet(
        userId: context.userId,
        amount: context.amount,
        source: source,
        referenceId: externalTransactionId,
        description: 'Crédit de portefeuille via ${paymentMethod.value}',
        metadata: {
          'paymentMethod': paymentMethod.value,
          'externalTransactionId': externalTransactionId,
          'internalTransactionId': transactionId,
          'timestamp': DateTime.now().toIso8601String(),
          'app_version': 'misy_v2',
          ...?additionalData,
        },
      );

      if (walletTransaction != null) {
        // Mettre à jour le provider de portefeuille
        final walletProvider = Provider.of<WalletProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false,
        );
        
        // Mettre à jour le coordinator provider
        final coordinatorProvider = Provider.of<WalletTopUpCoordinatorProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false,
        );
        
        // Actualiser les données du portefeuille
        await walletProvider.refreshWallet(context.userId);
        
        // Marquer la transaction comme réussie dans le coordinator
        coordinatorProvider.markTransactionSuccess(
          transactionId: transactionId,
          externalTransactionId: externalTransactionId,
        );
        
        showSnackbar('Portefeuille crédité avec succès: ${WalletHelper.formatAmount(context.amount)}');
        
        myCustomPrintStatement('Wallet successfully credited: ${walletTransaction.id}');
      } else {
        throw Exception('Failed to create wallet transaction');
      }
    } catch (e) {
      myCustomPrintStatement('Error handling payment success: $e');
      showSnackbar('Erreur lors du crédit du portefeuille: $e');
    } finally {
      // Nettoyer le contexte
      _currentWalletContext.remove(transactionId);
      myCustomPrintStatement('🧹 Context cleaned up for transaction: $transactionId');
    }
  }

  /// Gère l'échec d'un paiement mobile money pour wallet
  static Future<void> handlePaymentFailure({
    required String transactionId,
    required PaymentMethodType paymentMethod,
    String? errorMessage,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final context = _currentWalletContext[transactionId];
      if (context == null) {
        myCustomPrintStatement('No wallet context found for failed transaction: $transactionId');
        return;
      }

      myCustomPrintStatement('Processing failed wallet payment: $transactionId');

      // Mapper la méthode de paiement à la source
      PaymentSource source;
      switch (paymentMethod) {
        case PaymentMethodType.airtelMoney:
          source = PaymentSource.airtelMoney;
          break;
        case PaymentMethodType.orangeMoney:
          source = PaymentSource.orangeMoney;
          break;
        case PaymentMethodType.telmaMvola:
          source = PaymentSource.telmaMoney;
          break;
        case PaymentMethodType.creditCard:
          source = PaymentSource.creditCard;
          break;
        default:
          source = PaymentSource.airtelMoney;
      }

      // Créer une transaction échouée pour le suivi
      WalletTransaction failedTransaction = WalletTransactionHelper.createCreditTransaction(
        userId: context.userId,
        amount: context.amount,
        source: source,
        referenceId: transactionId,
        description: 'Échec de crédit portefeuille via ${paymentMethod.value}',
        metadata: {
          'paymentMethod': paymentMethod.value,
          'errorMessage': errorMessage ?? 'Unknown error',
          'timestamp': DateTime.now().toIso8601String(),
          'app_version': 'misy_v2',
          ...?additionalData,
        },
      );

      // Mettre le statut à échec
      failedTransaction = failedTransaction.copyWith(
        status: TransactionStatus.failed,
        errorMessage: errorMessage,
        processedAt: DateTime.now(),
      );

      // Enregistrer la transaction échouée (optionnel, pour le suivi)
      // await WalletService._processTransaction(failedTransaction);

      // Mettre à jour le coordinator provider
      final coordinatorProvider = Provider.of<WalletTopUpCoordinatorProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false,
      );
      
      // Marquer la transaction comme échouée dans le coordinator
      coordinatorProvider.markTransactionFailure(
        transactionId: transactionId,
        errorMessage: errorMessage,
      );

      showSnackbar('Échec du paiement: ${errorMessage ?? "Erreur inconnue"}');
      
      myCustomPrintStatement('Wallet payment failed: $transactionId - $errorMessage');
    } catch (e) {
      myCustomPrintStatement('Error handling payment failure: $e');
    } finally {
      // Nettoyer le contexte
      _currentWalletContext.remove(transactionId);
    }
  }

  /// Annule une transaction de portefeuille en cours
  static Future<void> cancelWalletTopUp(String transactionId) async {
    try {
      final context = _currentWalletContext[transactionId];
      if (context == null) {
        myCustomPrintStatement('No wallet context found for cancellation: $transactionId');
        return;
      }

      myCustomPrintStatement('Cancelling wallet top-up: $transactionId');

      // Nettoyer le contexte
      _currentWalletContext.remove(transactionId);
      
      showSnackbar('Transaction annulée');
    } catch (e) {
      myCustomPrintStatement('Error cancelling wallet top-up: $e');
    }
  }

  /// Récupère le contexte d'une transaction en cours
  static WalletTopUpContext? getTransactionContext(String transactionId) {
    return _currentWalletContext[transactionId];
  }

  /// Vérifie s'il y a des transactions de portefeuille en cours
  static bool hasActiveWalletTransactions() {
    return _currentWalletContext.isNotEmpty;
  }

  /// Nettoie tous les contextes de transaction (pour nettoyage)
  static void clearAllContexts() {
    _currentWalletContext.clear();
    myCustomPrintStatement('All wallet transaction contexts cleared');
  }

  /// Vérifie le statut d'une transaction de portefeuille
  static Future<TransactionStatus?> checkTransactionStatus(String transactionId) async {
    try {
      final context = _currentWalletContext[transactionId];
      if (context == null) return null;

      // Cette méthode pourrait être étendue pour vérifier le statut
      // auprès des providers de paiement spécifiques
      return TransactionStatus.processing;
    } catch (e) {
      myCustomPrintStatement('Error checking transaction status: $e');
      return null;
    }
  }
}

/// Contexte d'une transaction de top-up de portefeuille
class WalletTopUpContext {
  final String userId;
  final double amount;
  final PaymentMethodType paymentMethod;
  final String transactionId;
  final String? phoneNumber;
  final DateTime createdAt;

  const WalletTopUpContext({
    required this.userId,
    required this.amount,
    required this.paymentMethod,
    required this.transactionId,
    this.phoneNumber,
    required this.createdAt,
  });

  /// Vérifie si la transaction a expiré (plus de 10 minutes)
  bool get isExpired {
    return DateTime.now().difference(createdAt).inMinutes > 10;
  }

  /// Retourne une représentation string du contexte
  @override
  String toString() {
    return 'WalletTopUpContext(userId: $userId, amount: $amount, '
           'paymentMethod: ${paymentMethod.value}, transactionId: $transactionId, '
           'createdAt: $createdAt)';
  }
}