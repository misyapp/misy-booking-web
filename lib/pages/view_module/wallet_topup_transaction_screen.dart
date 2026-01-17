import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/view_module/my_wallet_management.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_coordinator_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

/// Écran de transition qui suit la progression d'une transaction de top-up
/// Affiche le statut en temps réel et permet l'annulation si nécessaire
class WalletTopUpTransactionScreen extends StatefulWidget {
  final double amount;
  final PaymentMethodType paymentMethod;
  final String userId;

  const WalletTopUpTransactionScreen({
    Key? key,
    required this.amount,
    required this.paymentMethod,
    required this.userId,
  }) : super(key: key);

  @override
  State<WalletTopUpTransactionScreen> createState() => _WalletTopUpTransactionScreenState();
}

class _WalletTopUpTransactionScreenState extends State<WalletTopUpTransactionScreen> {
  
  @override
  void initState() {
    super.initState();
    myCustomPrintStatement('WalletTopUpTransactionScreen: Monitoring transaction for ${widget.amount} MGA via ${widget.paymentMethod.value}');
    
    // Écouter les changements de statut du coordinator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coordinator = Provider.of<WalletTopUpCoordinatorProvider>(context, listen: false);
      
      // Si la transaction est déjà terminée, rediriger immédiatement
      if (coordinator.status == TopUpStatus.success) {
        _handleTransactionSuccess();
      } else if (coordinator.status == TopUpStatus.failed) {
        _handleTransactionFailure();
      }
    });
  }

  /// Gère le succès de la transaction
  void _handleTransactionSuccess() {
    myCustomPrintStatement('Transaction successful, redirecting to wallet');
    showSnackbar('Portefeuille crédité avec succès: ${formatAriary(widget.amount)} ${globalSettings.currency}');
    
    // Naviguer vers MyWalletManagement en remplaçant la stack
    pushReplacement(
      context: context,
      screen: const MyWalletManagement(),
    );
  }

  /// Gère l'échec de la transaction
  void _handleTransactionFailure() {
    myCustomPrintStatement('Transaction failed');
    // Rester sur l'écran et afficher l'erreur
    // L'user pourra cliquer "Retour" pour réessayer
  }

  /// Annule la transaction en cours
  void _cancelTransaction() {
    final coordinator = Provider.of<WalletTopUpCoordinatorProvider>(context, listen: false);
    coordinator.cancelCurrentTransaction();
    
    // Retourner à l'écran de top-up
    popPage(context: context);
  }

  /// Retourne à l'écran de top-up (en cas d'échec)
  void _goBackToTopUp() {
    popPage(context: context);
  }

  /// Retourne le message de statut approprié
  String _getStatusMessage(TopUpStatus status) {
    switch (status) {
      case TopUpStatus.initiating:
        return translate("InitiatingPayment");
      case TopUpStatus.processing:
        return translate("ProcessingPayment");
      case TopUpStatus.success:
        return translate("PaymentSuccessful");
      case TopUpStatus.failed:
        return translate("PaymentFailed");
      case TopUpStatus.cancelled:
        return translate("PaymentCancelled");
      case TopUpStatus.timeout:
        return translate("PaymentTimeout");
      default:
        return translate("ProcessingPayment");
    }
  }

  /// Retourne l'icône appropriée selon le statut
  Widget _getStatusIcon(TopUpStatus status) {
    switch (status) {
      case TopUpStatus.success:
        return Icon(
          Icons.check_circle,
          color: MyColors.success,
          size: 80,
        );
      case TopUpStatus.failed:
      case TopUpStatus.cancelled:
      case TopUpStatus.timeout:
        return Icon(
          Icons.error,
          color: MyColors.primaryColor,
          size: 80,
        );
      default:
        return SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(MyColors.coralPink),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.backgroundLight,
      appBar: CustomAppBar(
        title: translate("TransactionInProgress"),
        isBackIcon: false, // Pas de retour pendant la transaction
        bgcolor: MyColors.whiteColor,
      ),
      body: Consumer<WalletTopUpCoordinatorProvider>(
        builder: (context, coordinator, child) {
          // Auto-navigation en cas de succès
          if (coordinator.status == TopUpStatus.success) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleTransactionSuccess();
            });
          }
          
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icône de statut (loader, succès, ou erreur)
                  _getStatusIcon(coordinator.status),
                  
                  vSizedBox3,
                  
                  // Message de statut
                  SubHeadingText(
                    _getStatusMessage(coordinator.status),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    textAlign: TextAlign.center,
                    color: MyColors.textPrimary,
                  ),
                  
                  vSizedBox2,
                  
                  // Message détaillé depuis le coordinator
                  if (coordinator.statusMessage.isNotEmpty)
                    ParagraphText(
                      coordinator.statusMessage,
                      fontSize: 16,
                      textAlign: TextAlign.center,
                      color: MyColors.textSecondary,
                    ),
                  
                  vSizedBox2,
                  
                  // Détails de la transaction
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: MyColors.backgroundContrast,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MyColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ParagraphText(
                              translate("Amount"),
                              fontSize: 16,
                              color: MyColors.textSecondary,
                            ),
                            SubHeadingText(
                              "${formatAriary(widget.amount)} ${globalSettings.currency}",
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: MyColors.textPrimary,
                            ),
                          ],
                        ),
                        vSizedBox,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ParagraphText(
                              translate("PaymentMethod"),
                              fontSize: 16,
                              color: MyColors.textSecondary,
                            ),
                            SubHeadingText(
                              widget.paymentMethod.value,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: MyColors.textPrimary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  vSizedBox3,
                  
                  // Messages d'instruction selon le statut
                  if (coordinator.status == TopUpStatus.processing)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MyColors.coralPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MyColors.coralPink.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.phone_android,
                            color: MyColors.coralPink,
                            size: 32,
                          ),
                          vSizedBox,
                          ParagraphText(
                            widget.paymentMethod == PaymentMethodType.airtelMoney
                                ? translate("ConfirmOnAirtelPhone")
                                : translate("ConfirmOnTelmaPhone"),
                            fontSize: 14,
                            textAlign: TextAlign.center,
                            color: MyColors.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // Boutons d'action selon le statut
                  if (coordinator.status == TopUpStatus.processing) ...[
                    // Bouton annuler pendant le traitement
                    RoundEdgedButton(
                      text: translate("CancelTransaction"),
                      color: MyColors.blackThemeColorWithOpacity(0.1),
                      textColor: MyColors.primaryColor,
                      onTap: _cancelTransaction,
                      width: double.infinity,
                    ),
                  ] else if (coordinator.status == TopUpStatus.failed || 
                             coordinator.status == TopUpStatus.cancelled || 
                             coordinator.status == TopUpStatus.timeout) ...[
                    // Boutons pour les cas d'échec
                    Column(
                      children: [
                        RoundEdgedButton(
                          text: translate("TryAgain"),
                          onTap: _goBackToTopUp,
                          width: double.infinity,
                        ),
                        vSizedBox,
                        RoundEdgedButton(
                          text: translate("GoToWallet"),
                          color: MyColors.blackThemeColorWithOpacity(0.1),
                          textColor: MyColors.textPrimary,
                          onTap: () {
                            pushReplacement(
                              context: context,
                              screen: const MyWalletManagement(),
                            );
                          },
                          width: double.infinity,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}