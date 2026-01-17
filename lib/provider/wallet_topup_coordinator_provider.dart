import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_airtel_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_orange_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_telma_provider.dart';
import 'package:rider_ride_hailing_app/services/wallet_payment_integration_service.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

/// Provider coordinateur pour les top-ups de portefeuille
/// Orchestre les différents providers de paiement mobile money
/// et maintient l'état global des transactions de top-up
class WalletTopUpCoordinatorProvider with ChangeNotifier {
  
  // État global des top-ups
  bool _isProcessingTopUp = false;
  PaymentMethodType? _currentPaymentMethod;
  String? _currentTransactionId;
  double? _currentAmount;
  String? _currentUserId;
  DateTime? _transactionStartTime;
  
  // Messages de statut
  String _statusMessage = '';
  TopUpStatus _status = TopUpStatus.idle;

  // Getters
  bool get isProcessingTopUp => _isProcessingTopUp;
  PaymentMethodType? get currentPaymentMethod => _currentPaymentMethod;
  String? get currentTransactionId => _currentTransactionId;
  double? get currentAmount => _currentAmount;
  String? get currentUserId => _currentUserId;
  String get statusMessage => _statusMessage;
  TopUpStatus get status => _status;
  bool get hasActiveTransaction => _currentTransactionId != null;

  /// Initie un top-up de portefeuille via la méthode spécifiée
  Future<bool> initiateTopUp({
    required PaymentMethodType paymentMethod,
    required double amount,
    required String userId,
    String? phoneNumber,
  }) async {
    try {
      myCustomPrintStatement('WalletTopUpCoordinatorProvider: Initiating top-up');
      myCustomPrintStatement('Method: ${paymentMethod.value}, Amount: $amount, User: $userId');
      
      // Vérifier s'il y a déjà une transaction en cours
      if (_isProcessingTopUp) {
        showSnackbar('Une transaction de rechargement est déjà en cours');
        return false;
      }
      
      // Générer un ID de transaction unique
      String transactionId = _generateTransactionId();

      // ✅ IMPORTANT: Enregistrer le contexte de transaction AVANT d'initier le paiement
      // Sans cela, handlePaymentSuccess() ne pourra pas créditer le wallet
      WalletPaymentIntegrationService.registerTransactionContext(
        transactionId: transactionId,
        userId: userId,
        amount: amount,
        paymentMethod: paymentMethod,
        phoneNumber: phoneNumber,
      );
      myCustomPrintStatement('📝 Transaction context registered: $transactionId');

      // Mettre à jour l'état global
      _setProcessingState(
        isProcessing: true,
        paymentMethod: paymentMethod,
        transactionId: transactionId,
        amount: amount,
        userId: userId,
        status: TopUpStatus.initiating,
        statusMessage: 'Démarrage du rechargement...',
      );

      bool success = false;
      
      // Déléguer au provider approprié
      switch (paymentMethod) {
        case PaymentMethodType.airtelMoney:
          success = await _initiateAirtelTopUp(amount, phoneNumber ?? '', userId, transactionId);
          break;
          
        case PaymentMethodType.orangeMoney:
          success = await _initiateOrangeTopUp(amount, userId, transactionId);
          break;
          
        case PaymentMethodType.telmaMvola:
          success = await _initiateTelmaTopUp(amount, phoneNumber ?? '', userId, transactionId);
          break;
          
        case PaymentMethodType.creditCard:
          success = await _initiateCreditCardTopUp(amount, userId, transactionId);
          break;
          
        default:
          throw Exception('Méthode de paiement non supportée: ${paymentMethod.value}');
      }
      
      if (success) {
        _setProcessingState(
          isProcessing: true,
          status: TopUpStatus.processing,
          statusMessage: 'Traitement du paiement en cours...',
        );
      } else {
        _resetState();
      }
      
      return success;
    } catch (error) {
      myCustomPrintStatement('Error in WalletTopUpCoordinatorProvider.initiateTopUp: $error');
      showSnackbar('Erreur lors du démarrage du rechargement: $error');
      _resetState();
      return false;
    }
  }

  /// Initie un top-up via Airtel Money
  Future<bool> _initiateAirtelTopUp(double amount, String phoneNumber, String userId, String transactionId) async {
    try {
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final airtelProvider = Provider.of<WalletTopUpAirtelProvider>(context, listen: false);
      
      return await airtelProvider.initiateTopUp(
        amount: amount,
        mobileNumber: phoneNumber,
        userId: userId,
        internalTransactionId: transactionId,
      );
    } catch (error) {
      myCustomPrintStatement('Error initiating Airtel top-up: $error');
      return false;
    }
  }

  /// Initie un top-up via Orange Money
  Future<bool> _initiateOrangeTopUp(double amount, String userId, String transactionId) async {
    try {
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final orangeProvider = Provider.of<WalletTopUpOrangeProvider>(context, listen: false);
      
      return await orangeProvider.initiateTopUp(
        amount: amount,
        userId: userId,
        internalTransactionId: transactionId,
      );
    } catch (error) {
      myCustomPrintStatement('Error initiating Orange top-up: $error');
      return false;
    }
  }

  /// Initie un top-up via Telma MVola
  Future<bool> _initiateTelmaTopUp(double amount, String phoneNumber, String userId, String transactionId) async {
    try {
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final telmaProvider = Provider.of<WalletTopUpTelmaProvider>(context, listen: false);
      
      return await telmaProvider.initiateTopUp(
        amount: amount,
        phoneNumberDebitParty: phoneNumber,
        userId: userId,
        internalTransactionId: transactionId,
      );
    } catch (error) {
      myCustomPrintStatement('Error initiating Telma top-up: $error');
      return false;
    }
  }

  /// Initie un top-up via carte bancaire (simulation)
  Future<bool> _initiateCreditCardTopUp(double amount, String userId, String transactionId) async {
    try {
      myCustomPrintStatement('Initiating credit card top-up simulation: $amount');
      
      // Simulation d'un délai de traitement
      await Future.delayed(const Duration(seconds: 2));
      
      // Pour l'instant, simuler un succès
      // Dans une implémentation réelle, cela ouvrirait une WebView vers Stripe/PayPal
      myCustomPrintStatement('Credit card top-up simulation completed successfully');
      
      return true;
    } catch (error) {
      myCustomPrintStatement('Error initiating credit card top-up: $error');
      return false;
    }
  }

  /// Marque une transaction comme réussie
  void markTransactionSuccess({
    required String transactionId,
    String? externalTransactionId,
  }) {
    if (_currentTransactionId == transactionId) {
      myCustomPrintStatement('WalletTopUpCoordinatorProvider: Transaction marked as successful');
      _setProcessingState(
        isProcessing: false,
        status: TopUpStatus.success,
        statusMessage: 'Rechargement réussi !',
      );
      
      // Réinitialiser après un délai
      Future.delayed(const Duration(seconds: 3), () {
        if (_status == TopUpStatus.success && _currentTransactionId == transactionId) {
          _resetState();
        }
      });
    }
  }

  /// Marque une transaction comme échouée
  void markTransactionFailure({
    required String transactionId,
    String? errorMessage,
  }) {
    if (_currentTransactionId == transactionId) {
      myCustomPrintStatement('WalletTopUpCoordinatorProvider: Transaction marked as failed');
      _setProcessingState(
        isProcessing: false,
        status: TopUpStatus.failed,
        statusMessage: errorMessage ?? 'Rechargement échoué',
      );
      
      // Réinitialiser après un délai
      Future.delayed(const Duration(seconds: 5), () {
        if (_status == TopUpStatus.failed && _currentTransactionId == transactionId) {
          _resetState();
        }
      });
    }
  }

  /// Annule la transaction en cours
  void cancelCurrentTransaction() {
    try {
      if (!_isProcessingTopUp || _currentTransactionId == null) return;
      
      myCustomPrintStatement('WalletTopUpCoordinatorProvider: Cancelling current transaction');
      
      // Annuler dans le provider spécifique selon la méthode
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      
      switch (_currentPaymentMethod) {
        case PaymentMethodType.airtelMoney:
          // L'annulation Airtel se fait via le loader
          break;
          
        case PaymentMethodType.orangeMoney:
          final orangeProvider = Provider.of<WalletTopUpOrangeProvider>(context, listen: false);
          orangeProvider.cancelTransaction();
          break;
          
        case PaymentMethodType.telmaMvola:
          // L'annulation Telma se fait via le loader
          break;
          
        default:
          break;
      }
      
      _setProcessingState(
        isProcessing: false,
        status: TopUpStatus.cancelled,
        statusMessage: 'Transaction annulée',
      );
      
      // Réinitialiser après un délai
      Future.delayed(const Duration(seconds: 2), () {
        _resetState();
      });
      
    } catch (error) {
      myCustomPrintStatement('Error cancelling transaction: $error');
      _resetState();
    }
  }

  /// Met à jour le statut de la transaction
  void updateTransactionStatus({
    required String transactionId,
    required TopUpStatus status,
    String? statusMessage,
  }) {
    if (_currentTransactionId == transactionId) {
      _setProcessingState(
        status: status,
        statusMessage: statusMessage,
      );
    }
  }

  /// Vérifie si une transaction a expiré
  bool isTransactionExpired() {
    if (_transactionStartTime == null) return false;
    return DateTime.now().difference(_transactionStartTime!).inMinutes > 10;
  }

  /// Met à jour l'état du processing
  void _setProcessingState({
    bool? isProcessing,
    PaymentMethodType? paymentMethod,
    String? transactionId,
    double? amount,
    String? userId,
    TopUpStatus? status,
    String? statusMessage,
  }) {
    if (isProcessing != null) _isProcessingTopUp = isProcessing;
    if (paymentMethod != null) _currentPaymentMethod = paymentMethod;
    if (transactionId != null) _currentTransactionId = transactionId;
    if (amount != null) _currentAmount = amount;
    if (userId != null) _currentUserId = userId;
    if (status != null) _status = status;
    if (statusMessage != null) _statusMessage = statusMessage;
    
    if (isProcessing == true && _transactionStartTime == null) {
      _transactionStartTime = DateTime.now();
    }
    
    notifyListeners();
  }

  /// Réinitialise l'état
  void _resetState() {
    _isProcessingTopUp = false;
    _currentPaymentMethod = null;
    _currentTransactionId = null;
    _currentAmount = null;
    _currentUserId = null;
    _transactionStartTime = null;
    _statusMessage = '';
    _status = TopUpStatus.idle;
    notifyListeners();
  }

  /// Génère un ID de transaction unique
  String _generateTransactionId() {
    return 'WALLET_TOPUP_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Méthode pour nettoyer les ressources lors de la destruction
  @override
  void dispose() {
    _resetState();
    super.dispose();
  }

  /// Retourne un résumé de la transaction courante
  Map<String, dynamic> getCurrentTransactionSummary() {
    return {
      'isProcessing': _isProcessingTopUp,
      'paymentMethod': _currentPaymentMethod?.value,
      'transactionId': _currentTransactionId,
      'amount': _currentAmount,
      'userId': _currentUserId,
      'status': _status.toString(),
      'statusMessage': _statusMessage,
      'startTime': _transactionStartTime?.toIso8601String(),
      'isExpired': isTransactionExpired(),
    };
  }
}

/// Énumération des statuts de top-up
enum TopUpStatus {
  idle,           // Aucune transaction
  initiating,     // Démarrage de la transaction
  processing,     // Transaction en cours
  success,        // Transaction réussie
  failed,         // Transaction échouée
  cancelled,      // Transaction annulée
  timeout,        // Transaction expirée
}