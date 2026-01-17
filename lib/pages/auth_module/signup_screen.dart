import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/services/password_encrypt_and_decrypt_service.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
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

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final formKey = GlobalKey<FormState>();
  TextEditingController emailAddress = TextEditingController();
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController mobileNoController = TextEditingController();
  TextEditingController password = TextEditingController();
  ValueNotifier<bool> visibility = ValueNotifier(true);

  // ValueNotifier<File?> selectedImageNoti = ValueNotifier(null);

  String countryName = "Madagasikara";
  String countryCode = "+261";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: translate("signUp"),
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
                  "${translate("youHaveAnAccount")} ",
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
      body: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: globalHorizontalPadding, vertical: 15),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ParagraphText(
                    translate("signUp"),
                    fontWeight: FontWeight.w500,
                    fontSize: 35,
                  ),
                  vSizedBox,
                  // ParagraphText(
                  //   translate("signUpWithSocialMedia"),
                  //   fontWeight: FontWeight.w400,
                  //   color: MyColors.blackThemeColor06(),
                  //   fontSize: 20,
                  // ),
                  // vSizedBox,
                  // RoundEdgedButton(
                  //   borderRadius: 10,
                  //   text: translate("continueWithFacebook"),
                  //   isStartAlignment: true,
                  //   color: const Color(0xFF2c84f4),
                  //   icon: MyImagesUrl.facebook,
                  //   iconHeight: 25,
                  //   iconWidth: 25,
                  //   fontSize: 18,
                  //   textAlign: TextAlign.start,
                  //   fontWeight: FontWeight.w500,
                  //   verticalMargin: 8,
                  //   onTap: () {},
                  // ),
                  // vSizedBox,
                  // RoundEdgedButton(
                  //   borderRadius: 10,
                  //   text: translate("continueWithGoogle"),
                  //   isStartAlignment: true,
                  //   textColor: MyColors.blackColor.withOpacity(0.5),
                  //   color: MyColors.whiteColor,
                  //   icon: MyImagesUrl.google,
                  //   verticalMargin: 8,
                  //   iconHeight: 30,
                  //   iconWidth: 30,
                  //   fontSize: 18,
                  //   textAlign: TextAlign.start,
                  //   fontWeight: FontWeight.w500,
                  //   onTap: () async {
                  //     SocialLoginServices socialLoginServices =
                  //         SocialLoginServices();

                  //     await socialLoginServices.signInWithGoogle();
                  //   },
                  // ),
                  // vSizedBox2,
                  // const Row(
                  //   children: [
                  //     Expanded(
                  //       child: Divider(),
                  //     ),
                  //     hSizedBox,
                  //     ParagraphText(
                  //       "Or",
                  //       fontWeight: FontWeight.w500,
                  //       fontSize: 15,
                  //     ),
                  //     hSizedBox,
                  //     Expanded(
                  //       child: Divider(),
                  //     )
                  //   ],
                  // ),
                  // vSizedBox2,
                  ParagraphText(
                    translate("pleaseEnterYourSignUpDetail"),
                    fontWeight: FontWeight.w400,
                    color: MyColors.blackThemeColor06(),
                    fontSize: 20,
                  ),
                  vSizedBox05,
                  InputTextFieldWidget(
                    controller: firstNameController,
                    hintText: translate("firstName"),
                    validator: (val) {
                      return ValidationFunction.requiredValidation(val!);
                    },
                  ),
                  vSizedBox05,
                  InputTextFieldWidget(
                    controller: lastNameController,
                    hintText: translate("lastName"),
                    validator: (val) {
                      return ValidationFunction.requiredValidation(val!);
                    },
                  ),
                  vSizedBox05,
                  InputTextFieldWidget(
                    controller: emailAddress,
                    hintText: translate("enterEmail"),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      return ValidationFunction.emailValidation(val);
                    },
                  ),
                  vSizedBox05,
                  InputTextFieldWidget(
                    preffix: SizedBox(
                      width: 70,
                      child: CountryCodePicker(
                        flagWidth: 22,

                        onChanged: (value) {
                          myCustomPrintStatement(
                              "dail code is that ${value.name}");
                          countryName = value.name.toString();
                          countryCode = value.dialCode.toString();
                          // country_code = value.dialCode.toString();
                          // country_name = value.name.toString();
                        },
                        // Initial selection and favorite can be one of code ('IT') OR dial_code('+39')
                        initialSelection: 'Madagasikara',
                        boxDecoration: const BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: Colors.grey))),
                        padding: const EdgeInsets.all(0.0),
                        dialogBackgroundColor: MyColors.primaryColor,
                        flagDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                        ),
                        showCountryOnly: false,
                        showFlag: true,
                        alignLeft: true,
                        // optional. aligns the flag and the Text left
                        onInit: (code) {
                          myCustomPrintStatement(
                              'country ${code!.name}  ${code.dialCode}  ${code.name}');
                          countryName = code.name.toString();
                          countryCode = code.dialCode.toString();
                          // country_name = code.name.toString();
                        },

                        // showDropDownButton: true,
                      ),
                    ),
                    controller: mobileNoController,
                    hintText: translate("phoneNumber"),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(10),
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: false),
                    validator: (val) =>
                        ValidationFunction.mobileNumberValidation(val),
                  ),
                  vSizedBox05,
                  ValueListenableBuilder(
                    valueListenable: visibility,
                    builder: (_, value, __) => InputTextFieldWidget(
                      controller: password,
                      obscureText: value,
                      hintText: translate("enterPassword"),
                      validator: (val) =>
                          ValidationFunction.passwordValidation(val),
                      suffix: IconButton(
                        onPressed: () {
                          visibility.value = !value;
                        },
                        icon: Icon(
                          !value
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: Theme.of(context).hintColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  vSizedBox05,
                  Consumer<CustomAuthProvider>(
                      builder: (context, authPovider, child) {
                    return RoundEdgedButton(
                      width: double.infinity,
                      text: translate("submit"),
                      onTap: () async {
                        if (formKey.currentState!.validate()) {
                          DevFestPreferences().setVerificationCode("");
                          DevFestPreferences().setUserVerificationRequest({});
                          authPovider.numberVerificationOTP = '';
                           
                          Map<String, dynamic> request = {
                            'name':
                                "${firstNameController.text} ${lastNameController.text}",
                            'firstName': firstNameController.text,
                            'lastName': lastNameController.text,
                            'email': emailAddress.text,
                            "verified": true,
                            "isBlocked": false,
                            "isCustomer": true,
                            'phoneNo': mobileNoController.text,
                            'countryName': countryName,
                            'countryCode': countryCode,
                            'password': password.text,
                            'profileImage': dummyUserImage,
                          };
                          // ignore: use_build_context_synchronously
                          authPovider.checkMobileNumberAndEmailExist(
                              context, request);
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
