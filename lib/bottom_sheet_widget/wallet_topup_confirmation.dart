import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/wallet.dart';
import 'package:rider_ride_hailing_app/provider/airtel_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/orange_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/provider/telma_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

/// Bottom sheet de confirmation pour le top-up du portefeuille
/// Affiche un résumé de la transaction et permet la confirmation finale
class WalletTopUpConfirmation extends StatefulWidget {
  final double amount;
  final PaymentMethodType paymentMethod;
  final VoidCallback onConfirm;

  const WalletTopUpConfirmation({
    Key? key,
    required this.amount,
    required this.paymentMethod,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<WalletTopUpConfirmation> createState() => _WalletTopUpConfirmationState();
}

class _WalletTopUpConfirmationState extends State<WalletTopUpConfirmation> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    myCustomPrintStatement('WalletTopUpConfirmation initialized - Amount: ${widget.amount}, Method: ${widget.paymentMethod.value}');
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * MediaQuery.of(context).size.height),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle du bottom sheet
                _buildSheetHandle(),
                
                // Contenu principal
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        vSizedBox2,
                        
                        // En-tête
                        _buildHeader(),
                        
                        vSizedBox3,
                        
                        // Résumé de la transaction
                        _buildTransactionSummary(),
                        
                        vSizedBox3,
                        
                        // Informations sur la méthode de paiement
                        _buildPaymentMethodInfo(),
                        
                        vSizedBox3,
                        
                        // Informations importantes
                        _buildImportantInfo(),
                      ],
                    ),
                  ),
                ),
                
                // Boutons d'action
                SafeArea(
                  child: _buildActionButtons(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Handle visuel du bottom sheet
  Widget _buildSheetHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      height: 4,
      width: 48,
      decoration: BoxDecoration(
        color: MyColors.borderLight,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// En-tête avec titre et icône
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: MyColors.coralPink.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.account_balance_wallet,
            color: MyColors.coralPink,
            size: 32,
          ),
        ),
        vSizedBox2,
        SubHeadingText(
          translate("ConfirmTopUp"),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: MyColors.textPrimary,
          textAlign: TextAlign.center,
        ),
        vSizedBox,
        ParagraphText(
          translate("ReviewTransactionDetails"),
          fontSize: 14,
          color: MyColors.textSecondary,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Résumé de la transaction
  Widget _buildTransactionSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MyColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MyColors.borderLight),
      ),
      child: Column(
        children: [
          // Montant principal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ParagraphText(
                translate("TopUpAmount"),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: MyColors.textSecondary,
              ),
              SubHeadingText(
                WalletHelper.formatAmount(widget.amount),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: MyColors.coralPink,
              ),
            ],
          ),
          
          vSizedBox,
          
          Divider(color: MyColors.borderLight),
          
          vSizedBox,
          
          // Informations supplémentaires
          _buildSummaryRow(
            translate("PaymentMethod"),
            _getPaymentMethodDisplayName(),
          ),
          
          vSizedBox,
          
          _buildSummaryRow(
            translate("TransactionFee"),
            translate("Free"),
            valueColor: MyColors.success,
          ),
          
          vSizedBox,
          
          Divider(color: MyColors.borderLight),
          
          vSizedBox,
          
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SubHeadingText(
                translate("TotalAmount"),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MyColors.textPrimary,
              ),
              SubHeadingText(
                WalletHelper.formatAmount(widget.amount),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MyColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ligne de résumé avec clé-valeur
  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ParagraphText(
          label,
          fontSize: 14,
          color: MyColors.textSecondary,
        ),
        ParagraphText(
          value,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: valueColor ?? MyColors.textPrimary,
        ),
      ],
    );
  }

  /// Informations sur la méthode de paiement
  Widget _buildPaymentMethodInfo() {
    final paymentMethod = _getPaymentMethodData();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.backgroundContrast,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyColors.borderLight),
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
              child: Image.asset(
                paymentMethod['image'],
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          hSizedBox2,
          
          // Informations de la méthode
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ParagraphText(
                  paymentMethod['name'],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MyColors.textPrimary,
                ),
                ParagraphText(
                  translate("MobileMoneyPayment"),
                  fontSize: 12,
                  color: MyColors.textSecondary,
                ),
              ],
            ),
          ),
          
          // Icône de sécurité
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MyColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.security,
              color: MyColors.success,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Informations importantes sur la transaction
  Widget _buildImportantInfo() {
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
                translate("ImportantInformation"),
                fontWeight: FontWeight.w600,
                color: MyColors.horizonBlue,
              ),
            ],
          ),
          vSizedBox,
          _buildInfoPoint(translate("PaymentWillBeProcessedImmediately")),
          _buildInfoPoint(translate("YouWillReceiveConfirmationSMS")),
          _buildInfoPoint(translate("FundsAvailableAfterConfirmation")),
          _buildInfoPoint(translate("ContactSupportForIssues")),
        ],
      ),
    );
  }

  /// Point d'information avec bullet
  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: MyColors.horizonBlue,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: ParagraphText(
              text,
              fontSize: 13,
              color: MyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Boutons d'action (Annuler / Confirmer)
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
      child: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          final bool isProcessing = _isProcessing || walletProvider.isCrediting;
          
          return Row(
            children: [
              // Bouton Annuler
              Expanded(
                child: RoundEdgedButton(
                  text: "Annuler",
                  onTap: isProcessing ? null : _handleCancel,
                  color: MyColors.backgroundLight,
                  textColor: MyColors.textPrimary,
                  borderColor: MyColors.borderLight,
                  height: 50,
                  borderRadius: 12,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              hSizedBox2,
              
              // Bouton Confirmer
              Expanded(
                flex: 2,
                child: RoundEdgedButton(
                  text: isProcessing ? translate("Processing") : "Confirmer le paiement",
                  onTap: isProcessing ? null : _handleConfirm,
                  color: MyColors.primaryColor,
                  textColor: Colors.white,
                  load: isProcessing,
                  height: 50,
                  borderRadius: 12,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // === MÉTHODES UTILITAIRES ===

  /// Retourne les données de la méthode de paiement sélectionnée
  Map<String, dynamic> _getPaymentMethodData() {
    final savedPaymentProvider = Provider.of<SavedPaymentMethodProvider>(context, listen: false);
    return savedPaymentProvider.allPaymentMethods.firstWhere(
      (method) => method['paymentGatewayType'] == widget.paymentMethod,
      orElse: () => {
        'name': widget.paymentMethod.value,
        'image': 'assets/images/default_payment.png',
      },
    );
  }

  /// Retourne le nom d'affichage de la méthode de paiement
  String _getPaymentMethodDisplayName() {
    final paymentMethod = _getPaymentMethodData();
    return paymentMethod['name'];
  }

  /// Gère l'annulation de la transaction
  void _handleCancel() {
    myCustomPrintStatement('WalletTopUpConfirmation: Transaction cancelled by user');
    popPage(context: context);
  }

  /// Gère la confirmation et lance le processus de paiement
  Future<void> _handleConfirm() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      myCustomPrintStatement('WalletTopUpConfirmation: Starting payment process');

      // Lancer le processus de paiement mobile money
      await _initiatePaymentProcess();

    } catch (e) {
      myCustomPrintStatement('Error in payment process: $e');
      showSnackbar(translate("PaymentProcessError"));
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Initie le processus de paiement selon la méthode sélectionnée
  Future<void> _initiatePaymentProcess() async {
    switch (widget.paymentMethod) {
      case PaymentMethodType.airtelMoney:
        await _processAirtelMoneyPayment();
        break;
      case PaymentMethodType.orangeMoney:
        await _processOrangeMoneyPayment();
        break;
      case PaymentMethodType.telmaMvola:
        await _processTelmaMoneyPayment();
        break;
      default:
        throw Exception('Unsupported payment method: ${widget.paymentMethod}');
    }
  }

  /// Traite le paiement Airtel Money
  Future<void> _processAirtelMoneyPayment() async {
    // Note: Pour le portefeuille, on doit adapter la logique existante
    // qui est actuellement prévue pour les paiements de trajets
    showSnackbar(translate("AirtelMoneyRedirectingToPayment"));
    
    // Fermer le bottom sheet
    popPage(context: context);
    
    // Déclencher le callback pour que l'écran parent gère la suite
    widget.onConfirm();
  }

  /// Traite le paiement Orange Money
  Future<void> _processOrangeMoneyPayment() async {
    showSnackbar(translate("OrangeMoneyRedirectingToPayment"));
    
    // Fermer le bottom sheet
    popPage(context: context);
    
    // Déclencher le callback
    widget.onConfirm();
  }

  /// Traite le paiement Telma Money
  Future<void> _processTelmaMoneyPayment() async {
    showSnackbar(translate("TelmaMoneyRedirectingToPayment"));
    
    // Fermer le bottom sheet
    popPage(context: context);
    
    // Déclencher le callback
    widget.onConfirm();
  }
}