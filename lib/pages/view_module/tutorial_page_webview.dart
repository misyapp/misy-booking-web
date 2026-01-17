// ignore_for_file: unnecessary_string_interpolations

import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/widget/custom_loader.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TutorialPageWebview extends StatefulWidget {
  final String webViewUrl;
  const TutorialPageWebview({super.key, required this.webViewUrl});

  @override
  State<TutorialPageWebview> createState() => _TutorialPageWebviewState();
}

class _TutorialPageWebviewState extends State<TutorialPageWebview> {
  late WebViewController webViewController;
  ValueNotifier<bool> showLoadingNoti = ValueNotifier(true);
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
          onUrlChange: (change) {},
        ),
      )
      ..loadRequest(Uri.parse('${widget.webViewUrl}'));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return SafeArea(
      child: Scaffold(
        appBar: CustomAppBar(
          title: translate("Tutorial"),
        ),
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
    );
  }
}
