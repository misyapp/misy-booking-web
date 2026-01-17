import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/view_module/open_payment_webview.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:math';

class OrangeMoneyPaymentGatewayProvider with ChangeNotifier {
  bool firstTimeTransactionApiCall = true;
  bool _isUserCancelled = false; // Flag pour différencier annulation utilisateur vs erreur
  bool _isTransactionActive = false; // Flag pour arrêter les vérifications de statut en cas d'annulation
  TripProvider tripProvider = Provider.of<TripProvider>(
    MyGlobalKeys.navigatorKey.currentContext!,
    listen: false,
  );
  final String _orangeMoneyBaseUrl = "https://api.orange.com/";
  //1edae91a live app
  //98fa4f03 misy driver app
  // SQLServices sQLServices = SQLServices();
  String acessToken = "";
  String orderId = "";
  String payToken = "";
  String paymentUrl = "";
  Future generateAccessToken() async {
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
      var response =
          await http.post(apiUrl, body: encodedBody, headers: headers);
      // sQLServices.insertUserLog(
      //   usersLogModal: UsersLogModal(
      //     userId: "110011",
      //     date: DateTime.now().toString(),
      //     logString:
      //         "[${response.statusCode}]  Api Url :- ${apiUrl.toString()} header :- $headers response :- ${response.body} ",
      //   ),
      // );

      myCustomLogStatements("[LOG --- api token] $apiUrl header:$headers");
      var jsonResponse = convert.jsonDecode(response.body);
      if (response.statusCode == 200) {
        myCustomPrintStatement("json response for token $jsonResponse ");
        myCustomLogStatements(
            "Api token is that ${jsonResponse['access_token']}");
        acessToken = jsonResponse['access_token'];
        return jsonResponse;
      } else {
        hideLoading();
        var jsonResponse = convert.jsonDecode(response.body);

        showSnackbar("[${response.statusCode}] ${jsonResponse['description']}");
      }
    } catch (error) {
      myCustomPrintStatement('inside double catch block $error');
      showSnackbar("Erreur API : $error");
    }
  }

  Future generatePaymentRequest({
    required String amount,
  }) async {
    showLoading();
    // Réinitialiser les flags au début d'une nouvelle transaction
    _isUserCancelled = false;
    _isTransactionActive = true;
    await generateAccessToken();
    firstTimeTransactionApiCall = false;
    Uri apiUrl =
        Uri.parse("${_orangeMoneyBaseUrl}orange-money-webpay/mg/v1/webpayment");
    orderId = generateUUID();
    Map<String, dynamic> body = {
      "merchant_key": paymentGateWaySecretKeys!.orangeMoneyMerchantKey,
      "currency": "MGA",
      "order_id": orderId,
      "amount": amount,
      "return_url": "http://myvirtualshop.webnode.es",
      "cancel_url": "http://myvirtualshop.webnode.es/txncncld/",
      "notif_url": "http://www.merchant-example2.org/notif",
      "lang": "fr",
      "reference": "Ref Merchant"
    };
    var headers = {
      'Accept': '*/*',
      'Cache-Control': 'no-cache',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $acessToken',
    };
    try {
      myCustomLogStatements(
          "[LOG --- api create payment] $apiUrl header:$headers body is that $body");
      var response = await http.post(apiUrl,
          body: convert.jsonEncode(body), headers: headers);
      // sQLServices.insertUserLog(
      //   usersLogModal: UsersLogModal(
      //     userId: "110011",
      //     date: DateTime.now().toString(),
      //     logString:
      //         "[${response.statusCode}]  Api Url :- ${apiUrl.toString()} header :- $headers response :- ${response.body} ",
      //   ),
      // );
      hideLoading();
      myCustomPrintStatement("the response is that ${response.body}");
      if (response.statusCode == 200) {
        // var jsonResponse = convert.jsonDecode(response.body);
      } else if (response.statusCode == 201) {
        var jsonResponse = convert.jsonDecode(response.body);
        payToken = jsonResponse['pay_token'];
        paymentUrl = jsonResponse['payment_url'];
        FirestoreServices.bookingRequest
            .doc(tripProvider.booking!['id'])
            .update({
          "paymentStatusSummary": {
            "paymentType": PaymentMethodType.orangeMoney.value,
            "status": "INITIATED",
            "payToken": payToken,
            "orderId": orderId,
            "accessToken": acessToken,
            "createAt": Timestamp.now(),
            "paymentUrl": paymentUrl,
            "notifyToken": jsonResponse['notif_token']
          }
        });
        checkTranscationStatus(amount: amount);
        // Navigator.push(
        //     MyGlobalKeys.navigatorKey.currentContext!,
        //     MaterialPageRoute(
        //       builder: (context) => OpenPaymentWebview(
        //         webViewUrl: paymentUrl,
        //       ),
        //     ));
        push(
          context: MyGlobalKeys.navigatorKey.currentContext!,
          screen: OpenPaymentWebview(
            webViewUrl: paymentUrl,
            onCancellation: () {
              myCustomPrintStatement("Orange Money payment cancelled by user");
              // Annuler la transaction Orange Money
              _cancelOrangeTransaction();
            },
          ),
        );
      } else {
        // var jsonResponse = convert.jsonDecode(response.body);

        // showSnackbar(
        //     "[${response.statusCode}] [${jsonResponse['code']}] ${jsonResponse['description']}");
      }
    } catch (error) {
      myCustomPrintStatement('inside double catch block $error');
      showSnackbar("Erreur API : $error");
    }
  }

  Future checkTranscationStatus({required String amount}) async {
    // Ne pas continuer les vérifications si la transaction est annulée
    if (!_isTransactionActive) {
      myCustomPrintStatement("Transaction inactive - skipping status check");
      return;
    }
    
    myCustomPrintStatement("calling payment status");
    Uri apiUrl = Uri.parse(
        "${_orangeMoneyBaseUrl}orange-money-webpay/mg/v1/transactionstatus");
    var headers = {
      'Authorization': 'Bearer $acessToken',
    };
    var body = {
      "order_id": orderId,
      "amount": amount,
      "pay_token": payToken,
    };
    try {
      var response = await http.post(apiUrl,
          headers: headers, body: convert.jsonEncode(body));
      // sQLServices.insertUserLog(
      //   usersLogModal: UsersLogModal(
      //     userId: "110011",
      //     date: DateTime.now().toString(),
      //     logString:
      //         "[${response.statusCode}]  Api Url :- ${apiUrl.toString()} header :- $headers response :- ${response.body} ",
      //   ),
      // );
      var jsonResponse = convert.jsonDecode(response.body);
      myCustomPrintStatement(
          "check payment status is ${response.statusCode} response is that $jsonResponse");
      if (response.statusCode == 401 || response.statusCode == 403) {
        await generateAccessToken();
        await checkTranscationStatus(amount: amount);
      }
      myCustomLogStatements(
          "[LOG --- api create payment] $apiUrl header:$headers");
      if (response.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(response.body);
        myCustomPrintStatement(
            "json response for check payment ${response.statusCode} $jsonResponse");
      } else if (response.statusCode == 201) {
        var jsonResponse = convert.jsonDecode(response.body);

        myCustomPrintStatement(
            "json response for check payment ${response.statusCode} $jsonResponse");
        if (jsonResponse['status'] == "NOT FOUND") {
          // Ne pas afficher le message d'erreur immédiatement car la transaction 
          // peut ne pas encore être créée côté Orange Money après l'initiation
          myCustomPrintStatement("Orange transaction NOT FOUND - retrying in 3 seconds...");
          Future.delayed(const Duration(seconds: 3), () {
            checkTranscationStatus(amount: amount);
          });
        } else if (jsonResponse['status'] == "FAILED") {
          // Arrêter les vérifications car la transaction a échoué
          _isTransactionActive = false;
          showSnackbar("La transaction a échoué.");
        } else if ((jsonResponse['status'] == "INITIATED" ||
            jsonResponse['status'] == "PENDING")) {
          if (firstTimeTransactionApiCall) {
            push(
              context: MyGlobalKeys.navigatorKey.currentContext!,
              screen: OpenPaymentWebview(
                webViewUrl: paymentUrl,
                onCancellation: () {
                  myCustomPrintStatement("Orange Money payment cancelled by user (from status check)");
                  _cancelOrangeTransaction();
                },
              ),
            );
            firstTimeTransactionApiCall = false;
          } else {
            Future.delayed(const Duration(seconds: 5), () {
              checkTranscationStatus(amount: amount);
            });
          }
        } else if (jsonResponse['status'] == "SUCCESS") {
          // Arrêter les vérifications car la transaction est terminée
          _isTransactionActive = false;
          
          tripProvider.onlinePaymentDone(paymentInfo: {
            "paymentType": PaymentMethodType.orangeMoney.value,
            "status": "SUCCESS",
            "payToken": payToken,
            "txnid": jsonResponse['txnid'],
            "orderId": orderId,
            "accessToken": acessToken,
            "createAt": tripProvider.booking!['paymentStatusSummary']
                ['createAt'],
            "paymentUrl": paymentUrl,
            "notifyToken": tripProvider.booking!['paymentStatusSummary']
                ['notif_token']
          });
          showSnackbar("Transaction effectuée avec succès.");
        } else if (jsonResponse['status'] == "EXPIRED") {
          // Arrêter les vérifications car la transaction a expiré
          _isTransactionActive = false;
          
          showSnackbar(
              "La transaction a expiré. Vous avez cliqué sur 'Confirmer' trop tard.");
          FirestoreServices.bookingRequest
              .doc(tripProvider.booking!['id'])
              .update({
            "paymentStatusSummary": {
              "paymentType": PaymentMethodType.orangeMoney.value,
              "status": "EXPIRED",
              "payToken": payToken,
              "txnid": "",
              "orderId": orderId,
              "accessToken": acessToken,
              "createAt": tripProvider.booking!['paymentStatusSummary']
                  ['createAt'],
              "paymentUrl": paymentUrl,
              "notifyToken": tripProvider.booking!['paymentStatusSummary']
                  ['notif_token']
            }
          });
          popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
        }
      } else if (response.statusCode == 400) {
        // Ne pas afficher d'erreur si l'utilisateur a annulé volontairement
        if (!_isUserCancelled) {
          showSnackbar("Une erreur s'est produite !");
        }
      } else {}
      firstTimeTransactionApiCall = false;
    } catch (error) {
      myCustomPrintStatement('inside double catch block $error');
      showSnackbar("Erreur API : $error");
    }
  }

  String stringToBase64(String input) {
    convert.Codec<String, String> stringToBase64 =
        convert.utf8.fuse(convert.base64);
    return stringToBase64.encode(input);
  }

  String generateUUID() {
    // Create a UUID version 4

    String uuid = const Uuid().v4();
    // Truncate to at most 40 characters
    if (uuid.length > 28) {
      uuid = uuid.substring(0, 28);
    }

    return uuid;
  }

  Future<String> generateTransactionReferenceID() async {
    const allowedChars =
        'abcdefghijklmnopqrstuvwxyz0123456789'; // Define allowed characters
    final rand = Random();
    const idLength = 35; // Maximum length of the ID

    // Generate random characters from the allowed characters
    String id = List.generate(
            idLength, (_) => allowedChars[rand.nextInt(allowedChars.length)])
        .join();

    return id;
  }

  /// Annule la transaction Orange Money en cours
  void _cancelOrangeTransaction() {
    try {
      myCustomPrintStatement("Cancelling Orange Money transaction: $orderId");
      
      // Marquer comme annulation utilisateur pour éviter les messages d'erreur
      _isUserCancelled = true;
      // Arrêter toutes les vérifications de statut en cours
      _isTransactionActive = false;
      
      // Mettre à jour le statut de la transaction dans Firestore
      if (tripProvider.booking != null) {
        FirestoreServices.bookingRequest
            .doc(tripProvider.booking!['id'])
            .update({
          "paymentStatusSummary": {
            "paymentType": PaymentMethodType.orangeMoney.value,
            "status": "CANCELLED",
            "payToken": payToken,
            "txnid": "",
            "orderId": orderId,
            "accessToken": acessToken,
            "createAt": tripProvider.booking!['paymentStatusSummary']
                ['createAt'],
            "paymentUrl": paymentUrl,
            "notifyToken": tripProvider.booking!['paymentStatusSummary']
                ['notif_token'],
            "cancelledAt": Timestamp.now(),
            "cancellationReason": "User cancelled payment"
          }
        });

        // Revenir au paiement cash
        FirestoreServices.bookingRequest
            .doc(tripProvider.booking!['id'])
            .update({
          "paymentMethod": PaymentMethodType.cash.value,
        });
        
        // S'assurer que l'état UI revient à driverOnWay avec le booking intact
        tripProvider.setScreen(CustomTripType.driverOnWay);
      }
      
      // Fermer la WebView si elle est ouverte (évite les conflits de navigation)
      try {
        if (MyGlobalKeys.navigatorKey.currentContext != null) {
          popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
        }
      } catch (e) {
        myCustomPrintStatement("Note: WebView was already closed or context unavailable");
      }
      
      // Réinitialiser les variables
      orderId = "";
      payToken = "";
      paymentUrl = "";
      acessToken = "";
      firstTimeTransactionApiCall = true;
      // Garder _isUserCancelled à true pour cette session d'annulation
      
      showSnackbar("Paiement Orange Money annulé - Paiement en espèces sélectionné");
    } catch (error) {
      myCustomPrintStatement('Error cancelling Orange Money transaction: $error');
    }
  }
}
