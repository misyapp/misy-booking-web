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
import 'package:rider_ride_hailing_app/modal/saved_payment_method_modal.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:rider_ride_hailing_app/pages/view_module/wallet_topup_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/wallet_history_screen.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/input_text_field_widget.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_custom_dialog.dart';
import 'package:rider_ride_hailing_app/widget/wallet_balance_widget.dart';
import 'package:rider_ride_hailing_app/widget/wallet_transaction_card.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/add_payment_method_bottom_sheet.dart';

class MyWalletManagement extends StatefulWidget {
  const MyWalletManagement({super.key});

  @override
  State<MyWalletManagement> createState() => _MyWalletManagementState();
}

class _MyWalletManagementState extends State<MyWalletManagement> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // Initialiser les providers nécessaires
      final savedPaymentProvider = Provider.of<SavedPaymentMethodProvider>(context, listen: false);
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      // Charger les méthodes de paiement
      savedPaymentProvider.getMySavedPaymentMethod();
      
      // Initialiser le portefeuille si l'utilisateur est connecté ET si la feature est activée
      if (userData.value?.id != null && FeatureToggleService.instance.isDigitalWalletEnabled()) {
        myCustomPrintStatement('Initializing wallet for user: ${userData.value?.id}');
        await walletProvider.initializeWallet(userData.value!.id!);
      } else if (userData.value?.id != null) {
        myCustomPrintStatement('Digital wallet is disabled, skipping wallet initialization in MyWalletManagement');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.backgroundLight,
      appBar: CustomAppBar(
        bgcolor: MyColors.whiteThemeColor(),
        title: translate('myWallet'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshWallet,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Consumer3<WalletProvider, SavedPaymentMethodProvider, AdminSettingsProvider>(
            builder: (context, walletProvider, savedPayment, adminProvider, child) {
              return Column(
                children: [
                  // Widget d'affichage du solde - conditionnel selon le flag
                  if (FeatureToggleService.instance.isDigitalWalletEnabled())
                    WalletBalanceWidget(
                      onCreditTap: () => _showCreditDialog(context),
                      // onHistoryTap: () => _showTransactionHistory(context), // Temporairement masqué
                    ),
                  
                  // Résumé des transactions récentes - TEMPORAIREMENT MASQUÉ
                  // if (FeatureToggleService.instance.isDigitalWalletEnabled())
                  //   WalletTransactionsSummary(
                  //     recentTransactions: walletProvider.transactions.take(3).toList(),
                  //     onSeeAllTap: () {}, // Temporairement masqué - fonction vide
                  //   ),
                  
                  // Section d'information sur les promotions
                  _buildPromoInfoSection(adminProvider),
                  
                  // Section des méthodes de paiement avec option d'ajout intégrée
                  _buildPaymentMethodsSection(savedPayment, adminProvider),
                  
                  // Espacement en bas
                  const SizedBox(height: 100),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  /// Vérifie si une méthode de paiement est une carte bancaire
  bool _isCreditCardMethod(SavedPaymentMethodModal method) {
    // Identifier par le nom ou l'icône de la carte bancaire
    return method.name.toLowerCase().contains('credit card') || 
           method.name.toLowerCase().contains('carte') ||
           method.icons.contains('bankCardIcon') ||
           method.icons.contains('credit');
  }
  
  Widget _buildPaymentMethodsSection(SavedPaymentMethodProvider savedPayment, AdminSettingsProvider adminProvider) {
    // Filtrer les méthodes de paiement selon les flags de fonctionnalités
    final filteredMethods = savedPayment.savedPaymentMethod.where((method) {
      // Masquer les cartes bancaires si la fonctionnalité est désactivée
      if (!FeatureToggleService.instance.isCreditCardPaymentEnabled() && 
          _isCreditCardMethod(method)) {
        return false;
      }
      return true;
    }).toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          vSizedBox05,
          SubHeadingText(
            translate('paymentMethod'),
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: MyColors.textPrimary,
          ),
          vSizedBox2,
          // Liste des méthodes filtrées + option d'ajout
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredMethods.length + 1, // +1 pour l'option d'ajout
            separatorBuilder: (context, index) => Divider(
              color: MyColors.borderLight,
              height: 1,
              thickness: 0.5,
            ),
            itemBuilder: (context, index) {
              if (index < filteredMethods.length) {
                // Méthode de paiement existante filtrée
                return _buildPaymentMethodItem(
                  filteredMethods[index],
                  index,
                  adminProvider,
                );
              } else {
                // Option d'ajout d'un moyen de paiement
                return _buildAddPaymentMethodItem();
              }
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaymentMethodItem(SavedPaymentMethodModal paymentMethod, int index, AdminSettingsProvider adminProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          // Zone d'affichage (logo + texte + bouton radio) - tap désactivé
          Expanded(
            child: Row(
                children: [
                  // Logo du moyen de paiement
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: MyColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        paymentMethod.icons,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: MyColors.backgroundContrast,
                            child: Icon(
                              Icons.payment,
                              color: MyColors.textSecondary,
                              size: 20,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  hSizedBox2,
                  // Texte du moyen de paiement
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SubHeadingText(
                              paymentMethod.name,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: MyColors.textPrimary,
                            ),
                            _buildPromoBadgeForWallet(paymentMethod.name, adminProvider),
                          ],
                        ),
                        if (paymentMethod.mobileNumber.isNotEmpty)
                          ParagraphText(
                            paymentMethod.mobileNumber,
                            fontSize: 14,
                            color: MyColors.textSecondary,
                          ),
                      ],
                    ),
                  ),
                  // Bouton de sélection personnalisé (sans espacement)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: paymentMethod.isSelected 
                          ? const Color(0xFFFF5357) 
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: paymentMethod.isSelected 
                            ? const Color(0xFFFF5357) 
                            : MyColors.borderLight,
                        width: 2,
                      ),
                    ),
                    child: paymentMethod.isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ],
            ),
          ),
          hSizedBox,
          // Icône Modifier (zone séparée)
          GestureDetector(
            onTap: () {
              _showPaymentMethodConfig(context, paymentMethod, index);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.edit_outlined,
                color: MyColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Item pour ajouter une nouvelle méthode de paiement (intégré dans la liste)
  Widget _buildAddPaymentMethodItem() {
    return GestureDetector(
      onTap: () => _showAddPaymentMethodBottomSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            // Icône d'ajout à la place du logo
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MyColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: MyColors.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.add,
                color: MyColors.primaryColor,
                size: 20,
              ),
            ),
            hSizedBox2,
            // Texte
            Expanded(
              child: SubHeadingText(
                translate('addPaymentMethod'),
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: MyColors.primaryColor,
              ),
            ),
            // Flèche
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: MyColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
  

  Future<void> _refreshWallet() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    if (userData.value?.id != null) {
      await walletProvider.refreshWallet(userData.value!.id!);
    }
  }
  
  void _showCreditDialog(BuildContext context) {
    myCustomPrintStatement('Opening wallet top-up screen');
    
    // Naviguer vers l'écran de crédit du portefeuille
    push(
      context: context,
      screen: const WalletTopUpScreen(),
    );
  }
  
  void _showTransactionHistory(BuildContext context) {
    myCustomPrintStatement('Opening transaction history screen');
    
    // Naviguer vers l'écran d'historique des transactions
    push(
      context: context,
      screen: const WalletHistoryScreen(),
    );
  }

  /// Affiche la fenêtre de configuration d'une méthode de paiement
  void _showPaymentMethodConfig(
    BuildContext context, 
    SavedPaymentMethodModal paymentMethod, 
    int index
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: MyColors.backgroundContrast,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MyColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Titre
            Text(
              '${translate('configurePaymentMethod')} ${paymentMethod.name}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: MyColors.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 24),
            
            // Affichage de la méthode de paiement
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MyColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MyColors.borderLight),
              ),
              child: Row(
                children: [
                  Image.asset(
                    paymentMethod.icons,
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paymentMethod.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: MyColors.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        if (paymentMethod.mobileNumber.isNotEmpty)
                          Text(
                            PaymentMethodTypeExtension.maskPaymentNumber(
                              paymentMethod.mobileNumber,
                              PaymentMethodTypeExtension.fromValue(paymentMethod.name),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: MyColors.textSecondary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Bouton Définir par défaut (si pas déjà sélectionné)
            if (!paymentMethod.isSelected) ...[
              ListTile(
                leading: Icon(
                  Icons.radio_button_checked,
                  color: MyColors.coralPink,
                ),
                title: Text(
                  translate('setAsDefault'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: MyColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Définir cette méthode comme par défaut
                  _setAsDefaultPaymentMethod(paymentMethod);
                },
              ),
              
              // Ligne de séparation
              Divider(color: MyColors.borderLight),
            ],
            
            // Bouton Modifier
            if (paymentMethod.name != "Cash") ...[
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: MyColors.horizonBlue,
                ),
                title: Text(
                  translate('edit'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: MyColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  var temp = {
                    'id': paymentMethod.id,
                    'image': paymentMethod.icons,
                    'name': paymentMethod.name,
                    'mobileNumber': paymentMethod.mobileNumber,
                    'isSelected': false,
                  };
                  addOptratorDailog(
                    index: index,
                    editRequest: temp,
                    paymentMethodType: PaymentMethodTypeExtension.fromValue(
                      paymentMethod.name,
                    ),
                  );
                },
              ),
              
              // Ligne de séparation
              Divider(color: MyColors.borderLight),
              
              // Bouton Supprimer
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: MyColors.error,
                ),
                title: Text(
                  translate('delete'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: MyColors.error,
                    fontFamily: 'Poppins',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  paymentMethod.onDeleteTap?.call();
                },
              ),
            ],
            
            // Espacement en bas pour la navigation système
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  /// Affiche le bottom sheet pour ajouter une méthode de paiement
  void _showAddPaymentMethodBottomSheet() {
    myCustomPrintStatement('Opening add payment method bottom sheet');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => AddPaymentMethodBottomSheet(
        parentContext: context, // Passer le contexte de la page parente
      ),
    );
  }

  /// Définit une méthode de paiement comme par défaut
  void _setAsDefaultPaymentMethod(SavedPaymentMethodModal paymentMethod) async {
    final provider = Provider.of<SavedPaymentMethodProvider>(context, listen: false);
    
    // Trouver l'index de la méthode actuelle
    int targetIndex = provider.savedPaymentMethod.indexWhere((element) => element.id == paymentMethod.id);
    if (targetIndex == -1) return;
    
    // Déclencher la sélection via la logique existante du provider
    if (provider.savedPaymentMethod[targetIndex].onTap != null) {
      provider.savedPaymentMethod[targetIndex].onTap!();
    }
  }

  addOptratorDailog({
    PaymentMethodType? paymentMethodType = PaymentMethodType.orangeMoney,
    Map<String, dynamic>? editRequest,
    required int index,
  }) async {
    TextEditingController opratorMobileNumber = TextEditingController(
      text: editRequest == null ? "" : editRequest['mobileNumber'],
    );
    final formKey = GlobalKey<FormState>();
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
                    Provider.of<SavedPaymentMethodProvider>(context, listen: false)
                        .filteredAddPaymentGateways[index]['image'],
                    fit: BoxFit.contain,
                  ),
                ),
                hSizedBox,
                ParagraphText(
                  paymentMethodType!.value,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            vSizedBox05,
            ParagraphText(
              translate("Please enter your operator number"),
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
                    popPage(context: context);
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
                        'image': save.filteredAddPaymentGateways[index]['image'],
                        'name': paymentMethodType.value,
                        'mobileNumber': opratorMobileNumber.text,
                        'isSelected': false,
                      };
                      if (editRequest != null) {
                        editRequest['mobileNumber'] = opratorMobileNumber.text;
                      }
                      save.savePaymentMethod(editRequest ?? request, index);
                    }
                  },
                  height: 45,
                  width: 100,
                  color: MyColors.primaryColor,
                ),
              ],
            )
          ],
        ));
  }

  /// Crée un badge de promotion pour un mode de paiement dans l'onglet portefeuille
  Widget _buildPromoBadgeForWallet(String paymentMethodName, AdminSettingsProvider adminProvider) {
    PaymentMethodType paymentType = PaymentMethodTypeExtension.fromValue(paymentMethodName);
    double discountPercentage = adminProvider.getPaymentPromoDiscount(paymentType);
    
    myCustomPrintStatement('🏷️ Building wallet promo badge for $paymentMethodName: ${discountPercentage}% (active: ${adminProvider.isPaymentPromoActive()})');
    
    if (discountPercentage <= 0 || !adminProvider.isPaymentPromoActive()) {
      return const SizedBox.shrink();
    }

    // Vérifier si c'est le meilleur mode de paiement
    bool isBestPromo = paymentType == adminProvider.getBestPaymentPromoMethod();
    
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isBestPromo ? MyColors.coralPink : MyColors.warning,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '-${discountPercentage.toInt()}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Crée une section d'information sur les promotions actives
  Widget _buildPromoInfoSection(AdminSettingsProvider adminProvider) {
    if (!adminProvider.isPaymentPromoActive()) {
      return const SizedBox.shrink();
    }

    List<PaymentMethodType> methodsWithPromo = adminProvider.getMethodsWithPaymentPromo();
    if (methodsWithPromo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyColors.warning.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, color: MyColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                translate('activePromos'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MyColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            translate('saveOnPayment'),
            style: TextStyle(
              fontSize: 12,
              color: MyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: must_be_immutable
class CardWithCheckBox extends StatelessWidget {
  final String name;
  final String subtitle;
  final String icons;
  final Function()? onTap;
  final Function()? onDeleteTap;
  final Function()? onEditTap;
  bool showDivider;
  bool isSelected;
  bool showCheckBox;
  bool disabled;
  bool showEditIcon;
  bool showDeleteIcon;
  final PaymentMethodType? paymentMethodType;
  
  CardWithCheckBox({
    super.key,
    required this.name,
    this.showDivider = true,
    this.disabled = false,
    required this.isSelected,
    required this.icons,
    required this.onTap,
    this.showEditIcon = true,
    this.subtitle = '',
    this.showCheckBox = true,
    this.showDeleteIcon = true,
    this.onEditTap,
    this.onDeleteTap,
    this.paymentMethodType,
  });

  @override
  Widget build(BuildContext context) {
    // Masquer le numéro selon le type de paiement
    String displaySubtitle = subtitle;
    if (paymentMethodType != null && subtitle.isNotEmpty) {
      displaySubtitle = PaymentMethodTypeExtension.maskPaymentNumber(
        subtitle, 
        paymentMethodType!
      );
    }
    
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MyColors.backgroundContrast,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MyColors.coralPink : MyColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: MyColors.textPrimary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Logo du service de paiement
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MyColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                icons,
                fit: BoxFit.contain,
                color: disabled ? MyColors.textSecondary : null,
              ),
            ),
            const SizedBox(width: 16),
            
            // Informations de la méthode de paiement
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: disabled ? MyColors.textSecondary : MyColors.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  if (displaySubtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      displaySubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: disabled ? MyColors.textSecondary.withValues(alpha: 0.7) : MyColors.textSecondary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Bouton radio pour la sélection
            if (showCheckBox)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? MyColors.coralPink : MyColors.borderLight,
                    width: 2,
                  ),
                  color: MyColors.backgroundContrast,
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MyColors.coralPink,
                          ),
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour afficher un résumé des transactions récentes
class WalletTransactionsSummary extends StatelessWidget {
  final List<WalletTransaction> recentTransactions;
  final VoidCallback onSeeAllTap;

  const WalletTransactionsSummary({
    Key? key,
    required this.recentTransactions,
    required this.onSeeAllTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (recentTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.backgroundContrast,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MyColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                translate('recentTransactions'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MyColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              GestureDetector(
                onTap: onSeeAllTap,
                child: Text(
                  translate('seeAll'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MyColors.coralPink,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final transaction = recentTransactions[index];
              return WalletTransactionCard(
                transaction: transaction,
                showDetails: false, // Version compacte
              );
            },
          ),
        ],
      ),
    );
  }
}
