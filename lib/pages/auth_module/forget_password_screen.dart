import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../contants/global_data.dart';
import '../../contants/my_colors.dart';
import '../../contants/sized_box.dart';
import '../../functions/navigation_functions.dart';
import '../../functions/validation_functions.dart';
import '../../provider/auth_provider.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/custom_text.dart';
import '../../widget/input_text_field_widget.dart';
import '../../widget/round_edged_button.dart';

class ForgetScreen extends StatefulWidget {
  const ForgetScreen({Key? key}) : super(key: key);

  @override
  State<ForgetScreen> createState() => _ForgetScreenState();
}

class _ForgetScreenState extends State<ForgetScreen> {
  TextEditingController emailAddress = TextEditingController();
  final formKey = GlobalKey<FormState>();
  ValueNotifier<bool> visibility = ValueNotifier(true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: translate('forgotPasswordTitle'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18.0),
          child: GestureDetector(
            onTap: () {
              popPage(context: context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ParagraphText(
                  translate("youHaveAnAccount"),
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
                ParagraphText(
                  translate("signIn"),
                  fontWeight: FontWeight.w700,
                  color: MyColors.primaryColor,
                  underlined: true,
                  fontSize: 16,
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: globalHorizontalPadding, vertical: 30),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  vSizedBox8,
                  ParagraphText(
                    translate("forgotYourPassword"),
                    fontWeight: FontWeight.w500,
                    fontSize: 35,
                  ),
                  vSizedBox2,
                  ParagraphText(
                    translate("pleaseEnterRegisterEmailId"),
                    fontWeight: FontWeight.w400,
                    color: MyColors.blackThemeColor06(),
                    fontSize: 20,
                  ),
                  vSizedBox4,
                  InputTextFieldWidget(
                    controller: emailAddress,
                    obscureText: false,
                    hintText: translate("enterEmail"),
                    validator: (val) {
                      return ValidationFunction.emailValidation(val);
                    },
                    keyboardType: TextInputType.emailAddress,
                  ),
                  vSizedBox,
                  Consumer<CustomAuthProvider>(
                      builder: (context, authPovider, child) {
                    return RoundEdgedButton(
                      text: translate("send"),
                      verticalMargin: 30,
                      width: double.infinity,
                      onTap: () {
                        if (formKey.currentState!.validate()) {
                          authPovider.forgotPasswordFunction(
                              context, emailAddress.text);
                        }
                      },
                    );
                  }),
                  vSizedBox4,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
