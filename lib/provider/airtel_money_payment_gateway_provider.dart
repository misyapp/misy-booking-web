import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/widget/show_payment_proccess_loader.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'dart:convert' as convert;
import 'package:uuid/uuid.dart';

ValueNotifier<int> paymentStatus = ValueNotifier(0);

class AirtelMoneyPaymentGatewayProvider with ChangeNotifier {
  // Proxy URL pour contourner le whitelisting IP Airtel
  // Le proxy route les requêtes depuis une IP fixe (51.68.26.125)
  final String _proxyBaseUrl = "https://payment.misy.app";
  final String _proxyApiKey = "misy-airtel-proxy-8be62e8873d96869d595043ddc66fba1";

  bool showPaymentLoader = false;
  bool checkPaymentStatus = false;
  String acessToken = "";
  String transactionID = "";

  // === DEBUG / LOG HELPERS FOR AIRTEL INTEGRATION ===
  bool _airtelDebug = true;

  String _mask(String? input, {int showStart = 6, int showEnd = 4}) {
    if (input == null) return "";
    final s = input;
    if (s.length <= showStart + showEnd) return "*" * s.length;
    final start = s.substring(0, showStart);
    final end = s.substring(s.length - showEnd);
    return "$start***$end";
  }

  void _logAirtel(String label, String message) {
    if (!_airtelDebug) return;
    myCustomLogStatements("[AIRTEL] $label :: $message");
  }
  TripProvider tripProvider = Provider.of<TripProvider>(
    MyGlobalKeys.navigatorKey.currentContext!,
    listen: false,
  );
  Future generateAccessToken() async {
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
    _logAirtel("TOKEN REQUEST (via proxy)",
        "POST $_proxyBaseUrl/api/airtel/token | client_id: ${_mask(paymentGateWaySecretKeys!.airtelMoneyClientId)}");
    try {
      var response = await http.post(apiUrl,
          body: convert.jsonEncode(request), headers: headers);
      _logAirtel("TOKEN RESPONSE", "status: ${response.statusCode}, body: ${response.body}");

      commonApiResponseCode(response);
      myCustomLogStatements("[LOG --- api token via proxy] $apiUrl");
      var jsonResponse = convert.jsonDecode(response.body);
      if (response.statusCode == 200) {
        myCustomPrintStatement("json response for token $jsonResponse ");
        acessToken = jsonResponse['access_token'];
        _logAirtel("TOKEN PARSED", "access_token: ${_mask(acessToken)}");
        return jsonResponse;
      }
      if (response.statusCode == 400) {
        showSnackbar(
            "Requête invalide : ${jsonResponse['error_description'] ?? jsonResponse['error'] ?? 'Erreur inconnue'}");
      }
    } catch (error) {
      myCustomPrintStatement('inside double catch block $error');
      showSnackbar("Erreur API : $error");
    }
  }

  Future generatePaymentRequest(
      {required String amount, required String mobileNumber}) async {
    if (mobileNumber.startsWith('0')) {
      mobileNumber = mobileNumber.substring(1);
    }
    _logAirtel("MSISDN NORMALIZED", "msisdn(before country code check): ${_mask(mobileNumber, showStart: 3, showEnd: 2)}");
    await generateAccessToken();

    // Utilisation du proxy pour contourner le whitelisting IP
    Uri apiUrl = Uri.parse("$_proxyBaseUrl/api/airtel/payment");
    transactionID = generateUUID();

    // Corps de la requête adapté pour le proxy
    Map<String, dynamic> body = {
      "access_token": acessToken,
      "reference": "Pay For Ride",
      "subscriber": {
        "country": "MG",
        "currency": "MGA",
        "msisdn": mobileNumber
      },
      "transaction": {
        "amount": double.parse(tripProvider.booking!['ride_price_to_pay']),
        "country": "MG",
        "currency": "MGA",
        "id": transactionID
      }
    };
    _logAirtel(
      "CREATE PAYMENT REQUEST (via proxy)",
      "POST $_proxyBaseUrl/api/airtel/payment | transactionId: $transactionID | amount: ${tripProvider.booking!['ride_price_to_pay']}"
    );
    var headers = {
      'Content-Type': 'application/json',
      'X-API-Key': _proxyApiKey,
    };
    try {
      myCustomLogStatements(
          "[LOG --- api create payment via proxy] $apiUrl body: $body");
      var response = await http.post(apiUrl,
          body: convert.jsonEncode(body), headers: headers);
      _logAirtel("CREATE PAYMENT RESPONSE", "status: ${response.statusCode}, body: ${response.body}");
      // sQLServices.insertUserLog(
      //   usersLogModal: UsersLogModal(
      //     userId: "110011",
      //     date: DateTime.now().toString(),
      //     logString:
      //         "[${response.statusCode}]  Api Url :- ${apiUrl.toString()} header :- $headers response :- ${response.body} ",
      //   ),
      // );
      myCustomLogStatements(
          "Response is that ${response.statusCode} --- ${response.body}");
      commonApiResponseCode(response);
      if (response.statusCode == 200) {
        paymentStatus.value = 1;
        hideLoading();
        var jsonResponse = convert.jsonDecode(response.body);
        if (jsonResponse['status']['result_code'] == "ESB000010" &&
            jsonResponse['status']['success'] == true) {
          FirestoreServices.bookingRequest
              .doc(tripProvider.booking!['id'])
              .update({
            "paymentStatusSummary": {
              "paymentType": PaymentMethodType.airtelMoney.value,
              "status": "TIP",
              "transactionID": transactionID,
              "accessToken": acessToken,
              "createAt": Timestamp.now(),
            }
          });
          showSnackbar(
              "Payment request has been send to you. Please check and confirm");
          Future.delayed(const Duration(seconds: 3), () async {
            checkPaymentStatus = true;
            await checkTranscationStatus();
          });
        } else if (jsonResponse['status']['result_code'] == "ESB000001") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}]  Something went wrong. The request can be in ambiguous state please do a transaction enquiry.");
        } else if (jsonResponse['status']['result_code'] == "ESB000004") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}]  An error occurred while initiating the payment. The request can be in ambiguous state please do a transaction enquiry.");
        } else if (jsonResponse['status']['result_code'] == "ESB000011") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}] Request was Failed.");
        } else if (jsonResponse['status']['result_code'] == "ESB000014") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}]  An error occurred while fetching the transaction status. The request can be in ambiguous state please do a transaction enquiry after some time.");
        } else if (jsonResponse['status']['result_code'] == "ESB000033") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}]  The request has been failed due to Invalid MSISDN Length. Please try again with correct request.	");
        } else if (jsonResponse['status']['result_code'] == "ESB000034") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}]  The request has been failed due to Invalid Country Name. Please try again with correct request.");
        } else if (jsonResponse['status']['result_code'] == "ESB000035") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}]  The request has been failed due to Invalid Currency Code. Please try again with correct request.");
        } else if (jsonResponse['status']['result_code'] == "ESB000036") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}] The request has been failed due to either it is Invalid MSISDN Length or it doesn't starts with 0. Please try again with correct request");
        } else if (jsonResponse['status']['result_code'] == "ESB000039") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}] Vendor is not configured to do transaction in the provided country. Please try again with correct request.");
        } else if (jsonResponse['status']['result_code'] == "ESB000041") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}] Transaction with External Transaction ID already exists. Please try again with correct request.");
        } else if (jsonResponse['status']['result_code'] == "ESB000045") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}] No Transaction Found With Provided Transaction Id.");
        } else if (jsonResponse['status']['result_code'] == "0000900") {
          showSnackbar(
              "[${jsonResponse['status']['result_code']}] Transaction might be in ambigous state. Please try again.");
        }
      }
    } catch (error) {
      myCustomPrintStatement('inside double catch block $error');
      showSnackbar("Erreur API : $error");
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
      myCustomPrintStatement("calling payment method via proxy");
      // Utilisation du proxy pour contourner le whitelisting IP
      Uri apiUrl = Uri.parse("$_proxyBaseUrl/api/airtel/status/$transactionID");
      var headers = {
        'X-API-Key': _proxyApiKey,
        'Authorization': 'Bearer $acessToken',
      };
      try {
        _logAirtel("CHECK STATUS REQUEST (via proxy)", "GET $_proxyBaseUrl/api/airtel/status/$transactionID");
        var response = await http.get(apiUrl, headers: headers);
        _logAirtel("CHECK STATUS RESPONSE", "status: ${response.statusCode}, body: ${response.body}");
        // sQLServices.insertUserLog(
        //   usersLogModal: UsersLogModal(
        //     userId: "110011",
        //     date: DateTime.now().toString(),
        //     logString:
        //         "[${response.statusCode}]  Api Url :- ${apiUrl.toString()} header :- $headers response :- ${response.body} ",
        //   ),
        // );
        commonApiResponseCode(response);
        myCustomLogStatements(
            "[LOG --- api create payment] $apiUrl header:$headers ${response.statusCode} -- ${response.body}");
        if (response.statusCode == 401 || response.statusCode == 403) {
          await generateAccessToken();
          await checkTranscationStatus();
        } else if (response.statusCode == 200) {
          var jsonResponse = convert.jsonDecode(response.body);
          myCustomPrintStatement(
              "json response for check payment ${response.statusCode} $jsonResponse");
          if (jsonResponse['status']['result_code'] == "ESB000010" &&
              jsonResponse['status']['success'] == true) {
            if (jsonResponse['data']['transaction']['status'] == "TF") {
              paymentStatus.value = 2;
              showSnackbar(
                  "[${jsonResponse['data']['transaction']['status']}] ${jsonResponse['data']['transaction']['message']}");
              hidePaymentProccessLoader();
              showPaymentLoader = false;
              FirestoreServices.bookingRequest
                  .doc(tripProvider.booking!['id'])
                  .update({
                "paymentStatusSummary": {
                  "paymentType": PaymentMethodType.airtelMoney.value,
                  "status": "TF",
                  "txnid": jsonResponse['data']['transaction']
                      ['airtel_money_id'],
                  "transactionID": transactionID,
                  "accessToken": acessToken,
                  "createAt": tripProvider.booking!['paymentStatusSummary']
                      ['createAt'],
                }
              });
            } else if (jsonResponse['data']['transaction']['status'] == "TS") {
              paymentStatus.value = 3;
              showSnackbar(
                  "[${jsonResponse['data']['transaction']['status']}] ${jsonResponse['data']['transaction']['message']}");
              hidePaymentProccessLoader();
              showPaymentLoader = false;
              // FirestoreServices.bookingRequest
              //     .doc(tripProvider.booking!['id'])
              //     .update({
              //   "paymentStatusSummary": {
              //     "paymentType": PaymentMethodType.airtelMoney.value,
              //     "status": "TS",
              //     "txnid": jsonResponse['data']['transaction']
              //         ['airtel_money_id'],
              //     "transactionID": transactionID,
              //     "accessToken": acessToken,
              //     "createAt": tripProvider.booking!['paymentStatusSummary']
              //         ['createAt'],
              //   }
              // });
              tripProvider.onlinePaymentDone(paymentInfo: {
                "paymentType": PaymentMethodType.airtelMoney.value,
                "status": "TS",
                "txnid": jsonResponse['data']['transaction']['airtel_money_id'],
                "transactionID": transactionID,
                "accessToken": acessToken,
                "createAt": tripProvider.booking!['paymentStatusSummary']
                    ['createAt'],
              });
            } else if (jsonResponse['data']['transaction']['status'] == "TIP") {
              paymentStatus.value = 1;
              Future.delayed(
                const Duration(seconds: 8),
                () async {
                  await checkTranscationStatus();
                },
              );
            }
          }
        } else if (response.statusCode == 400) {
          showSnackbar("Une erreur s'est produite !");
        } else {}
      } catch (error) {
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
    uuid.split("-").join("");
    // Truncate to at most 20 characters
    if (uuid.length > 20) {
      uuid = uuid.substring(0, 20);
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

  commonApiResponseCode(http.Response response) {
    switch (response.statusCode) {
      case 400:
        showSnackbar(
            "[${response.statusCode}] Bad Request -- Your request is invalid");
        hideLoading();
        if (showPaymentLoader) {
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          checkPaymentStatus = false;
        }
        break;
      case 401:
        showSnackbar(
            "[${response.statusCode}] Unauthorized -- Your API key or bearer token is incorrect.");
        hideLoading();
        if (showPaymentLoader) {
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          checkPaymentStatus = false;
        }
        break;
      case 403:
        showSnackbar(
            "[${response.statusCode}] Forbidden -- The requested item is hidden for administrators only.");
        _logAirtel("HTTP 403", "Forbidden on last request. Verify merchant permissions, resource visibility, and headers.");
        hideLoading();
        if (showPaymentLoader) {
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          checkPaymentStatus = false;
        }
        break;
      case 404:
        showSnackbar(
            "[${response.statusCode}] Not Found -- The specified path could not be found.	");
        hideLoading();
        if (showPaymentLoader) {
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          checkPaymentStatus = false;
        }
        break;
      case 405:
        showSnackbar(
            "[${response.statusCode}] Method Not Allowed -- You tried to access a path with an invalid method.");
        hideLoading();
        if (showPaymentLoader) {
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          checkPaymentStatus = false;
        }
        break;
      case 408:
        showSnackbar(
            "[${response.statusCode}] Read Timeout -- The request has timed out. In case of payments/refund, please perform an transaction enquiry; otherwise, try again later.");
        hideLoading();
        if (showPaymentLoader) {
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          checkPaymentStatus = false;
        }
        break;
      case 429:
        showSnackbar(
            "[${response.statusCode}] Too Many Requests -- You're requesting too many requests! Slow down.");
        break;
      case 500:
        showSnackbar(
            "[${response.statusCode}] Internal Server Error -- We had a problem with our server. Try again later.");
        break;
      case 502:
        showSnackbar(
            "[${response.statusCode}] Bad gateway -- In case of payments/refund, please perform an transaction enquiry; otherwise, try again later.");
        hideLoading();
        if (showPaymentLoader) {
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          checkPaymentStatus = false;
        }
        break;
      case 503:
        showSnackbar(
            "[${response.statusCode}] Gateway Timeout -- In case of payments/refund, please perform an transaction enquiry; otherwise, try again later.");
        hideLoading();
        if (showPaymentLoader) {
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          checkPaymentStatus = false;
        }
        break;
      case 504:
        showSnackbar(
            "[${response.statusCode}] Service Unavailable -- We're temporarily offline for maintenance. Please try again later.");
        hideLoading();
        if (showPaymentLoader) {
          hidePaymentProccessLoader();
          showPaymentLoader = false;
          checkPaymentStatus = false;
        }
        break;
      default:
    }
  }
}
