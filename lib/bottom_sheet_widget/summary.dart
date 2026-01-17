import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/modal/notification_modal.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_circular_image.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import '../../../contants/my_colors.dart';
import '../../../contants/my_image_url.dart';
import '../../../contants/sized_box.dart';
import '../../../widget/custom_rich_text.dart';
import '../../../widget/custom_text.dart';

class SummaryPage extends StatelessWidget {
  final Map booking;
  final DriverModal driver;
  const SummaryPage({required this.booking, required this.driver, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: MyColors.whiteThemeColor(),
          borderRadius: BorderRadius.circular(40)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              if (!sheetValue) vSizedBox4,
              vSizedBox,
              if (sheetValue)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    vSizedBox,
                    if (booking['paymentMethod'].toString().toLowerCase() ==
                        "cash")
                      ParagraphText(
                        translate("cashPayment"),
                        fontSize: 13,
                      ),
                    if (booking['paymentMethod'].toString().toLowerCase() !=
                        "cash")
                      ParagraphText(
                        booking['paymentMethod'],
                        fontSize: 13,
                      ),
                    vSizedBox05,
                    RichTextCustomWidget(
                      firstText:
                          "${formatAriary(double.parse(booking['ride_price_to_pay'].toString()))} ",
                      firstTextColor: MyColors.blackThemeColor(),
                      firstTextFontSize: 30,
                      firstTextFontweight: FontWeight.bold,
                      secondTextColor: MyColors.blackThemeColor(),
                      secondText: globalSettings.currency,
                      secondTextFontweight: FontWeight.bold,
                      secondTextFontSize: 18,
                    ),
                    if (booking['total_duration'] != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${booking['total_duration']} mins.",
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            "\u2022",
                            style: TextStyle(
                                fontSize: 20,
                                color: MyColors.primaryColor,
                                height: 1),
                          ),
                          Text(
                            " ${booking['total_distance']} KM ",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    vSizedBox,
                    Row(
                      children: [
                        Icon(
                          Icons.watch_later_outlined,
                          color: MyColors.primaryColor,
                        ),
                        hSizedBox,
                        ParagraphText(formatTimestamp(booking["startedTime"],
                            formateString: "dd MMM yyyy HH:mm"))
                      ],
                    ),
                    vSizedBox,
                    Row(
                      children: [
                        Column(
                          children: [
                            Image.asset(
                              MyImagesUrl.pickupCircleIconTheme(),
                              width: 22,
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              width: 3,
                              height: 45,
                              color: MyColors.blackThemeColor(),
                            ),
                            Image.asset(
                              MyImagesUrl.dropLocationCircleIconTheme(),
                              width: 20,
                            )
                          ],
                        ),
                        hSizedBox,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ParagraphText(
                                translate('Startpoint'),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              ParagraphText(
                                booking['pickAddress'],
                                fontSize: 13,
                                color: MyColors.blackThemeColorWithOpacity(0.5),
                                fontWeight: FontWeight.w400,
                              ),
                              vSizedBox4,
                              ParagraphText(
                                translate('EndPoint'),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              ParagraphText(
                                booking['dropAddress'],
                                fontSize: 13,
                                color: MyColors.blackThemeColorWithOpacity(0.5),
                                fontWeight: FontWeight.w400,
                                maxLines: 1,
                                textOverflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    vSizedBox2,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: MyColors.textFillThemeColor(),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                CustomCircularImage(
                                  height: 50,
                                  width: 50,
                                  imageUrl: driver.profileImage,
                                  borderRadius: 100,
                                   fit: BoxFit.cover,
                                  fileType: CustomFileType.network,
                                ),
                                hSizedBox,
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        ParagraphText(
                                          driver.fullName,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        Row(
                                          children: [
                                            RatingBar(
                                              initialRating:
                                                  driver.averageRating,
                                              itemSize: 12,
                                              direction: Axis.horizontal,
                                              allowHalfRating: false,
                                              itemCount: 5,
                                              ratingWidget: RatingWidget(
                                                full: Image.asset(
                                                  MyImagesUrl.star,
                                                  color: MyColors.primaryColor,
                                                ),
                                                half: Image.asset(
                                                  MyImagesUrl.star,
                                                  color: MyColors.primaryColor,
                                                ),
                                                empty: Image.asset(
                                                  MyImagesUrl.star,
                                                  color: MyColors.blackColor
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                              itemPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 1.0),
                                              onRatingUpdate: (rating) {},
                                            ),
                                            ParagraphText(
                                              " (${driver.totalReveiwCount} ${translate("Reviews")})",
                                              fontSize: 11,
                                              color: MyColors.blackThemeColor()
                                                  .withOpacity(0.5),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    vSizedBox2,
                    SizedBox(
                        height: 10 + MediaQuery.of(context).viewInsets.bottom),
                    if (booking['paymentMethod'].toString().toLowerCase() !=
                        "cash")
                      Consumer<TripProvider>(
                        builder: (context, tripProvider, child) =>
                            RoundEdgedButton(
                          width: double.infinity,
                          text: translate("goToPaymentPage"),
                          onTap: () {
                            tripProvider.redirectToOnlinePaymentPage();
                            // onPaid({"txn_id": "12345"});
                          },
                        ),
                      ),
                    // if (booking['paymentMethod'].toString().toLowerCase() !=
                    //     "cash")
                    //   Align(
                    //     alignment: Alignment.centerLeft,
                    //     child: SubHeadingText(
                    //       translate("payWith"),
                    //       textAlign: TextAlign.start,
                    //     ),
                    //   ),
                    // if (booking['paymentMethod'].toString().toLowerCase() !=
                    //     "cash")
                    //   Align(
                    //     alignment: Alignment.centerLeft,
                    //     child: Wrap(
                    //       alignment: WrapAlignment.start,
                    //       crossAxisAlignment: WrapCrossAlignment.start,
                    //       children: [
                    //         Container(
                    //           margin:
                    //               const EdgeInsets.symmetric(horizontal: 10),
                    //           child: InkWell(
                    //             onTap: () async {
                    //               Provider.of<OrangeMoneyPaymentGatewayProvider>(
                    //                       context,
                    //                       listen: false)
                    //                   .generatePaymentRequest(
                    //                 amount:
                    //                     booking['ride_price_to_pay'].toString(),
                    //               );
                    //             },
                    //             child: const CustomCircularImage(
                    //               imageUrl: MyImagesUrl.orangeMoneyIcon,
                    //               fileType: CustomFileType.asset,
                    //               borderRadius: 0,
                    //               height: 80,
                    //               width: 80,
                    //             ),
                    //           ),
                    //         ),
                    //         Container(
                    //           margin:
                    //               const EdgeInsets.symmetric(horizontal: 10),
                    //           child: InkWell(
                    //             onTap: () {
                    //               TripProvider tripProvider =
                    //                   Provider.of(context, listen: false);
                    //               tripProvider.setScreen(
                    //                   CustomTripType.paymentMobileConfirm);
                    //               tripProvider.setPaymentConfirmMobileNumber(
                    //                   PaymentMethodType.telmaMvola);
                    //               // showPaymentProccessLoader(onTap: () {
                    //               //   popPage(context: context);
                    //               // });
                    //             },
                    //             child: const CustomCircularImage(
                    //               imageUrl: MyImagesUrl.telmaMvolaIcon,
                    //               fileType: CustomFileType.asset,
                    //               borderRadius: 0,
                    //               height: 80,
                    //               width: 80,
                    //             ),
                    //           ),
                    //         ),
                    //         Container(
                    //           margin:
                    //               const EdgeInsets.symmetric(horizontal: 10),
                    //           child: InkWell(
                    //             onTap: () {
                    //               TripProvider tripProvider =
                    //                   Provider.of(context, listen: false);
                    //               tripProvider.setScreen(
                    //                   CustomTripType.paymentMobileConfirm);
                    //               tripProvider.setPaymentConfirmMobileNumber(
                    //                   PaymentMethodType.airtelMoney);
                    //             },
                    //             child: const CustomCircularImage(
                    //               imageUrl: MyImagesUrl.airtelMoneyIcon,
                    //               fileType: CustomFileType.asset,
                    //               borderRadius: 0,
                    //               height: 80,
                    //               width: 80,
                    //             ),
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),

                    vSizedBox3
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
