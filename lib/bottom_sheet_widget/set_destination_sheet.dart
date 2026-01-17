import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import '../widget/input_text_field_widget.dart';

class SetDestinationSheet extends StatelessWidget {
  SetDestinationSheet({Key? key}) : super(key: key);
  final TextEditingController searchDestination = TextEditingController();
  final TextEditingController searchDestinationFromCurrent =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    myCustomPrintStatement(
        "location search list ${lastSearchSuggestion.value}");
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SingleChildScrollView(
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
              vSizedBox,
             if (!sheetValue)
            vSizedBox4,
              if (sheetValue)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    vSizedBox,
                    InkWell(
                      onTap: () {
                        Provider.of<TripProvider>(context, listen: false)
                            .setScreen(CustomTripType.choosePickupDropLocation);
                      },
                      child: InputTextFieldWidget(
                        enabled: false,
                        borderColor: Colors.transparent,
                        fillColor: MyColors.textFillThemeColor(),
                        controller: searchDestination,
                        obscureText: false,
                        hintText: translate("Whereto"),
                        preffix: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            MyImagesUrl.search,
                            color: Theme.of(context).hintColor,
                            width: 20,
                          ),
                        ),
                      ),
                    ),
                    vSizedBox2,
                    ValueListenableBuilder(
                      valueListenable: lastSearchSuggestion,
                      builder: (context, lastSearch, child) => lastSearch
                              .isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ParagraphText(
                                  "Recent Search",
                                  fontSize: 15,
                                  color:
                                      MyColors.blackThemeColorWithOpacity(0.5),
                                  fontWeight: FontWeight.w400,
                                ),
                                vSizedBox,
                              ],
                            )
                          : Container(),
                    ),
                    ValueListenableBuilder(
                        valueListenable: lastSearchSuggestion,
                        builder: (context, lastSearch, child) => lastSearch
                                .isEmpty
                            ? InkWell(
                                onTap: () {
                                  Provider.of<TripProvider>(context,
                                          listen: false)
                                      .setScreen(CustomTripType
                                          .choosePickupDropLocation);
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor:
                                              MyColors.colorD9D9D9Theme(),
                                          child: Image.asset(
                                            MyImagesUrl.myLocation,
                                            width: 23,
                                            color: MyColors.blackThemeColor(),
                                          ),
                                        ),
                                        hSizedBox,
                                        SubHeadingText(
                                          translate('SetyourDestination'),
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                        )
                                      ],
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 19,
                                      color:
                                          MyColors.blackThemeColorWithOpacity(
                                              0.4),
                                    )
                                  ],
                                ),
                              )
                            : SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: lastSearch.length,
                                  itemBuilder: (context, index) => Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.all(8),
                                    width:
                                        MediaQuery.of(context).size.width / 1.6,
                                    decoration: BoxDecoration(
                                        color: MyColors.textFillThemeColor(),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Row(
                                      children: [
                                        Column(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 15,
                                              color: MyColors.blackThemeColor(),
                                            ),
                                            Expanded(
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 4),
                                                width: 3,
                                                color:
                                                    MyColors.blackThemeColor(),
                                              ),
                                            ),
                                            Icon(
                                              Icons.square,
                                              size: 15,
                                              color: MyColors.blackThemeColor(),
                                            ),
                                          ],
                                        ),
                                        hSizedBox,
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              ParagraphText(
                                                lastSearch[index]['pickup']
                                                    ['address'],
                                                fontSize: 13,
                                                color: MyColors
                                                    .blackThemeColorWithOpacity(
                                                        0.5),
                                                fontWeight: FontWeight.w400,
                                              ),
                                              vSizedBox,
                                              ParagraphText(
                                                lastSearch[index]['drop']
                                                    ['address'],
                                                fontSize: 12,
                                                color: MyColors
                                                    .blackThemeColorWithOpacity(
                                                        0.5),
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              )),
                    vSizedBox3,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
