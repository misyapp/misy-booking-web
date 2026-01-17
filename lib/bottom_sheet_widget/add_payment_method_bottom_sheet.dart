import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/functions/validation_functions.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/input_text_field_widget.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_custom_dialog.dart';

/// Bottom sheet pour ajouter une nouvelle méthode de paiement
/// Affiche la liste des méthodes de paiement disponibles à ajouter
class AddPaymentMethodBottomSheet extends StatelessWidget {
  final BuildContext? parentContext;
  const AddPaymentMethodBottomSheet({Key? key, this.parentContext}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SavedPaymentMethodProvider>(
      builder: (context, savedPayment, child) {
        return Container(
          decoration: BoxDecoration(
            color: MyColors.backgroundContrast,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MyColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Contenu du bottom sheet
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête
                    _buildHeader(),
                    
                    // Liste des méthodes de paiement disponibles
                    _buildPaymentMethodsList(context, savedPayment),
                    
                    // Espacement en bas pour la navigation système
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// En-tête du bottom sheet
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MyColors.coralPink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.add,
              size: 20,
              color: MyColors.coralPink,
            ),
          ),
          hSizedBox,
          SubHeadingText(
            translate("Add payment methods"),
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: MyColors.textPrimary,
          ),
        ],
      ),
    );
  }

  /// Liste des méthodes de paiement disponibles à ajouter
  Widget _buildPaymentMethodsList(BuildContext context, SavedPaymentMethodProvider savedPayment) {
    // Utiliser la liste filtrée selon les flags de fonctionnalités
    final availableMethods = savedPayment.filteredAddPaymentGateways;

    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: availableMethods.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final method = availableMethods[index];
          
          return _buildPaymentMethodCard(context, method, index);
        },
      ),
    );
  }

  /// Carte pour une méthode de paiement disponible
  Widget _buildPaymentMethodCard(BuildContext context, Map<String, dynamic> method, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          myCustomPrintStatement('Adding payment method: ${method['name']}');
          _addPaymentMethod(context, method, index);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MyColors.backgroundContrast,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MyColors.borderLight,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Logo du service
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MyColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  method['image'],
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 16),
              
              // Nom du service
              Expanded(
                child: Text(
                  method['name'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: MyColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              
              // Icône de navigation
              Icon(
                Icons.add_circle_outline,
                color: MyColors.coralPink,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ajoute une méthode de paiement (réutilise la logique existante)
  void _addPaymentMethod(BuildContext context, Map<String, dynamic> method, int index) {
    // Utiliser le contexte parent si disponible, sinon le contexte actuel
    final targetContext = parentContext ?? context;
    
    // Fermer le bottom sheet actuel
    Navigator.of(context).pop();
    
    // Utiliser un délai pour permettre à la navigation de se terminer
    Future.delayed(const Duration(milliseconds: 150), () {
      // Ouvrir le dialog d'ajout d'opérateur avec le bon contexte
      _showAddOperatorDialog(targetContext, method, index);
    });
  }

  /// Affiche le dialog pour ajouter un opérateur (reprend la logique existante)
  Future<void> _showAddOperatorDialog(
    BuildContext context,
    Map<String, dynamic> method,
    int index,
  ) async {
    final PaymentMethodType paymentMethodType = method['paymentGatewayType'];
    
    // Gérer les différents types de paiement
    if (paymentMethodType == PaymentMethodType.creditCard) {
      _showCreditCardDialog(context, method, index);
    } else {
      _showMobileMoneyDialog(context, method, index, paymentMethodType);
    }
  }

  /// Dialog spécifique pour les cartes bancaires
  Future<void> _showCreditCardDialog(
    BuildContext context,
    Map<String, dynamic> method,
    int index,
  ) async {
    TextEditingController cardNumberController = TextEditingController();
    TextEditingController cardHolderController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showCustomDialog(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec icône
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MyColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  method['image'],
                  fit: BoxFit.contain,
                ),
              ),
              hSizedBox,
              ParagraphText(
                PaymentMethodType.creditCard.value,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          vSizedBox05,
          ParagraphText(
            "Veuillez entrer les informations de votre carte",
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
          vSizedBox,
          Form(
            key: formKey,
            child: Column(
              children: [
                InputTextFieldWidget(
                  controller: cardNumberController,
                  hintText: "Numéro de carte (16 chiffres)",
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return "Veuillez entrer le numéro de carte";
                    }
                    if (val.length != 16) {
                      return "Le numéro de carte doit contenir 16 chiffres";
                    }
                    return null;
                  },
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(16),
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  keyboardType: TextInputType.number,
                ),
                vSizedBox,
                InputTextFieldWidget(
                  controller: cardHolderController,
                  hintText: "Nom du titulaire",
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return "Veuillez entrer le nom du titulaire";
                    }
                    return null;
                  },
                  keyboardType: TextInputType.text,
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              RoundEdgedButton(
                text: translate("cancel"),
                onTap: () {
                  Navigator.of(context).pop();
                },
                height: 45,
                width: 100,
                color: MyColors.blackThemeColorWithOpacity(0.8),
              ),
              RoundEdgedButton(
                text: translate("submit"),
                onTap: () {
                  if (formKey.currentState!.validate()) {
                    SavedPaymentMethodProvider save =
                        Provider.of<SavedPaymentMethodProvider>(context,
                            listen: false);
                    var request = {
                      'image': method['image'],
                      'name': PaymentMethodType.creditCard.value,
                      'mobileNumber': cardNumberController.text, // Stocké comme numéro pour compatibilité
                      'cardHolder': cardHolderController.text,
                      'isSelected': false,
                    };
                    save.savePaymentMethod(request, index);
                  }
                },
                height: 45,
                width: 100,
                color: MyColors.primaryColor,
              ),
            ],
          )
        ],
      )
    );
  }

  /// Dialog pour les services mobile money (Orange Money, Airtel Money, MVola)
  Future<void> _showMobileMoneyDialog(
    BuildContext context,
    Map<String, dynamic> method,
    int index,
    PaymentMethodType paymentMethodType,
  ) async {
    TextEditingController opratorMobileNumber = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Personnaliser le message selon le service
    String promptMessage;
    switch (paymentMethodType) {
      case PaymentMethodType.orangeMoney:
        promptMessage = "Veuillez entrer votre numéro Orange Money";
        break;
      case PaymentMethodType.airtelMoney:
        promptMessage = "Veuillez entrer votre numéro Airtel Money";
        break;
      case PaymentMethodType.telmaMvola:
        promptMessage = "Veuillez entrer votre numéro MVola";
        break;
      default:
        promptMessage = translate("Please enter your operator number");
    }

    await showCustomDialog(
      height: MediaQuery.of(context).size.height * 0.41,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec icône
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MyColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  method['image'],
                  fit: BoxFit.contain,
                ),
              ),
              hSizedBox,
              ParagraphText(
                paymentMethodType.value,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          vSizedBox05,
          ParagraphText(
            promptMessage,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
          vSizedBox,
          Form(
            key: formKey,
            child: InputTextFieldWidget(
              controller: opratorMobileNumber,
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
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              RoundEdgedButton(
                text: translate("cancel"),
                onTap: () {
                  Navigator.of(context).pop();
                },
                height: 45,
                width: 100,
                color: MyColors.blackThemeColorWithOpacity(0.8),
              ),
              RoundEdgedButton(
                text: translate("submit"),
                onTap: () {
                  if (formKey.currentState!.validate()) {
                    SavedPaymentMethodProvider save =
                        Provider.of<SavedPaymentMethodProvider>(context,
                            listen: false);
                    var request = {
                      'image': method['image'],
                      'name': paymentMethodType.value,
                      'mobileNumber': opratorMobileNumber.text,
                      'isSelected': false,
                    };
                    save.savePaymentMethod(request, index);
                  }
                },
                height: 45,
                width: 100,
                color: MyColors.primaryColor,
              ),
            ],
          )
        ],
      )
    );
  }
}