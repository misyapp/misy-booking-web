import 'package:rider_ride_hailing_app/utils/platform.dart';

import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/view_module/privacy_screen.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widget/round_edged_button.dart';
import 'login_screen.dart';

class IntroScreenIOS extends StatefulWidget {
  const IntroScreenIOS({super.key});

  @override
  State<IntroScreenIOS> createState() => _IntroScreenIOSState();
}

class _IntroScreenIOSState extends State<IntroScreenIOS>
    with WidgetsBindingObserver {
  ValueNotifier<LocationPermission> permissionGiven =
      ValueNotifier(LocationPermission.denied);
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      permissionGiven.value = await Geolocator.checkPermission();
      myCustomPrintStatement(" permissionGiven.value ${permissionGiven.value}");
      //   var m1;
      //   if (Platform.isAndroid) {
      //     m1 = await Permission.locationWhenInUse.status;
      //   } else {
      //     m1 = await Permission.locationWhenInUse.request();
      //   }
      //   if (Platform.isAndroid &&
      //       (m1 == LocationPermission.denied) &&
      //       locationPopUpOpend) {
      //     showPermissionNeedPopup();
      //   } else if (Platform.isIOS &&
      //       (m1 == LocationPermission.denied ||
      //           m1 == LocationPermission.deniedForever) &&
      //       locationPopUpOpend) {
      //     askForIntroScrenn();
      //   }
    });
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (locationPopUpOpend) {
        if (Platform.isIOS) {
          permissionGiven.value = await Geolocator.checkPermission();
        } else {
          permissionGiven.value = await Geolocator.checkPermission();
        }
        myCustomPrintStatement(
            " permissionGiven.value ${permissionGiven.value}");
      }
      // else if (Platform.isIOS &&
      //     (m1 == LocationPermission.denied ||
      //         m1 == LocationPermission.deniedForever) &&
      //     locationPopUpOpend) {
      //   askForIntroScrenn();
      // }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.primaryColor,
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: permissionGiven,
        builder: (context, permissionGivenValue, child) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundEdgedButton(
              width: double.infinity,
              color: MyColors.whiteColor,
              textColor: MyColors.blackColor,
              height: 60,
              fontSize: 20,
              ignoreInternetConnectivity: true,
              fontWeight: FontWeight.w500,
              borderRadius: 35,
              horizontalMargin: 30,
              onTap: () async {
                if (permissionGivenValue != LocationPermission.denied &&
                    permissionGivenValue != LocationPermission.deniedForever) {
                  pushAndRemoveUntil(
                      context: context, screen: const LoginPage());
                } else if (permissionGivenValue ==
                    LocationPermission.deniedForever) {
                  await openAppSettings();
                  permissionGiven.value = await Geolocator.checkPermission();
                  myCustomPrintStatement(
                      "permissionGiven.value ${permissionGiven.value}");
                } else {
                  if (Platform.isIOS) {
                    await askForIntroScrenn();
                    permissionGiven.value = await Geolocator.checkPermission();
                  } else {
                    permissionGiven.value =
                        await Geolocator.requestPermission();
                    if (permissionGiven.value == LocationPermission.denied) {
                      await askForIntroScrenn();
                      permissionGiven.value =
                          await Geolocator.checkPermission();
                    } else if (permissionGiven.value ==
                        LocationPermission.deniedForever) {
                      await openAppSettings();
                      permissionGiven.value =
                          await Geolocator.requestPermission();
                    }
                  }
                }
              },
              verticalMargin: 50,
              text: permissionGivenValue == LocationPermission.denied
                  ? translate("Allow")
                  : permissionGivenValue == LocationPermission.deniedForever
                      ? translate("openAppSetting")
                      : translate("letsGo"),
            ),
            if (permissionGivenValue != LocationPermission.denied &&
                permissionGivenValue != LocationPermission.deniedForever)
              ParagraphText(
                translate("byContinuing"),
                fontWeight: FontWeight.w400,
                fontSize: 16,
                color: MyColors.whiteColor,
              ),
            if (permissionGivenValue != LocationPermission.denied &&
                permissionGivenValue != LocationPermission.deniedForever)
              Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: GestureDetector(
                  onTap: () {
                    push(
                      context: context,
                      screen: const PrivacyPolicyScreen(),
                    );
                  },
                  child: ParagraphText(
                    translate("privacyPolicy"),
                    fontWeight: FontWeight.w600,
                    color: MyColors.whiteColor,
                    underlined: true,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: permissionGiven,
        builder: (context, permissionGivenValue, child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: permissionGivenValue == LocationPermission.deniedForever
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      MyImagesUrl.location,
                      color: MyColors.whiteColor,
                      height: 150,
                      width: 150,
                    ),
                    ParagraphText(
                      translate(
                        "openAppSettingMsg",
                      ),
                      color: MyColors.whiteColor,
                      fontSize: 16,
                    )
                  ],
                )
              : permissionGivenValue == LocationPermission.denied
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          MyImagesUrl.location,
                          color: MyColors.whiteColor,
                          height: 150,
                          width: 150,
                        ),
                        ParagraphText(
                          translate("prePermissionPopup"),
                          color: MyColors.whiteColor,
                        )
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Image.asset(
                            MyImagesUrl.splashLogo,
                            color: MyColors.whiteColor,
                            width: MediaQuery.of(context).size.width / 4,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
