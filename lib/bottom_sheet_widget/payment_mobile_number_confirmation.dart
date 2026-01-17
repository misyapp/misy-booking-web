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
import 'package:rider_ride_hailing_app/provider/airtel_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/provider/telma_money_payment_gateway_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/widget/common_alert_dailog.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PALETTES OFFICIELLES DES OPÉRATEURS
/// ═══════════════════════════════════════════════════════════════════════════

class _MVolaPalette {
  static const Color primaryYellow = Color(0xFFFED100);
  static const Color primaryGreen = Color(0xFF026936);
  static const Color darkGreen = Color(0xFF01552B);
  static const Color lightYellow = Color(0xFFFFF8DC);
  static const Color backgroundLight = Color(0xFFFFFDF5);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF6B7280);
}

class _AirtelPalette {
  static const Color primaryRed = Color(0xFFED1C24);
  static const Color darkRed = Color(0xFFB91C1C);
  static const Color lightRed = Color(0xFFFEE2E2);
  static const Color backgroundLight = Color(0xFFFFFBFB);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
}

/// ═══════════════════════════════════════════════════════════════════════════

class PaymentMobileNumberConfirmation extends StatefulWidget {
  const PaymentMobileNumberConfirmation({
    super.key,
  });

  @override
  State<PaymentMobileNumberConfirmation> createState() =>
      _PaymentMobileNumberConfirmationState();
}

class _PaymentMobileNumberConfirmationState
    extends State<PaymentMobileNumberConfirmation> {
  TextEditingController mobileNumberController = TextEditingController(text: "");
  final formKey = GlobalKey<FormState>();

  bool _isInstructionsExpanded = false; // Fermé par défaut

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS PALETTE COULEURS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isAirtel(PaymentMethodType? type) => type == PaymentMethodType.airtelMoney;

  Color _getPrimaryColor(PaymentMethodType? type) =>
      _isAirtel(type) ? _AirtelPalette.primaryRed : _MVolaPalette.primaryGreen;

  Color _getAccentColor(PaymentMethodType? type) =>
      _isAirtel(type) ? _AirtelPalette.darkRed : _MVolaPalette.primaryYellow;

  Color _getBackgroundColor(PaymentMethodType? type) =>
      _isAirtel(type) ? _AirtelPalette.backgroundLight : _MVolaPalette.backgroundLight;

  Color _getLightAccentColor(PaymentMethodType? type) =>
      _isAirtel(type) ? _AirtelPalette.lightRed : _MVolaPalette.lightYellow;

  Color _getTextDarkColor(PaymentMethodType? type) =>
      _isAirtel(type) ? _AirtelPalette.textDark : _MVolaPalette.textDark;

  Color _getTextGreyColor(PaymentMethodType? type) =>
      _isAirtel(type) ? _AirtelPalette.textGrey : _MVolaPalette.textGrey;

  String _getOperatorName(PaymentMethodType? type) =>
      _isAirtel(type) ? "Airtel Money" : "MVola";

  String _getOperatorIcon(PaymentMethodType? type) =>
      _isAirtel(type) ? MyImagesUrl.airtelMoneyIcon : MyImagesUrl.telmaMvolaIcon;

  String _getPhoneHint() {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final isAirtel = _isAirtel(tripProvider.confirmMobileNumberPaymentType);
    return isAirtel ? "33 00 000 00" : "34 00 000 00";
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGIQUE MÉTIER (INCHANGÉE)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleCancelTransaction(BuildContext context, TripProvider tripProvider) async {
    await showCommonAlertDailog(
      context,
      headingText: translate("areYouSure"),
      successIcon: false,
      message: translate("cancelTransactionMsg"),
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
                await _checkDiscountAndProceed(context, tripProvider);
              },
            ),
            hSizedBox,
          ],
        ),
      ],
    );
  }

  Future<void> _checkDiscountAndProceed(BuildContext context, TripProvider tripProvider) async {
    bool hasPaymentDiscount = tripProvider.booking!['ride_payment_method_discount'] != null &&
        double.parse(tripProvider.booking!['ride_payment_method_discount'].toString()) > 0;

    if (hasPaymentDiscount) {
      double discountAmount = double.parse(tripProvider.booking!['ride_payment_method_discount'].toString());
      double discountPercentage = double.parse(tripProvider.booking!['ride_payment_method_discount_percentage'].toString());
      double currentPrice = double.parse(tripProvider.booking!['ride_price_to_pay'].toString());
      double newPrice = currentPrice + discountAmount;
      await _showDiscountLossDialog(context, tripProvider, discountAmount, discountPercentage, currentPrice, newPrice);
    } else {
      await _processPaymentChangeWithoutDiscount(tripProvider);
    }
  }

  Future<void> _showDiscountLossDialog(
    BuildContext context,
    TripProvider tripProvider,
    double discountAmount,
    double discountPercentage,
    double currentPrice,
    double newPrice,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (BuildContext context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            decoration: BoxDecoration(
              color: MyColors.whiteThemeColor(),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: MyColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(Icons.warning_rounded, color: MyColors.warning, size: 32),
                  ),
                  vSizedBox2,
                  Column(
                    children: [
                      SubHeadingText("Attention :", fontSize: 18, fontWeight: FontWeight.w600, color: MyColors.warning, textAlign: TextAlign.center),
                      SubHeadingText("Perte de remise !", fontSize: 20, fontWeight: FontWeight.w700, color: MyColors.warning, textAlign: TextAlign.center),
                    ],
                  ),
                  vSizedBox,
                  ParagraphText(
                    translate("loseDiscountMessage")
                        .replaceAll("{percentage}", discountPercentage.toInt().toString())
                        .replaceAll("{amount}", formatAriary(discountAmount)),
                    fontSize: 16,
                    textAlign: TextAlign.center,
                    color: MyColors.blackThemeColor(),
                  ),
                  vSizedBox2,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MyColors.warning.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MyColors.warning.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SubHeadingText(translate("currentDiscountedPrice"), fontSize: 14, fontWeight: FontWeight.w500, color: MyColors.blackThemeColor()),
                        const SizedBox(height: 4),
                        SubHeadingText("${formatAriary(currentPrice)} ${globalSettings.currency}", fontSize: 18, fontWeight: FontWeight.w700, color: MyColors.success),
                        vSizedBox,
                        SubHeadingText(translate("newPriceWithoutDiscount"), fontSize: 14, fontWeight: FontWeight.w500, color: MyColors.blackThemeColor()),
                        const SizedBox(height: 4),
                        SubHeadingText("${formatAriary(newPrice)} ${globalSettings.currency}", fontSize: 18, fontWeight: FontWeight.w700, color: MyColors.primaryColor),
                      ],
                    ),
                  ),
                  vSizedBox3,
                  Column(
                    children: [
                      RoundEdgedButton(
                        text: translate("confirmLoseDiscount"),
                        width: double.infinity,
                        height: 48,
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _processPaymentChangeWithDiscountLoss(tripProvider, discountAmount, newPrice);
                        },
                      ),
                      vSizedBox,
                      RoundEdgedButton(
                        text: translate("no"),
                        width: double.infinity,
                        color: MyColors.blackThemeColorWithOpacity(0.1),
                        textColor: MyColors.blackThemeColor(),
                        height: 48,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _processPaymentChangeWithDiscountLoss(TripProvider tripProvider, double discountAmount, double newPrice) async {
    showLoading();
    try {
      await FirestoreServices.bookingRequest.doc(tripProvider.booking!['id']).update({
        "paymentMethod": PaymentMethodType.cash.value,
        "ride_price_to_pay": newPrice.toString(),
        "ride_payment_method_discount": 0,
        "ride_payment_method_discount_percentage": 0,
      });
      tripProvider.setScreen(CustomTripType.driverOnWay);
    } finally {
      hideLoading();
    }
  }

  Future<void> _processPaymentChangeWithoutDiscount(TripProvider tripProvider) async {
    showLoading();
    try {
      await FirestoreServices.bookingRequest.doc(tripProvider.booking!['id']).update({
        "paymentMethod": PaymentMethodType.cash.value,
      });
      tripProvider.setScreen(CustomTripType.driverOnWay);
    } finally {
      hideLoading();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      SavedPaymentMethodProvider saved = Provider.of<SavedPaymentMethodProvider>(context, listen: false);
      TripProvider tripProvider = Provider.of<TripProvider>(context, listen: false);
      List<SavedPaymentMethodModal> savedlist = saved.savedPaymentMethod;
      final a = savedlist.where((element) =>
          PaymentMethodTypeExtension.fromValue(element.name) == tripProvider.confirmMobileNumberPaymentType);
      if (a.isNotEmpty) {
        mobileNumberController.text = a.first.mobileNumber;
      }
    });
  }

  @override
  void dispose() {
    mobileNumberController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) {
        final paymentType = tripProvider.confirmMobileNumberPaymentType;
        final primaryColor = _getPrimaryColor(paymentType);
        final accentColor = _getAccentColor(paymentType);
        final bgColor = _getBackgroundColor(paymentType);
        final lightAccent = _getLightAccentColor(paymentType);
        final textDark = _getTextDarkColor(paymentType);
        final textGrey = _getTextGreyColor(paymentType);
        final operatorName = _getOperatorName(paymentType);
        final operatorIcon = _getOperatorIcon(paymentType);
        final amount = double.parse(tripProvider.booking!['ride_price_to_pay'].toString());
        final bookingId = tripProvider.booking!['id']?.toString() ?? '';
        final shortBookingId = bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase();

        return Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // ═══════════════════════════════════════════════════════════
              // HEADER AVEC BANDE COLORÉE
              // ═══════════════════════════════════════════════════════════
              _buildHeader(primaryColor, accentColor, operatorIcon, operatorName, paymentType),

              // ═══════════════════════════════════════════════════════════
              // CONTENU SCROLLABLE
              // ═══════════════════════════════════════════════════════════
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // Card montant premium
                        _buildAmountCard(amount, shortBookingId, primaryColor, accentColor, lightAccent, textDark, textGrey, paymentType),

                        const SizedBox(height: 28),

                        // Champ téléphone premium
                        _buildPhoneInput(primaryColor, textDark, textGrey),

                        const SizedBox(height: 20),

                        // Instructions dépliables
                        _buildInstructionsCard(primaryColor, lightAccent, textDark, operatorName),

                        const SizedBox(height: 28),

                        // Bouton confirmer premium
                        _buildConfirmButton(primaryColor, accentColor, tripProvider),

                        const SizedBox(height: 16),

                        // Lien payer en espèces
                        _buildCashLink(textGrey, tripProvider),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS COMPOSANTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(Color primaryColor, Color accentColor, String operatorIcon, String operatorName, PaymentMethodType? paymentType) {
    final isAirtel = _isAirtel(paymentType);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isAirtel
            ? LinearGradient(
                colors: [primaryColor, _AirtelPalette.darkRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [_MVolaPalette.primaryGreen, _MVolaPalette.darkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Pas de barre de drag car bottom sheet à 100%

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo de l'opérateur à gauche (filtre blanc pour les deux)
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      isAirtel
                          ? MyImagesUrl.airtelMoneyLogoWhite
                          : MyImagesUrl.telmaMoneyBannerImage,
                      width: isAirtel ? 140 : 110,
                      height: isAirtel ? 70 : 55,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Badge SSL + "Paiement sécurisé" à droite
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, size: 12, color: Colors.white.withValues(alpha: 0.9)),
                              const SizedBox(width: 4),
                              Text(
                                "SSL",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Paiement sécurisé",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(double amount, String shortBookingId, Color primaryColor, Color accentColor, Color lightAccent, Color textDark, Color textGrey, PaymentMethodType? paymentType) {
    final isAirtel = _isAirtel(paymentType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Label avec icône
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, size: 18, color: textGrey),
              const SizedBox(width: 8),
              Text(
                "Montant à payer",
                style: TextStyle(fontSize: 14, color: textGrey, fontWeight: FontWeight.w500),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Montant GRAND avec accent
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: isAirtel
                  ? [_AirtelPalette.primaryRed, _AirtelPalette.darkRed]
                  : [_MVolaPalette.primaryGreen, _MVolaPalette.darkGreen],
            ).createShader(bounds),
            child: Text(
              "${formatAriary(amount)} ${globalSettings.currency}",
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Référence course
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: lightAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Référence: #MIS-$shortBookingId",
              style: TextStyle(
                fontSize: 12,
                color: primaryColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput(Color primaryColor, Color textDark, Color textGrey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Numéro de téléphone",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Préfixe +261
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    const Text("🇲🇬", style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      "+261",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),

              Container(width: 1, height: 32, color: Colors.grey.shade200),

              // Champ de saisie
              Expanded(
                child: TextFormField(
                  controller: mobileNumberController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    hintText: _getPhoneHint(),
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(10),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (val) => ValidationFunction.mobileNumberValidation(val),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard(Color primaryColor, Color lightAccent, Color textDark, String operatorName) {
    return GestureDetector(
      onTap: () => setState(() => _isInstructionsExpanded = !_isInstructionsExpanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: lightAccent.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.info_outline_rounded, color: primaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Comment ça marche ?",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isInstructionsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor, size: 24),
                ),
              ],
            ),

            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                  children: [
                    _buildInstructionStep(1, "Confirmez votre numéro", primaryColor, textDark),
                    _buildInstructionStep(2, "Vous recevrez une demande USSD", primaryColor, textDark),
                    _buildInstructionStep(3, "Tapez votre code PIN $operatorName", primaryColor, textDark),
                    _buildInstructionStep(4, "Validez le paiement", primaryColor, textDark, isLast: true),
                  ],
                ),
              ),
              crossFadeState: _isInstructionsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int number, String text, Color primaryColor, Color textDark, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: textDark, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(Color primaryColor, Color accentColor, TripProvider tripProvider) {
    // Bouton jaune pour MVola, rouge pour Airtel
    final bool isAirtel = tripProvider.confirmMobileNumberPaymentType == PaymentMethodType.airtelMoney;
    final Color buttonColor = isAirtel ? _AirtelPalette.primaryRed : _MVolaPalette.primaryYellow;
    final Color textColor = isAirtel ? Colors.white : _MVolaPalette.textDark;

    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        color: buttonColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (formKey.currentState!.validate()) {
            showLoading();
            if (tripProvider.confirmMobileNumberPaymentType == PaymentMethodType.airtelMoney) {
              Provider.of<AirtelMoneyPaymentGatewayProvider>(context, listen: false).generatePaymentRequest(
                amount: formatNearest(double.parse(tripProvider.booking!['ride_price_to_pay'].toString())),
                mobileNumber: mobileNumberController.text,
              );
            } else if (tripProvider.confirmMobileNumberPaymentType == PaymentMethodType.telmaMvola) {
              Provider.of<TelmaMoneyPaymentGatewayProvider>(context, listen: false).generatePaymentRequest(
                phoneNumberDebitParty: mobileNumberController.text,
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 20, color: textColor),
            const SizedBox(width: 12),
            Text(
              "Confirmer le paiement",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashLink(Color textGrey, TripProvider tripProvider) {
    return GestureDetector(
      onTap: () async => await _handleCancelTransaction(context, tripProvider),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Payer en espèces à la place ?",
          style: TextStyle(
            fontSize: 14,
            color: textGrey,
            decoration: TextDecoration.underline,
            decorationColor: textGrey,
          ),
        ),
      ),
    );
  }
}
