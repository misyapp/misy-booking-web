import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'dart:convert' as convert;
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/users_log_modal.dart';
import 'package:rider_ride_hailing_app/services/user_log_store_service.dart';
import 'package:rider_ride_hailing_app/services/wallet_payment_integration_service.dart';
import 'package:rider_ride_hailing_app/widget/show_payment_proccess_loader.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:uuid/uuid.dart';

/// Provider dédié au top-up de portefeuille via Telma MVola
/// Basé sur TelmaMoneyPaymentGatewayProvider mais adapté pour les top-ups
/// de portefeuille sans dépendance sur TripProvider
class WalletTopUpTelmaProvider with ChangeNotifier {
  // URLs API Telma MVola
  final String _telmaMvolaMoneyBaseUrl = "https://api.mvola.mg/";
  
  // Services
  UserLogStoreService sQLServices = UserLogStoreService();
  
  // État du provider
  String accessToken = "";
  String correlationID = "";
  String serverCorrelationId = "";
  String merchantPhoneNumber = "0384219719";
  String objectReferenceId = "";
  bool showPaymentLoader = false;
  bool checkPaymentStatus = false;
  bool isProcessingPayment = false;
  
  // Contexte de top-up actuel
  WalletTopUpTelmaContext? currentContext;

  /// Génère un token d'accès Telma MVola
  /// Identique à la méthode originale
  Future<Map<String, dynamic>?> generateAccessToken() async {
    Uri apiUrl = Uri.parse("${_telmaMvolaMoneyBaseUrl}token");
    String uuid = generateUUID();
    
    var headers = {
      'Authorization':
          'Basic ${stringToBase64("${paymentGateWaySecretKeys!.telmaConsumerKey}:${paymentGateWaySecretKeys!.telmaConsumerSecretKey}")}',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Cache-Control': 'no-cache'
    };
    
    try {
      myCustomPrintStatement('WalletTopUpTelmaProvider: Generating access token');
      var response = await http.post(apiUrl,
          body: {
            'grant_type': 'client_credentials',
            "scope": "EXT_INT_MVOLA_SCOPE device_$uuid"
          },
          headers: headers);
      
      sQLServices.insertUserLog(
        usersLogModal: UsersLogModal(
          userId: "110011",
          date: DateTime.now().toString(),
          logString:
              "[${response.statusCode}] Telma token API: ${apiUrl.toString()} - ${response.body}",
        ),
      );
      
      if (response.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(response.body);
        myCustomPrintStatement("Telma access token generated successfully");
        accessToken = jsonResponse['access_token'];
        return jsonResponse;
      } else {
        showSnackbar("Erreur d'authentification Telma MVola");
        return null;
      }
    } catch (error) {
      myCustomPrintStatement('Error generating Telma access token: $error');
      showSnackbar("Erreur d'API Telma: $error");
      return null;
    }
  }

  /// Initie un top-up de portefeuille via Telma MVola
  /// Adapté de generatePaymentRequest mais pour les top-ups
  Future<bool> initiateTopUp({
    required double amount,
    required String phoneNumberDebitParty,
    required String userId,
    required String internalTransactionId,
  }) async {
    try {
      myCustomPrintStatement('WalletTopUpTelmaProvider: Initiating top-up for $amount MGA');
      
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
      
      // Créer l'ID de corrélation
      correlationID = generateUUID();
      
      // Créer le contexte de transaction
      currentContext = WalletTopUpTelmaContext(
        userId: userId,
        amount: amount,
        paymentMethod: PaymentMethodType.telmaMvola,
        transactionId: internalTransactionId,
        correlationId: correlationID,
        phoneNumber: phoneNumberDebitParty,
        createdAt: DateTime.now(),
      );
      
      // Préparer la requête de paiement
      Uri apiUrl = Uri.parse(
          "${_telmaMvolaMoneyBaseUrl}mvola/mm/transactions/type/merchantpay/1.0.0/");
      
      Map<String, dynamic> body = {
        "amount": double.parse(formatNearest(amount))
            .toInt()
            .toString(),
        "currency": "Ar",
        "descriptionText": "Recharge Portefeuille Misy",
        "requestingOrganisationTransactionReference": "MISY_WALLET_${correlationID.substring(0, 8)}",
        "originalTransactionReference": "WALLET_TOPUP_${DateTime.now().millisecondsSinceEpoch}",
        "requestDate":
            "${DateFormat('yyyy-MM-ddTHH:mm:ss.SSS').format(DateTime.now())}Z",
        "debitParty": [
          {"key": "msisdn", "value": phoneNumberDebitParty}
        ],
        "creditParty": [
          {"key": "msisdn", "value": merchantPhoneNumber}
        ],
        "metadata": [
          {"key": "partnerName", "value": "Misy"},
          {"key": "fc", "value": "USD"}, // Cohérence avec le provider qui fonctionne
          {
            "key": "amountFc",
            "value": amount
          },
          {"key": "transactionType", "value": "wallet_topup"}
        ]
      };
      
      var headers = {
        'accept': '*/*',
        'Version': '1.0.0', // Cohérence avec le provider qui fonctionne
        'X-CorrelationID': correlationID,
        'UserAccountIdentifier': 'msisdn;$merchantPhoneNumber', // Header manquant - REQUIS
        'partnerName': 'Misy', // Header manquant - REQUIS
        'UserLanguage': selectedLanguageNotifier.value['key'] == 'mg' ||
                selectedLanguageNotifier.value['key'] == 'en'
            ? 'MG'
            : 'FR',
        'Cache-Control': 'no-cache',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      
      myCustomPrintStatement('Sending Telma payment request: ${convert.jsonEncode(body)}');
      var response = await http.post(apiUrl,
          body: convert.jsonEncode(body), headers: headers);
      
      sQLServices.insertUserLog(
        usersLogModal: UsersLogModal(
          userId: userId,
          date: DateTime.now().toString(),
          logString:
              "[${response.statusCode}] Telma payment API: ${apiUrl.toString()} - ${response.body}",
        ),
      );
      
      var jsonResponse = convert.jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        showSnackbar("Demande de paiement créée avec succès");
        return true;
      } else if (response.statusCode == 202) {
        myCustomPrintStatement(
            "Telma payment request accepted: ${response.statusCode} $jsonResponse");
        
        // Récupérer les informations de la réponse
        if (jsonResponse.containsKey('serverCorrelationId')) {
          serverCorrelationId = jsonResponse['serverCorrelationId'];
        }
        if (jsonResponse.containsKey('objectReference')) {
          objectReferenceId = jsonResponse['objectReference'];
        }
        
        // Mettre à jour le contexte avec les informations Telma
        currentContext = currentContext!.copyWith(
          serverCorrelationId: serverCorrelationId,
          objectReferenceId: objectReferenceId,
        );
        
        showSnackbar(
            "Demande de paiement envoyée. Veuillez confirmer sur votre téléphone MVola.");
        
        // Commencer la vérification du statut
        Future.delayed(const Duration(seconds: 5), () async {
          checkPaymentStatus = true;
          await _checkTransactionStatus();
        });
        
        return true;
      } else if (response.statusCode == 400) {
        _handleTelmaErrorResponse(jsonResponse);
        return false;
      } else if (response.statusCode == 403) {
        showSnackbar("Accès refusé. Vérifiez vos identifiants MVola.");
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      myCustomPrintStatement('Error initiating Telma top-up: $error');
      showSnackbar("Erreur lors du démarrage du paiement: $error");
      isProcessingPayment = false;
      notifyListeners();
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
      myCustomPrintStatement("Checking Telma transaction status: serverCorrelationId=$serverCorrelationId, correlationID=$correlationID");

      // URL correcte: utiliser /status/ et serverCorrelationId (pas correlationID)
      Uri apiUrl = Uri.parse(
          "${_telmaMvolaMoneyBaseUrl}mvola/mm/transactions/type/merchantpay/1.0.0/status/$serverCorrelationId");

      var headers = {
        'accept': '*/*',
        'Version': '1.0.0',
        'X-CorrelationID': correlationID,
        'UserAccountIdentifier': 'msisdn;$merchantPhoneNumber',
        'partnerName': 'Misy',
        'UserLanguage': selectedLanguageNotifier.value['key'] == 'mg' ||
                selectedLanguageNotifier.value['key'] == 'en'
            ? 'MG'
            : 'FR',
        'Cache-Control': 'no-cache',
        'Authorization': 'Bearer $accessToken',
      };
      
      var response = await http.get(apiUrl, headers: headers);
      
      sQLServices.insertUserLog(
        usersLogModal: UsersLogModal(
          userId: currentContext!.userId,
          date: DateTime.now().toString(),
          logString:
              "[${response.statusCode}] Telma status check: ${apiUrl.toString()} - ${response.body}",
        ),
      );
      
      if (response.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(response.body);
        myCustomPrintStatement(
            "Telma transaction status response: ${response.statusCode} $jsonResponse");

        // Les statuts MVola sont en minuscules: 'completed', 'failed', 'pending'
        String transactionStatus = (jsonResponse['status'] ?? 'pending').toString().toLowerCase();

        if (transactionStatus == 'completed') {
          // Transaction réussie
          await _handlePaymentSuccess(jsonResponse);
        } else if (transactionStatus == 'failed') {
          // Transaction échouée
          String errorMessage = jsonResponse['errorInformation']?['errorDescription'] ?? 'Transaction échouée';
          await _handlePaymentFailure(errorMessage);
        } else if (transactionStatus == 'pending') {
          // Transaction en cours, continuer la vérification
          Future.delayed(
            const Duration(seconds: 5),
            () async {
              if (checkPaymentStatus) {
                await _checkTransactionStatus();
              }
            },
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token expiré, regénérer
        await generateAccessToken();
        await _checkTransactionStatus();
      } else {
        throw Exception('Status check failed: ${response.statusCode} ${response.body}');
      }
    } catch (error) {
      myCustomPrintStatement('Error checking Telma transaction status: $error');
      await _handlePaymentFailure("Erreur de vérification: $error");
    }
  }

  /// Gère le succès du paiement
  Future<void> _handlePaymentSuccess(Map<String, dynamic> response) async {
    try {
      myCustomPrintStatement('Telma payment successful');
      
      String telmaTransactionId = response['transactionId'] ?? correlationID;
      
      // Nettoyer l'UI
      _cleanupPaymentProcess();
      
      // Appeler le service d'intégration pour créditer le portefeuille
      await WalletPaymentIntegrationService.handlePaymentSuccess(
        transactionId: currentContext!.transactionId,
        externalTransactionId: telmaTransactionId,
        paymentMethod: PaymentMethodType.telmaMvola,
        additionalData: {
          'telma_transaction_id': telmaTransactionId,
          'telma_correlation_id': correlationID,
          'telma_server_correlation_id': serverCorrelationId,
          'telma_object_reference_id': objectReferenceId,
          'phone_number': currentContext!.phoneNumber,
          'response_data': response,
        },
      );
      
      // Réinitialiser le contexte
      currentContext = null;
      
    } catch (error) {
      myCustomPrintStatement('Error handling Telma payment success: $error');
      showSnackbar('Erreur lors du traitement du paiement réussi');
    }
  }

  /// Gère l'échec du paiement
  Future<void> _handlePaymentFailure(String errorMessage) async {
    try {
      myCustomPrintStatement('Telma payment failed: $errorMessage');
      
      // Nettoyer l'UI
      _cleanupPaymentProcess();
      
      if (currentContext != null) {
        // Appeler le service d'intégration pour enregistrer l'échec
        await WalletPaymentIntegrationService.handlePaymentFailure(
          transactionId: currentContext!.transactionId,
          paymentMethod: PaymentMethodType.telmaMvola,
          errorMessage: errorMessage,
          additionalData: {
            'telma_correlation_id': correlationID,
            'telma_server_correlation_id': serverCorrelationId,
            'phone_number': currentContext!.phoneNumber,
          },
        );
      }
      
      // Réinitialiser le contexte
      currentContext = null;
      
      showSnackbar('Paiement MVola échoué: $errorMessage');
      
    } catch (error) {
      myCustomPrintStatement('Error handling Telma payment failure: $error');
    }
  }

  /// Annule la transaction en cours
  void _cancelTransaction() {
    myCustomPrintStatement('Cancelling Telma transaction');
    
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
    isProcessingPayment = false;
    if (showPaymentLoader) {
      hidePaymentProccessLoader();
      showPaymentLoader = false;
    }
    notifyListeners();
  }

  /// Gère les réponses d'erreur spécifiques à Telma
  void _handleTelmaErrorResponse(Map<String, dynamic> jsonResponse) {
    if (jsonResponse.containsKey('errorInformation')) {
      var errorInfo = jsonResponse['errorInformation'];
      String errorCode = errorInfo['errorCode'] ?? 'UNKNOWN';
      String errorDescription = errorInfo['errorDescription'] ?? 'Erreur inconnue';
      
      showSnackbar("[$errorCode] $errorDescription");
    } else {
      showSnackbar("Erreur de validation de la demande MVola");
    }
  }

  /// Convertit une chaîne en Base64
  String stringToBase64(String input) {
    convert.Codec<String, String> stringToBase64 =
        convert.utf8.fuse(convert.base64);
    return stringToBase64.encode(input);
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

/// Contexte d'une transaction de top-up Telma
class WalletTopUpTelmaContext {
  final String userId;
  final double amount;
  final PaymentMethodType paymentMethod;
  final String transactionId; // ID interne
  final String correlationId; // ID Telma
  final String? serverCorrelationId;
  final String? objectReferenceId;
  final String? phoneNumber;
  final DateTime createdAt;

  const WalletTopUpTelmaContext({
    required this.userId,
    required this.amount,
    required this.paymentMethod,
    required this.transactionId,
    required this.correlationId,
    this.serverCorrelationId,
    this.objectReferenceId,
    this.phoneNumber,
    required this.createdAt,
  });

  WalletTopUpTelmaContext copyWith({
    String? serverCorrelationId,
    String? objectReferenceId,
  }) {
    return WalletTopUpTelmaContext(
      userId: userId,
      amount: amount,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      correlationId: correlationId,
      serverCorrelationId: serverCorrelationId ?? this.serverCorrelationId,
      objectReferenceId: objectReferenceId ?? this.objectReferenceId,
      phoneNumber: phoneNumber,
      createdAt: createdAt,
    );
  }

  bool get isExpired {
    return DateTime.now().difference(createdAt).inMinutes > 10;
  }

  @override
  String toString() {
    return 'WalletTopUpTelmaContext(userId: $userId, amount: $amount, '
           'paymentMethod: ${paymentMethod.value}, transactionId: $transactionId, '
           'correlationId: $correlationId, createdAt: $createdAt)';
  }
}