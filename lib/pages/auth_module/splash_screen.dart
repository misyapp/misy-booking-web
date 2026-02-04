import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/pages/test_invoice_regeneration_page.dart';

import '../../../contants/my_image_url.dart';
import '../../../provider/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late CustomAuthProvider auth;

  // Vérifie si on est en mode test-invoice
  bool get _isTestInvoiceMode {
    final url = Uri.base.toString();
    return url.contains('test-invoice');
  }

  @override
  void initState() {
    super.initState();

    // Si mode test-invoice, ne pas faire l'authentification normale
    if (_isTestInvoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TestInvoiceRegenerationPage()),
        );
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
