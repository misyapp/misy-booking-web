// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/validation_functions.dart';
import 'package:rider_ride_hailing_app/modal/saved_payment_method_modal.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_coordinator_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_airtel_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_telma_provider.dart';
import 'package:rider_ride_hailing_app/widget/common_alert_dailog.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/input_text_field_widget.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/pages/view_module/wallet_topup_transaction_screen.dart';

/// Bottom sheet de confirmation pour les top-ups de portefeuille
/// Adapté de PaymentMobileNumberConfirmation pour les rechargements de portefeuille
class WalletTopUpPaymentConfirmation extends StatefulWidget {
  final double amount;
  final PaymentMethodType paymentMethod;
  
  const WalletTopUpPaymentConfirmation({
    super.key,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  State<WalletTopUpPaymentConfirmation> createState() =>
      _WalletTopUpPaymentConfirmationState();
}

class _WalletTopUpPaymentConfirmationState
    extends State<WalletTopUpPaymentConfirmation> {
  TextEditingController mobileNumberController =
      TextEditingController(text: "");

  final formKey = GlobalKey<FormState>();
  
  /// Gère l'annulation simple de la transaction de top-up
  Future<void> _handleCancelTransaction(BuildContext context) async {
    await showCommonAlertDailog(
      context,
      headingText: translate("areYouSure"),
      successIcon: false,
      message: translate("cancelTopUpMsg"), // Message spécifique au top-up
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
                popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
              },
            ),
            hSizedBox2,
            RoundEdgedButton(
              text: translate("yes"),
              width: 100,
              height: 40,
              onTap: () async {
                popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
                // Fermer le bottom sheet principal
                popPage(context: context);
              },
            ),
            hSizedBox,
          ],
        ),
      ],
    );
  }
  
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      SavedPaymentMethodProvider saved =
          Provider.of<SavedPaymentMethodProvider>(context, listen: false);
      List<SavedPaymentMethodModal> savedlist = saved.savedPaymentMethod;
      
      // Chercher un numéro sauvegardé pour cette méthode de paiement
      final savedMethod = savedlist.where((element) =>
          PaymentMethodTypeExtension.fromValue(element.name) ==
          widget.paymentMethod);
      if (savedMethod.isNotEmpty) {
        // Remplir uniquement si la méthode de paiement a été configurée
        mobileNumberController.text = savedMethod.first.mobileNumber;
      }
      // Ne pas remplir automatiquement avec le numéro du profil utilisateur
      // Le champ reste vide si la méthode n'est pas configurée
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    hideLoading();
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
          color: MyColors.whiteThemeColor(),
          borderRadius: BorderRadius.circular(40)),
      child: ValueListenableBuilder(
        valueListenable: sheetShowNoti,
        builder: (context, sheetValue, child) => Consumer<WalletTopUpCoordinatorProvider>(
          builder: (context, coordinatorProvider, child) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header en position fixe
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.paymentMethod == PaymentMethodType.airtelMoney
                      ? const Color.fromRGBO(255, 5, 5, 1)
                      : const Color.fromRGBO(0, 111, 60, 1),
                ),
                child: Image.asset(
                  widget.paymentMethod == PaymentMethodType.airtelMoney
                      ? MyImagesUrl.airtelMoneyBannerImage
                      : MyImagesUrl.telmaMoneyBannerImage,
                ),
              ),
              vSizedBox,
              
              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        vSizedBox3,
                        // Montant du top-up
                        SubHeadingText(
                          "${translate("TopUpAmount")}: ${formatAriary(widget.amount)} ${globalSettings.currency}",
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        vSizedBox2,
                        Divider(
                          color: MyColors.greyWhiteThemeColor(),
                        ),
                        vSizedBox2,
                        SubHeadingText(
                          translate("Payment Confirmation"),
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                        vSizedBox,
                        SubHeadingText(
                          translate("Please confirm your operator number"),
                          maxLines: 2,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        vSizedBox,
                        
                        // Champ de saisie du numéro
                        Form(
                          key: formKey,
                          child: InputTextFieldWidget(
                            controller: mobileNumberController,
                            hintText: translate("enterPhoneNumber"),
                            validator: (val) {
                              return ValidationFunction.mobileNumberValidation(val);
                            },
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(10),
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: false),
                          ),
                        ),
                        vSizedBox2,
                        
                        // Bouton Confirm - Appelle les nouveaux providers de top-up
                        RoundEdgedButton(
                          verticalMargin: 0,
                          width: double.infinity,
                          text: translate("Confirm"),
                          onTap: () async {
                            if (formKey.currentState!.validate()) {
                              showLoading();
                              
                              try {
                                bool success = false;
                                
                                // Appeler le provider approprié selon la méthode
                                if (widget.paymentMethod == PaymentMethodType.airtelMoney) {
                                  final airtelProvider = Provider.of<WalletTopUpAirtelProvider>(
                                      context, listen: false);
                                  
                                  success = await airtelProvider.initiateTopUp(
                                    amount: widget.amount,
                                    mobileNumber: mobileNumberController.text,
                                    userId: userData.value!.id,
                                    internalTransactionId: DateTime.now().millisecondsSinceEpoch.toString(),
                                  );
                                } else if (widget.paymentMethod == PaymentMethodType.telmaMvola) {
                                  final telmaProvider = Provider.of<WalletTopUpTelmaProvider>(
                                      context, listen: false);
                                  
                                  success = await telmaProvider.initiateTopUp(
                                    amount: widget.amount,
                                    phoneNumberDebitParty: mobileNumberController.text,
                                    userId: userData.value!.id,
                                    internalTransactionId: DateTime.now().millisecondsSinceEpoch.toString(),
                                  );
                                }
                                
                                if (success) {
                                  // Fermer le loading et naviguer vers l'écran de transaction
                                  hideLoading();
                                  popPage(context: context); // Fermer le bottom sheet
                                  
                                  // Naviguer vers l'écran de suivi de transaction
                                  push(
                                    context: MyGlobalKeys.navigatorKey.currentContext!,
                                    screen: WalletTopUpTransactionScreen(
                                      amount: widget.amount,
                                      paymentMethod: widget.paymentMethod,
                                      userId: userData.value!.id,
                                    ),
                                  );
                                } else {
                                  hideLoading();
                                  // L'erreur est déjà gérée dans les providers
                                }
                              } catch (e) {
                                hideLoading();
                                print('Error initiating wallet top-up: $e');
                              }
                            }
                          },
                        ),
                        vSizedBox2,
                        
                        // Bouton Cancel Transaction (version simplifiée)
                        Align(
                          alignment: Alignment.center,
                          child: InkWell(
                            onTap: () async {
                              await _handleCancelTransaction(context);
                            },
                            child: ParagraphText(
                              translate("cancel"),
                              underlined: true,
                              color: MyColors.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        vSizedBox2,
                        
                        // Logo de l'opérateur en bas - centré parfaitement
                        Container(
                          width: double.infinity,
                          height: 180,
                          alignment: Alignment.center,
                          child: Image.asset(
                            height: 150,
                            widget.paymentMethod == PaymentMethodType.airtelMoney
                                ? MyImagesUrl.airtelMoneyIcon
                                : MyImagesUrl.telmaMvolaIcon,
                            fit: BoxFit.contain,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}