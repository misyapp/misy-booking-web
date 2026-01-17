import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'dart:convert' as convert;

import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/users_log_modal.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/user_log_store_service.dart';
import 'package:rider_ride_hailing_app/widget/show_payment_proccess_loader.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:uuid/uuid.dart';

class TelmaMoneyPaymentGatewayProvider with ChangeNotifier {
  // development api url
  // final String _telmaMvolaMoneyBaseUrl = "https://devapi.mvola.mg/";
  // production api url
  final String _telmaMvolaMoneyBaseUrl = "https://api.mvola.mg/";
  TripProvider tripProvider = Provider.of<TripProvider>(
    MyGlobalKeys.navigatorKey.currentContext!,
    listen: false,
  );
  UserLogStoreService sQLServices = UserLogStoreService();
  String acessToken = "";
  String correlationID = "";
  String serverCorrelationId = "";
  String merchantPhoneNumber = "0384219719";
  String objectReferenceId = "";
  bool showPaymentLoader = false;
  bool checkPaymentStatus = false;
  Future generateAccessToken() async {
    Uri apiUrl = Uri.parse("${_telmaMvolaMoneyBaseUrl}token");
    String uuid = generateUUID();
    var headers = {
      'Authorization':
          'Basic ${stringToBase64("${paymentGateWaySecretKeys!.telmaConsumerKey}:${paymentGateWaySecretKeys!.telmaConsumerSecretKey}")}',

          // Development test token credentials
          // 'Basic ${stringToBase64("73xldaoD5QikdePz1KxpZoJbR8ca:sv7gkDXFSnYrLRAmEQM8LxmNQ3Ma")}',
      // consumer key: consumer screate key
      'Content-Type': 'application/x-www-form-urlencoded',
      'Cache-Control': 'no-cache'
    };
    try {
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
              "[${response.statusCode}]  Api Url :- ${apiUrl.toString()} header :- $headers response :- ${response.body} ",
        ),
      );
      myCustomLogStatements("[LOG --- api token] $apiUrl header:$headers");
      if (response.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(response.body);
        myCustomPrintStatement("json response for token $jsonResponse ");
        acessToken = jsonResponse['access_token'];
        return jsonResponse;
      }
    } catch (error) {
      myCustomPrintStatement('inside double catch block $error');
      showSnackbar("Erreur API : $error");
    }
  }

  Future generatePaymentRequest({required String phoneNumberDebitParty}) async {
    tripProvider.loadingOnPayButton = true;
    tripProvider.notifyListeners();
    await generateAccessToken();
    Uri apiUrl = Uri.parse(
        "${_telmaMvolaMoneyBaseUrl}mvola/mm/transactions/type/merchantpay/1.0.0/");
    correlationID = generateUUID();
    Map<String, dynamic> body = {
      "amount": double.parse(formatNearest(
              double.parse(tripProvider.booking!['ride_price_to_pay'])))
          .toInt()
          .toString(),
      "currency": "Ar",
      "descriptionText": "Paiement course Misy",
      "requestingOrganisationTransactionReference": "ABC1234565",
      "originalTransactionReference": "AZERTY98798",
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
        {"key": "fc", "value": "USD"},
        {
          "key": "amountFc",
          "value": double.parse(tripProvider.booking!['ride_price_to_pay'])
        }
      ]
    };
    var headers = {
      'accept': '*/*',
      'Version': '1.0',
      'X-CorrelationID': correlationID,
      'UserLanguage': selectedLanguageNotifier.value['key'] == 'mg' ||
              selectedLanguageNotifier.value['key'] == 'en'
          ? 'MG'
          : 'FR',
      'Cache-Control': 'no-cache',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $acessToken',
    };
    try {
      var response = await http.post(apiUrl,
          body: convert.jsonEncode(body), headers: headers);
      myCustomLogStatements(
          "[LOG --- api create payment ${response.statusCode}] $apiUrl header:$headers body is that ${convert.jsonEncode(body)}");
      sQLServices.insertUserLog(
        usersLogModal: UsersLogModal(
          userId: "110011",
          date: DateTime.now().toString(),
          logString:
              "[${response.statusCode}]  Api Url :- ${apiUrl.toString()} header :- $headers response :- ${response.body} ",
        ),
      );
      var jsonResponse = convert.jsonDecode(response.body);
      hideLoading();
      if (response.statusCode == 200) {
        tripProvider.loadingOnPayButton = false;
        tripProvider.notifyListeners();
        showSnackbar("Demande de paiement créée (${response.statusCode})");
      } else if (response.statusCode == 202) {
        myCustomPrintStatement(
            "json response for create payment ${response.statusCode} $jsonResponse");
        if (jsonResponse['serverCorrelationId'] != null) {
          serverCorrelationId = jsonResponse['serverCorrelationId'];
          FirestoreServices.bookingRequest
              .doc(tripProvider.booking!['id'])
              .update({
            "paymentStatusSummary": {
              "paymentType": PaymentMethodType.telmaMvola.value,
              "status": "pending",
              "accessToken": acessToken,
              "correlationID": correlationID,
              "serverCorrelationId": serverCorrelationId,
              "createAt": Timestamp.now(),
            }
          });
          // FirestoreServices.bookingRequest
          //     .doc(tripProvider.booking!['id'])
          //     .update({
          //   "paymentStatusSummary": {
          //     "status": "pending",
          //     "serverCorrelationId": jsonResponse["serverCorrelationId"],
          //     "correlationID": correlationID,
          //     "accessToken": acessToken,
          //     "createAt": Timestamp.now()
          //   }
          // });
          showSnackbar(
              "Demande de paiement envoyée. Veuillez vérifier et confirmer.");
          Future.delayed(const Duration(seconds: 3), () async {
            checkPaymentStatus = true;
            await checkTranscationStatus();
          });
        }
        return jsonResponse;
      } else if (response.statusCode == 400) {
        hideLoading();
        showSnackbar("Une erreur s'est produite !");
        tripProvider.loadingOnPayButton = false;
        tripProvider.notifyListeners();
      }
    } catch (error) {
      myCustomPrintStatement('inside double catch block $error');
      tripProvider.loadingOnPayButton = false;

      tripProvider.notifyListeners();
      showSnackbar("Erreur API : $error");
      hideLoading();
    }
  }

  Future checkTranscationStatus() async {
    if (checkPaymentStatus) {
      if (!showPaymentLoader) {
        showPaymentLoader = true;
        showPaymentProccessLoader(
          onTap: () {
            popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
            checkPaymentStatus = false;
            FirestoreServices.bookingRequest
                .doc(tripProvider.booking!['id'])
                .update({"paymentStatusSummary": {}});
          },
        );
      }
      myCustomPrintStatement("calling payment method");
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
        'Authorization': 'Bearer $acessToken',
      };
      try {
        var response = await http.get(apiUrl, headers: headers);
        var jsonResponse = convert.jsonDecode(response.body);
        myCustomLogStatements(
            "[LOG --- api create payment] $apiUrl header:$headers response is that $jsonResponse");
        sQLServices.insertUserLog(
          usersLogModal: UsersLogModal(
            userId: "110011",
            date: DateTime.now().toString(),
            logString:
                "[${response.statusCode}]  Api Url :- ${apiUrl.toString()} header :- $headers response :- ${response.body} ",
          ),
        );
        if (response.statusCode == 200) {
          myCustomPrintStatement(
              "json response for check payment ${response.statusCode} $jsonResponse");
          if (jsonResponse['status'] == 'failed') {
            hidePaymentProccessLoader();
            showPaymentLoader = false;
            FirestoreServices.bookingRequest
                .doc(tripProvider.booking!['id'])
                .update({
              "paymentStatusSummary": {
                "paymentType": PaymentMethodType.telmaMvola.value,
                "status": "failed",
                'correlationID': correlationID,
                'serverCorrelationId': serverCorrelationId,
                "txnid": jsonResponse['serverCorrelationId'],
                "accessToken": acessToken,
                "createAt": tripProvider.booking!['paymentStatusSummary']
                    ['createAt'],
              },
            });

            showSnackbar("Échec de la transaction. Veuillez réessayer.");
            tripProvider.loadingOnPayButton = false;
            tripProvider.notifyListeners();
          } else if (jsonResponse['status'] == 'pending') {
            Future.delayed(
              const Duration(seconds: 5),
              () {
                checkTranscationStatus();
              },
            );
          } else if (jsonResponse['status'] == 'completed') {
            hidePaymentProccessLoader();
            showPaymentLoader = false;
            tripProvider.loadingOnPayButton = false;

            tripProvider.onlinePaymentDone(paymentInfo: {
              "paymentType": PaymentMethodType.telmaMvola.value,
              "status": "completed",
              'correlationID': correlationID,
              'serverCorrelationId': serverCorrelationId,
              "txnid": jsonResponse['serverCorrelationId'],
              "accessToken": acessToken,
              "createAt": tripProvider.booking!['paymentStatusSummary']
                  ['createAt'],
            });

            // tripProvider.onlinePaymentDone();
          }
        } else if (response.statusCode == 400) {
          tripProvider.loadingOnPayButton = false;
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          tripProvider.notifyListeners();
          showSnackbar("Une erreur s'est produite !");
        } else {
          tripProvider.loadingOnPayButton = false;
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          tripProvider.notifyListeners();
        }
      } catch (error) {
        hidePaymentProccessLoader();
        showPaymentLoader = false;
        tripProvider.loadingOnPayButton = false;
        tripProvider.notifyListeners();
        myCustomPrintStatement('inside double catch block $error');
        showSnackbar("Erreur API : $error");
      }
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
    if (uuid.length > 40) {
      uuid = uuid.substring(0, 40);
    }

    return uuid;
  }

  Future<String> generateTransactionReferenceID() async {
    const allowedChars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'; // Define allowed characters
    final rand = Random();
    const idLength = 35; // Maximum length of the ID

    // Generate random characters from the allowed characters
    String id = List.generate(
            idLength, (_) => allowedChars[rand.nextInt(allowedChars.length)])
        .join();

    return id;
  }
}
