import 'package:rider_ride_hailing_app/utils/platform.dart';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/change_password_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/image_picker.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/widget/common_alert_dailog.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../contants/global_data.dart';
import '../../contants/my_colors.dart';
import '../../contants/my_image_url.dart';
import '../../contants/sized_box.dart';
import '../../functions/validation_functions.dart';
import '../../provider/auth_provider.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/custom_circular_image.dart';
import '../../widget/custom_text.dart';
import '../../widget/input_text_field_widget.dart';
import '../../widget/round_edged_button.dart';

class EditProfileFormScreen extends StatefulWidget {
  const EditProfileFormScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileFormScreen> createState() => _EditProfileFormScreenState();
}

class _EditProfileFormScreenState extends State<EditProfileFormScreen> {
  TextEditingController emailAddress = TextEditingController();
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController mobileNoController = TextEditingController();
  TextEditingController dobController = TextEditingController();
  ValueNotifier<bool> mobileNumberDisableNoti = ValueNotifier(false);
  final formKey = GlobalKey<FormState>();
  ValueNotifier<File?> selectedImageNoti = ValueNotifier(null);
  String countryName = "Madagasikara";
  String countryCode = "+261";

  @override
  void initState() {
    super.initState();
    // Initialize controllers with user data
    final user = userData.value;
    if (user != null) {
      emailAddress.text = user.email;
      firstNameController.text = user.firstName;
      lastNameController.text = user.lastName;
      mobileNoController.text = user.phone;
      mobileNumberDisableNoti.value = user.phone.isEmpty || user.phone.length < 10;
      dobController.text = user.dob;
      countryName = user.countryName;
      countryCode = user.countryCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: translate('Modifier mes informations'),
      ),
      bottomNavigationBar:
          Consumer<CustomAuthProvider>(builder: (context, authPovider, child) {
        return SafeArea(
          child: RoundEdgedButton(
            width: double.infinity,
            text: translate("save"),
            verticalMargin: 20,
            horizontalMargin: globalHorizontalPadding,
            onTap: () async {
              if (formKey.currentState!.validate()) {
                showLoading();
                String url = "";
                if (selectedImageNoti.value != null) {
                  url = await FirestoreServices.uploadFile(
                      selectedImageNoti.value!, 'users',
                      showloader: false);
                  if (url.isNotEmpty && userData.value!.profileImage.isNotEmpty) {
                    await FirestoreServices.deleteUploadedImage(
                        userData.value!.profileImage,
                        showLoader: false);
                  }
                }
                await authPovider.editProfile({
                  "profileImage": selectedImageNoti.value != null
                      ? url
                      : userData.value!.profileImage,
                  "phoneNo": mobileNoController.text,
                  'countryName': countryName,
                  'countryCode': countryCode,
                  "name":
                      "${firstNameController.text} ${lastNameController.text}",
                  "firstName": firstNameController.text,
                  "lastName": lastNameController.text,
                  "dob": dobController.text,
                });
                hideLoading();
                showSnackbar(translate("profileUpdatedSuccessfully"));
              }
            },
          ),
        );
      }),
      body: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: globalHorizontalPadding, vertical: 15),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                ValueListenableBuilder(
                  valueListenable: userData,
                  builder: (context, userDataValue, child) =>
                      ValueListenableBuilder(
                    valueListenable: selectedImageNoti,
                    builder: (context, selectImageValue, child) => Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CustomCircularImage(
                          height: 110,
                          width: 110,
                          imageUrl: userDataValue!.profileImage,
                          image: selectImageValue,
                          borderRadius: 100,
                          fit: BoxFit.fill,
                          fileType: selectImageValue == null
                              ? CustomFileType.network
                              : CustomFileType.file,
                        ),
                        InkWell(
                          onTap: () async {
                            var data = await cameraGallerypicker(
                              context,
                            );
                            if (data != null) {
                              selectedImageNoti.value = data['value'];
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 6, bottom: 8),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                color: MyColors.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 0.8)),
                            child: Icon(
                              Icons.edit,
                              size: 14,
                              color: MyColors.whiteColor,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                ParagraphText(
                  translate("Profile picture"),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                vSizedBox,
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
                  fillColor: MyColors.backgroundThemeColor(),
                  hintText: translate("enterEmail"),
                  enabled: false,
                  keyboardType: TextInputType.emailAddress,
                  suffix: const Icon(
                    Icons.email_outlined,
                    size: 20,
                  ),
                  validator: (val) {
                    return ValidationFunction.emailValidation(val);
                  },
                ),
                vSizedBox05,
                ValueListenableBuilder(
                  valueListenable: mobileNumberDisableNoti,
                  builder: (context, mobileNumberDisable, child) =>
                      InputTextFieldWidget(
                    controller: mobileNoController,
                    enabled: mobileNumberDisable,
                    fillColor: mobileNumberDisable
                        ? null
                        : MyColors.backgroundThemeColor(),
                    hintText: translate("phoneNumber"),
                    preffix: SizedBox(
                      width: 70,
                      child: CountryCodePicker(
                        flagWidth: 22,
                        onChanged: (value) {
                          countryName = value.name.toString();
                          countryCode = value.dialCode.toString();
                        },
                        initialSelection: userData.value!.countryName,
                        boxDecoration: BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: MyColors.borderThemeColor()))),
                        padding: const EdgeInsets.all(0.0),
                        dialogBackgroundColor: MyColors.primaryColor,
                        flagDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                        ),
                        showCountryOnly: false,
                        showFlag: true,
                        alignLeft: true,
                        onInit: (code) {
                          if (code != null) {
                            countryName = code.name.toString();
                          }
                        },
                      ),
                    ),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(10),
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: false),
                    suffix: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                        MyImagesUrl.phoneOutline01,
                        width: 16,
                        color: MyColors.blackThemeColor(),
                      ),
                    ),
                    validator: (val) => mobileNumberDisable
                        ? ValidationFunction.mobileNumberValidation(val)
                        : null,
                  ),
                ),
                vSizedBox05,
                InkWell(
                  onTap: () async {
                    var dobIsThat = await showDatePicker(
                        context: context,
                        firstDate: DateTime(DateTime.now().year - 100),
                        lastDate: DateTime(DateTime.now().year - 17));
                    if (dobIsThat != null) {
                      dobController.text =
                          DateFormat("dd-MM-yyyy").format(dobIsThat);
                    }
                  },
                  child: InputTextFieldWidget(
                    controller: dobController,
                    enabled: false,
                    textColor: MyColors.blackThemeColor(),
                    hintText: translate("enterDateOfBirth"),
                    suffix: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          MyImagesUrl.dobIcon,
                          height: 20,
                          width: 20,
                          color: MyColors.blackThemeColor(),
                        )),
                    validator: (val) =>
                        ValidationFunction.requiredValidation(val!),
                  ),
                ),
                vSizedBox05,
                RoundEdgedButton(
                  text: translate("changePassword"),
                  verticalMargin: 0,
                  fontSize: 13,
                  color: MyColors.blueColor,
                  fontWeight: FontWeight.normal,
                  height: 30,
                  onTap: () {
                    push(
                        context: context, screen: const ChangePasswordScreen());
                  },
                  borderRadius: 7,
                ),
                vSizedBox,
                InkWell(
                  child: ParagraphText(
                    translate("Delete your account"),
                    underlined: true,
                    color: MyColors.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: () {
                    TripProvider tripProvider =
                        Provider.of<TripProvider>(context, listen: false);
                    if (tripProvider.booking != null) {
                      showSnackbar(
                        translate(
                          "Please complete your booking first and then request account deletion",
                        ),
                      );
                    } else {
                      showCommonAlertDailog(
                        context,
                        headingText: translate("areYouSure"),
                        successIcon: false,
                        message:
                            translate("Do you want to delete your account"),
                        actions: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RoundEdgedButton(
                                text: translate("no"),
                                color: MyColors.blackThemeColorWithOpacity(0.3),
                                width: 100,
                                height: 40,
                                onTap: () {
                                  popPage(context: context);
                                },
                              ),
                              hSizedBox2,
                              RoundEdgedButton(
                                text: translate("yes"),
                                width: 100,
                                height: 40,
                                onTap: () async {
                                  showLoading();
                                  CustomAuthProvider customAuthProvider =
                                      Provider.of<CustomAuthProvider>(context,
                                          listen: false);

                                  popPage(context: context);
                                  try {
                                    // 🔐 CRITIQUE: Sauvegarder les providers AVANT de supprimer l'utilisateur
                                    // Car après .delete(), currentUser devient null et on ne peut plus savoir
                                    // quels providers déconnecter (Google, Facebook, etc.)
                                    final user = customAuthProvider.currentUser;
                                    final providers = user?.providerData.map((info) => info.providerId).toList() ?? [];
                                    myCustomPrintStatement("🔍 Providers détectés avant suppression: $providers");

                                    // 🗑️ Marquer le compte comme supprimé dans Firestore AVANT de supprimer l'utilisateur
                                    // Car après .delete(), on ne peut plus accéder à Firestore avec ce user
                                    await customAuthProvider.editProfile({
                                      "accountDeleted": true,
                                    });
                                    myCustomPrintStatement("✅ Compte marqué comme supprimé dans Firestore");

                                    // 🔐 Déconnecter les providers sociaux AVANT de supprimer l'utilisateur Firebase
                                    // Sinon, les sessions Google/Facebook restent actives après suppression
                                    if (providers.contains('google.com')) {
                                      try {
                                        final googleSignIn = GoogleSignIn();
                                        if (await googleSignIn.isSignedIn()) {
                                          await googleSignIn.signOut();
                                          myCustomPrintStatement("✅ Google Sign-In déconnecté");
                                        }
                                      } catch (e) {
                                        myCustomPrintStatement("⚠️ Erreur déconnexion Google Sign-In: $e");
                                      }
                                    }

                                    if (providers.contains('facebook.com')) {
                                      try {
                                        await FacebookAuth.instance.logOut();
                                        myCustomPrintStatement("✅ Facebook Auth déconnecté");
                                      } catch (e) {
                                        myCustomPrintStatement("⚠️ Erreur déconnexion Facebook Auth: $e");
                                      }
                                    }

                                    // 🗑️ Maintenant on peut supprimer l'utilisateur Firebase en toute sécurité
                                    await user!.delete();
                                    myCustomPrintStatement("✅ Utilisateur Firebase supprimé");

                                    // 🧹 Nettoyer les données locales (currentUser, userData, SharedPreferences)
                                    customAuthProvider.currentUser = null;
                                    userData.value = null;
                                    DevFestPreferences().setUserDetails("");
                                    DevFestPreferences().setVerificationCode("");
                                    DevFestPreferences().setUserVerificationRequest({});

                                    // ⚡ Activer le mode invité après suppression de compte
                                    await customAuthProvider.enableGuestMode();

                                    // ⚡ FIX: Fermer le loading avant navigation
                                    await hideLoading();
                                    myCustomPrintStatement("✅ Compte supprimé avec succès - Loading fermé");

                                    showSnackbar(translate(
                                        "Your account has been successfully deleted"));

                                    // ✅ Navigation vers MainNavigationScreen en mode invité
                                    if (context.mounted) {
                                      pushAndRemoveUntil(
                                          context: context,
                                          screen: const MainNavigationScreen());
                                    }
                                  } catch (e) {
                                    // ⚡ FIX: Fermer le loading en cas d'erreur
                                    hideLoading();
                                    myCustomPrintStatement("❌ Erreur lors de la suppression du compte: $e");

                                    // En cas d'erreur, faire un signOut complet pour nettoyer l'état
                                    await customAuthProvider.signOutUser();

                                    // ⚡ Activer le mode invité même en cas d'erreur
                                    await customAuthProvider.enableGuestMode();

                                    // ⚡ FIX SUPPLÉMENTAIRE: Forcer la fermeture du loading après signOutUser
                                    await hideLoading();
                                    myCustomPrintStatement("🔒 Loading forcé fermé après signOutUser en cas d'erreur");

                                    showSnackbar("Erreur lors de la suppression du compte. Déconnexion en cours...");

                                    // Navigation vers MainNavigationScreen en mode invité
                                    if (context.mounted) {
                                      pushAndRemoveUntil(
                                          context: context,
                                          screen: const MainNavigationScreen());
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
