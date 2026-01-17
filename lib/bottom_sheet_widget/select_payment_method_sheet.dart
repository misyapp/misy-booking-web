import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:rider_ride_hailing_app/widget/wallet_balance_widget.dart';
import '../contants/my_colors.dart';
import '../contants/sized_box.dart';
import '../services/analytics/analytics_service.dart';
import '../widget/custom_text.dart';
import '../widget/round_edged_button.dart';

class SelectPaymentMethod extends StatefulWidget {
  final Function(PaymentMethodType selectedPaymentMethod) onTap;
  const SelectPaymentMethod({Key? key, required this.onTap}) : super(key: key);

  @override
  State<SelectPaymentMethod> createState() => _SelectPaymentMethodState();
}

class _SelectPaymentMethodState extends State<SelectPaymentMethod> with WidgetsBindingObserver {
  DateTime? _screenOpenedAt;
  Timer? _inactivityTimer;
  bool _hasLoggedAbandonment = false;

  // Tracking abandonment
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 60), () {
      if (!_hasLoggedAbandonment) {
        logPaymentAbandonment('timeout');
      }
    });
  }

  void _resetInactivityTimer() {
    if (!_hasLoggedAbandonment) {
      _startInactivityTimer();
    }
  }

  int _getTimeSpentSeconds() {
    if (_screenOpenedAt == null) return 0;
    return DateTime.now().difference(_screenOpenedAt!).inSeconds;
  }

  Future<void> logPaymentAbandonment(String reason) async {
    if (_hasLoggedAbandonment) return;
    _hasLoggedAbandonment = true;
    
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final userDetails = await DevFestPreferences().getUserDetails();
    final savedPayment = Provider.of<SavedPaymentMethodProvider>(context, listen: false);
    
    final tripPrice = _getTripPrice(tripProvider);
    final allMethods = savedPayment.allPaymentMethods;
    final availableMethodsCount = allMethods.length;
    
    final methodNames = allMethods.map((m) {
      final paymentType = m['paymentGatewayType'] as PaymentMethodType;
      return paymentType.value;
    }).join(',');
    
    await AnalyticsService.logPaymentSelectionAbandoned(
      timeSpentSeconds: _getTimeSpentSeconds(),
      reason: reason,
      tripPrice: tripPrice,
      paymentMethodsAvailable: availableMethodsCount,
      availableMethods: methodNames,
      userId: userDetails?.id,
    );
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _screenOpenedAt = DateTime.now();
    _startInactivityTimer();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      logPaymentAbandonment('app_backgrounded');
    }
  }

  /// Calcule le prix du trajet en cours
  double _getTripPrice(TripProvider tripProvider) {
    if (tripProvider.selectedVehicle == null) {
      return 0.0;
    }
    
    // Utiliser la même logique que dans TripProvider
    double price = tripProvider.selectedPromoCode != null 
        ? tripProvider.calculatePriceAfterCouponApply()
        : tripProvider.calculatePrice(tripProvider.selectedVehicle!);
        
    return price;
  }

  /// Crée un widget badge de promotion pour un mode de paiement
  Widget _buildPromoBadge(double discountPercentage, PaymentMethodType paymentType, AdminSettingsProvider adminProvider) {
    myCustomPrintStatement('🏷️ Building promo badge for ${paymentType.value}: ${discountPercentage}% (active: ${adminProvider.isPaymentPromoActive()})');
    
    if (discountPercentage <= 0 || !adminProvider.isPaymentPromoActive()) {
      return const SizedBox.shrink();
    }

    // Vérifier si c'est le meilleur mode de paiement
    bool isBestPromo = paymentType == adminProvider.getBestPaymentPromoMethod();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isBestPromo ? MyColors.coralPink : MyColors.warning,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '-${discountPercentage.toInt()}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Crée le texte explicatif pour la promotion
  Widget _buildPromoText(double discountPercentage, double tripPrice, AdminSettingsProvider adminProvider) {
    if (discountPercentage <= 0 || !adminProvider.isPaymentPromoActive()) {
      return const SizedBox.shrink();
    }

    double savings = tripPrice * discountPercentage / 100;
    
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        'Économisez ${savings.toInt()} Ar sur ce trajet',
        style: TextStyle(
          color: MyColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Log abandonment via bouton système
          await logPaymentAbandonment('system_back_button');
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Container(
      constraints: BoxConstraints(
          minHeight: 60, maxHeight: MediaQuery.of(context).size.height * 0.6),
      // padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ValueListenableBuilder(
        valueListenable: sheetShowNoti,
        builder: (context, sheetValue, child) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicateur de tiroir centré
            Center(
              child: GestureDetector(
                onTap: () {
                  sheetShowNoti.value = !sheetValue;
                  MyGlobalKeys.homePageKey.currentState!
                      .updateBottomSheetHeight(milliseconds: 20);
                },
                child: Container(
                  height: 6,
                  width: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: MyColors.colorD9D9D9Theme(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Ligne avec bouton retour et titre
            Row(
              children: [
                // Bouton retour à gauche
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: MyColors.blackThemeColor(),
                    size: 24,
                  ),
                  onPressed: () {
                    // Log abandonment pour bouton retour
                    logPaymentAbandonment('back_button');

                    // Retour à l'écran de choix de véhicule
                    Provider.of<TripProvider>(context, listen: false)
                        .setScreen(CustomTripType.chooseVehicle);
                  },
                ),
                // Titre centré avec Expanded
                Expanded(
                  child: Center(
                    child: SubHeadingText(
                      translate("SelectPaymentMethod"),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Espace équivalent au bouton pour centrer le titre
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 4),
            // Trait de séparation gris
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: MyColors.colorD9D9D9Theme(),
            ),
            const SizedBox(height: 6),
            if (sheetValue)
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: selectPayMethod,
                  builder: (context, value, child) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: Consumer4<SavedPaymentMethodProvider, WalletProvider, TripProvider, AdminSettingsProvider>(
                            builder: (context, savedPayment, walletProvider, tripProvider, adminProvider, child) {
                              // Filtrer les méthodes selon les flags de fonctionnalités
                              final allMethods = List.from(savedPayment.allPaymentMethods);
                              
                              // Exclure le portefeuille si la fonctionnalité est désactivée
                              if (!FeatureToggleService.instance.isDigitalWalletEnabled()) {
                                allMethods.removeWhere((method) => 
                                  method['paymentGatewayType'] == PaymentMethodType.wallet);
                              }
                              
                              // Exclure les cartes bancaires si la fonctionnalité est désactivée
                              if (!FeatureToggleService.instance.isCreditCardPaymentEnabled()) {
                                allMethods.removeWhere((method) => 
                                  method['paymentGatewayType'] == PaymentMethodType.creditCard);
                              }
                              
                              // Réorganiser pour mettre le portefeuille en premier si activé
                              if (FeatureToggleService.instance.isDigitalWalletEnabled()) {
                                // Si activé, réorganiser pour mettre le portefeuille en premier
                                final walletIndex = allMethods.indexWhere((method) => 
                                  method['paymentGatewayType'] == PaymentMethodType.wallet);
                                
                                if (walletIndex != -1) {
                                  final walletMethod = allMethods.removeAt(walletIndex);
                                  allMethods.insert(0, walletMethod);
                                }
                              }
                              
                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: allMethods.length,
                                itemBuilder: (context, index) {
                                  final paymentMethod = allMethods[index];
                                  final isWalletMethod = paymentMethod['paymentGatewayType'] == PaymentMethodType.wallet;
                                
                                // Vérifier le solde pour le portefeuille
                                bool isWalletDisabled = false;
                                String walletSubtitle = '';
                                double tripPrice = _getTripPrice(tripProvider);
                                double promoDiscount = adminProvider.getPaymentPromoDiscount(paymentMethod['paymentGatewayType']);
                                
                                if (isWalletMethod) {
                                  if (!walletProvider.hasSufficientBalance(tripPrice)) {
                                    isWalletDisabled = true;
                                    walletSubtitle = '${translate('insufficientBalance')} - ${walletProvider.formattedBalance}';
                                  } else {
                                    walletSubtitle = '${translate('walletBalanceLabel')}: ${walletProvider.formattedBalance}';
                                  }
                                }
                                
                                // Traitement spécial pour le portefeuille Misy (en haut avec fond gris)
                                if (isWalletMethod) {
                                  return Column(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          // Reset timer d'inactivité lors d'interaction
                                          _resetInactivityTimer();
                                          
                                          if (!isWalletDisabled) {
                                            selectPayMethod.value = paymentMethod['paymentGatewayType'];
                                          }
                                        },
                                        child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: MyColors.colorD9D9D9Theme(),
                                              borderRadius: BorderRadius.circular(12),
                                              border: (value == paymentMethod['paymentGatewayType'] && !isWalletDisabled)
                                                  ? Border.all(color: MyColors.coralPink, width: 2)
                                                  : null,
                                            ),
                                            child: Row(
                                            children: [
                                              // Logo du portefeuille
                                              Container(
                                                width: 40,
                                                height: 40,
                                                padding: const EdgeInsets.all(6),
                                                child: Image.asset(
                                                  paymentMethod['image'],
                                                  fit: BoxFit.contain,
                                                  color: isWalletDisabled ? Colors.grey : null,
                                                ),
                                              ),
                                              const SizedBox(width: 12),

                                              // Texte et sous-texte
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          paymentMethod['name'],
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w600,
                                                            color: isWalletDisabled ? MyColors.blackThemeColorWithOpacity(0.5) : MyColors.blackThemeColor(),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        _buildPromoBadge(promoDiscount, paymentMethod['paymentGatewayType'], adminProvider),
                                                      ],
                                                    ),
                                                    if (walletSubtitle.isNotEmpty)
                                                      Text(
                                                        walletSubtitle,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: isWalletDisabled ? Colors.red.shade400 : MyColors.blackThemeColorWithOpacity(0.6),
                                                        ),
                                                      ),
                                                    _buildPromoText(promoDiscount, tripPrice, adminProvider),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            ),
                                        ),
                                      ),
                                      // Widget compact du portefeuille si sélectionné
                                      if (value == PaymentMethodType.wallet) ...[
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                          child: WalletBalanceCompact(
                                            showActions: false,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                }
                                
                                // Pour les autres méthodes de paiement (format simple sans rectangle)
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  child: GestureDetector(
                                    onTap: () {
                                      // Reset timer d'inactivité lors d'interaction
                                      _resetInactivityTimer();
                                      
                                      if (!paymentMethod['disabled']) {
                                        selectPayMethod.value = paymentMethod['paymentGatewayType'];
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        // Logo du service de paiement
                                        Container(
                                          width: 40,
                                          height: 40,
                                          padding: const EdgeInsets.all(6),
                                          child: Image.asset(
                                            paymentMethod['image'],
                                            fit: BoxFit.contain,
                                            color: paymentMethod['disabled'] ? Colors.grey : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        
                                        // Nom de la méthode de paiement
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    paymentMethod['name'],
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                      color: paymentMethod['disabled'] ? MyColors.blackThemeColorWithOpacity(0.5) : MyColors.blackThemeColor(),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _buildPromoBadge(promoDiscount, paymentMethod['paymentGatewayType'], adminProvider),
                                                ],
                                              ),
                                              _buildPromoText(promoDiscount, tripPrice, adminProvider),
                                            ],
                                          ),
                                        ),
                                        
                                        // Bouton radio
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: (value == paymentMethod['paymentGatewayType'])
                                                  ? MyColors.coralPink
                                                  : MyColors.blackThemeColorWithOpacity(0.3),
                                              width: 2,
                                            ),
                                            color: MyColors.whiteThemeColor(),
                                          ),
                                          child: (value == paymentMethod['paymentGatewayType'])
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
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      RoundEdgedButton(
                        verticalMargin: 20,
                        horizontalMargin: 20,
                        text: translate("next"),
                        width: double.infinity,
                        onTap: () async {
                          if (selectPayMethod.value == null) {
                            showSnackbar(
                                translate("Pleaseselectpaymentmethod"));
                            return;
                          }

                          // Validation spéciale pour le portefeuille
                          if (selectPayMethod.value == PaymentMethodType.wallet) {
                            try {
                              final walletProvider = Provider.of<WalletProvider>(context, listen: false);
                              final tripProvider = Provider.of<TripProvider>(context, listen: false);
                              
                              // Vérifier que le portefeuille est initialisé
                              if (walletProvider.wallet == null) {
                                showSnackbar("Portefeuille non initialisé. Veuillez réessayer.");
                                return;
                              }
                              
                              // Vérifier que le portefeuille est actif
                              if (!walletProvider.isWalletActive) {
                                showSnackbar("Votre portefeuille n'est pas actif. Contactez le support.");
                                return;
                              }
                              
                              // Calculer le prix du trajet
                              double tripPrice = _getTripPrice(tripProvider);
                              
                              if (tripPrice <= 0) {
                                showSnackbar("Erreur: montant du trajet invalide.");
                                return;
                              }
                              
                              // Vérifier le solde suffisant
                              if (!walletProvider.hasSufficientBalance(tripPrice)) {
                                showSnackbar("Solde insuffisant: ${walletProvider.formattedBalance}. Montant requis: ${tripPrice.toStringAsFixed(0)} MGA");
                                return;
                              }
                              
                              // Vérifier si une transaction est en cours
                              if (walletProvider.isProcessing) {
                                showSnackbar("Une transaction est déjà en cours. Veuillez patienter.");
                                return;
                              }
                            } catch (e) {
                              showSnackbar("Erreur lors de la validation du portefeuille: ${e.toString()}");
                              return;
                            }
                          }

                          await DevFestPreferences()
                              .setLastPaymentMethodSelected(
                                  selectPayMethod.value!.value);

                          // Calculer la promo de paiement avant de continuer
                          final tripProvider = Provider.of<TripProvider>(context, listen: false);
                          tripProvider.calculatePaymentMethodDiscount(selectPayMethod.value);

                          widget.onTap(selectPayMethod.value!);
                        },
                      ),
                      vSizedBox3,
                    ],
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
