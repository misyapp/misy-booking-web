import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

bool isInternetConnect = false;

class InternetConnectivityProvider extends ChangeNotifier {
  int isDialogShow = 0;

  final Connectivity connectivity = Connectivity();

  late StreamSubscription streamSubscription;

  internetConnectivityState() async {
    myCustomLogStatements('Initializing internet connection checker');
    Future.delayed(const Duration(seconds: 2)).then((value) {
      streamSubscription = checkNetworkConnection();
    });
  }

  static Future<bool> internetConnectionCheckerMethod() async {
    try {
      // Augmentation du timeout pour les réseaux lents
      final checker = InternetConnectionChecker.createInstance(
        checkTimeout: const Duration(seconds: 10), // Timeout plus long pour réseaux lents
        checkInterval: const Duration(seconds: 5),
      );

      bool result = await checker.hasConnection.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          // Si le timeout est atteint, on considère qu'il y a une connexion lente
          myCustomPrintStatement('Connection check timeout - assuming slow connection exists');
          return true; // Optimiste: on assume qu'il y a une connexion lente
        },
      );
      return result;
    } catch (e) {
      myCustomPrintStatement('Error checking connection: $e - assuming connection exists');
      return true; // En cas d'erreur, on assume qu'il y a une connexion
    }
  }

  BuildContext? context;

  StreamSubscription checkNetworkConnection() {
    bool networkConnection = false;
    return connectivity.onConnectivityChanged.listen((event) async {
      networkConnection = await internetConnectionCheckerMethod();
      myCustomPrintStatement(
          'sdfdkasjl $event ----- $networkConnection $isDialogShow');
      if (networkConnection) {
        isInternetConnect = true;
        if (isDialogShow == 1) {}
      } else {
        isInternetConnect = false;
        isDialogShow = 1;
      }
    });
  }

  bool get isConnected => isInternetConnect;
}
