// ignore_for_file: unnecessary_string_interpolations

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/widget/custom_loader.dart';
import 'package:webview_flutter/webview_flutter.dart';

class OpenPaymentWebview extends StatefulWidget {
  final String webViewUrl;
  final VoidCallback? onCancellation;
  const OpenPaymentWebview({
    super.key, 
    required this.webViewUrl,
    this.onCancellation,
  });

  @override
  State<OpenPaymentWebview> createState() => _OpenPaymentWebviewState();
}

class _OpenPaymentWebviewState extends State<OpenPaymentWebview> {
  late WebViewController webViewController;
  ValueNotifier<bool> showLoadingNoti = ValueNotifier(true);
  bool _isNavigating = false; // Flag pour éviter les navigations multiples
  @override
  void initState() {
    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(false)
      // ..runJavaScript('document.body.style.zoom = "$defaultZoom%";')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            myCustomPrintStatement("Progressing $progress");
            // webViewController
            //     .runJavaScript('document.body.style.zoom = "$defaultZoom%";');
            // Update loading bar.
          },
          onPageStarted: (String url) {
            myCustomPrintStatement("on page started url $url");
            // webViewController
            //     .runJavaScript('document.body.style.zoom = "$defaultZoom%";');
          },
          onPageFinished: (String url) {
            showLoadingNoti.value = false;
            myCustomPrintStatement("on page finished url $url");
            // webViewController
            //     .runJavaScript('document.body.style.zoom = "$defaultZoom%";');
          },
          onWebResourceError: (WebResourceError error) {
            myCustomPrintStatement("Webview Error is that $error");
          },
          onUrlChange: (change) {
            myCustomPrintStatement("Url is changing from old ${change.url}");
            
            // Éviter les appels multiples
            if (_isNavigating) {
              myCustomPrintStatement("Payment WebView: Navigation already in progress, ignoring");
              return;
            }
            
            if (change.url == "http://myvirtualshop.webnode.es/txncncld/") {
              _isNavigating = true;
              myCustomPrintStatement("Payment WebView: Transaction cancelled via URL");
              
              // Appeler le callback d'annulation si fourni
              if (widget.onCancellation != null) {
                widget.onCancellation!();
              } else {
                // Seulement si pas de callback spécifique, utiliser le comportement par défaut
                TripProvider tripProvider =
                    Provider.of<TripProvider>(context, listen: false);
                tripProvider.setScreen(CustomTripType.driverOnWay);
                if (tripProvider.booking != null) {
                  FirestoreServices.bookingRequest
                      .doc(tripProvider.booking!['id'])
                      .update({
                    "paymentMethod": PaymentMethodType.cash.value,
                  });
                }
              }
              
              popPage(context: context);
            } else if (change.url == "http://myvirtualshop.webnode.es/") {
              _isNavigating = true;
              myCustomPrintStatement("Payment WebView: Return to merchant site - treating as cancellation");
              
              // Appeler le callback d'annulation si fourni (le callback gère la fermeture)
              if (widget.onCancellation != null) {
                widget.onCancellation!();
                // Le callback gère lui-même la fermeture de la WebView et la navigation
              } else {
                // Seulement si pas de callback spécifique, utiliser le comportement par défaut
                TripProvider tripProvider =
                    Provider.of<TripProvider>(context, listen: false);
                tripProvider.setScreen(CustomTripType.driverOnWay);
                if (tripProvider.booking != null) {
                  FirestoreServices.bookingRequest
                      .doc(tripProvider.booking!['id'])
                      .update({
                    "paymentMethod": PaymentMethodType.cash.value,
                  });
                }
                // Dans ce cas, on ferme manuellement la WebView
                popPage(context: context);
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('${widget.webViewUrl}'));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        // Éviter les appels multiples
        if (_isNavigating) {
          myCustomPrintStatement("Payment WebView: Navigation already in progress, ignoring back button");
          return true;
        }
        
        _isNavigating = true;
        myCustomPrintStatement("Payment WebView: User pressed back button - treating as cancellation");
        
        // Appeler le callback d'annulation si fourni
        if (widget.onCancellation != null) {
          widget.onCancellation!();
        } else {
          // Seulement si pas de callback spécifique, utiliser le comportement par défaut
          TripProvider tripProvider =
              Provider.of<TripProvider>(context, listen: false);
          tripProvider.setScreen(CustomTripType.driverOnWay);
        }
        
        return true;
      },
      child: SafeArea(
        child: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: showLoadingNoti,
            builder: (context, showLoadingNotiValue, child) => Stack(
              children: [
                WebViewWidget(
                  controller: webViewController,
                ),
                if (showLoadingNotiValue) const CustomLoader()
              ],
            ),
          ),
        ),
      ),
    );
  }
}
