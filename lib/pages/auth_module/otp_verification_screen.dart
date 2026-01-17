import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/phone_number_screen.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_rich_text.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import '../../contants/global_data.dart';
import '../../contants/my_colors.dart';
import '../../contants/sized_box.dart';
import '../../provider/auth_provider.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/custom_text.dart';
import '../../widget/round_edged_button.dart';

class OTPVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const OTPVerificationScreen({Key? key, required this.request})
      : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final formKey = GlobalKey<FormState>();
  String numberVerificationOTP = "";
  Timer? timer;
  TextEditingController textEditingController = TextEditingController();
  // ..text = "123456";

  // ignore: close_sinks
  StreamController<ErrorAnimationType>? errorController;
  ValueNotifier<int> remainingSeconds = ValueNotifier(180);
  @override
  void initState() {
    errorController = StreamController<ErrorAnimationType>();
    startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      CustomAuthProvider customAuthProvider =
          Provider.of<CustomAuthProvider>(context, listen: false);
      if (customAuthProvider.numberVerificationOTP.isEmpty) {
        customAuthProvider.sendOTPSmsToMobileNumber(
            sendToMobileNo:
                "${widget.request['countryCode']}${widget.request['phoneNo']}");
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    errorController!.close();
    timer!.cancel();
    super.dispose();
  }

  void startCountdown() {
    const oneSecond = Duration(seconds: 1);
    timer = Timer.periodic(oneSecond, (Timer timer) {
      if (remainingSeconds.value <= 0) {
        timer.cancel();
      } else {
        remainingSeconds.value--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: translate('verifyMobileTitle'),
        onPressed: () {
          if (widget.request['email'] == null) {
            pushReplacement(
                screen: const PhoneNumberScreen(), context: context);
          } else {
            pushReplacement(context: context, screen: const LoginPage());
          }
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: globalHorizontalPadding, vertical: 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                vSizedBox8,
                ParagraphText(
                  translate("enterYourOTP"),
                  fontWeight: FontWeight.w500,
                  fontSize: 35,
                ),
                vSizedBox2,
                ParagraphText(
                  translate("pleaseEnterOtpNumber"),
                  fontWeight: FontWeight.w400,
                  color: MyColors.blackThemeColor06(),
                  fontSize: 16,
                ),
                vSizedBox,
                Consumer<CustomAuthProvider>(
                  builder: (context, authProvider, child) => Form(
                    key: formKey,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 0.0, horizontal: 16),
                        child: PinCodeTextField(
                          appContext: context,
                          pastedTextStyle: const TextStyle(
                            color: Colors.green,
                            backgroundColor: Colors.yellow,
                            fontWeight: FontWeight.bold,
                          ),

                          length: 4,
                          enablePinAutofill: true,

                          animationType: AnimationType.fade,
                         
                          // validator: (v) {
                          //   // if (v!.length < 3) {
                          //   //   // return "I'm from validator";
                          //   // } else {
                          //   //   return null;
                          //   // }
                          // },

                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.box,
                            borderRadius: BorderRadius.circular(10),
                            fieldHeight: 56,
                            fieldWidth: 56,
                            selectedColor: MyColors.primaryColor,
                            activeFillColor: MyColors.whiteColor,
                            selectedFillColor: MyColors.whiteColor,
                            inactiveFillColor: MyColors.whiteColor,
                            activeColor: MyColors.greyColor,
                            inactiveColor: MyColors.greyColor,
                          ),
                          hintCharacter: '-',
                          cursorColor: MyColors.primaryColor,
                          animationDuration: const Duration(milliseconds: 300),
                          enableActiveFill: true,
                          errorAnimationController: errorController,
                          controller: textEditingController,
                              inputFormatters: [
                              LengthLimitingTextInputFormatter(10),
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: false),
                          onCompleted: (v) {
                            myCustomPrintStatement("Completed");
                          },
                          // onTap: () {
                          //   myCustomPrintStatement("Pressed");
                          // },

                          onChanged: (value) async {
                            myCustomPrintStatement(
                                'otp on changed is called $value');

                            myCustomPrintStatement(value);

                            numberVerificationOTP = value;

                            // if (numberVerificationOTP ==
                            //     authProvider.numberVerificationOTP) {
                            //   // widget.load();

                            //   // Navigator.pushNamed(context, SelectUserTypeScreen.id);
                            // } else if (numberVerificationOTP.length == 4) {
                            //   numberVerificationOTP = '';
                            //   textEditingController.clear();
                            //   showSnackbar("Wrong Otp");
                            // }
                          },

                          beforeTextPaste: (text) {
                            myCustomPrintStatement("Allowing to paste $text");

                            //if you return true then it will show the paste confirmation dialog. Otherwise if false, then nothing will happen.
                            //but you can show anything you want here, like your pop up saying wrong paste format or etc
                            return true;
                          },
                        )),
                  ),
                ),
                // OtpTextField(
                //   numberOfFields: 4,
                //   borderColor: MyColors.textFillThemeColor(),
                //   fillColor: MyColors.textFillThemeColor(),
                //   borderRadius: BorderRadius.circular(15),
                //   focusedBorderColor: MyColors.primaryColor,
                //   showFieldAsBox: true,
                //   margin: const EdgeInsets.symmetric(horizontal: 10),
                //   fieldHeight: 60,
                //   fieldWidth: 60,
                //   textStyle: TextStyle(color: MyColors.blackThemeColor()),
                //   onCodeChanged: (String value) {
                //     print("verifcation code $value");
                //   },
                //   readOnly: true,
                //   handleControllers: (controllers) {},
                //   onSubmit: (String verificationCode) {
                //     numberVerificationOTP = verificationCode;
                //   },
                // ),

                vSizedBox2,
                ValueListenableBuilder(
                  valueListenable: remainingSeconds,
                  builder: (context, remaining, child) => Align(
                    alignment: Alignment.centerRight,
                    child: remaining > 0
                        ? Container(
                            width: 155,
                            child: RichTextCustomWidget(
                              firstText: "Resend After :- ",
                              firstTextFontSize: 14,
                              secondTextFontSize: 14,
                              secondText:
                                  "${formattedTime(timeInSecond: remaining)}",
                              firstTextColor: MyColors.blackColor,
                              secondTextColor: MyColors.primaryColor,
                            ),
                          )
                        : InkWell(
                            onTap: () {
                              Provider.of<CustomAuthProvider>(context,
                                      listen: false)
                                  .sendOTPSmsToMobileNumber(
                                      sendToMobileNo:
                                          "${widget.request['countryCode']}${widget.request['phoneNo']}");
                              remainingSeconds.value = 180;
                              startCountdown();
                            },
                            child: ParagraphText(
                              translate("resend"),
                              fontWeight: FontWeight.w700,
                              color: MyColors.primaryColor,
                              underlined: true,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                vSizedBox,
                Consumer<CustomAuthProvider>(
                    builder: (context, authPovider, child) {
                  return RoundEdgedButton(
                    text: translate("submit"),
                    width: double.infinity,
                    verticalMargin: 30,
                    onTap: () async {
                      if (numberVerificationOTP.isEmpty) {
                        showSnackbar("Veuillez entrer le code OTP.");
                      } else if (numberVerificationOTP.length < 4) {
                        showSnackbar("Veuillez entrer un code OTP à 4 chiffres.");
                      } else if (numberVerificationOTP !=
                          authPovider.numberVerificationOTP) {
                        showSnackbar(
                            "Le code OTP saisi est incorrect. Veuillez réessayer.");
                      } else if (widget.request['email'] == null) {
                        await DevFestPreferences().setVerificationCode("");
                        await DevFestPreferences()
                            .setUserVerificationRequest({});
                        await authPovider.editProfile({
                          "phoneNo": widget.request['phoneNo'],
                          'countryName': widget.request['countryName'],
                          'countryCode': widget.request['countryCode'],
                        });
                        authPovider.setAuthListener(context);
                      } else {
                        authPovider.signup(context, widget.request);
                      }
                    },
                  );
                }),
                vSizedBox,
              ],
            ),
          ),
        ),
      ),
    );
  }

  formattedTime({required int timeInSecond}) {
    int sec = timeInSecond % 60;
    int min = (timeInSecond / 60).floor();
    String minute = min.toString().length <= 1 ? "0$min" : "$min";
    String second = sec.toString().length <= 1 ? "0$sec" : "$sec";
    return "$minute : $second";
  }
}
