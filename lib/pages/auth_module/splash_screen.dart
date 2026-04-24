import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/pages/test_invoice_regeneration_page.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/editor_dashboard_screen.dart';

import '../../../contants/my_image_url.dart';
import '../../../provider/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late CustomAuthProvider auth;

  String _currentUrl() {
    if (!kIsWeb) return '';
    return '${html.window.location.href}|hash=${html.window.location.hash}|pathname=${html.window.location.pathname}';
  }

  // Vérifie si on est en mode test-invoice
  bool get _isTestInvoiceMode => _currentUrl().contains('test-invoice');

  // Vérifie si on est en mode éditeur terrain transport (consultant),
  /// en mode review admin (review par admin), ou sur la page de login
  /// dédiée transport. Ces routes partagent le même flow auth
  /// (skip splash lourd, setAuthListener léger).
  bool get _isTransportEditorMode =>
      _currentUrl().contains('transport-editor') ||
      _currentUrl().contains('transport-admin') ||
      _currentUrl().contains('transport-login') ||
      _currentUrl().contains('transport-iam');

  @override
  void initState() {
    super.initState();
    // DEBUG: tracer ce que voit l'app au démarrage pour diagnostiquer
    // pourquoi le deep-link `/#/transport-editor` ne fonctionne pas.
    // ignore: avoid_print
    print('🔍 SPLASH URL: ${_currentUrl()} | Uri.base=${Uri.base}');

    // Si mode test-invoice, ne pas faire l'authentification normale
    if (_isTestInvoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TestInvoiceRegenerationPage()),
        );
      });
      return;
    }

    // Mode éditeur terrain : on saute le `splashAuthentication` lourd
    // (GPS, langues, settings Firestore, admin settings…) mais on arme
    // quand même `setAuthListener` pour que la navigation post-login
    // fonctionne. Le listener a une branche dédiée qui re-pousse le
    // dashboard, lequel vérifie le custom claim via `AdminAuthService`.
    if (_isTransportEditorMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        auth = Provider.of<CustomAuthProvider>(context, listen: false);
        auth.setAuthListener(context);
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      auth = Provider.of<CustomAuthProvider>(context, listen: false);
      auth.splashAuthentication(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sur le web, fond blanc simple sans logo
    if (kIsWeb) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.shrink(),
      );
    }

    // Sur mobile, afficher le logo
    return Scaffold(
      backgroundColor: MyColors.primaryColor,
      body: Center(
        child: Image.asset(
          MyImagesUrl.splashLogo,
          color: MyColors.whiteColor,
          width: MediaQuery.of(context).size.width / 4,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
