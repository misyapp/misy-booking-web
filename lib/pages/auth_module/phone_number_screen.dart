import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/functions/validation_functions.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/otp_verification_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/input_text_field_widget.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_custom_dialog.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/widget/web_card_shell.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  TextEditingController mobileNoController = TextEditingController();
  String countryName = "Madagasikara";
  String countryCode = "+261";
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // 🐛 FIX: le loader (twistingDots rouge/bleu, EasyLoading maskType:none) du flux
    // de login n'était pas masqué en arrivant ici → il tournait à l'infini par-dessus
    // le formulaire. On le force à disparaître au 1er frame, quel que soit le chemin
    // d'entrée sur cet écran.
    WidgetsBinding.instance.addPostFrameCallback((_) => forceHideLoading());
    // ⚡ Pré-remplir le numéro de téléphone si disponible depuis les données utilisateur
    _prefillUserData();
  }

  void _prefillUserData() {
    if (userData.value != null) {
      // Pré-remplir le numéro de téléphone s'il existe
      if (userData.value!.phoneNo != null && userData.value!.phoneNo!.isNotEmpty) {
        mobileNoController.text = userData.value!.phoneNo!;
        myCustomPrintStatement("📱 Numéro de téléphone pré-rempli: ${userData.value!.phoneNo}");
      }

      // Pré-remplir le code pays et nom du pays s'ils existent
      if (userData.value!.countryCode != null && userData.value!.countryCode!.isNotEmpty) {
        countryCode = userData.value!.countryCode!;
        myCustomPrintStatement("🌍 Code pays pré-rempli: $countryCode");
      }

      if (userData.value!.countryName != null && userData.value!.countryName!.isNotEmpty) {
        countryName = userData.value!.countryName!;
        myCustomPrintStatement("🌍 Nom pays pré-rempli: $countryName");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⚡ FIX: Bloquer le bouton "back" pour forcer la saisie du numéro
    // L'utilisateur DOIT saisir son numéro ou se déconnecter
    return PopScope(
      canPop: false, // Bloque le bouton "back" physique
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Si l'utilisateur tente de revenir en arrière, afficher un message
          showSnackbar(translate("phoneNumberRequired"));
          myCustomPrintStatement("⚠️ Tentative de retour bloquée - Numéro de téléphone requis");
        }
      },
      child: kIsWeb ? _buildWebLayout(context) : _buildMobileLayout(context),
    ); // Fermeture de PopScope
  }

  /// Présentation web : carte blanche centrée (parité WebAuthScreen) au lieu
  /// du Scaffold mobile pleine largeur. Même contenu, même logique.
  Widget _buildWebLayout(BuildContext context) {
    return WebCardShell(
      title: translate("Verify Phone Number"),
      footer: Center(
        child: TextButton.icon(
          onPressed: () {
            Provider.of<CustomAuthProvider>(context, listen: false)
                .logout(context);
          },
          icon: const Icon(Icons.logout, size: 18, color: Colors.black54),
          label: Text(
            translate("logout"),
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ),
      child: _buildFormContent(context),
    );
  }

  /// Présentation mobile d'origine (inchangée).
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        actions: [
          IconButton(
            onPressed: () {
              Provider.of<CustomAuthProvider>(context, listen: false)
                  .logout(context);
            },
            icon: CircleAvatar(
              radius: 20,
              backgroundColor: MyColors.colorD9D9D9Theme(),
              child: Image.asset(
                MyImagesUrl.logout,
                width: 23,
              ),
            ),
          ),
        ],
        isBackIcon: false,
        leadingWidth: 15,
        title: translate("Verify Phone Number"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: Center(
          child: SingleChildScrollView(
            child: _buildFormContent(context),
          ),
        ),
      ),
    );
  }

  /// Contenu commun mobile/web : textes, champ téléphone + indicatif, bouton
  /// « Suivant » avec toute la logique de vérification/OTP existante.
  Widget _buildFormContent(BuildContext context) {
    return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ParagraphText(
                  translate("Please enter your phone number"),
                  fontWeight: FontWeight.w400,
                  color: MyColors.blackThemeColor06(),
                  fontSize: kIsWeb ? 18 : 24,
                ),
                ParagraphText(
                  translate("pleaseEnterNewPhoneNumberMsg"),
                  fontWeight: FontWeight.w400,
                  color: MyColors.blackThemeColor06(),
                  fontSize: 14,
                ),
                vSizedBox2,
                Form(
                  key: formKey,
                  child: InputTextFieldWidget(
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
                    validator: (val) =>
                        ValidationFunction.mobileNumberValidation(val),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(10),
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: false),
                  ),
                ),
                vSizedBox,
                Consumer<CustomAuthProvider>(
                    builder: (context, authPovider, child) {
                  return RoundEdgedButton(
                    text: translate("next"),
                    width: double.infinity,
                    onTap: () async {
                      if (formKey.currentState!.validate()) {
                        await showLoading();
                        final QuerySnapshot mobileNumberSnapshot =
                            await FirestoreServices.users
                                .where('phoneNo',
                                    isEqualTo: mobileNoController.text)
                                .where('countryCode', isEqualTo: countryCode)
                                .where('accountDeleted', isNotEqualTo: true)
                                .get();

                        // 🔧 FIX: Vérifier si le numéro appartient à l'utilisateur actuel
                        // Permet à l'utilisateur de réutiliser son propre numéro lors d'une reconnexion Google
                        final currentUserId = authPovider.currentUser?.uid;
                        final bool isOwnNumber = mobileNumberSnapshot.docs.isNotEmpty &&
                            mobileNumberSnapshot.docs.every((doc) => doc.id == currentUserId);

                        if (mobileNumberSnapshot.docs.isEmpty || isOwnNumber) {
                          if (globalSettings.enableOTPVerification) {
                            await hideLoading();
                            return await showCustomDialog(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SubHeadingText(
                                  translate("Please confirm phone number"),
                                  fontSize: 22,
                                  maxLines: 2,
                                ),
                                ParagraphText(
                                  translate("confirmNumberMessage"),
                                  fontSize: 16,
                                  color: MyColors.blackThemeColor(),
                                ),
                                vSizedBox2,
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    RoundEdgedButton(
                                      text: translate("cancel"),
                                      color:
                                          MyColors.blackThemeColorWithOpacity(
                                              0.3),
                                      width: 100,
                                      height: 40,
                                      onTap: () {
                                        popPage(context: context);
                                      },
                                    ),
                                    hSizedBox2,
                                    RoundEdgedButton(
                                        text: translate("send"),
                                        width: 100,
                                        height: 40,
                                        onTap: () async {
                                          var request = {
                                            "phoneNo": mobileNoController.text,
                                            'countryName': countryName,
                                            'countryCode': countryCode,
                                          };
                                          DevFestPreferences()
                                              .setUserVerificationRequest(
                                                  request);
                                          pushReplacement(
                                              context: context,
                                              screen: OTPVerificationScreen(
                                                request: request,
                                              ));
                                        }),
                                    hSizedBox,
                                  ],
                                ),
                              ],
                            ));
                          } else {
                            // ⚡ FIX: editProfile() met à jour Firestore ET appelle getAndUpdateUserModal()
                            // pour synchroniser userData.value avec les nouvelles données
                            myCustomPrintStatement("📞 Mise à jour du numéro de téléphone: ${mobileNoController.text}");

                            // ⚡ SOLUTION COMPLÈTE: Inclure TOUS les champs requis non-nullables
                            // pour éviter les erreurs "Null is not a subtype of Type" lors du parsing UserModal.fromJson
                            // On utilise les données existantes de userData.value créées par signup()
                            await authPovider.editProfile({
                              "id": authPovider.currentUser!.uid,
                              "name": userData.value!.fullName,
                              "firstName": userData.value!.firstName,
                              "lastName": userData.value!.lastName,
                              "email": userData.value!.email,
                              "verified": userData.value!.verified,
                              "isBlocked": userData.value!.isBlocked,
                              "isCustomer": userData.value!.isCustomer,
                              "profileImage": userData.value!.profileImage,
                              // Mise à jour des champs téléphone/pays avec les nouvelles valeurs
                              "phoneNo": mobileNoController.text,
                              'countryName': countryName,
                              'countryCode': countryCode,
                            });
                            myCustomPrintStatement("✅ Profil mis à jour avec succès");

                            // ⚡ FIX CRITIQUE: Fermer le loading AVANT la navigation
                            await hideLoading();

                            // Après editProfile(), userData.value est à jour avec le numéro de téléphone
                            // On peut maintenant naviguer vers l'écran principal
                            myCustomPrintStatement("🏠 Navigation vers MainNavigationScreen");
                            pushAndRemoveUntil(
                              context: context,
                              screen: const MainNavigationScreen(),
                            );
                          }
                        } else {
                          hideLoading();
                          showSnackbar(translate("alreadyExistMsg"));
                        }
                      }
                    },
                  );
                })
              ],
            );
  }
}
