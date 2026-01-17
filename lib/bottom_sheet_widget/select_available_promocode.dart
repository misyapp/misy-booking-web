// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/modal/promocodes_modal.dart';
import 'package:rider_ride_hailing_app/provider/promocodes_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_pagination_grid_view.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:rider_ride_hailing_app/widget/input_text_field_widget.dart';
import '../contants/my_colors.dart';
import '../contants/sized_box.dart';
import '../widget/custom_text.dart';
import '../widget/round_edged_button.dart';

class SelectAvailablePromocode extends StatefulWidget {
  final Function(PromoCodeModal selectedPromo) onSelect;
  const SelectAvailablePromocode({super.key, required this.onSelect});

  @override
  State<SelectAvailablePromocode> createState() => _SelectAvailablePromocodeState();
}

class _SelectAvailablePromocodeState extends State<SelectAvailablePromocode> {
  bool _showPromoCodeInput = false;
  final TextEditingController _promoCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          minHeight: 60, maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: ValueListenableBuilder(
        valueListenable: sheetShowNoti,
        builder: (context, sheetValue, child) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            vSizedBox,
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
            if (!sheetValue)
            vSizedBox4,
            vSizedBox,
            if (sheetValue)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    vSizedBox,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SubHeadingText(
                            translate("Available Promo Codes"),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        Consumer<TripProvider>(
                          builder: (context, tripProvider, child) => Row(
                            children: [
                              SubHeadingText(
                                formatAriary(tripProvider.calculatePrice(
                                    tripProvider.selectedVehicle!)),
                                fontWeight: FontWeight.w600,
                                fontSize: tripProvider.selectedPromoCode != null
                                    ? 14
                                    : 18,
                                decoration:
                                    tripProvider.selectedPromoCode == null
                                        ? null
                                        : TextDecoration.lineThrough,
                              ),
                              hSizedBox05,
                              if (tripProvider.selectedPromoCode != null)
                                SubHeadingText(
                                  formatAriary(
                                    tripProvider.calculatePriceAfterCouponApply()
                                    ),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              if (tripProvider.selectedPromoCode != null)
                                hSizedBox05,
                              SubHeadingText(
                                globalSettings.currency,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                              hSizedBox
                            ],
                          ),
                        ),
                        ],
                      ),
                    ),
                    vSizedBox2,
                    Consumer<TripProvider>(
                      builder: (context, tripProvider, child) =>
                          Consumer<PromocodesProvider>(
                        builder: (context, promocodesProvider, child) =>
                            Expanded(
                          child: CustomPaginatedGridView(
                            noDataHeight: 120,
                            padding: EdgeInsets.symmetric(
                                horizontal: globalHorizontalPadding),
                            itemBuilder: (p0, index) => GestureDetector(
                              onTap: () {
                                tripProvider.selectedPromoCode =
                                    promocodesProvider
                                        .filteredPromocodes[index];
                                tripProvider.notifyListeners();
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: MyColors.textFillThemeColor(),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        vSizedBox,
                                        Center(
                                            child: SubHeadingText(
                                          "${promocodesProvider.filteredPromocodes[index].discountPercent}% ${translate("Off")}",
                                          color: MyColors.redColor,
                                          maxLines:2,
                                        )),
                                        vSizedBox,
                                        Row(
                                          children: [
                                            Image.asset(
                                              MyImagesUrl.vehicleManagementIcon,
                                              height: 18,
                                              width: 18,
                                            ),
                                            hSizedBox02,
                                            ParagraphText(
                                              promocodesProvider
                                                      .filteredPromocodes[index]
                                                      .vehicleCategory
                                                      .isEmpty
                                                  ? translate("All Vehicle")
                                                  : vehicleMap[promocodesProvider
                                                              .filteredPromocodes[
                                                                  index]
                                                              .vehicleCategory
                                                              .first]
                                                          ?.name ??
                                                      "",
                                              color: MyColors.blackThemeColor(),
                                            ),
                                          ],
                                        ),
                                        vSizedBox05,
                                        ParagraphText(
                                          promocodesProvider
                                              .filteredPromocodes[index]
                                              .description,
                                          fontSize: 12,
                                          color: MyColors.blackThemeColor(),
                                        ),
                                        ParagraphText(
                                          "${translate("Max discount")} :- ${formatAriary(promocodesProvider.filteredPromocodes[index].maxRideAmount)} ${globalSettings.currency}",
                                          fontSize: 12,
                                          color: MyColors.blackThemeColor(),
                                        ),
                                        ParagraphText(
                                          "${translate("Exp:")} ${DateFormat("dd MMM yyyy").format(promocodesProvider.filteredPromocodes[index].expiryDate.toDate())}",
                                          fontSize: 10,
                                          color: MyColors.blackThemeColor(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (tripProvider.selectedPromoCode?.id ==
                                      promocodesProvider
                                          .filteredPromocodes[index].id)
                                    Container(
                                        padding: EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: MyColors.primaryColor)),
                                        child: Icon(
                                          Icons.check,
                                          size: 18,
                                          color: MyColors.primaryColor,
                                        ))
                                ],
                              ),
                            ),
                            itemCount:
                                promocodesProvider.filteredPromocodes.length,
                            noDataText: translate("No Promocodes available..."),
                          ),
                        ),
                      ),
                    ),
                    // Section d'entrée de code promo
                    if (_showPromoCodeInput) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            vSizedBox,
                            SubHeadingText(
                              translate("Enter promo code"),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            vSizedBox,
                            Form(
                              key: _formKey,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InputTextFieldWidget(
                                      controller: _promoCodeController,
                                      hintText: translate("Enter promo code"),
                                      fillColor: MyColors.textFillThemeColor(),
                                      borderColor: MyColors.borderLight,
                                    ),
                                  ),
                                  hSizedBox,
                                  Consumer<PromocodesProvider>(
                                    builder: (context, promocodes, child) => ElevatedButton(
                                      onPressed: () {
                                        if (_formKey.currentState!.validate() &&
                                            _promoCodeController.text.isNotEmpty) {
                                          promocodes.applyForPromocode(
                                              code: _promoCodeController.text);
                                          _promoCodeController.clear();
                                          setState(() {
                                            _showPromoCodeInput = false;
                                          });
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: MyColors.primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 14),
                                      ),
                                      child: Text(
                                        translate('Ajouter'),
                                        style: TextStyle(color: MyColors.whiteColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            vSizedBox,
                            // Bouton pour annuler
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showPromoCodeInput = false;
                                  _promoCodeController.clear();
                                });
                              },
                              child: ParagraphText(
                                translate("Annuler"),
                                color: MyColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Consumer<TripProvider>(
                      builder: (context, tripProvider, child) {
                        // Si on est en mode entrée de code, masquer le bouton principal
                        if (_showPromoCodeInput) {
                          return const SizedBox.shrink();
                        }
                        return RoundEdgedButton(
                          verticalMargin: 20,
                          horizontalMargin: 20,
                          text: tripProvider.selectedPromoCode == null
                              ? translate("Ajouter un code promo")
                              : translate("next"),
                          width: double.infinity,
                          onTap: () async {
                            // Si aucun code promo n'est sélectionné, afficher le champ de saisie
                            if (tripProvider.selectedPromoCode == null) {
                              setState(() {
                                _showPromoCodeInput = true;
                              });
                              return;
                            }

                            widget.onSelect(tripProvider.selectedPromoCode!);
                          },
                        );
                      },
                    ),
                    vSizedBox3,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
