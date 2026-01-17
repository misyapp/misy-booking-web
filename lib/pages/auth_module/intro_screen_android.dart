import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/view_module/privacy_screen.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import '../../widget/round_edged_button.dart';
import 'login_screen.dart';

class IntroScreenAndroid extends StatefulWidget {
  const IntroScreenAndroid({super.key});

  @override
  State<IntroScreenAndroid> createState() => _IntroScreenAndroidState();
}

class _IntroScreenAndroidState extends State<IntroScreenAndroid>
    with WidgetsBindingObserver {
  ValueNotifier<PermissionStatus> permissionGiven =
      ValueNotifier(PermissionStatus.denied);
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      permissionGiven.value = await Permission.locationWhenInUse.status;

      //   var m1;
      //   if (Platform.isAndroid) {
      //     m1 = await Permission.locationWhenInUse.status;
      //   } else {
      //     m1 = await Permission.locationWhenInUse.request();
      //   }
      //   if (Platform.isAndroid &&
      //       (m1 == PermissionStatus.denied) &&
      //       locationPopUpOpend) {
      //     showPermissionNeedPopup();
      //   } else if (Platform.isIOS &&
      //       (m1 == PermissionStatus.denied ||
      //           m1 == PermissionStatus.permanentlyDenied) &&
      //       locationPopUpOpend) {
      //     askForIntroScrenn();
      //   }
    });
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (Platform.isAndroid && locationPopUpOpend) {
        permissionGiven.value = await Permission.locationWhenInUse.status;
        myCustomPrintStatement(
            " permissionGiven.value ${permissionGiven.value}");
      }
      // else if (Platform.isIOS &&
      //     (m1 == PermissionStatus.denied ||
      //         m1 == PermissionStatus.permanentlyDenied) &&
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
        builder: (context, permissionGivenValue, child) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoundEdgedButton(
                width: double.infinity,
                color: MyColors.whiteColor,
                textColor: MyColors.blackColor,
                height: 60,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                borderRadius: 35,
                horizontalMargin: 50,
                onTap: () async {
                  if (permissionGivenValue != PermissionStatus.denied &&
                      permissionGivenValue !=
                          PermissionStatus.permanentlyDenied) {
                    pushAndRemoveUntil(
                        context: context, screen: const LoginPage());
                  }
                  if (permissionGivenValue ==
                      PermissionStatus.permanentlyDenied) {
                    await openAppSettings();
                    permissionGiven.value =
                        await Permission.locationWhenInUse.status;
                    myCustomPrintStatement(
                        "permissionGiven.value ${permissionGiven.value}");
                  } else {
                    await askForIntroScrenn();
                    permissionGiven.value =
                        await Permission.locationWhenInUse.status;
                  }
                },
                verticalMargin: 30,
                ignoreInternetConnectivity: true,
                text: permissionGivenValue == PermissionStatus.denied
                    ? translate("Allow")
                    : permissionGivenValue == PermissionStatus.permanentlyDenied
                        ? translate("openAppSetting")
                        : translate("letsGo"),
              ),
              if (permissionGivenValue != PermissionStatus.denied &&
                  permissionGivenValue != PermissionStatus.permanentlyDenied)
                ParagraphText(
                  translate("byContinuing"),
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: MyColors.blackColor,
                ),
              if (permissionGivenValue != PermissionStatus.denied &&
                  permissionGivenValue != PermissionStatus.permanentlyDenied)
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
      ),
      body: ValueListenableBuilder(
        valueListenable: permissionGiven,
        builder: (context, permissionGivenValue, child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: permissionGivenValue == PermissionStatus.permanentlyDenied
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      MyImagesUrl.location,
                      color: MyColors.whiteColor,
                      height: 100,
                    ),
                    vSizedBox,
                    ParagraphText(
                      translate(
                        "openAppSettingMsg",
                      ),
                      color: MyColors.whiteColor,
                      fontSize: 16,
                    )
                  ],
                )
              : permissionGivenValue == PermissionStatus.denied
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          MyImagesUrl.location,
                          color: MyColors.whiteColor,
                          height: 100,
                        ),
                        vSizedBox,
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
