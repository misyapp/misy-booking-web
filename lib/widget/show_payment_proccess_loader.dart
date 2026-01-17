// ignore_for_file: deprecated_member_use

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_custom_dialog.dart';

showPaymentProccessLoader({Function()? onTap}) async {
  return await showCustomDialog(
      barrierDismissible: false,
      height: 230,
      child: WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ParagraphText(
            translate("Payment is being processed"),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          vSizedBox,
          Container(
            clipBehavior: Clip.none,
            width: (MediaQuery.of(MyGlobalKeys.navigatorKey.currentContext!)
                    .size
                    .width -
                70),
            // padding:EdgeInsets.fromLTRB(0, 0, 20, 0),
            child: LoadingAnimationWidget.twistingDots(
              leftDotColor: MyColors.coralPink,
              rightDotColor: MyColors.horizonBlue,
              size: 50.0,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: ParagraphText(
              translate("Please wait"),
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
          vSizedBox,
          Align(
            alignment: Alignment.center,
            child: RoundEdgedButton(
              text: translate('cancel'),
              onTap: onTap,
              width: 100,
              height: 35,
              fontSize: 14,
            ),
          )
        ]),
      ));
}

paymentRecivedSuccessFullDailog() async {
  final player = AudioPlayer();
  player.play(
    AssetSource('audio/payment_successfull.mp3'),
  );
  Future.delayed(
      const Duration(
        seconds: 3,
      ), () {
    popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
  });
  return await showCustomDialog(
      barrierDismissible: false,
      height: 200,
      child: WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.green, width: 2)),
              child: const Icon(
                Icons.done,
                color: Colors.green,
                size: 45,
              ),
            ),
          ),
          vSizedBox,
          const Align(
            alignment: Alignment.center,
            child: ParagraphText(
              "Successfully Paid",
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ));
}

hidePaymentProccessLoader() {
  popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
}
