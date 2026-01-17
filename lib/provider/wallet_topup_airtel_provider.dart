import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/services/wallet_payment_integration_service.dart';
import 'package:rider_ride_hailing_app/widget/show_payment_proccess_loader.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'dart:convert' as convert;
import 'package:uuid/uuid.dart';

/// Provider dédié au top-up de portefeuille via Airtel Money
/// Basé sur AirtelMoneyPaymentGatewayProvider mais adapté pour les top-ups
/// de portefeuille sans dépendance sur TripProvider
class WalletTopUpAirtelProvider with ChangeNotifier {
  // Proxy URL pour contourner le whitelisting IP Airtel
  // Le proxy route les requêtes depuis une IP fixe (51.68.26.125)
  final String _proxyBaseUrl = "https://payment.misy.app";
  final String _proxyApiKey = "misy-airtel-proxy-8be62e8873d96869d595043ddc66fba1";

  // État du provider
  bool showPaymentLoader = false;
  bool checkPaymentStatus = false;
  String accessToken = "";
  String transactionID = "";
  
  // Contexte de top-up actuel
  WalletTopUpContext? currentContext;

  /// Génère un token d'accès Airtel Money via le proxy
  Future<Map<String, dynamic>?> generateAccessToken() async {
    // Utilisation du proxy pour contourner le whitelisting IP
    Uri apiUrl = Uri.parse("$_proxyBaseUrl/api/airtel/token");
    var headers = {
      'Content-Type': 'application/json',
      'X-API-Key': _proxyApiKey,
    };
    var request = {
      "client_id": paymentGateWaySecretKeys!.airtelMoneyClientId,
      "client_secret": paymentGateWaySecretKeys!.airtelMoneyClientSecret,
    };

    try {
      myCustomPrintStatement('WalletTopUpAirtelProvider: Generating access token via proxy');
      var response = await http.post(apiUrl,
          body: convert.jsonEncode(request), headers: headers);

      var jsonResponse = convert.jsonDecode(response.body);
      if (response.statusCode == 200) {
        myCustomPrintStatement("Airtel access token generated successfully via proxy");
        accessToken = jsonResponse['access_token'];
        return jsonResponse;
      }

      if (response.statusCode == 400) {
        showSnackbar(
            "Erreur d'authentification Airtel: ${jsonResponse['error_description'] ?? jsonResponse['error'] ?? 'Erreur inconnue'}");
      }
      return null;
    } catch (error) {
      myCustomPrintStatement('Error generating Airtel access token: $error');
      showSnackbar("Erreur d'API Airtel: $error");
      return null;
    }
  }

  /// Initie un top-up de portefeuille via Airtel Money
  /// Adapté de generatePaymentRequest mais pour les top-ups
  Future<bool> initiateTopUp({
    required double amount,
    required String mobileNumber,
    required String userId,
    required String internalTransactionId,
  }) async {
    try {
      myCustomPrintStatement('WalletTopUpAirtelProvider: Initiating top-up for $amount MGA');
      
      // Formater le numéro de téléphone
      if (mobileNumber.startsWith('0')) {
        mobileNumber = mobileNumber.substring(1);
      }
      
      // Générer le token d'accès
      var tokenResult = await generateAccessToken();
      if (tokenResult == null) {
        throw Exception('Failed to generate access token');
      }
      
      // Créer le contexte de transaction
      transactionID = generateUUID();
      currentContext = WalletTopUpContext(
        userId: userId,
        amount: amount,
        paymentMethod: PaymentMethodType.airtelMoney,
        transactionId: internalTransactionId,
        externalTransactionId: transactionID,
        phoneNumber: mobileNumber,
        createdAt: DateTime.now(),
      );
      
      // Préparer la requête de paiement via le proxy
      Uri apiUrl = Uri.parse("$_proxyBaseUrl/api/airtel/payment");
      Map<String, dynamic> body = {
        "access_token": accessToken,
        "reference": "Recharge Portefeuille Misy",
        "subscriber": {
          "country": "MG",
          "currency": "MGA",
          "msisdn": mobileNumber
        },
        "transaction": {
          "amount": amount,
          "country": "MG",
          "currency": "MGA",
          "id": transactionID
        }
      };

      var headers = {
        'Content-Type': 'application/json',
        'X-API-Key': _proxyApiKey,
      };

      myCustomPrintStatement('Sending Airtel payment request via proxy: $body');
      var response = await http.post(apiUrl,
          body: convert.jsonEncode(body), headers: headers);
      
      if (response.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(response.body);
        
        if (jsonResponse['status']['result_code'] == "ESB000010" &&
            jsonResponse['status']['success'] == true) {
          
          showSnackbar(
              "Demande de paiement envoyée. Veuillez confirmer sur votre téléphone.");
          
          // Commencer la vérification du statut
          Future.delayed(const Duration(seconds: 3), () async {
            checkPaymentStatus = true;
            await _checkTransactionStatus();
          });
          
          return true;
        } else {
          _handleAirtelErrorCode(jsonResponse['status']['result_code']);
          return false;
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      myCustomPrintStatement('Error initiating Airtel top-up: $error');
      showSnackbar("Erreur lors du démarrage du paiement: $error");
      return false;
    }
  }

  /// Vérifie le statut de la transaction
  /// Adapté de checkTranscationStatus mais avec callbacks vers WalletPaymentIntegrationService
  Future<void> _checkTransactionStatus() async {
    if (!checkPaymentStatus || currentContext == null) return;
    
    if (!showPaymentLoader) {
      showPaymentLoader = true;
      showPaymentProccessLoader(
        onTap: () {
          _cancelTransaction();
        },
      );
    }
    
    try {
      myCustomPrintStatement("Checking Airtel transaction status via proxy: $transactionID");
      // Utilisation du proxy pour contourner le whitelisting IP
      Uri apiUrl = Uri.parse("$_proxyBaseUrl/api/airtel/status/$transactionID");
      var headers = {
        'X-API-Key': _proxyApiKey,
        'Authorization': 'Bearer $accessToken',
      };

      var response = await http.get(apiUrl, headers: headers);
      
      if (response.statusCode == 401 || response.statusCode == 403) {
        await generateAccessToken();
        await _checkTransactionStatus();
        return;
      }
      
      if (response.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(response.body);
        myCustomPrintStatement(
            "Airtel transaction status response: ${response.statusCode} $jsonResponse");
        
        if (jsonResponse['status']['result_code'] == "ESB000010" &&
            jsonResponse['status']['success'] == true) {
          
          String transactionStatus = jsonResponse['data']['transaction']['status'];

          // Statuts Airtel Money:
          // TS = Transaction Success (succès)
          // TF = Transaction Failed (échec)
          // TIP = Transaction In Progress (en cours)
          if (transactionStatus == "TS") {
            // Transaction réussie
            await _handlePaymentSuccess(jsonResponse);
          } else if (transactionStatus == "TF") {
            // Transaction échouée
            await _handlePaymentFailure(
                jsonResponse['data']['transaction']['message'] ?? 'Transaction échouée');
          } else if (transactionStatus == "TIP") {
            // Transaction en cours, continuer la vérification
            Future.delayed(
              const Duration(seconds: 8),
              () async {
                await _checkTransactionStatus();
              },
            );
          }
        }
      } else {
        throw Exception('Status check failed: ${response.statusCode}');
      }
    } catch (error) {
      myCustomPrintStatement('Error checking Airtel transaction status: $error');
      await _handlePaymentFailure("Erreur de vérification: $error");
    }
  }

  /// Gère le succès du paiement
  Future<void> _handlePaymentSuccess(Map<String, dynamic> response) async {
    try {
      myCustomPrintStatement('Airtel payment successful');
      
      String airtelTransactionId = response['data']['transaction']['airtel_money_id'];
      
      // Nettoyer l'UI
      _cleanupPaymentProcess();
      
      // Appeler le service d'intégration pour créditer le portefeuille
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
      
      // Réinitialiser le contexte
      currentContext = null;
      
    } catch (error) {
      myCustomPrintStatement('Error handling Airtel payment success: $error');
      showSnackbar('Erreur lors du traitement du paiement réussi');
    }
  }

  /// Gère l'échec du paiement
  Future<void> _handlePaymentFailure(String errorMessage) async {
    try {
      myCustomPrintStatement('Airtel payment failed: $errorMessage');
      
      // Nettoyer l'UI
      _cleanupPaymentProcess();
      
      if (currentContext != null) {
        // Appeler le service d'intégration pour enregistrer l'échec
        await WalletPaymentIntegrationService.handlePaymentFailure(
          transactionId: currentContext!.transactionId,
          paymentMethod: PaymentMethodType.airtelMoney,
          errorMessage: errorMessage,
          additionalData: {
            'airtel_transaction_id': transactionID,
            'phone_number': currentContext!.phoneNumber,
          },
        );
      }
      
      // Réinitialiser le contexte
      currentContext = null;
      
    } catch (error) {
      myCustomPrintStatement('Error handling Airtel payment failure: $error');
    }
  }

  /// Annule la transaction en cours
  void _cancelTransaction() {
    myCustomPrintStatement('Cancelling Airtel transaction');
    
    // Nettoyer l'UI
    _cleanupPaymentProcess();
    
    if (currentContext != null) {
      WalletPaymentIntegrationService.cancelWalletTopUp(currentContext!.transactionId);
      currentContext = null;
    }
    
    showSnackbar('Transaction annulée');
  }

  /// Nettoie le processus de paiement
  void _cleanupPaymentProcess() {
    checkPaymentStatus = false;
    if (showPaymentLoader) {
      hidePaymentProccessLoader();
      showPaymentLoader = false;
    }
    notifyListeners();
  }

  /// Gère les codes d'erreur spécifiques à Airtel
  void _handleAirtelErrorCode(String resultCode) {
    Map<String, String> errorMessages = {
      "ESB000001": "Une erreur s'est produite. Veuillez faire une enquête de transaction.",
      "ESB000004": "Erreur lors de l'initiation du paiement.",
      "ESB000011": "La demande a échoué.",
      "ESB000014": "Erreur lors de la récupération du statut de transaction.",
      "ESB000033": "Longueur MSISDN invalide.",
      "ESB000034": "Nom de pays invalide.",
      "ESB000035": "Code de devise invalide.",
      "ESB000036": "MSISDN invalide ou ne commence pas par 0.",
      "ESB000039": "Vendeur non configuré pour ce pays.",
      "ESB000041": "Transaction avec cet ID externe existe déjà.",
      "ESB000045": "Aucune transaction trouvée avec cet ID.",
      "0000900": "Transaction dans un état ambigu. Veuillez réessayer.",
    };
    
    String message = errorMessages[resultCode] ?? "Erreur inconnue: $resultCode";
    showSnackbar("[$resultCode] $message");
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

/// Contexte d'une transaction de top-up Airtel
class WalletTopUpContext {
  final String userId;
  final double amount;
  final PaymentMethodType paymentMethod;
  final String transactionId; // ID interne
  final String externalTransactionId; // ID Airtel
  final String? phoneNumber;
  final DateTime createdAt;

  const WalletTopUpContext({
    required this.userId,
    required this.amount,
    required this.paymentMethod,
    required this.transactionId,
    required this.externalTransactionId,
    this.phoneNumber,
    required this.createdAt,
  });

  bool get isExpired {
    return DateTime.now().difference(createdAt).inMinutes > 10;
  }

  @override
  String toString() {
    return 'WalletTopUpContext(userId: $userId, amount: $amount, '
           'paymentMethod: ${paymentMethod.value}, transactionId: $transactionId, '
           'externalTransactionId: $externalTransactionId, createdAt: $createdAt)';
  }
}