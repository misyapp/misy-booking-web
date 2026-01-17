// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/payment_mobile_number_confirmation.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/pickup_and_drop_location_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/request_for_ride.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/schedule_ride_with_custom_time.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/select_available_promocode.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/summary.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/contants/static_json.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/promocodes_provider.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_gesture_detector.dart';
import 'package:rider_ride_hailing_app/widget/custom_pagination_grid_view.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import '../../bottom_sheet_widget/confirm_destination.dart';
import '../../bottom_sheet_widget/choose_vehicle_sheet.dart';
import '../../bottom_sheet_widget/drive_on_way.dart';
import '../../bottom_sheet_widget/select_payment_method_sheet.dart';
import '../../contants/global_data.dart';
import '../../contants/my_colors.dart';
import '../../contants/my_image_url.dart';
import '../../modal/lat_log_modal.dart';
import '../../provider/trip_provider.dart';
import '../../widget/custom_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

// import 'package:badges/badges.dart' as badges;
class HomeScreen extends StatefulWidget {
  const HomeScreen({required Key key}) : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _key = GlobalKey();
  final GlobalKey bottomSheetKey = GlobalKey();
  late GoogleMapController googleMapController;
  ValueNotifier<LatLngModal> currentLatLngNotifier =
      ValueNotifier(LatLngModal(lat: 22.699540, lng: 75.879750));
  PaymentMethodType? selectedPaymentMethod;
  bool loaded = false;
  Stream<QuerySnapshot>? usersStream; // to listen all nearby drviers
  List<DriverModal> allDrivers = [];
  // CustomInfoWindowController customInfoWindowController =
  //     CustomInfoWindowController();
  CameraPosition? cameraLastPosition;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      Provider.of<SavedPaymentMethodProvider>(context, listen: false)
          .getMySavedPaymentMethod();
      Provider.of<PromocodesProvider>(context, listen: false).getPromoCodes();
      getLocation();
      // listenNotification();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  didChangePlatformBrightness() async {
    int settingValue = await DevFestPreferences().getDarkModeSetting();
    if (settingValue == 3) {
      final themeChange =
          Provider.of<DarkThemeProvider>(context, listen: false);
      final mapProvider =
          Provider.of<GoogleMapProvider>(context, listen: false);
      DevFestPreferences().setDarkModeSetting(3);
      Brightness platformBrightness = MediaQuery.of(context).platformBrightness;
      if (platformBrightness == Brightness.light) {
        myCustomPrintStatement("Platform britness change $platformBrightness");
        themeChange.darkTheme = true;
      } else {
        themeChange.darkTheme = false;
        myCustomPrintStatement("Platform britness change $platformBrightness");
      }
      mapProvider.setMapStyle(context);
    }
  }

  updateBottomSheetHeight({int milliseconds = 20}) {
    Future.delayed(Duration(milliseconds: milliseconds)).then((value) {
      final RenderBox? renderBox =
          bottomSheetKey.currentContext!.findRenderObject() as RenderBox?;
      bottomSheetHeightNotifier.value =
          renderBox == null ? 0 : renderBox.size.height;
      myCustomPrintStatement(
          'Bottom sheet height: ${bottomSheetHeightNotifier.value}');
    });
  }

  ValueNotifier<double> bottomSheetHeightNotifier = ValueNotifier(20);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // customInfoWindowController.dispose();
    super.dispose();
  }

  getLocation() async {
    var tripProvider = Provider.of<TripProvider>(context, listen: false);
    if (positionStream == null) {
      startLocationListner(() async {
        if (loaded == false) {
          loaded = true;
        }
        tripProvider.locationChange();
      });
    }
  }

  listenNotification() {
    FirestoreServices.notifications
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((event) {
      unreadCount.value = event.docs.length;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && locationPopUpOpend) {
      updateBottomSheetHeight();
      var m1;
      if (Platform.isAndroid) {
        m1 = await Permission.locationWhenInUse.status;
      } else {
        m1 = await Permission.locationWhenInUse.request();
      }
      if (Platform.isAndroid &&
          (m1 == PermissionStatus.denied) &&
          locationPopUpOpend) {
        showPermissionNeedPopup();
      } else if (Platform.isIOS &&
          (m1 == PermissionStatus.denied ||
              m1 == PermissionStatus.permanentlyDenied) &&
          locationPopUpOpend) {
        ask();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(builder: (context, tripProvider, child) {
      myCustomLogStatements(
          "default screeen is this ${tripProvider.currentStep}");
      // tripProvider.setPaymentConfirmMobileNumber(PaymentMethodType.telmaMvola);
      // tripProvider.setScreen(CustomTripType.paymentMobileConfirm);
      return WillPopScope(
        onWillPop: () async {
          if (tripProvider.currentStep != null &&
              tripProvider.currentStep != CustomTripType.setYourDestination) {
            if (dropLocationPickerHideNoti.value) {
              dropLocationPickerHideNoti.value = false;
            } else if (pickupLocationPickerHideNoti.value) {
              if (MyGlobalKeys.chooseDropAndPickAddPageKey.currentState!
                      .showConfirmPopUp.value ==
                  true) {
                MyGlobalKeys.chooseDropAndPickAddPageKey.currentState!
                    .showConfirmPopUp.value = false;
                await Provider.of<GoogleMapProvider>(context, listen: false)
                    .controller
                    .animateCamera(CameraUpdate.zoomTo(13.80));
              }
              pickupLocationPickerHideNoti.value = false;
            } else if (tripProvider.currentStep ==
                    CustomTripType.selectScheduleTime &&
                tripProvider.booking == null) {
              tripProvider.setScreen(CustomTripType.setYourDestination);
            } else if (tripProvider.currentStep ==
                    CustomTripType.choosePickupDropLocation &&
                tripProvider.booking == null) {
              tripProvider.setScreen(CustomTripType.setYourDestination);
            } else if (tripProvider.currentStep ==
                    CustomTripType.chooseVehicle &&
                tripProvider.booking == null) {
              tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
              GoogleMapProvider mapInstan =
                  Provider.of<GoogleMapProvider>(context, listen: false);
              mapInstan.polylineCoordinates.clear();
              mapInstan.markers.removeWhere((key, value) => key == "pickup");
              mapInstan.markers.removeWhere((key, value) => key == "drop");

              mapInstan.controller.animateCamera(CameraUpdate.newCameraPosition(
                CameraPosition(
                    target: LatLng(
                        currentPosition!.latitude, currentPosition!.longitude),
                    zoom: 13.80,
                    bearing: 0,
                    tilt: 0),
              ));

              mapInstan.notifyListeners();
            } else if (tripProvider.currentStep == CustomTripType.payment &&
                tripProvider.booking == null) {
              tripProvider.setScreen(CustomTripType.chooseVehicle);
            } else if (tripProvider.currentStep ==
                    CustomTripType.selectAvailablePromocode &&
                tripProvider.booking == null) {
              tripProvider.selectedPromoCode = null;
              tripProvider.setScreen(CustomTripType.chooseVehicle);
            } else if (tripProvider.currentStep ==
                    CustomTripType.confirmDestination &&
                tripProvider.booking == null) {
              tripProvider.setScreen(CustomTripType.payment);
            } else if (tripProvider.currentStep ==
                    CustomTripType.requestForRide &&
                tripProvider.booking == null) {
              tripProvider.setScreen(CustomTripType.confirmDestination);
            } else if (tripProvider.currentStep ==
                    CustomTripType.paymentMobileConfirm &&
                tripProvider.booking != null) {
              tripProvider.setScreen(CustomTripType.driverOnWay);
            }
            updateBottomSheetHeight();

            return false;
          } else {
            if (showHomePageMenuNoti.value) {
              return true;
            } else {
              showHomePageMenuNoti.value = true;
              return false;
            }
          }
        },
        child: Consumer<DarkThemeProvider>(
          builder: (BuildContext context, value, child) => Scaffold(
            key: _key,
            drawer: const CustomDrawer(),
            drawerEnableOpenDragGesture: false,
            bottomSheet: tripProvider.currentStep == null
                ? null
                : BottomSheet(
                    key: bottomSheetKey,
                    enableDrag: false,
                    backgroundColor: MyColors.whiteThemeColor(),
                    onClosing: () {},
                    shape: CustomDrawerShape(),
                    builder: (context) {
                      return Container(
                        decoration: BoxDecoration(
                            color: MyColors.whiteThemeColor(),
                            boxShadow: [
                              BoxShadow(
                                color: MyColors.blackThemeColorWithOpacity(0.2),
                                blurRadius: 1,
                                spreadRadius: 1,
                                offset: const Offset(0, 0),
                              ),
                            ]),
                        child: SafeArea(
                          child: tripProvider.currentStep ==
                                  CustomTripType.selectScheduleTime
                              ? const SceduleRideWithCustomeTime()
                              : tripProvider.currentStep ==
                                      CustomTripType.choosePickupDropLocation
                                  ? PickupAndDropLocation(
                                      key: MyGlobalKeys
                                          .chooseDropAndPickAddPageKey,
                                      onTap: (pickup, drop) async {
                                        showLoading();
                                        tripProvider.pickLocation = pickup;
                                        tripProvider.dropLocation = drop;

                                        await tripProvider.createPath(
                                            topPaddingPercentage: 0.8);
                                        // Provider.of<BookingProvider>(context, listen: false).setPickupDropLocation(pickup,drop);
                                        tripProvider.setScreen(
                                            CustomTripType.chooseVehicle);
                                        updateBottomSheetHeight();
                                      },
                                    )
                                  : tripProvider.currentStep ==
                                          CustomTripType.chooseVehicle
                                      ? ChooseVehicle(
                                          pickLocation:
                                              tripProvider.pickLocation!,
                                          drpLocation:
                                              tripProvider.dropLocation!,
                                          onTap: (sVehicle) {
                                            tripProvider.selectedVehicle =
                                                sVehicle;
                                            tripProvider.setScreen(
                                                CustomTripType.payment);
                                            updateBottomSheetHeight();
                                          },
                                        )
                                      : tripProvider.currentStep ==
                                              CustomTripType
                                                  .paymentMobileConfirm
                                          ? const PaymentMobileNumberConfirmation()
                                          : tripProvider.currentStep ==
                                                  CustomTripType
                                                      .selectAvailablePromocode
                                              ? SelectAvailablePromocode(
                                                  onSelect: (selectedValue) {
                                                    tripProvider
                                                            .selectedPromoCode =
                                                        selectedValue;
                                                    tripProvider.setScreen(
                                                        CustomTripType.payment);
                                                    updateBottomSheetHeight();
                                                  },
                                                )
                                              : tripProvider.currentStep ==
                                                      CustomTripType.payment
                                                  ? SelectPaymentMethod(
                                                      onTap: (payMethod) {
                                                        selectedPaymentMethod =
                                                            payMethod;
                                                        tripProvider.setScreen(
                                                            CustomTripType
                                                                .confirmDestination);
                                                        updateBottomSheetHeight();
                                                      },
                                                    )
                                                  : tripProvider.currentStep ==
                                                          CustomTripType
                                                              .confirmDestination
                                                      ? ConfirmDestination(
                                                          paymentMethod:
                                                              selectedPaymentMethod!,
                                                        )
                                                      : tripProvider.currentStep ==
                                                              CustomTripType
                                                                  .requestForRide
                                                          ? const RequestForRide()
                                                          : tripProvider.booking != null &&
                                                                  tripProvider
                                                                          .acceptedDriver !=
                                                                      null &&
                                                                  tripProvider.booking!['status'] ==
                                                                      BookingStatusType
                                                                          .RIDE_COMPLETE
                                                                          .value &&
                                                                  (tripProvider.booking!['paymentMethod']
                                                                              .toString()
                                                                              .toLowerCase() !=
                                                                          "cash" ||
                                                                      (tripProvider.booking!['paymentMethod'].toString().toLowerCase() ==
                                                                              "cash" &&
                                                                          tripProvider.booking!['cancelledByUserId'] ==
                                                                              userData
                                                                                  .value!.id))
                                                              ? SummaryPage(
                                                                  booking:
                                                                      tripProvider
                                                                          .booking!,
                                                                  driver: tripProvider
                                                                      .acceptedDriver!,
                                                                )
                                                              : tripProvider.currentStep ==
                                                                      CustomTripType
                                                                          .driverOnWay
                                                                  ? DriverOnWay(
                                                                      booking:
                                                                          tripProvider
                                                                              .booking!,
                                                                      driver: tripProvider
                                                                          .acceptedDriver,
                                                                      selectedVehicle:
                                                                          tripProvider
                                                                              .selectedVehicle,
                                                                      onCancelTap:
                                                                          (reason) {
                                                                        tripProvider.cancelRide(
                                                                            reason:
                                                                                reason,
                                                                            cancelAnotherRide:
                                                                                tripProvider.booking!);
                                                                        updateBottomSheetHeight();
                                                                      },
                                                                    )
                                                                  : Container(
                                                                      height: 1,
                                                                    ),
                        ),
                      );
                    },
                  ),
            resizeToAvoidBottomInset: true,
            floatingActionButton: ValueListenableBuilder(
              valueListenable: showHomePageMenuNoti,
              builder: (context, showMenu, child) =>
                  Consumer<GoogleMapProvider>(
                builder: (context, provider, child) => provider
                                .initialPosition ==
                            null ||
                        (tripProvider.currentStep ==
                                CustomTripType.setYourDestination &&
                            showMenu)
                    ? Container(
                        height: 1,
                      )
                    : Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        child: InkWell(
                          onTap: () async {
                            provider.controller
                                .animateCamera(CameraUpdate.newCameraPosition(
                              CameraPosition(
                                  target: LatLng(currentPosition!.latitude,
                                      currentPosition!.longitude),
                                  zoom: 13.80,
                                  bearing: 0,
                                  tilt: 0),
                            ));
                          },
                          child: Container(
                            height: 35,
                            width: 35,
                            padding: const EdgeInsets.all(0),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                color: MyColors.whiteThemeColor(),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          MyColors.blackThemeColorWithOpacity(
                                              0.2),
                                      blurRadius: 1,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 0))
                                ]),
                            child: Image.asset(
                              MyImagesUrl.myLocation,
                              width: 25,
                              height: 25,
                              color: MyColors.blackThemeColor(),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            body: Consumer<GoogleMapProvider>(
                builder: (context, provider, child) {
              return ValueListenableBuilder(
                  valueListenable: bottomSheetHeightNotifier,
                  builder: (context, bottomSheetHeight, child) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: bottomSheetHeight,
                        // bottom: bottomSheetKey.currentContext!.size.height
                      ),
                      child: provider.initialPosition == null
                          ? Center(
                              child: LoadingAnimationWidget.twistingDots(
                                leftDotColor: MyColors.coralPink,
                                rightDotColor: MyColors.horizonBlue,
                                size: 30.0,
                              ),
                            )
                          : Stack(
                              children: [
                                GoogleMap(
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: false,
                                  compassEnabled: false,
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,

                                  initialCameraPosition: CameraPosition(
                                      target: provider.initialPosition!,
                                      zoom: 13.80,
                                      bearing: 0,
                                      tilt: 0.0),
                                  markers: provider.markers.values
                                      .toList()
                                      .reversed
                                      .toSet(), //(_markers.values.toList().length>0)?_markers.values.toSet():<Marker>{},
                                  polylines: provider.polyLines,
                                  onTap: (position) {
                                    // customInfoWindowController
                                    //     .hideInfoWindow!();
                                  },
                                  onCameraMove: (position) {
                                    // customInfoWindowController.onCameraMove!();
                                    cameraLastPosition = position;
                                  },
                                  onCameraIdle: () {
                                    if (cameraLastPosition != null &&
                                        dropLocationPickerHideNoti.value) {
                                      MyGlobalKeys.chooseDropAndPickAddPageKey
                                          .currentState!
                                          .pickedLocationLatLong(
                                        latitude:
                                            cameraLastPosition!.target.latitude,
                                        longitude: cameraLastPosition!
                                            .target.longitude,
                                      );
                                    }
                                    if (cameraLastPosition != null &&
                                        pickupLocationPickerHideNoti.value) {
                                      MyGlobalKeys.chooseDropAndPickAddPageKey
                                          .currentState!
                                          .pickUpLocationMapLatLong(
                                        latitude:
                                            cameraLastPosition!.target.latitude,
                                        longitude: cameraLastPosition!
                                            .target.longitude,
                                      );
                                    }
                                  },
                                  // cameraTargetBounds:
                                  //     CameraTargetBounds(getLatLongBounds([
                                  //   [22.7004337, 75.8758717],
                                  //   [23.2599333, 77.412615],
                                  // ])),
                                  onMapCreated:
                                      (GoogleMapController controller) async {
                                    updateBottomSheetHeight(milliseconds: 1000);
                                    // customInfoWindowController
                                    //     .googleMapController = controller;
                                    provider.setController(controller);
                                    provider.setMapStyle(context);
                                    provider.addPolyline(Polyline(
                                      polylineId: const PolylineId('path'),
                                      color:
                                          MyColors.blackThemewithC3C3C3Color(),
                                      width: 5,
                                      geodesic: true,
                                      visible: provider.visiblePolyline,
                                      points: provider.polylineCoordinates,
                                    ));
                                    provider.addPolyline(
                                      Polyline(
                                        polylineId: const PolylineId('path1'),
                                        color: MyColors.primaryColor,
                                        width: 5,
                                        geodesic: true,
                                        visible:
                                            provider.visibleCoveredPolyline,
                                        points:
                                            provider.coveredPolylineCoordinates,
                                      ),
                                    );
                                    var bookingProvider =
                                        Provider.of<TripProvider>(context,
                                            listen: false);
                                    await bookingProvider.setBookingStream();
                                    setUserStream();
                                  },
                                ),
                                if (tripProvider.currentStep ==
                                    CustomTripType.setYourDestination)
                                  scheduleAndOtherInformation(),
                                ValueListenableBuilder(
                                  valueListenable: dropLocationPickerHideNoti,
                                  builder: (context, hidePicker, child) =>
                                      hidePicker == false
                                          ? Container()
                                          : Center(
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 30),
                                                child: Image.asset(
                                                  MyImagesUrl
                                                      .locationSelectFromMap(),
                                                  height: 40,
                                                  width: 40,
                                                ),
                                              ),
                                            ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: pickupLocationPickerHideNoti,
                                  builder: (context, hidePicker, child) =>
                                      hidePicker == false
                                          ? Container()
                                          : Center(
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 30),
                                                child: Image.asset(
                                                  MyImagesUrl
                                                      .locationSelectFromMap(),
                                                  height: 40,
                                                  width: 40,
                                                ),
                                              ),
                                            ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: dropLocationPickerHideNoti,
                                  builder: (context, hideDropPicker, child) =>
                                      ValueListenableBuilder(
                                    valueListenable:
                                        pickupLocationPickerHideNoti,
                                    builder:
                                        (context, hidePickupPicker, child) =>
                                            Positioned(
                                      top: tripProvider.currentStep ==
                                              CustomTripType.chooseVehicle
                                          ? 15
                                          : 10,
                                      left: 18,
                                      right: 18,
                                      child: SafeArea(
                                        child:
                                            tripProvider.currentStep ==
                                                    CustomTripType.chooseVehicle
                                                ? Container(
                                                    height: 55,
                                                    decoration: BoxDecoration(
                                                        boxShadow: [
                                                          BoxShadow(
                                                              color: MyColors
                                                                  .blackThemeColorWithOpacity(
                                                                      0.3),
                                                              blurRadius: 2,
                                                              spreadRadius: 1,
                                                              offset:
                                                                  const Offset(
                                                                      0, 0))
                                                        ],
                                                        color: MyColors
                                                            .whiteThemeColor(),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6)),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () {
                                                            tripProvider.setScreen(
                                                                CustomTripType
                                                                    .choosePickupDropLocation);

                                                            provider.polyLines
                                                                .clear();
                                                            // provider.controlle

                                                            provider.markers
                                                                .removeWhere(
                                                                    (key, value) =>
                                                                        key ==
                                                                        "drop");
                                                            provider.markers
                                                                .removeWhere((key,
                                                                        value) =>
                                                                    key ==
                                                                    "pickup");
                                                            provider.controller
                                                                .animateCamera(
                                                                    CameraUpdate
                                                                        .newCameraPosition(
                                                              CameraPosition(
                                                                  target: LatLng(
                                                                      currentPosition!
                                                                          .latitude,
                                                                      currentPosition!
                                                                          .longitude),
                                                                  zoom: 13.80,
                                                                  bearing: 0,
                                                                  tilt: 0),
                                                            ));
                                                            myCustomPrintStatement(
                                                                "my coverd path is ${provider.coveredPolylineCoordinates} ${provider.polylineCoordinates}");
                                                            provider
                                                                .notifyListeners();
                                                          },
                                                          child: const SizedBox(
                                                            width: 40,
                                                            child: Icon(
                                                              Icons
                                                                  .keyboard_backspace,
                                                              size: 30,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Container(
                                                            height: 40,
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                              right: 10,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: MyColors
                                                                  .textFillThemeColor(),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                hSizedBox05,
                                                                Icon(
                                                                  Icons.search,
                                                                  color: Theme.of(
                                                                          context)
                                                                      .hintColor,
                                                                ),
                                                                hSizedBox05,
                                                                Expanded(
                                                                  child:
                                                                      ParagraphText(
                                                                    tripProvider
                                                                            .dropLocation![
                                                                        'address'],
                                                                    color: Theme.of(
                                                                            context)
                                                                        .hintColor,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .start,
                                                                    maxLines: 1,
                                                                    textOverflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : ValueListenableBuilder(
                                                    valueListenable:
                                                        showHomePageMenuNoti,
                                                    builder: (context, showMenu,
                                                            child) =>
                                                        Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        (Platform.isAndroid ||
                                                                tripProvider
                                                                        .currentStep ==
                                                                    null ||
                                                                tripProvider
                                                                        .currentStep ==
                                                                    CustomTripType
                                                                        .setYourDestination ||
                                                                (!hideDropPicker &&
                                                                    !hidePickupPicker &&
                                                                    tripProvider
                                                                            .currentStep ==
                                                                        CustomTripType
                                                                            .setYourDestination) ||
                                                                tripProvider
                                                                        .currentStep ==
                                                                    CustomTripType
                                                                        .driverOnWay)
                                                            ? tripProvider.currentStep ==
                                                                        CustomTripType
                                                                            .setYourDestination &&
                                                                    !showMenu
                                                                ? InkWell(
                                                                    onTap:
                                                                        () async {
                                                                      showHomePageMenuNoti
                                                                              .value =
                                                                          true;
                                                                      // Provider.of<TripProvider>(context, listen: false)
                                                                      //     .setScreen(CustomTripType.newRequest);
                                                                    },
                                                                    child:
                                                                        Container(
                                                                      height:
                                                                          45,
                                                                      width: 45,
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      margin: EdgeInsets
                                                                          .zero,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        boxShadow: [
                                                                          BoxShadow(
                                                                              color: MyColors.blackThemeColorWithOpacity(0.2),
                                                                              blurRadius: 1,
                                                                              spreadRadius: 1,
                                                                              offset: const Offset(0, 0))
                                                                        ],
                                                                        borderRadius:
                                                                            BorderRadius.circular(25),
                                                                        color: MyColors
                                                                            .whiteThemeColor(),
                                                                        border: Border.all(
                                                                            color:
                                                                                MyColors.whiteThemeColor(),
                                                                            width: 5),
                                                                      ),
                                                                      child:
                                                                          Icon(
                                                                        Icons
                                                                            .arrow_back,
                                                                        color: MyColors
                                                                            .blackThemeColor(),
                                                                      ),
                                                                    ),
                                                                  )
                                                                : Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      InkWell(
                                                                        onTap:
                                                                            () async {
                                                                          _key.currentState!
                                                                              .openDrawer();
                                                                          // Provider.of<TripProvider>(context, listen: false)
                                                                          //     .setScreen(CustomTripType.newRequest);
                                                                        },
                                                                        child:
                                                                            Container(
                                                                          height:
                                                                              45,
                                                                          width:
                                                                              45,
                                                                          padding:
                                                                              EdgeInsets.zero,
                                                                          margin:
                                                                              EdgeInsets.zero,
                                                                          decoration: BoxDecoration(
                                                                              borderRadius: BorderRadius.circular(25),
                                                                              border: Border.all(color: tripProvider.currentStep == CustomTripType.setYourDestination ? MyColors.whiteColor : MyColors.whiteThemeColor(), width: 5),
                                                                              color: tripProvider.currentStep == CustomTripType.setYourDestination ? MyColors.whiteColor : MyColors.blackThemeColorOnlyBlackOpacity(),
                                                                              boxShadow: [
                                                                                BoxShadow(color: MyColors.blackThemeColorWithOpacity(0.2), blurRadius: 0.5, spreadRadius: 1, offset: const Offset(0, 0))
                                                                              ]),
                                                                          child:
                                                                              Image.asset(
                                                                            tripProvider.currentStep == CustomTripType.setYourDestination
                                                                                ? MyImagesUrl.newMenu
                                                                                : MyImagesUrl.menu,
                                                                            width:
                                                                                50,
                                                                            color: tripProvider.currentStep == CustomTripType.setYourDestination
                                                                                ? null
                                                                                : MyColors.blackThemeColor(),
                                                                            height:
                                                                                50,
                                                                            fit:
                                                                                BoxFit.fill,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  )
                                                            : InkWell(
                                                                onTap:
                                                                    () async {
                                                                  if (tripProvider
                                                                              .currentStep !=
                                                                          null &&
                                                                      tripProvider
                                                                              .currentStep !=
                                                                          CustomTripType
                                                                              .setYourDestination) {
                                                                    if (dropLocationPickerHideNoti
                                                                        .value) {
                                                                      if (MyGlobalKeys
                                                                              .chooseDropAndPickAddPageKey
                                                                              .currentState!
                                                                              .showConfirmPopUp
                                                                              .value ==
                                                                          true) {
                                                                        MyGlobalKeys
                                                                            .chooseDropAndPickAddPageKey
                                                                            .currentState!
                                                                            .showConfirmPopUp
                                                                            .value = false;
                                                                        await Provider.of<GoogleMapProvider>(context,
                                                                                listen: false)
                                                                            .controller
                                                                            .animateCamera(CameraUpdate.zoomTo(13.80));
                                                                      } else {
                                                                        dropLocationPickerHideNoti.value =
                                                                            false;
                                                                      }
                                                                    } else if (pickupLocationPickerHideNoti
                                                                        .value) {
                                                                      if (MyGlobalKeys
                                                                              .chooseDropAndPickAddPageKey
                                                                              .currentState!
                                                                              .showConfirmPopUp
                                                                              .value ==
                                                                          true) {
                                                                        MyGlobalKeys
                                                                            .chooseDropAndPickAddPageKey
                                                                            .currentState!
                                                                            .showConfirmPopUp
                                                                            .value = false;
                                                                        await Provider.of<GoogleMapProvider>(context,
                                                                                listen: false)
                                                                            .controller
                                                                            .animateCamera(CameraUpdate.zoomTo(13.80));
                                                                      } else {
                                                                        pickupLocationPickerHideNoti.value =
                                                                            false;
                                                                      }
                                                                    } else if (tripProvider.currentStep ==
                                                                            CustomTripType
                                                                                .selectScheduleTime &&
                                                                        tripProvider.booking ==
                                                                            null) {
                                                                      tripProvider
                                                                          .setScreen(
                                                                              CustomTripType.setYourDestination);
                                                                    
                                                                    } else if (tripProvider.currentStep ==
                                                                            CustomTripType
                                                                                .selectAvailablePromocode &&
                                                                        tripProvider.booking ==
                                                                            null) {
                                                                      tripProvider
                                                                          .setScreen(
                                                                              CustomTripType.chooseVehicle);
                                                                    
                                                                    } else if (tripProvider.currentStep ==
                                                                            CustomTripType
                                                                                .choosePickupDropLocation &&
                                                                        tripProvider.booking ==
                                                                            null) {
                                                                      tripProvider
                                                                          .setScreen(
                                                                              CustomTripType.setYourDestination);
                                                                    } else if (tripProvider.currentStep ==
                                                                            CustomTripType
                                                                                .chooseVehicle &&
                                                                        tripProvider.booking ==
                                                                            null) {
                                                                      tripProvider
                                                                          .setScreen(
                                                                              CustomTripType.choosePickupDropLocation);
                                                                      GoogleMapProvider
                                                                          mapInstan =
                                                                          Provider.of<GoogleMapProvider>(
                                                                              context,
                                                                              listen: false);
                                                                      mapInstan
                                                                          .polyLines
                                                                          .clear();
                                                                      mapInstan.markers.removeWhere((key,
                                                                              value) =>
                                                                          key ==
                                                                          "pickup");
                                                                      mapInstan.markers.removeWhere((key,
                                                                              value) =>
                                                                          key ==
                                                                          "drop");

                                                                      mapInstan
                                                                          .notifyListeners();
                                                                    } else if (tripProvider.currentStep ==
                                                                            CustomTripType
                                                                                .payment &&
                                                                        tripProvider.booking ==
                                                                            null) {
                                                                      tripProvider
                                                                          .setScreen(
                                                                              CustomTripType.chooseVehicle);
                                                                    } else if (tripProvider.currentStep ==
                                                                            CustomTripType
                                                                                .confirmDestination &&
                                                                        tripProvider.booking ==
                                                                            null) {
                                                                      tripProvider
                                                                          .setScreen(
                                                                              CustomTripType.payment);
                                                                    } else if (tripProvider.currentStep ==
                                                                            CustomTripType
                                                                                .requestForRide &&
                                                                        tripProvider.booking ==
                                                                            null) {
                                                                      tripProvider
                                                                          .setScreen(
                                                                              CustomTripType.confirmDestination);
                                                                    } else if (tripProvider.currentStep ==
                                                                            CustomTripType
                                                                                .paymentMobileConfirm &&
                                                                        tripProvider.booking !=
                                                                            null) {
                                                                      tripProvider
                                                                          .setScreen(
                                                                              CustomTripType.driverOnWay);
                                                                    }
                                                                    updateBottomSheetHeight(
                                                                        milliseconds:
                                                                            500);
                                                                  }
                                                                },
                                                                child:
                                                                    Container(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  height: 45,
                                                                  width: 45,
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  margin:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  decoration: BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              25),
                                                                      border: Border.all(
                                                                          color: MyColors
                                                                              .whiteThemeColor(),
                                                                          width:
                                                                              5),
                                                                      color: MyColors
                                                                          .blackThemeColorOnlyBlackOpacity(),
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                            color: MyColors.blackThemeColorWithOpacity(
                                                                                0.2),
                                                                            blurRadius:
                                                                                1,
                                                                            spreadRadius:
                                                                                1,
                                                                            offset:
                                                                                const Offset(0, 0))
                                                                      ]),
                                                                  child: Icon(
                                                                    Icons
                                                                        .arrow_back_ios_new,
                                                                    color: MyColors
                                                                        .blackThemeColor(),
                                                                    size: 20,
                                                                  ),
                                                                ),
                                                              ),
                                                        if (tripProvider
                                                                    .booking !=
                                                                null &&
                                                            (tripProvider
                                                                        .booking![
                                                                    'status'] ==
                                                                BookingStatusType
                                                                    .ACCEPTED
                                                                    .value))
                                                          InkWell(
                                                            onTap: () {
                                                              tripProvider.updateStatusDriverReadchedToLocation();
                                                            },
                                                            child: Container(
                                                              height: 45,
                                                              width: 45,
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              margin: EdgeInsets
                                                                  .zero,
                                                              decoration: BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              25),
                                                                  color: MyColors
                                                                      .blackThemeColor(),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                        color: MyColors.blackThemeColorWithOpacity(
                                                                            0.2),
                                                                        blurRadius:
                                                                            0.5,
                                                                        spreadRadius:
                                                                            1,
                                                                        offset: const Offset(
                                                                            0,
                                                                            0))
                                                                  ]),
                                                              child:
                                                                  Image.asset(
                                                                MyImagesUrl
                                                                    .questionMarkIcon,
                                                                width: 40,
                                                                color: MyColors
                                                                    .whiteThemeColor(),
                                                                height: 40,
                                                                fit:
                                                                    BoxFit.fill,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (tripProvider.booking != null &&
                                    (tripProvider.booking!['status'] ==
                                            BookingStatusType.ACCEPTED.value ||
                                        tripProvider.booking!['status'] ==
                                            BookingStatusType
                                                .DRIVER_REACHED.value))
                                  Positioned(
                                      top: 120,
                                      left: 15,
                                      right: 15,
                                      child: Center(
                                          child: Container(
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            color: MyColors.whiteThemeColor()
                                                .withOpacity(0.9)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 15, vertical: 15),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 15),
                                        child: ParagraphText(
                                            translate(
                                                "For your safety and to ensure your fare is guaranteed, please decline any requests for rides outside of the app."),
                                            color: const Color(0xffad1328)),
                                      ))),

                                // Positioned(
                                //     top: 250,
                                //     left: 15,
                                //     right: 15,
                                //     child: RoundEdgedButton(
                                //       text: "Download Excel file",
                                //       onTap: () {
                                //         FirebaseBackupService
                                //             .backupCollectionToCSV("users");
                                //       },
                                //     )),

                                // Positioned(
                                //   top: 120,
                                //   left: 15,
                                //   right: 15,
                                //   child: SafeArea(
                                //     child: tripProvider.currentStep ==
                                //             CustomTripType.setYourDestination
                                //         ? Container(
                                //             height: 60,
                                //             padding: const EdgeInsets.symmetric(
                                //                 horizontal: 6),
                                //             decoration: BoxDecoration(
                                //                 borderRadius:
                                //                     BorderRadius.circular(10),
                                //                 color: tripProvider
                                //                             .currentStep ==
                                //                         CustomTripType
                                //                             .setYourDestination
                                //                     ? MyColors.colorLightGreye8e8e8
                                //                     : MyColors
                                //                         .whiteThemeColor(),
                                //                 boxShadow: [
                                //                   BoxShadow(
                                //                       color: MyColors
                                //                           .blackThemeColorWithOpacity(
                                //                               0.2),
                                //                       blurRadius: 1,
                                //                       spreadRadius: 1,
                                //                       offset:
                                //                           const Offset(0, 1))
                                //                 ]),
                                //             child: Row(
                                //               children: [
                                //                 Expanded(
                                //                   child: InkWell(
                                //                     onTap: () {
                                //                       Provider.of<TripProvider>(
                                //                               context,
                                //                               listen: false)
                                //                           .setScreen(CustomTripType
                                //                               .choosePickupDropLocation);
                                //                     },
                                //                     child: Row(
                                //                       children: [
                                //                         Padding(
                                //                           padding:
                                //                               const EdgeInsets
                                //                                   .all(10),
                                //                           child: Image.asset(
                                //                             MyImagesUrl.search,
                                //                             color: tripProvider
                                //                                         .currentStep ==
                                //                                     CustomTripType
                                //                                         .setYourDestination
                                //                                 ? MyColors
                                //                                     .blackColor
                                //                                 : Theme.of(
                                //                                         context)
                                //                                     .hintColor,
                                //                             width: 25,
                                //                           ),
                                //                         ),
                                //                         ParagraphText(
                                //                           translate("Whereto"),
                                //                           fontSize: 16,
                                //                           color: tripProvider
                                //                                       .currentStep ==
                                //                                   CustomTripType
                                //                                       .setYourDestination
                                //                               ? const Color(0xff4B4B4B)
                                //                               : Theme.of(
                                //                                       context)
                                //                                   .hintColor,
                                //                         ),
                                //                       ],
                                //                     ),
                                //                   ),
                                //                 ),
                                //                 if (globalSettings
                                //                     .enableScheduledBooking)
                                //                   InkWell(
                                //                     onTap: () {
                                //                       Provider.of<TripProvider>(
                                //                               context,
                                //                               listen: false)
                                //                           .setScreen(CustomTripType
                                //                               .selectScheduleTime);
                                //                     },
                                //                     child: Container(
                                //                       height: 45,
                                //                       padding: const EdgeInsets
                                //                           .symmetric(
                                //                           horizontal: 10),
                                //                       decoration: BoxDecoration(
                                //                           color: MyColors
                                //                               .scheduleButtonColor6E77C5,
                                //                           borderRadius:
                                //                               BorderRadius
                                //                                   .circular(8)),
                                //                       child: Column(
                                //                         mainAxisAlignment:
                                //                             MainAxisAlignment
                                //                                 .center,
                                //                         children: [
                                //                           ParagraphText(
                                //                             translate(
                                //                                 "Schedule"),
                                //                             color: MyColors
                                //                                 .whiteColor,
                                //                             fontSize: 8,
                                //                           ),
                                //                           Image.asset(
                                //                             MyImagesUrl
                                //                                 .calendarIcon,
                                //                             color: MyColors
                                //                                 .whiteColor,
                                //                             width: 24,
                                //                           ),
                                //                         ],
                                //                       ),
                                //                     ),
                                //                   ),
                                //               ],
                                //             ),
                                //           )
                                //         : Container(),
                                //   ),
                                // ),
                                // CustomInfoWindow(
                                //   controller: customInfoWindowController,
                                //   height: 40,
                                //   width: 120,
                                //   offset: 10,
                                // ),
                              ],
                            ),
                    );
                  });
            }),
          ),
        ),
      );
    });
  }

  void openAppStoreOrPlayStore() async {
    String url;

    if (Platform.isAndroid) {
      // Google Play Store URL for Android
      url =
          'https://play.google.com/store/apps/details?id=com.misy.driver&pcampaignid=web_share';
    } else if (Platform.isIOS) {
      // Apple App Store URL for iOS
      url = 'https://apps.apple.com/fr/app/misy-driver/id6504241997';
    } else {
      // Unsupported platform
      print('Unsupported platform');
      return;
    }

    // Launch the URL
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  scheduleAndOtherInformation() {
    if (!globalSettings.enableScheduledBooking) {
      homePageMenuList.removeWhere(
        (element) => element['id'] == 2,
      );
    }
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) => ValueListenableBuilder(
        valueListenable: showHomePageMenuNoti,
        builder: (context, showMenu, child) => !showMenu
            ? Positioned(
                top: 120,
                left: 15,
                right: 15,
                child: SafeArea(
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: MyColors.whiteThemeColor(),
                        boxShadow: [
                          BoxShadow(
                              color: MyColors.blackThemeColorWithOpacity(0.2),
                              blurRadius: 1,
                              spreadRadius: 1,
                              offset: const Offset(0, 1))
                        ]),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Provider.of<TripProvider>(context, listen: false)
                                  .setScreen(
                                      CustomTripType.choosePickupDropLocation);
                            },
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.asset(
                                    MyImagesUrl.search,
                                    color: Theme.of(context).hintColor,
                                    width: 25,
                                  ),
                                ),
                                ParagraphText(
                                  translate("Whereto"),
                                  fontSize: 16,
                                  color: Theme.of(context).hintColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (globalSettings.enableScheduledBooking)
                          InkWell(
                            onTap: () {
                              Provider.of<TripProvider>(context, listen: false)
                                  .setScreen(CustomTripType.selectScheduleTime);
                            },
                            child: Container(
                              height: 45,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                  color: MyColors.scheduleButtonColor6E77C5,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ParagraphText(
                                    translate("Schedule"),
                                    color: MyColors.whiteColor,
                                    fontSize: 8,
                                  ),
                                  Image.asset(
                                    MyImagesUrl.calendarIcon,
                                    color: MyColors.whiteColor,
                                    width: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            : Container(
                color: MyColors.whiteColor,
                height: double.infinity,
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.only(
                          top: MediaQuery.of(context).size.height * 0.08,
                        ),
                      ),
                      Image.asset(
                        MyImagesUrl.splashLogo,
                        height: 70,
                      ),
                      Container(
                        height: 60,
                        margin: EdgeInsets.only(
                            top: MediaQuery.of(context).size.height * 0.04,
                            left: globalHorizontalPadding,
                            right: globalHorizontalPadding),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: tripProvider.currentStep ==
                                    CustomTripType.setYourDestination
                                ? MyColors.colorLightGreye8e8e8
                                : MyColors.whiteThemeColor(),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      MyColors.blackThemeColorWithOpacity(0.2),
                                  blurRadius: 1,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 1))
                            ]),
                        child: Row(
                          children: [
                            Expanded(
                              child: CustomGestureDetector(
                                onTap: () {
                                  Provider.of<TripProvider>(context,
                                          listen: false)
                                      .setScreen(CustomTripType
                                          .choosePickupDropLocation);
                                },
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Image.asset(
                                        MyImagesUrl.search,
                                        color: tripProvider.currentStep ==
                                                CustomTripType
                                                    .setYourDestination
                                            ? MyColors.blackColor
                                            : Theme.of(context).hintColor,
                                        width: 25,
                                      ),
                                    ),
                                    ParagraphText(
                                      translate("Whereto"),
                                      fontSize: 16,
                                      color: tripProvider.currentStep ==
                                              CustomTripType.setYourDestination
                                          ? const Color(0xff4B4B4B)
                                          : Theme.of(context).hintColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // InkWell(
                            //   onTap: () {
                            //     Provider.of<TripProvider>(context, listen: false)
                            //         .setScreen(CustomTripType.selectScheduleTime);
                            //   },
                            //   child: Container(
                            //     height: 45,
                            //     padding:
                            //         const EdgeInsets.symmetric(horizontal: 10),
                            //     decoration: BoxDecoration(
                            //         color: MyColors.scheduleButtonColor6E77C5,
                            //         borderRadius: BorderRadius.circular(8)),
                            //     child: Column(
                            //       mainAxisAlignment: MainAxisAlignment.center,
                            //       children: [
                            //         ParagraphText(
                            //           translate("Schedule"),
                            //           color: MyColors.whiteColor,
                            //           fontSize: 8,
                            //         ),
                            //         Image.asset(
                            //           MyImagesUrl.calendarIcon,
                            //           color: MyColors.whiteColor,
                            //           width: 24,
                            //         ),
                            //       ],
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                      vSizedBox2,
                      CustomPaginatedGridView(
                        crossAxisSpacing: 8,
                        padding: const EdgeInsets.symmetric(
                            horizontal: globalHorizontalPadding),
                        itemBuilder: (p0, index) => CustomGestureDetector(
                          onTap: homePageMenuList[index]['onTap'],
                          ignoreInternetConnectivity: homePageMenuList[index]
                              ['ignoreInternetConnectivity'],
                          child: Container(
                            height: 115,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: tripProvider.currentStep ==
                                      CustomTripType.setYourDestination
                                  ? MyColors.colorLightGreye8e8e8
                                      .withOpacity(0.5)
                                  : MyColors.whiteThemeColor(),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                vSizedBox,
                                Image.asset(
                                  homePageMenuList[index]['image'],
                                  height: double.parse(homePageMenuList[index]
                                          ['imageHeight']
                                      .toString()),
                                  width: double.tryParse(homePageMenuList[index]
                                          ['imagewidth']
                                      .toString()),
                                ),
                                const Spacer(),
                                SubHeadingText(
                                  translate(homePageMenuList[index]['name']),
                                  fontSize: 14,
                                  color: MyColors.blackColor,
                                ),
                                vSizedBox
                              ],
                            ),
                          ),
                        ),
                        itemCount: homePageMenuList.length,
                      ),
                      vSizedBox2,
                      Container(
                        height: 120,
                        padding: EdgeInsetsDirectional.zero,
                        margin: const EdgeInsets.symmetric(
                            horizontal: globalHorizontalPadding),
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: MyColors.primaryColor,
                            borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                                child: Padding(
                              padding:
                                  const EdgeInsets.only(left: 8.0, top: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ParagraphText(
                                    translate(
                                        "Are you a ride-hailing driver, taxi driver, or motorcycle taxi driver? Download the Misy Driver app and earn money with Misy."),
                                    color: MyColors.whiteColor,
                                    fontSize: 11,
                                  ),
                                  vSizedBox,
                                  RoundEdgedButton(
                                    text: translate("Download now"),
                                    verticalPadding: 0,
                                    verticalMargin: 0,
                                    horizontlyPadding: 15,
                                    onTap: () {
                                      openAppStoreOrPlayStore();
                                    },
                                    height: 20,
                                    fontSize: 10,
                                    borderRadius: 4,
                                    color: MyColors.whiteColor,
                                    textColor: MyColors.primaryColor,
                                  ),
                                  vSizedBox,
                                ],
                              ),
                            )),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.asset(
                                  MyImagesUrl.drivingCarImage,
                                  height: 80,
                                ))
                          ],
                        ),
                      ),
                      vSizedBox4
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  setUserStream() async {
    usersStream = FirestoreServices.users
        .where('isCustomer', isEqualTo: false)
        .where('isOnline', isEqualTo: true)
        .snapshots();
    var bookingProvider = Provider.of<TripProvider>(context, listen: false);
    usersStream!.listen((event) async {
      allDrivers = [];
      List driver8NearMarker = [];

      for (int i = 0; i < event.docs.length; i++) {
        DriverModal m = DriverModal.fromJson(event.docs[i].data() as Map);

        if (bookingProvider.acceptedDriver == null) {
          if (m.currentLat != null && m.currentLng != null) {
            var distance = getDistance(
                m.currentLat!,
                m.currentLng!,
                applyDummyMadasagarPosition
                    ? -18.932972240415356
                    : currentPosition!.latitude,
                applyDummyMadasagarPosition
                    ? 47.47820354998112
                    : currentPosition!.longitude);

            if (distance <= globalSettings.distanceLimitNow ||
                distance <= globalSettings.distanceLimitScheduled) {
              driver8NearMarker.add({"distance": distance, "driverData": m});
              if (minVehicleDistance[m.vehicleType] == null) {
                minVehicleDistance[m.vehicleType!] = distance;
                nearestVehicleLatLng[m.vehicleType!] =
                    LatLng(m.currentLat!, m.currentLng!);
              } else {
                if (minVehicleDistance[m.vehicleType] > distance) {
                  minVehicleDistance[m.vehicleType!] = distance;
                  nearestVehicleLatLng[m.vehicleType!] =
                      LatLng(m.currentLat!, m.currentLng!);
                }
              }

              allDrivers.add(m);
            }
          } else {
            // m['distance'] = 1000;
          }
        } else {
          if (m.id == bookingProvider.acceptedDriver!.id) {
            var mapProvider =
                Provider.of<GoogleMapProvider>(context, listen: false);
            allDrivers = [];
            bookingProvider.acceptedDriver = m;
            allDrivers.add(m);

            mapProvider.createUpdateMarker(
              m.id,
              // LatLng(lat!,lng!),
              LatLng(m.currentLat!, m.currentLng!),
              url: vehicleMap[m.vehicleType!]!.marker,
              rotate: true,
              animateToCenter: (bookingProvider.booking != null &&
                      bookingProvider.booking!['acceptedBy'] == m.id)
                  ? bookingProvider.booking!['status'] > 1
                      ? false
                      : true
                  : false,
              onTap: () {},
            );

            bookingProvider.notifyListeners();
          }
        }
      }
      driver8NearMarker.sort(
        (a, b) => a['distance']!.compareTo(b['distance']!),
      );
      if (bookingProvider.acceptedDriver == null &&
          driver8NearMarker.isNotEmpty) {
        addOnly8NearDriverMarker(driver8NearMarker.sublist(
            0, driver8NearMarker.length > 7 ? 7 : driver8NearMarker.length));
      }
      removeOtherDriverMarkers();
    });
  }

  addOnly8NearDriverMarker(List driver8NearMarker) {
    var mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);

    for (var i = 0; i < driver8NearMarker.length; i++) {
      var bookingProvider = Provider.of<TripProvider>(context, listen: false);

      if (mapProvider.markers[driver8NearMarker[i]['driverData'].id] == null) {
        var url =
            vehicleMap[driver8NearMarker[i]['driverData'].vehicleType!]!.marker;
        mapProvider.createUpdateMarker(
          driver8NearMarker[i]['driverData'].id,
          // LatLng(lat!,lng!),
          LatLng(driver8NearMarker[i]['driverData'].currentLat!,
              driver8NearMarker[i]['driverData'].currentLng!),
          rotate: true,
          oldLocation: !driver8NearMarker[i]['driverData'].isOnline ||
                  (driver8NearMarker[i]['driverData'].currentLat ==
                          driver8NearMarker[i]['driverData'].oldLat &&
                      driver8NearMarker[i]['driverData'].currentLng ==
                          driver8NearMarker[i]['driverData'].oldLng)
              ? null
              : LatLng(driver8NearMarker[i]['driverData'].oldLat!,
                  driver8NearMarker[i]['driverData'].oldLng!),
          onTap: () {},
          url: url,
          animateToCenter: (bookingProvider.booking != null &&
                  bookingProvider.booking!['acceptedBy'] ==
                      driver8NearMarker[i]['driverData'].id)
              ? bookingProvider.booking!['status'] > 1
                  ? true
                  : false
              : false,
        );
      } else {
        mapProvider.createUpdateMarker(
          driver8NearMarker[i]['driverData'].id,
          // LatLng(lat!,lng!),

          LatLng(driver8NearMarker[i]['driverData'].currentLat!,
              driver8NearMarker[i]['driverData'].currentLng!),
          rotate: true,
          oldLocation: !driver8NearMarker[i]['driverData'].isOnline ||
                  (driver8NearMarker[i]['driverData'].currentLat ==
                          driver8NearMarker[i]['driverData'].oldLat &&
                      driver8NearMarker[i]['driverData'].currentLng ==
                          driver8NearMarker[i]['driverData'].oldLng)
              ? null
              : LatLng(driver8NearMarker[i]['driverData'].oldLat!,
                  driver8NearMarker[i]['driverData'].oldLng!),
          animateToCenter: (bookingProvider.booking != null &&
                  bookingProvider.booking!['acceptedBy'] ==
                      driver8NearMarker[i]['driverData'].id)
              ? bookingProvider.booking!['status'] > 1
                  ? true
                  : false
              : false,
          onTap: () {},
        );
      }
    }
  }

  removeOtherDriverMarkers() {
    var bookingProvider = Provider.of<TripProvider>(context, listen: false);
    if (bookingProvider.acceptedDriver != null) {
      allDrivers = [bookingProvider.acceptedDriver!];
    }
    var mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    Future.delayed(const Duration(seconds: 2), () {
      // if (bookingProvider.acceptedDriver == null) {
      List<String> keysToRemove = [];

      mapProvider.markers.forEach((key, value) {
        if (-1 == allDrivers.indexWhere((element) => element.id == key)) {
          if (mapProvider.markers[key]!.markerId != const MarkerId('pickup') &&
              mapProvider.markers[key]!.markerId != const MarkerId('drop')) {
            keysToRemove.add(key);
          }
        }
      });
      for (var key in keysToRemove) {
        mapProvider.markers.remove(key);
      }
      mapProvider.notifyListeners();
      // }
    });
  }
}
