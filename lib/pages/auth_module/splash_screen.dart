import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';

import '../../../contants/my_image_url.dart';
import '../../../provider/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late CustomAuthProvider auth;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      auth = Provider.of<CustomAuthProvider>(context, listen: false);
      auth.splashAuthentication(context);
    });
  }

  @override
  Widget build(BuildContext context) {
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
