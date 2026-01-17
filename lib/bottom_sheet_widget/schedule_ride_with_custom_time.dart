import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/navigation_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

class SceduleRideWithCustomeTime extends StatefulWidget {
  const SceduleRideWithCustomeTime({super.key});

  @override
  State<SceduleRideWithCustomeTime> createState() =>
      _SceduleRideWithCustomeTimeState();
}

class _SceduleRideWithCustomeTimeState
    extends State<SceduleRideWithCustomeTime> {
  ValueNotifier<DateTime> selecteScheduleTime =
      ValueNotifier(DateTime.now().add(const Duration(hours: 1, minutes: 5)));
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Provider.of<DarkThemeProvider>(context).darkTheme 
            ? MyColors.blackColor 
            : MyColors.whiteColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: globalHorizontalPadding, vertical: 10),
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
            vSizedBox,
            vSizedBox,
            if (sheetValue)
              ValueListenableBuilder(
                valueListenable: selectedLanguageNotifier,
                builder: (context, selectedLanguage, child) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: SubHeadingText(
                        translate("Reserver a trip"),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: selecteScheduleTime,
                      builder: (context, scheduletime, child) => Center(
                        child: SubHeadingText(
                          DateFormat("HH:mm").format(scheduletime),
                          textAlign: TextAlign.center,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: selecteScheduleTime,
                      builder: (context, scheduletime, child) => Center(
                        child: SubHeadingText(
                          DateFormat(
                                  "EEE, d MMM",
                                  selectedLanguage['key'] == 'mg'
                                      ? 'fr_MG'
                                      : selectedLanguage['key'])
                              .format(scheduletime),
                          textAlign: TextAlign.center,
                          fontWeight: FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    vSizedBox,
                    SizedBox(
                        height: 200,
                        child: CupertinoDatePicker(
                          initialDateTime: DateTime.now()
                              .add(const Duration(hours: 1, minutes: 5)),
                          maximumDate:
                              DateTime.now().add(const Duration(days: 30)),
                          minimumDate: DateTime.now(),
                          mode: CupertinoDatePickerMode.dateAndTime,
                          use24hFormat: true,
                          // This is called when the user changes the dateTime.
                          onDateTimeChanged: (DateTime newDateTime) {
                            selecteScheduleTime.value = newDateTime;
                          },
                        )),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 40,
                        ),
                        hSizedBox,
                        Expanded(
                          child: ParagraphText(translate(
                              "Choose your exact pickup time up to 30 days in advance")),
                        ),
                      ],
                    ),
                    vSizedBox,
                    SafeArea(
                      child: RoundEdgedButton(
                        text: translate("next"),
                        verticalMargin: 18,
                        width: double.infinity,
                        onTap: () {
                          if (selecteScheduleTime.value
                              .isBefore(DateTime.now())) {
                            showSnackbar(translate(
                                "Please select a scheduled time that is at least 1 hours from the current time."));
                          } else if (selecteScheduleTime.value.isBefore(
                              DateTime.now().add(const Duration(hours: 1)))) {
                            showSnackbar(translate(
                                "Please select a scheduled time that is at least 1 hours from the current time."));
                          } else {
                            var schedule =
                                Provider.of<TripProvider>(context, listen: false);
                            schedule.rideScheduledTime =
                                selecteScheduleTime.value;
                            schedule.setScreen(
                                CustomTripType.choosePickupDropLocation);
                          }
                        },
                      ),
                    )
                  ],
                ),
              )
          ],
        ),
        ),
      ),
    );
  }
}
