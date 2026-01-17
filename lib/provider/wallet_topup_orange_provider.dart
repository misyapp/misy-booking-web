import 'package:flutter/material.dart';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/view_module/open_payment_webview.dart';
import 'package:rider_ride_hailing_app/services/wallet_payment_integration_service.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

/// Provider dédié au top-up de portefeuille via Orange Money
/// Basé sur OrangeMoneyPaymentGatewayProvider mais adapté pour les top-ups
/// de portefeuille sans dépendance sur TripProvider
class WalletTopUpOrangeProvider with ChangeNotifier {
  final String _orangeMoneyBaseUrl = "https://api.orange.com/";
  
  // État du provider
  String accessToken = "";
  String orderId = "";
  String payToken = "";
  String paymentUrl = "";
  bool isProcessingPayment = false;
  
  // Contexte de top-up actuel
  WalletTopUpOrangeContext? currentContext;
  
  // Timer pour vérifier le statut
  Timer? _statusCheckTimer;

  /// Génère un token d'accès Orange Money
  /// Identique à la méthode originale
  Future<Map<String, dynamic>?> generateAccessToken() async {
    Uri apiUrl = Uri.parse("${_orangeMoneyBaseUrl}oauth/v3/token");
    var headers = {
      'Authorization':
          'Basic ${paymentGateWaySecretKeys!.orangeMoneyApiSecretKey}',
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    var body = {"grant_type": "client_credentials"};
    final encodedBody = body.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    try {
      myCustomPrintStatement('WalletTopUpOrangeProvider: Generating access token');
      var response =
          await http.post(apiUrl, body: encodedBody, headers: headers);
      
      if (response.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(response.body);
        myCustomPrintStatement("Orange access token generated successfully");
        accessToken = jsonResponse['access_token'];
        return jsonResponse;
      } else {
        var jsonResponse = convert.jsonDecode(response.body);
        showSnackbar("[${response.statusCode}] ${jsonResponse['description']}");
        return null;
      }
    } catch (error) {
      myCustomPrintStatement('Error generating Orange access token: $error');
      showSnackbar("Erreur d'API Orange: $error");
      return null;
    }
  }

  /// Initie un top-up de portefeuille via Orange Money
  /// Adapté de generatePaymentRequest mais pour les top-ups
  Future<bool> initiateTopUp({
    required double amount,
    required String userId,
    required String internalTransactionId,
  }) async {
    try {
      myCustomPrintStatement('WalletTopUpOrangeProvider: Initiating top-up for $amount MGA');
      
      if (isProcessingPayment) {
        showSnackbar('Une transaction est déjà en cours');
        return false;
      }
      
      isProcessingPayment = true;
      notifyListeners();
      
      // Générer le token d'accès
      var tokenResult = await generateAccessToken();
      if (tokenResult == null) {
        throw Exception('Failed to generate access token');
      }
      
      // Créer l'ID de commande
      orderId = generateUUID();
      
      // Créer le contexte de transaction
      currentContext = WalletTopUpOrangeContext(
        userId: userId,
        amount: amount,
        paymentMethod: PaymentMethodType.orangeMoney,
        transactionId: internalTransactionId,
        orderId: orderId,
        createdAt: DateTime.now(),
      );
      
      // Préparer la requête de paiement web
      Uri apiUrl =
          Uri.parse("${_orangeMoneyBaseUrl}orange-money-webpay/mg/v1/webpayment");
      
      Map<String, dynamic> body = {
        "merchant_key": paymentGateWaySecretKeys!.orangeMoneyMerchantKey,
        "currency": "MGA",
        "order_id": orderId,
        "amount": amount.toString(),
        "return_url": "http://myvirtualshop.webnode.es",
        "cancel_url": "http://myvirtualshop.webnode.es/txncncld/",
        "notif_url": "http://www.merchant-example2.org/notif",
        "lang": "fr",
        "reference": "Recharge Portefeuille Misy"
      };
      
      var headers = {
        'Accept': '*/*',
        'Cache-Control': 'no-cache',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      
      myCustomPrintStatement('Sending Orange payment request: $body');
      var response = await http.post(apiUrl,
          body: convert.jsonEncode(body), headers: headers);
      
      if (response.statusCode == 201) {
        var jsonResponse = convert.jsonDecode(response.body);
        payToken = jsonResponse['pay_token'];
        paymentUrl = jsonResponse['payment_url'];
        
        // Mettre à jour le contexte avec les informations Orange
        currentContext = currentContext!.copyWith(
          payToken: payToken,
          paymentUrl: paymentUrl,
          notifyToken: jsonResponse['notif_token'],
        );
        
        myCustomPrintStatement('Orange payment URL generated: $paymentUrl');
        
        // Ouvrir la WebView pour le paiement
        await _openPaymentWebView();
        
        // Commencer la vérification du statut
        _startStatusChecking();
        
        return true;
      } else if (response.statusCode == 200) {
        // Cas particulier Orange (parfois retourne 200 au lieu de 201)
        var jsonResponse = convert.jsonDecode(response.body);
        if (jsonResponse.containsKey('pay_token')) {
          payToken = jsonResponse['pay_token'];
          paymentUrl = jsonResponse['payment_url'];
          
          currentContext = currentContext!.copyWith(
            payToken: payToken,
            paymentUrl: paymentUrl,
            notifyToken: jsonResponse['notif_token'],
          );
          
          await _openPaymentWebView();
          _startStatusChecking();
          
          return true;
        }
      }
      
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (error) {
      myCustomPrintStatement('Error initiating Orange top-up: $error');
      showSnackbar("Erreur lors du démarrage du paiement: $error");
      isProcessingPayment = false;
      notifyListeners();
      return false;
    }
  }

  /// Ouvre la WebView pour le paiement Orange
  Future<void> _openPaymentWebView() async {
    if (paymentUrl.isEmpty) return;
    
    try {
      await push(
        context: MyGlobalKeys.navigatorKey.currentContext!,
        screen: OpenPaymentWebview(
          webViewUrl: paymentUrl,
          onCancellation: () {
            myCustomPrintStatement("Orange Money wallet top-up cancelled by user");
            cancelTransaction();
          },
        ),
      );
      
      // Démarrer le timer pour vérifier le statut
      _startStatusChecking();
    } catch (error) {
      myCustomPrintStatement('Error opening Orange payment WebView: $error');
      showSnackbar('Erreur lors de l\'ouverture du navigateur de paiement');
    }
  }

  /// Démarre la vérification périodique du statut
  void _startStatusChecking() {
    if (currentContext == null) return;
    
    myCustomPrintStatement('Starting Orange status checking for order: ${currentContext!.orderId}');
    
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _checkTransactionStatus();
    });
    
    // Arrêter après 10 minutes maximum
    Future.delayed(const Duration(minutes: 10), () {
      _stopStatusChecking();
      if (isProcessingPayment) {
        _handlePaymentTimeout();
      }
    });
  }

  /// Arrête la vérification du statut
  void _stopStatusChecking() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  /// Vérifie le statut de la transaction Orange
  /// Adapté de checkTranscationStatus mais avec callbacks vers WalletPaymentIntegrationService
  Future<void> _checkTransactionStatus() async {
    if (currentContext == null || !isProcessingPayment) return;

    try {
      myCustomPrintStatement("Checking Orange transaction status for order: ${currentContext!.orderId}");

      Uri apiUrl = Uri.parse(
          "${_orangeMoneyBaseUrl}orange-money-webpay/mg/v1/transactionstatus");

      var headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

      var body = {
        "order_id": currentContext!.orderId,
        "amount": currentContext!.amount.toString(),
        "pay_token": currentContext!.payToken ?? '',
      };

      var response = await http.post(apiUrl,
          headers: headers, body: convert.jsonEncode(body));

      myCustomPrintStatement(
          "Orange status check response: ${response.statusCode} ${response.body}");

      if (response.statusCode == 401 || response.statusCode == 403) {
        // Token expiré, regénérer
        await generateAccessToken();
        // Ne pas rappeler immédiatement, le timer s'en chargera
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        var jsonResponse = convert.jsonDecode(response.body);
        String status = jsonResponse['status'] ?? '';

        // Statuts Orange Money:
        // SUCCESS = Transaction réussie
        // FAILED = Transaction échouée
        // EXPIRED = Transaction expirée
        // INITIATED, PENDING = Transaction en cours
        // NOT FOUND = Transaction pas encore créée côté Orange

        if (status == "SUCCESS") {
          _stopStatusChecking();
          await _handlePaymentSuccess(jsonResponse);
        } else if (status == "FAILED") {
          _stopStatusChecking();
          await _handlePaymentFailure("La transaction a échoué");
        } else if (status == "EXPIRED") {
          _stopStatusChecking();
          await _handlePaymentFailure("La transaction a expiré");
        } else if (status == "NOT FOUND") {
          // Transaction pas encore créée, continuer à vérifier
          myCustomPrintStatement("Orange transaction NOT FOUND - will retry...");
        }
        // Pour INITIATED et PENDING, le timer continuera de vérifier
      }
    } catch (error) {
      myCustomPrintStatement('Error checking Orange transaction status: $error');
      // Ne pas échouer immédiatement, le timer réessaiera
    }
  }


  /// Gère le succès du paiement
  Future<void> _handlePaymentSuccess(Map<String, dynamic> response) async {
    try {
      myCustomPrintStatement('Orange payment successful');
      
      if (currentContext == null) return;
      
      // Nettoyer le processus
      _cleanupPaymentProcess();
      
      // Appeler le service d'intégration pour créditer le portefeuille
      await WalletPaymentIntegrationService.handlePaymentSuccess(
        transactionId: currentContext!.transactionId,
        externalTransactionId: currentContext!.orderId,
        paymentMethod: PaymentMethodType.orangeMoney,
        additionalData: {
          'orange_order_id': currentContext!.orderId,
          'orange_pay_token': currentContext!.payToken,
          'orange_payment_url': currentContext!.paymentUrl,
          'response_data': response,
        },
      );
      
      // Réinitialiser le contexte
      currentContext = null;
      
    } catch (error) {
      myCustomPrintStatement('Error handling Orange payment success: $error');
      showSnackbar('Erreur lors du traitement du paiement réussi');
    }
  }

  /// Gère l'échec du paiement
  Future<void> _handlePaymentFailure(String errorMessage) async {
    try {
      myCustomPrintStatement('Orange payment failed: $errorMessage');
      
      // Nettoyer le processus
      _cleanupPaymentProcess();
      
      if (currentContext != null) {
        // Appeler le service d'intégration pour enregistrer l'échec
        await WalletPaymentIntegrationService.handlePaymentFailure(
          transactionId: currentContext!.transactionId,
          paymentMethod: PaymentMethodType.orangeMoney,
          errorMessage: errorMessage,
          additionalData: {
            'orange_order_id': currentContext!.orderId,
            'orange_pay_token': currentContext!.payToken,
          },
        );
      }
      
      // Réinitialiser le contexte
      currentContext = null;
      
      showSnackbar('Paiement Orange échoué: $errorMessage');
      
    } catch (error) {
      myCustomPrintStatement('Error handling Orange payment failure: $error');
    }
  }

  /// Gère le timeout du paiement
  void _handlePaymentTimeout() {
    myCustomPrintStatement('Orange payment timeout');
    _handlePaymentFailure('Délai de paiement dépassé (10 minutes)');
  }

  /// Annule la transaction en cours
  void cancelTransaction() {
    myCustomPrintStatement('Cancelling Orange transaction');
    
    // Nettoyer le processus
    _cleanupPaymentProcess();
    
    if (currentContext != null) {
      WalletPaymentIntegrationService.cancelWalletTopUp(currentContext!.transactionId);
      currentContext = null;
    }
    
    showSnackbar('Transaction annulée');
  }

  /// Nettoie le processus de paiement
  void _cleanupPaymentProcess() {
    _stopStatusChecking();
    isProcessingPayment = false;
    notifyListeners();
  }

  /// Génère un UUID unique
  String generateUUID() {
    String uuid = const Uuid().v4();
    uuid = uuid.split("-").join("");
    if (uuid.length > 20) {
      uuid = uuid.substring(0, 20);
    }
    return uuid;
  }

  /// Dispose du provider
  @override
  void dispose() {
    _cleanupPaymentProcess();
    super.dispose();
  }
}

/// Contexte d'une transaction de top-up Orange
class WalletTopUpOrangeContext {
  final String userId;
  final double amount;
  final PaymentMethodType paymentMethod;
  final String transactionId; // ID interne
  final String orderId; // ID Orange
  final String? payToken;
  final String? paymentUrl;
  final String? notifyToken;
  final DateTime createdAt;

  const WalletTopUpOrangeContext({
    required this.userId,
    required this.amount,
    required this.paymentMethod,
    required this.transactionId,
    required this.orderId,
    this.payToken,
    this.paymentUrl,
    this.notifyToken,
    required this.createdAt,
  });

  WalletTopUpOrangeContext copyWith({
    String? payToken,
    String? paymentUrl,
    String? notifyToken,
  }) {
    return WalletTopUpOrangeContext(
      userId: userId,
      amount: amount,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      orderId: orderId,
      payToken: payToken ?? this.payToken,
      paymentUrl: paymentUrl ?? this.paymentUrl,
      notifyToken: notifyToken ?? this.notifyToken,
      createdAt: createdAt,
    );
  }

  bool get isExpired {
    return DateTime.now().difference(createdAt).inMinutes > 10;
  }

  @override
  String toString() {
    return 'WalletTopUpOrangeContext(userId: $userId, amount: $amount, '
           'paymentMethod: ${paymentMethod.value}, transactionId: $transactionId, '
           'orderId: $orderId, createdAt: $createdAt)';
  }
}