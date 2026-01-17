import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/modal/user_social_login_detail_modal.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/services/social_login_service.dart';
import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../../contants/global_data.dart';
import '../../contants/my_colors.dart';
import '../../contants/sized_box.dart';
import '../../functions/navigation_functions.dart';
import '../../functions/validation_functions.dart';
import '../../provider/auth_provider.dart';
import '../../widget/custom_text.dart';
import '../../widget/input_text_field_widget.dart';
import '../../widget/round_edged_button.dart';
import '../view_module/privacy_screen.dart';
import 'forget_password_screen.dart';
import 'signup_screen.dart';
import 'package:rider_ride_hailing_app/utils/platform.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final loginFormKey = GlobalKey<FormState>();
  ValueNotifier<bool> visibility = ValueNotifier(true);
  ValueNotifier<bool> isEmail = ValueNotifier(true);
  ValueNotifier<bool> hasEmailInput = ValueNotifier(false);
  ValueNotifier<bool> showEmailSuggestions = ValueNotifier(false);
  ValueNotifier<List<String>> filteredDomains = ValueNotifier([]);
  String countryCode = "+261";
  String currentEmailPrefix = "";

  // Liste des domaines email populaires
  final List<String> emailDomains = [
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
    'protonmail.com',
    'aol.com',
    'mail.com',
  ];
  @override
  void initState() {
    // WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
    //   var getRequest = await DevFestPreferences().getUserVerificationRequest();
    //   if (getRequest.isNotEmpty) {
    //     push(
    //         // ignore: use_build_context_synchronously
    //         context: context,
    //         screen: OTPVerificationScreen(request: getRequest));
    //   }
    // });
    super.initState();
  }

  // Méthode pour sélectionner un domaine email
  void selectEmailDomain(String domain, CustomAuthProvider authProvider) {
    final newEmail = currentEmailPrefix + domain;
    authProvider.emailAddressCont.text = newEmail;
    authProvider.emailAddressCont.selection = TextSelection.fromPosition(
      TextPosition(offset: newEmail.length),
    );
    showEmailSuggestions.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Bouton retour en haut à gauche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: MyColors.blackThemeColor(),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: globalHorizontalPadding, vertical: 15),
                child: SingleChildScrollView(
                  child: Form(
                    key: loginFormKey,
                    child: Consumer<AdminSettingsProvider>(
                      builder: (context, adminSettingProvider, child) => Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            // Logo Misy rose centré
                            Center(
                              child: Image.asset(
                                'assets/icons/misy_logo_rose.png',
                                height: 80,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Texte de sécurité avec cadenas vert
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  ParagraphText(
                                    "Chiffrement des données",
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                            ),
                            vSizedBox2,
                      ParagraphText(
                        "Numéro de téléphone ou adresse e-mail",
                        fontWeight: FontWeight.w400,
                        color: MyColors.blackThemeColor06(),
                        fontSize: 14,
                      ),
                      vSizedBox05,
                      Consumer<CustomAuthProvider>(
                        builder: (context, authPovider, child) =>
                            ValueListenableBuilder(
                          valueListenable: isEmail,
                          builder: (context, emailValue, child) =>
                              InputTextFieldWidget(
                            preffix: emailValue
                                ? null
                                : SizedBox(
                                    width: 70,
                                    child: CountryCodePicker(
                                      flagWidth: 22,

                                      onChanged: (value) {
                                        myCustomPrintStatement(
                                            "dail code is that ${value.name}");
                                        countryCode = value.dialCode.toString();
                                        // country_name = value.name.toString();
                                      },
                                      // Initial selection and favorite can be one of code ('IT') OR dial_code('+39')
                                      initialSelection: 'Madagasikara',
                                      boxDecoration: const BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: Colors.grey))),
                                      padding: const EdgeInsets.all(0.0),
                                      dialogBackgroundColor:
                                          MyColors.primaryColor,
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

                                        // country_name = code.name.toString();
                                      },

                                      // showDropDownButton: true,
                                    ),
                                  ),
                            controller: authPovider.emailAddressCont,
                            obscureText: false,
                            hintText: "",
                            validator: (val) {
                              return emailValue
                                  ? ValidationFunction.emailValidation(val)
                                  : ValidationFunction.mobileNumberValidation(
                                      val);
                            },
                            onChanged: (val) {
                              hasEmailInput.value = val.isNotEmpty;
                              if (val.startsWith(RegExp(r'[0-9]'))) {
                                isEmail.value = false;
                                showEmailSuggestions.value = false;
                              } else {
                                isEmail.value = true;

                                // Détecter si l'utilisateur a tapé @
                                if (val.contains('@')) {
                                  final parts = val.split('@');
                                  if (parts.length == 2) {
                                    currentEmailPrefix = parts[0] + '@';
                                    final domainInput = parts[1].toLowerCase();

                                    // Filtrer les domaines qui correspondent
                                    if (domainInput.isEmpty) {
                                      filteredDomains.value = emailDomains;
                                      showEmailSuggestions.value = true;
                                    } else {
                                      final matches = emailDomains
                                          .where((domain) => domain.startsWith(domainInput))
                                          .toList();
                                      filteredDomains.value = matches;
                                      showEmailSuggestions.value = matches.isNotEmpty;
                                    }
                                  } else {
                                    showEmailSuggestions.value = false;
                                  }
                                } else {
                                  showEmailSuggestions.value = false;
                                }
                              }
                            },
                            inputFormatters: emailValue
                                ? null
                                : [
                                    LengthLimitingTextInputFormatter(10),
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                            keyboardType: emailValue
                                ? TextInputType.emailAddress
                                : const TextInputType.numberWithOptions(
                                    signed: true, decimal: false),
                            fillColor: Colors.grey[100],
                            borderColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      // Suggestions de domaines email
                      ValueListenableBuilder(
                        valueListenable: showEmailSuggestions,
                        builder: (context, showSuggestions, child) {
                          if (!showSuggestions) return const SizedBox.shrink();
                          return ValueListenableBuilder(
                            valueListenable: filteredDomains,
                            builder: (context, domains, child) {
                              return Consumer<CustomAuthProvider>(
                                builder: (context, authProvider, child) {
                                  return Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: MyColors.whiteColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: MyColors.primaryColor.withOpacity(0.3),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: domains.map((domain) {
                                        return InkWell(
                                          onTap: () => selectEmailDomain(domain, authProvider),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.withOpacity(0.2),
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.email_outlined,
                                                  size: 18,
                                                  color: MyColors.primaryColor,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    currentEmailPrefix + domain,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color: MyColors.blackThemeColor(),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      ValueListenableBuilder(
                        valueListenable: hasEmailInput,
                        builder: (context, hasInput, child) {
                          if (!hasInput) return const SizedBox.shrink();
                          return Column(
                            children: [
                              vSizedBox05,
                              Consumer<CustomAuthProvider>(
                                builder: (context, authPovider, child) =>
                                    ValueListenableBuilder(
                                  valueListenable: visibility,
                                  builder: (_, value, __) => InputTextFieldWidget(
                                    controller: authPovider.passwordCont,
                                    obscureText: value,
                                    hintText: translate("enterPassword"),
                                    validator: (val) =>
                                        ValidationFunction.passwordValidation(val),
                                    keyboardType: TextInputType.emailAddress,
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
                              ),
                              vSizedBox,
                            ],
                          );
                        },
                      ),
                      ValueListenableBuilder(
                        valueListenable: hasEmailInput,
                        builder: (context, hasInput, child) {
                          if (!hasInput) return const SizedBox.shrink();
                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  push(
                                    context: context,
                                    screen: const ForgetScreen(),
                                  );
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  child: SubHeadingText(
                                    translate("forgotPassword"),
                                    fontSize: 18,
                                    color: MyColors.primaryColor,
                                    underlined: true,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              vSizedBox05,
                              Consumer<CustomAuthProvider>(
                                  builder: (context, authPovider, child) {
                                return RoundEdgedButton(
                                  text: translate("login"),
                                  width: double.infinity,
                                  onTap: () {
                                    if (loginFormKey.currentState!.validate()) {
                                      FocusScope.of(context).unfocus();
                                      if (isEmail.value) {
                                        authPovider.loginFunction(
                                            context: context,
                                            password: authPovider.passwordCont.text,
                                            emailId: authPovider.emailAddressCont.text);
                                      } else {
                                        authPovider.logInWithPhoneNumberAndPassword(
                                            context: context,
                                            countryCode: countryCode,
                                            password: authPovider.passwordCont.text,
                                            phoneNumber:
                                                authPovider.emailAddressCont.text);
                                      }
                                    }
                                  },
                                );
                              }),
                            ],
                          );
                        },
                      ),
                      if (!(Platform.isAndroid &&
                              adminSettingProvider.defaultAppSettingModal
                                  .hideAndroidSocialLogin) &&
                          !(Platform.isIOS &&
                              adminSettingProvider
                                  .defaultAppSettingModal.hideIOSSocialLogin))
                        vSizedBox05,
                      if (!(Platform.isAndroid &&
                              adminSettingProvider.defaultAppSettingModal
                                  .hideAndroidSocialLogin) &&
                          !(Platform.isIOS &&
                              adminSettingProvider
                                  .defaultAppSettingModal.hideIOSSocialLogin))
                        Center(
                          child: ParagraphText(
                            "Se connecter avec",
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: MyColors.blackThemeColor06(),
                          ),
                        ),
                      if (!(Platform.isAndroid &&
                              adminSettingProvider.defaultAppSettingModal
                                  .hideAndroidSocialLogin) &&
                          !(Platform.isIOS &&
                              adminSettingProvider
                                  .defaultAppSettingModal.hideIOSSocialLogin))
                        vSizedBox,
                      if (!(Platform.isAndroid &&
                              adminSettingProvider.defaultAppSettingModal
                                  .hideAndroidSocialLogin) &&
                          !(Platform.isIOS &&
                              adminSettingProvider
                                  .defaultAppSettingModal.hideIOSSocialLogin))
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icône Google
                            GestureDetector(
                              onTap: () async {
                                // Afficher immédiatement l'indicateur de chargement avec EasyLoading
                                EasyLoading.show(
                                  status: 'Connexion avec Google...',
                                  maskType: EasyLoadingMaskType.black,
                                  dismissOnTap: false,
                                );

                                try {
                                  SocialLoginServices socialLoginServices =
                                      SocialLoginServices();
                                  UserSocialLoginDeatilModal?
                                      userSocialLoginDeatilModal =
                                      await socialLoginServices.signInWithGoogle();

                                  // Fermer le loader
                                  EasyLoading.dismiss();

                                  if (userSocialLoginDeatilModal != null) {
                                    myCustomPrintStatement(
                                        "social login detail ${userSocialLoginDeatilModal.toJson()}");

                                    // Analytics tracking pour connexion Google réussie
                                    AnalyticsService.logUserLogin(
                                      method: 'google',
                                      userId: userSocialLoginDeatilModal.socialLoginId ?? 'unknown',
                                    );
                                  } else {
                                    // ⚡ FIX: L'utilisateur a annulé la connexion Google
                                    // S'assurer que l'état est correctement réinitialisé
                                    myCustomPrintStatement("⚠️ Connexion Google annulée - retour à l'écran de login");
                                    // Le flag isGoogleSignInInProgress est déjà réinitialisé dans SocialLoginServices
                                  }
                                } catch (e) {
                                  // Fermer le loader en cas d'erreur
                                  EasyLoading.dismiss();
                                  myCustomPrintStatement("Erreur lors de la connexion Google: $e");
                                }
                              },
                              child: SvgPicture.asset(
                                MyImagesUrl.google,
                                width: 56,
                                height: 56,
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Icône Facebook
                            GestureDetector(
                              onTap: () async {
                                if (Platform.isIOS) {
                                  TrackingStatus status =
                                      await AppTrackingTransparency
                                          .trackingAuthorizationStatus;

                                  if (status == TrackingStatus.notDetermined) {
                                    status = await AppTrackingTransparency
                                        .requestTrackingAuthorization();
                                  } else {
                                    if (status != TrackingStatus.authorized) {
                                      await openAppSettings();
                                    }
                                  }

                                  if (status != TrackingStatus.authorized) {
                                    showSnackbar(
                                      'Login cancelled, to continue please allow this app to track your activity.',
                                    );
                                    return;
                                  }
                                }

                                // Afficher immédiatement l'indicateur de chargement avec EasyLoading
                                EasyLoading.show(
                                  status: 'Connexion avec Facebook...',
                                  maskType: EasyLoadingMaskType.black,
                                  dismissOnTap: false,
                                );

                                try {
                                  SocialLoginServices socialLoginServices =
                                      SocialLoginServices();
                                  UserSocialLoginDeatilModal?
                                      userSocialLoginDeatilModal =
                                      await socialLoginServices.facebookLogin();

                                  // Fermer le loader
                                  EasyLoading.dismiss();

                                  if (userSocialLoginDeatilModal != null) {
                                    myCustomPrintStatement(
                                        "social login detail ${userSocialLoginDeatilModal.toJson()}");
                                  }
                                } catch (e) {
                                  // Fermer le loader en cas d'erreur
                                  EasyLoading.dismiss();
                                  myCustomPrintStatement("Erreur lors de la connexion Facebook: $e");
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(0),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    MyImagesUrl.facebook,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (!(Platform.isAndroid &&
                              adminSettingProvider.defaultAppSettingModal
                                  .hideAndroidSocialLogin) &&
                          !(Platform.isIOS &&
                              adminSettingProvider
                                  .defaultAppSettingModal.hideIOSSocialLogin))
                        vSizedBox,
                      Divider(
                        color: MyColors.blackThemeColor(),
                      ),
                      Center(
                        child: ParagraphText(
                          "${translate("youDontHaveAccount")}  ",
                          fontWeight: FontWeight.w400,
                          fontSize: 18,
                        ),
                      ),
                      RoundEdgedButton(
                        width: double.infinity,
                        color: MyColors.blueLinerColor,
                        fontSize: 16,
                        ignoreInternetConnectivity: true,
                        text: translate("signUp"),
                        onTap: () {
                          push(
                            context: context,
                            screen: const SignUpScreen(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ), // fin Expanded
        // Texte de confidentialité en bas de l'écran
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                    text: "En continuant, vous acceptez notre ",
                  ),
                  TextSpan(
                    text: "Politique de confidentialité et de cookies",
                    style: TextStyle(
                      color: MyColors.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        push(
                          context: context,
                          screen: const PrivacyPolicyScreen(),
                        );
                      },
                  ),
                  const TextSpan(
                    text: " et nos ",
                  ),
                  TextSpan(
                    text: "Conditions générales",
                    style: TextStyle(
                      color: MyColors.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        push(
                          context: context,
                          screen: const PrivacyPolicyScreen(),
                        );
                      },
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),  // fin Column
    ),  // fin SafeArea
    );  // fin Scaffold
  }
}
