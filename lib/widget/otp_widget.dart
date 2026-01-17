import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import '../functions/print_function.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class OtpVerification extends StatefulWidget {
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final String navigationFrom;
  final String correctOtp;
  final Function load;
  final Function() wrongOtp;
  final String? prefill;

  const OtpVerification({
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.navigationFrom,
    required this.correctOtp,
    required this.load,
    required this.wrongOtp,
    this.prefill,
    Key? key,
  }) : super(key: key);

  @override
  OtpVerificationState createState() => OtpVerificationState();
}

class OtpVerificationState extends State<OtpVerification> {
  TextEditingController textEditingController = TextEditingController();
  // ..text = "123456";

  // ignore: close_sinks
  StreamController<ErrorAnimationType>? errorController;

  bool hasError = false;
  String currentText = "";
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    errorController = StreamController<ErrorAnimationType>();
    if (widget.prefill != null) {
      textEditingController.text = widget.prefill!;
    }
    super.initState();
  }

  @override
  void dispose() {
    errorController!.close();

    super.dispose();
  }

  // snackBar Widget
  snackBar(String? message) {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message!),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Form(
          key: formKey,
          child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16),
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
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
                  activeFillColor: widget.bgColor,
                  selectedFillColor: widget.bgColor,
                  inactiveFillColor: widget.bgColor,
                  activeColor: widget.borderColor,
                  inactiveColor: widget.borderColor,
                  selectedColor: MyColors.primaryColor,
                ),
                hintCharacter: '-',
                cursorColor: widget.textColor,
                animationDuration: const Duration(milliseconds: 300),
                enableActiveFill: true,
                errorAnimationController: errorController,
                controller: textEditingController,
                keyboardType: TextInputType.number,
                onCompleted: (v) {
                  if (kDebugMode) {
                    myCustomPrintStatement("Completed");
                  }
                },
                // onTap: () {
                //   myCustomPrintStatement("Pressed");
                // },

                onChanged: (value) async {
                  if (kDebugMode) {
                    myCustomPrintStatement('otp on changed is called $value');
                  }
                  if (kDebugMode) {
                    myCustomPrintStatement(value);
                  }
                  setState(() {
                    currentText = value;
                  });
                  if (currentText == widget.correctOtp) {
                    widget.load();

                    // Navigator.pushNamed(context, SelectUserTypeScreen.id);
                  } else if (currentText.length == 6) {
                    currentText = '';
                    textEditingController.clear();
                    widget.wrongOtp();
                    setState(() {});
                    showSnackbar("Code OTP incorrect");
                  }
                  setState(() {});
                },

                beforeTextPaste: (text) {
                  if (kDebugMode) {
                    myCustomPrintStatement("Allowing to paste $text");
                  }
                  //if you return true then it will show the paste confirmation dialog. Otherwise if false, then nothing will happen.
                  //but you can show anything you want here, like your pop up saying wrong paste format or etc
                  return true;
                },
              )),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Text(
            hasError ? "*Please fill up all the cells properly" : "",
            style: const TextStyle(
                color: Colors.red, fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}
