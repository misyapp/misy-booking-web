import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/wallet_topup_confirmation.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/wallet_topup_payment_confirmation.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/functions/validation_functions.dart';
import 'package:rider_ride_hailing_app/models/wallet.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/services/wallet_payment_integration_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/input_text_field_widget.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:rider_ride_hailing_app/widget/wallet_balance_widget.dart';

/// Écran de crédit du portefeuille numérique
/// Permet aux utilisateurs de sélectionner un montant et une méthode de paiement
/// pour créditer leur portefeuille via mobile money
class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({Key? key}) : super(key: key);

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  // Controllers
  final TextEditingController _customAmountController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // État local
  PaymentMethodType? _selectedPaymentMethod;
  double? _selectedAmount;
  bool _isCustomAmount = false;

  // Montants prédéfinis suivant les patterns mobile money malgaches
  final List<double> _predefinedAmounts = [
    1000.0,   // 1,000 MGA
    5000.0,   // 5,000 MGA
    10000.0,  // 10,000 MGA
    20000.0,  // 20,000 MGA
    50000.0,  // 50,000 MGA
    100000.0, // 100,000 MGA
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    myCustomPrintStatement('WalletTopUpScreen: Initializing data');
    
    // Charger les méthodes de paiement disponibles
    final savedPaymentProvider = Provider.of<SavedPaymentMethodProvider>(context, listen: false);
    if (savedPaymentProvider.allPaymentMethods.isEmpty) {
      savedPaymentProvider.getMySavedPaymentMethod();
    }
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Vérifier si la fonctionnalité est activée
    if (!FeatureToggleService.instance.isDigitalWalletEnabled()) {
      return Scaffold(
        backgroundColor: MyColors.backgroundLight,
        appBar: CustomAppBar(
          title: translate("TopUpWallet"),
          isBackIcon: true,
          bgcolor: MyColors.whiteColor,
          onPressed: () => popPage(context: context),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wallet_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                SubHeadingText(
                  'Fonctionnalité temporairement indisponible',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ParagraphText(
                  'Le crédit portefeuille n\'est pas disponible pour le moment. Veuillez réessayer plus tard.',
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: MyColors.backgroundLight,
      appBar: CustomAppBar(
        title: translate("TopUpWallet"),
        isBackIcon: true,
        bgcolor: MyColors.whiteColor,
        onPressed: () => popPage(context: context),
      ),
      body: Consumer2<WalletProvider, SavedPaymentMethodProvider>(
        builder: (context, walletProvider, savedPaymentProvider, child) {
          return Column(
            children: [
              // Widget du solde actuel
              _buildCurrentBalanceSection(walletProvider),
              
              // Contenu principal scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section sélection du montant
                        _buildAmountSelectionSection(),
                        
                        vSizedBox05,
                        
                        // Section sélection méthode de paiement
                        _buildPaymentMethodSection(savedPaymentProvider),
                        
                        vSizedBox05,
                        
                        // Informations sur les limites
                        _buildLimitsInfoSection(),
                        
                        vSizedBox,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Bouton de confirmation fixe en bas
              SafeArea(
                child: _buildConfirmButton(walletProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Section affichant le solde actuel du portefeuille
  Widget _buildCurrentBalanceSection(WalletProvider walletProvider) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: WalletBalanceWidget(
        showActions: false,
      ),
    );
  }

  /// Section de sélection du montant à créditer
  Widget _buildAmountSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubHeadingText(
          translate("SelectAmount"),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: MyColors.textPrimary,
        ),
        vSizedBox2,
        
        // Montants prédéfinis
        _buildPredefinedAmountsGrid(),
        
        vSizedBox2,
        
        // Option montant personnalisé
        _buildCustomAmountOption(),
        
        if (_isCustomAmount) ...[
          vSizedBox,
          _buildCustomAmountInput(),
        ],
      ],
    );
  }

  /// Grille des montants prédéfinis
  Widget _buildPredefinedAmountsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _predefinedAmounts.length,
      itemBuilder: (context, index) {
        final amount = _predefinedAmounts[index];
        final isSelected = _selectedAmount == amount && !_isCustomAmount;
        
        return GestureDetector(
          onTap: () => _selectPredefinedAmount(amount),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? MyColors.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? MyColors.primaryColor : MyColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: MyColors.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Center(
              child: ParagraphText(
                WalletHelper.formatAmount(amount),
                color: isSelected ? Colors.white : MyColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Option pour saisir un montant personnalisé
  Widget _buildCustomAmountOption() {
    return GestureDetector(
      onTap: () => _toggleCustomAmount(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isCustomAmount ? MyColors.coralPink : MyColors.backgroundContrast,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isCustomAmount ? MyColors.coralPink : MyColors.borderLight,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ParagraphText(
              translate("CustomAmount"),
              color: _isCustomAmount ? Colors.white : MyColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            Icon(
              _isCustomAmount ? Icons.check_circle : Icons.edit,
              color: _isCustomAmount ? Colors.white : MyColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Champ de saisie pour montant personnalisé
  Widget _buildCustomAmountInput() {
    return InputTextFieldWidget(
      controller: _customAmountController,
      hintText: translate("EnterAmount"),
      prefixText: "MGA ",
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(7), // Maximum 1,000,000
      ],
      validator: _validateCustomAmount,
      onChanged: (value) {
        if (value.isNotEmpty) {
          _selectedAmount = double.tryParse(value);
        } else {
          _selectedAmount = null;
        }
        setState(() {});
      },
    );
  }

  /// Section de sélection de la méthode de paiement
  Widget _buildPaymentMethodSection(SavedPaymentMethodProvider savedPaymentProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubHeadingText(
          translate("SelectPaymentMethod"),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: MyColors.textPrimary,
        ),
        vSizedBox2,
        
        // Liste des méthodes de paiement disponibles (exclut selon les flags de fonctionnalités)
        ...savedPaymentProvider.allPaymentMethods
            .where((method) {
              if (method['disabled']) return false;
              
              final paymentType = method['paymentGatewayType'] as PaymentMethodType;
              
              // Exclure le portefeuille et le cash (toujours)
              if (paymentType == PaymentMethodType.wallet || paymentType == PaymentMethodType.cash) {
                return false;
              }
              
              // Exclure les cartes bancaires si la fonctionnalité est désactivée
              if (paymentType == PaymentMethodType.creditCard && 
                  !FeatureToggleService.instance.isCreditCardPaymentEnabled()) {
                return false;
              }
              
              return true;
            })
            .map((method) => _buildPaymentMethodCard(method)),
      ],
    );
  }

  /// Carte pour une méthode de paiement
  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final PaymentMethodType methodType = method['paymentGatewayType'];
    final bool isSelected = _selectedPaymentMethod == methodType;

    return GestureDetector(
      onTap: () => _selectPaymentMethod(methodType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MyColors.backgroundContrast,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? MyColors.coralPink : MyColors.borderLight,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Icône de la méthode de paiement
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MyColors.borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: Image.asset(
                    method['image'],
                    fit: BoxFit.contain,
                    width: 36,
                    height: 36,
                  ),
                ),
              ),
            ),
            
            hSizedBox2,
            
            // Nom de la méthode
            Expanded(
              child: ParagraphText(
                method['name'],
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MyColors.textPrimary,
              ),
            ),
            
            // Indicateur de sélection
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: MyColors.coralPink,
                size: 24,
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                color: MyColors.textSecondary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  /// Section d'informations sur les limites
  Widget _buildLimitsInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.horizonBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MyColors.horizonBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: MyColors.horizonBlue,
                size: 20,
              ),
              hSizedBox,
              ParagraphText(
                translate("TransactionLimits"),
                fontWeight: FontWeight.w600,
                color: MyColors.horizonBlue,
              ),
            ],
          ),
          vSizedBox,
          ParagraphText(
            "• ${translate("MinimumAmount")}: ${WalletHelper.formatAmount(WalletConstraints.minimumTransactionAmount)}",
            fontSize: 13,
            color: MyColors.textSecondary,
          ),
          ParagraphText(
            "• ${translate("MaximumAmount")}: ${WalletHelper.formatAmount(WalletConstraints.maximumTransactionAmount)}",
            fontSize: 13,
            color: MyColors.textSecondary,
          ),
          ParagraphText(
            "• ${translate("WalletMaxBalance")}: ${WalletHelper.formatAmount(WalletConstraints.defaultMaxBalance)}",
            fontSize: 13,
            color: MyColors.textSecondary,
          ),
        ],
      ),
    );
  }

  /// Bouton de confirmation du top-up
  Widget _buildConfirmButton(WalletProvider walletProvider) {
    final bool isEnabled = _selectedAmount != null && 
                          _selectedPaymentMethod != null && 
                          !walletProvider.isCrediting;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: RoundEdgedButton(
        text: walletProvider.isCrediting 
            ? translate("Processing")
            : "Créditer le portefeuille",
        width: double.infinity,
        height: 50,
        onTap: isEnabled ? _proceedToConfirmation : null,
        color: isEnabled ? MyColors.primaryColor : MyColors.textSecondary.withOpacity(0.3),
        textColor: Colors.white,
        load: walletProvider.isCrediting,
        borderRadius: 12,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // === MÉTHODES DE GESTION D'ÉTAT ===

  /// Sélectionne un montant prédéfini
  void _selectPredefinedAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
      _isCustomAmount = false;
      _customAmountController.clear();
    });
    myCustomPrintStatement('Selected predefined amount: $amount');
  }

  /// Active/désactive le mode montant personnalisé
  void _toggleCustomAmount() {
    setState(() {
      _isCustomAmount = !_isCustomAmount;
      if (!_isCustomAmount) {
        _customAmountController.clear();
        _selectedAmount = null;
      } else {
        _selectedAmount = null;
      }
    });
  }

  /// Sélectionne une méthode de paiement
  void _selectPaymentMethod(PaymentMethodType method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
    myCustomPrintStatement('Selected payment method: ${method.value}');
  }

  /// Valide le montant personnalisé saisi
  String? _validateCustomAmount(String? value) {
    if (value == null || value.isEmpty) {
      return translate("PleaseEnterAmount");
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      return translate("InvalidAmount");
    }

    if (!WalletConstraints.isValidTransactionAmount(amount)) {
      return translate("AmountOutOfRange");
    }

    return null;
  }

  /// Procède à la confirmation du top-up
  void _proceedToConfirmation() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAmount == null || _selectedPaymentMethod == null) {
      showSnackbar(translate("PleaseSelectAmountAndPayment"));
      return;
    }

    myCustomPrintStatement('Proceeding to confirmation - Amount: $_selectedAmount, Method: ${_selectedPaymentMethod!.value}');

    // Ouvrir le bottom sheet de confirmation
    _showConfirmationBottomSheet();
  }

  /// Affiche le bottom sheet de confirmation
  void _showConfirmationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WalletTopUpConfirmation(
        amount: _selectedAmount!,
        paymentMethod: _selectedPaymentMethod!,
        onConfirm: _executeTopUp,
      ),
    );
  }

  /// Exécute le top-up après confirmation
  Future<void> _executeTopUp() async {
    if (_selectedAmount == null || _selectedPaymentMethod == null) return;

    try {
      myCustomPrintStatement('Executing top-up: $_selectedAmount via ${_selectedPaymentMethod!.value}');

      // Pour Airtel Money et Telma MVola, ouvrir le bottom sheet de confirmation
      if (_selectedPaymentMethod == PaymentMethodType.airtelMoney || 
          _selectedPaymentMethod == PaymentMethodType.telmaMvola) {
        await _showPaymentConfirmationBottomSheet();
      } else {
        // Pour Orange Money et Credit Card, utiliser le service d'intégration directement
        bool success = await WalletPaymentIntegrationService.initiateWalletTopUp(
          amount: _selectedAmount!,
          paymentMethod: _selectedPaymentMethod!,
          userId: userData.value!.id,
          phoneNumber: null, // Pas de numéro requis pour Orange/Credit Card
        );

        if (success) {
          showSnackbar(translate("PaymentProcessInitiated"));
          popPage(context: context);
        } else {
          showSnackbar(translate("FailedToInitiatePayment"));
        }
      }
    } catch (e) {
      myCustomPrintStatement('Error executing top-up: $e');
      showSnackbar(translate("TopUpError"));
    }
  }

  /// Affiche le bottom sheet de confirmation de paiement
  /// pour Airtel Money et Telma MVola (saisie du numéro)
  Future<void> _showPaymentConfirmationBottomSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WalletTopUpPaymentConfirmation(
        amount: _selectedAmount!,
        paymentMethod: _selectedPaymentMethod!,
      ),
    );
  }
  
  /// Récupère le numéro de téléphone pour le paiement (DEPRECATED)
  /// Cette méthode n'est plus utilisée car la saisie du numéro
  /// se fait maintenant dans WalletTopUpPaymentConfirmation
  @deprecated
  String? _getPhoneNumberForPayment() {
    // Cette méthode est conservée pour compatibilité mais n'est plus utilisée
    return null;
  }
}