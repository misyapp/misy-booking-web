// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';
import 'package:rider_ride_hailing_app/services/airport_detection_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

import '../widget/input_text_field_widget.dart';
import '../widget/round_edged_button.dart';

class PickupAndDropLocation extends StatefulWidget {
  final Function(Map, Map) onTap;

  const PickupAndDropLocation({
    required Key key,
    required this.onTap,
  }) : super(key: key);

  @override
  State<PickupAndDropLocation> createState() => PickupAndDropLocationState();
}

class PickupAndDropLocationState extends State<PickupAndDropLocation> with WidgetsBindingObserver {
  Map pickupLocation = {
    "lat": null,
    "lng": null,
    "controller": TextEditingController(),
    "isAirport": false,
    "flightNumber": null,
  };
  ValueNotifier<String> pickUpAddress = ValueNotifier("");
  ValueNotifier<String> dropAddress = ValueNotifier("");
  
  // Abandonment tracking
  DateTime? _screenOpenedAt;
  Timer? _inactivityTimer;
  bool _hasLoggedAbandonment = false;
  int _addressSearchCount = 0;
  
  // Tracking methods
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 60), () {
      if (!_hasLoggedAbandonment) {
        logAddressAbandonment('timeout');
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

  Future<void> logAddressAbandonment(String reason) async {
    if (_hasLoggedAbandonment) return;
    _hasLoggedAbandonment = true;
    
    final userDetails = await DevFestPreferences().getUserDetails();
    String partialAddress = '';
    if (pickupLocation['controller'].text.isNotEmpty) {
      partialAddress = pickupLocation['controller'].text;
    } else if (dropLocation['controller'].text.isNotEmpty) {
      partialAddress = dropLocation['controller'].text;
    }
    
    await AnalyticsService.logAddressSelectionAbandoned(
      timeSpentSeconds: _getTimeSpentSeconds(),
      reason: reason,
      addressesSearched: _addressSearchCount,
      partialAddress: partialAddress,
      userId: userDetails?.id,
    );
  }



  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      logAddressAbandonment('app_backgrounded');
    }
  }

  Map dropLocation = {
    "lat": null,
    "lng": null,
    "controller": TextEditingController(),
    "isAirport": false,
    "flightNumber": null,
  };

  ValueNotifier<List> pickupLocationSuggestion = ValueNotifier([]);
  ValueNotifier<bool> isPickup = ValueNotifier(true);
  ValueNotifier<bool> showConfirmPopUp = ValueNotifier(false);

  /// Helper pour créer les Maps de localisation avec détection d'aéroport
  Map _buildLocationMap(Map location) {
    final address = location['controller'].text;
    final isAirport = AirportDetectionService.isAirportAddress(address);

    myCustomPrintStatement('📍 _buildLocationMap:');
    myCustomPrintStatement('  address: $address');
    myCustomPrintStatement('  isAirport detecté: $isAirport');
    myCustomPrintStatement('  location[isAirport]: ${location['isAirport']}');
    myCustomPrintStatement('  flightNumber: ${location['flightNumber']}');

    return {
      "lat": location['lat'],
      "lng": location['lng'],
      "address": address,
      "isAirport": isAirport || location['isAirport'] == true,
      "flightNumber": location['flightNumber'],
    };
  }

  /// Met à jour la détection d'aéroport pour un TextEditingController
  void _updateAirportDetection() {
    // Pickup
    final pickupAddress = pickupLocation['controller'].text;
    pickupLocation['isAirport'] = AirportDetectionService.isAirportAddress(pickupAddress);

    // Drop
    final dropAddress = dropLocation['controller'].text;
    dropLocation['isAirport'] = AirportDetectionService.isAirportAddress(dropAddress);

    myCustomPrintStatement('✈️ _updateAirportDetection appelé:');
    myCustomPrintStatement('  Pickup: $pickupAddress → ${pickupLocation['isAirport']}');
    myCustomPrintStatement('  Drop: $dropAddress → ${dropLocation['isAirport']}');

    setState(() {});
  }
  ValueNotifier<bool> showLinearLoader = ValueNotifier(false);
  ValueNotifier<List> drop = ValueNotifier([]);
  FocusNode focusPickup = FocusNode();
  FocusNode focusDrop = FocusNode();

  // ⚡ OPTIMISATION API: Debouncing pour Places Autocomplete
  // Économise ~70% des appels API en attendant que l'utilisateur arrête de taper
  Timer? _pickupDebounceTimer;
  Timer? _dropDebounceTimer;
  String? _lastPickupQuery;
  String? _lastDropQuery;
  static const int _minCharsForSearch = 3;
  static const Duration _debounceDuration = Duration(milliseconds: 400);

  /// Recherche d'adresse avec debouncing pour le pickup
  void _debouncedPickupSearch(String query) {
    // Annuler la requête précédente
    _pickupDebounceTimer?.cancel();

    // Ne pas chercher si moins de 3 caractères
    if (query.length < _minCharsForSearch) {
      pickupLocationSuggestion.value = [];
      return;
    }

    // Ne pas chercher si la requête est identique à la précédente
    if (query == _lastPickupQuery) {
      return;
    }

    // Lancer la recherche après le délai de debounce
    _pickupDebounceTimer = Timer(_debounceDuration, () async {
      _lastPickupQuery = query;
      myCustomPrintStatement('🔍 Places API call (pickup): "$query"');
      pickupLocationSuggestion.value = await getPlacePridiction(query);
      _updateAirportDetection();
    });
  }

  /// Recherche d'adresse avec debouncing pour le drop
  void _debouncedDropSearch(String query) {
    // Annuler la requête précédente
    _dropDebounceTimer?.cancel();

    // Ne pas chercher si moins de 3 caractères
    if (query.length < _minCharsForSearch) {
      drop.value = [];
      return;
    }

    // Ne pas chercher si la requête est identique à la précédente
    if (query == _lastDropQuery) {
      return;
    }

    // Lancer la recherche après le délai de debounce
    _dropDebounceTimer = Timer(_debounceDuration, () async {
      _lastDropQuery = query;
      myCustomPrintStatement('🔍 Places API call (drop): "$query"');
      drop.value = await getPlacePridiction(query);
      _updateAirportDetection();
    });
  }
  @override
  void initState() {
    // Setup abandonment tracking
    WidgetsBinding.instance.addObserver(this);
    _screenOpenedAt = DateTime.now();
    _startInactivityTimer();
    print('🔍 PickupAndDropLocation initState - abandonment tracking initialized');
    
    super.initState();
    pickupLocation['controller'].text = currentFullAddress ?? '';
    pickUpAddress.value = currentFullAddress ?? '';
    pickupLocation['lat'] = currentPosition!.latitude;
    pickupLocation['lng'] = currentPosition!.longitude;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await getCurrentLocation();
      // var tripProvider = Provider.of<TripProvider>(context, listen: false);
      // if (tripProvider.pickLocation == null) {
      pickupLocation['controller'].text = currentFullAddress ?? '';
      pickUpAddress.value = currentFullAddress ?? '';
      pickupLocation['lat'] = currentPosition!.latitude;
      pickupLocation['lng'] = currentPosition!.longitude;
      // } else {
      //   pickupLocation['controller'].text =
      //       tripProvider.pickLocation!['address'] ?? '';
      //   pickUpAddress.value = tripProvider.pickLocation!['address'] ?? '';
      //   pickupLocation['lat'] = tripProvider.pickLocation!['lat'];
      //   pickupLocation['lng'] = tripProvider.pickLocation!['lng'];
      //   dropLocation['controller'].text =
      //       tripProvider.dropLocation!['address'] ?? '';
      //   dropAddress.value = tripProvider.dropLocation!['address'] ?? '';
      //   dropLocation['lat'] = tripProvider.dropLocation!['lat'];
      //   dropLocation['lng'] = tripProvider.dropLocation!['lng'];
      // }
    });
    focusPickup.addListener(_onPickupFocusChange);
    focusDrop.addListener(_onDropFocusChange);
  }

  @override
  void dispose() {
    // Cleanup abandonment tracking
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();

    // ⚡ Cleanup debounce timers
    _pickupDebounceTimer?.cancel();
    _dropDebounceTimer?.cancel();

    super.dispose();
    focusPickup.removeListener(_onPickupFocusChange);
    focusDrop.removeListener(_onDropFocusChange);
    focusPickup.dispose();
    focusDrop.dispose();
  }

  void _onPickupFocusChange() {
    myCustomPrintStatement("Pickup Focus: ${focusPickup.hasFocus.toString()}");
    if (focusPickup.hasFocus == true) {
      isPickup.value = true;
    }
  }

  void _onDropFocusChange() {
    myCustomPrintStatement("Drop Focus: ${focusDrop.hasFocus.toString()}");
    if (focusDrop.hasFocus == true) {
      isPickup.value = false;
    }
  }

  pickedLocationLatLong(
      {required double latitude, required double longitude}) async {
    showLinearLoader.value = true;
    var getAddress = await getAddressWithPlusCodeByLatLng(
        latitude: latitude, longitude: longitude);
    dropLocation['lat'] = latitude;
    dropLocation['lng'] = longitude;

    // Vérifier si les résultats sont vides avant d'y accéder
    if (getAddress['results'] == null || getAddress['results'].isEmpty) {
      myCustomPrintStatement("⚠️ Geocoding API: aucun résultat trouvé pour $latitude, $longitude");
      dropLocation['controller'].text = "$latitude, $longitude";
      showLinearLoader.value = false;
      if (showConfirmPopUp.value) {
        hideLoading();
      }
      return;
    }

    // 🔧 FIX: Toujours nettoyer le Plus Code de l'adresse de fallback
    dropLocation['controller'].text =
    removeGooglePlusCode(getAddress['results'][0]['formatted_address']);
    showLinearLoader.value = false;
    if (showConfirmPopUp.value) {
      hideLoading();
    }
    // Chercher le Fokontany (neighborhood ou administrative_area_level_4)
    for (int i = 0; i < getAddress['results'].length; i++) {
      final List<dynamic> results =
          getAddress['results'][i]['address_components'] ?? [];
      for (final component in results) {
        final List<dynamic> types = component['types'] ?? [];

        if (types.contains("neighborhood") ||
            types.contains("administrative_area_level_4")) {
          myCustomPrintStatement(
              "i ---------$i ${component['long_name']}, ${getAddress['results'][0]['formatted_address']}}");
          dropLocation['controller'].text =
          "${component['long_name']}, ${removeGooglePlusCode(getAddress['results'][0]['formatted_address'])}";
          return;
        }
      }
    }
  }

  pickUpLocationMapLatLong(
      {required double latitude, required double longitude}) async {
    showLinearLoader.value = true;
    var getAddress = await getAddressWithPlusCodeByLatLng(
        latitude: latitude, longitude: longitude);

    pickupLocation['lat'] = latitude;
    pickupLocation['lng'] = longitude;

    // Vérifier si les résultats sont vides avant d'y accéder
    if (getAddress['results'] == null || getAddress['results'].isEmpty) {
      myCustomPrintStatement("⚠️ Geocoding API: aucun résultat trouvé pour $latitude, $longitude");
      pickupLocation['controller'].text = "$latitude, $longitude";
      showLinearLoader.value = false;
      if (showConfirmPopUp.value) {
        hideLoading();
      }
      return;
    }

    // 🔧 FIX: Toujours nettoyer le Plus Code de l'adresse de fallback
    pickupLocation['controller'].text =
    removeGooglePlusCode(getAddress['results'][0]['formatted_address']);
    showLinearLoader.value = false;
    if (showConfirmPopUp.value) {
      hideLoading();
    }
    // Chercher le Fokontany (neighborhood ou administrative_area_level_4)
    for (int i = 0; i < getAddress['results'].length; i++) {
      final List<dynamic> results =
          getAddress['results'][i]['address_components'] ?? [];
      for (final component in results) {
        final List<dynamic> types = component['types'] ?? [];

        // 🔧 FIX: Ajouter administrative_area_level_4 (Fokontany à Madagascar)
        if (types.contains("neighborhood") ||
            types.contains("administrative_area_level_4")) {
          myCustomPrintStatement(
              "i ---------$i ${component['long_name']}, ${getAddress['results'][0]['formatted_address']}}");
          pickupLocation['controller'].text =
          "${component['long_name']}, ${removeGooglePlusCode(getAddress['results'][0]['formatted_address'])}";
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Log abandonment via bouton système
          await logAddressAbandonment('system_back_button');
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Container(
      decoration: BoxDecoration(
        color: MyColors.bottomSheetBackgroundColor(),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          constraints: BoxConstraints(
              minHeight: 60,
              maxHeight: MediaQuery.of(context).size.height * 0.55),
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
                      if (MyGlobalKeys.homePageKey.currentState != null) {
                        MyGlobalKeys.homePageKey.currentState!
                            .updateBottomSheetHeight(milliseconds: 20);
                      }
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
                  vSizedBox,
                if (sheetValue)
                  Flexible(
                    child: SingleChildScrollView(
                      child: ValueListenableBuilder(
                        valueListenable: dropLocationPickerHideNoti,
                        builder: (context, hidePicker, child) =>
                            ValueListenableBuilder(
                              valueListenable: pickupLocationPickerHideNoti,
                              builder: (context, hidePickupPicker, child) =>
                              hidePicker
                                  ? Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: globalHorizontalPadding),
                                child: ValueListenableBuilder(
                                  valueListenable: showLinearLoader,
                                  builder:
                                      (context, showLinearload, child) =>
                                      ValueListenableBuilder(
                                        valueListenable: showConfirmPopUp,
                                        builder:
                                            (context, showConfirm, child) =>
                                            SafeArea(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (showConfirm)
                                                    SubHeadingText(
                                                      translate(
                                                          "Confrim the drop spot by dragging the pin."),
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: 18,
                                                      maxLines: 3,
                                                    ),
                                                  showLinearload
                                                      ? LoadingAnimationWidget.twistingDots(
                                                    leftDotColor: MyColors.coralPink,
                                                    rightDotColor: MyColors.horizonBlue,
                                                    size: 20.0,
                                                  )
                                                      : vSizedBox05,
                                                  vSizedBox,
                                                  InputTextFieldWidget(
                                                    borderColor: Colors.transparent,
                                                    fillColor: MyColors
                                                        .textFillThemeColor(),
                                                    focusNode: focusPickup,
                                                    enabled: false,
                                                    controller:
                                                    dropLocation['controller'],
                                                    obscureText: false,
                                                    onChanged: (v) {
                                                      dropAddress.value = v;
                                                      // ⚡ OPTIMISATION: Debounce 400ms + min 3 chars
                                                      _debouncedDropSearch(v);
                                                    },
                                                    hintText: translate("Whereto"),
                                                    preffix: const Padding(
                                                        padding: EdgeInsets.all(13),
                                                        child: Icon(Icons.search)),
                                                  ),
                                                  RoundEdgedButton(
                                                    text: translate("Confirm"),
                                                    color: showLinearload
                                                        ? MyColors
                                                        .colorLightGrey727272
                                                        : MyColors.primaryColor,
                                                    width: double.infinity,
                                                    onTap: showLinearload
                                                        ? null
                                                        : !showConfirm
                                                        ? () async {
                                                      myCustomPrintStatement(
                                                          "this fuction called ${pickupLocationPickerHideNoti.value}");
                                                      if (pickupLocation[
                                                      'lat'] ==
                                                          null) {
                                                        Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                500),
                                                                () {
                                                              focusPickup
                                                                  .requestFocus();
                                                            });
                                                      }
                                                      dropLocationPickerHideNoti
                                                          .value = false;
                                                      pickupLocationPickerHideNoti
                                                          .value = false;
                                                      if (dropLocation[
                                                      'lat'] ==
                                                          null ||
                                                          pickupLocation[
                                                          'lat'] ==
                                                              null) {
                                                        return;
                                                      }
                                                      // Mise à jour détection aéroport
                                                      _updateAirportDetection();
                                                      var p = _buildLocationMap(pickupLocation);
                                                      var d = _buildLocationMap(dropLocation);
                                                      if (p['lat'] != null &&
                                                          p['lng'] !=
                                                              null &&
                                                          d['lat'] !=
                                                              null &&
                                                          d['lng'] !=
                                                              null) {
                                                        await DevFestPreferences()
                                                            .setSearchSuggestion({
                                                          "pickup": p,
                                                          "drop": d
                                                        });
                                                      }
                                                      // lastSearchSuggestion.value = [
                                                      //       {"pickup": p, "drop": d}
                                                      //     ] + lastSearchSuggestion.value.is
                                                      //     [lastSearchSuggestion.value[0]];

                                                      widget.onTap(p, d);
                                                    }
                                                        : () async {
                                                      if (pickupLocationPickerHideNoti
                                                          .value) {
                                                        Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                500),
                                                                () {
                                                              focusDrop
                                                                  .requestFocus();
                                                            });
                                                      }
                                                      dropLocationPickerHideNoti
                                                          .value = false;
                                                      pickupLocationPickerHideNoti
                                                          .value = false;
                                                      if (dropLocation[
                                                      'lat'] ==
                                                          null ||
                                                          pickupLocation[
                                                          'lat'] ==
                                                              null) {
                                                        return;
                                                      }
                                                      // Mise à jour détection aéroport
                                                      _updateAirportDetection();
                                                      var p = _buildLocationMap(pickupLocation);
                                                      var d = _buildLocationMap(dropLocation);
                                                      if (p['lat'] != null &&
                                                          p['lng'] !=
                                                              null &&
                                                          d['lat'] !=
                                                              null &&
                                                          d['lng'] !=
                                                              null) {
                                                        await DevFestPreferences()
                                                            .setSearchSuggestion({
                                                          "pickup": p,
                                                          "drop": d
                                                        });
                                                      }
                                                      // lastSearchSuggestion.value = [
                                                      //       {"pickup": p, "drop": d}
                                                      //     ] + lastSearchSuggestion.value.is
                                                      //     [lastSearchSuggestion.value[0]];
                                                      showConfirmPopUp
                                                          .value = false;
                                                      widget.onTap(p, d);
                                                    },
                                                  ),
                                                  vSizedBox
                                                ],
                                              ),
                                            ),
                                      ),
                                ),
                              )
                                  : hidePickupPicker
                                  ? SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal:
                                      globalHorizontalPadding),
                                  child: ValueListenableBuilder(
                                    valueListenable: showLinearLoader,
                                    builder: (context, showLinearload,
                                        child) =>
                                        ValueListenableBuilder(
                                          valueListenable: showConfirmPopUp,
                                          builder: (context, showConfirm,
                                              child) =>
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (showConfirm)
                                                    SubHeadingText(
                                                      translate(
                                                          "Confrim the pickup spot by dragging the pin."),
                                                      fontWeight:
                                                      FontWeight.w500,
                                                      fontSize: 18,
                                                      maxLines: 3,
                                                    ),
                                                  if (showConfirm) vSizedBox,
                                                  showLinearload
                                                      ? LoadingAnimationWidget.twistingDots(
                                                    leftDotColor: MyColors.coralPink,
                                                    rightDotColor: MyColors.horizonBlue,
                                                    size: 20.0,
                                                  )
                                                      : vSizedBox05,
                                                  vSizedBox,
                                                  InputTextFieldWidget(
                                                    borderColor:
                                                    Colors.transparent,
                                                    fillColor: MyColors
                                                        .textFillThemeColor(),
                                                    focusNode: focusPickup,
                                                    enabled: false,
                                                    controller: pickupLocation[
                                                    'controller'],
                                                    obscureText: false,
                                                    onChanged: (v) {
                                                      pickUpAddress.value = v;
                                                      // ⚡ OPTIMISATION: Debounce 400ms + min 3 chars
                                                      _debouncedPickupSearch(v);
                                                    },
                                                    hintText: translate(
                                                        "pickupLocation"),
                                                    preffix: const Padding(
                                                        padding:
                                                        EdgeInsets.all(13),
                                                        child:
                                                        Icon(Icons.search)),
                                                  ),
                                                  RoundEdgedButton(
                                                    text: translate("Confirm"),
                                                    color: showLinearload
                                                        ? MyColors
                                                        .colorLightGrey727272
                                                        : MyColors.primaryColor,
                                                    width: double.infinity,
                                                    onTap: showLinearload
                                                        ? null
                                                        : !showConfirm
                                                        ? () async {
                                                      if (pickupLocationPickerHideNoti
                                                          .value) {
                                                        Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                500),
                                                                () {
                                                              focusDrop
                                                                  .requestFocus();
                                                            });
                                                      }
                                                      dropLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      pickupLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      if (dropLocation[
                                                      'lat'] ==
                                                          null ||
                                                          pickupLocation[
                                                          'lat'] ==
                                                              null) {
                                                        return;
                                                      }
                                                      // Mise à jour détection aéroport
                                                      _updateAirportDetection();
                                                      var p = _buildLocationMap(pickupLocation);
                                                      var d = _buildLocationMap(dropLocation);
                                                      if (p['lat'] != null &&
                                                          p['lng'] !=
                                                              null &&
                                                          d['lat'] !=
                                                              null &&
                                                          d['lng'] !=
                                                              null) {
                                                        await DevFestPreferences()
                                                            .setSearchSuggestion({
                                                          "pickup": p,
                                                          "drop": d
                                                        });
                                                      }
                                                      // lastSearchSuggestion.value = [
                                                      //       {"pickup": p, "drop": d}
                                                      //     ] + lastSearchSuggestion.value.is
                                                      //     [lastSearchSuggestion.value[0]];
                                                      showConfirmPopUp
                                                          .value =
                                                      false;
                                                      widget.onTap(
                                                          p, d);
                                                    }
                                                        : () async {
                                                      if (pickupLocationPickerHideNoti
                                                          .value) {
                                                        Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                500),
                                                                () {
                                                              focusDrop
                                                                  .requestFocus();
                                                            });
                                                      }
                                                      dropLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      pickupLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      if (dropLocation[
                                                      'lat'] ==
                                                          null ||
                                                          pickupLocation[
                                                          'lat'] ==
                                                              null) {
                                                        return;
                                                      }
                                                      // Mise à jour détection aéroport
                                                      _updateAirportDetection();
                                                      var p = _buildLocationMap(pickupLocation);
                                                      var d = _buildLocationMap(dropLocation);
                                                      if (p['lat'] != null &&
                                                          p['lng'] !=
                                                              null &&
                                                          d['lat'] !=
                                                              null &&
                                                          d['lng'] !=
                                                              null) {
                                                        await DevFestPreferences()
                                                            .setSearchSuggestion({
                                                          "pickup": p,
                                                          "drop": d
                                                        });
                                                      }
                                                      // lastSearchSuggestion.value = [
                                                      //       {"pickup": p, "drop": d}
                                                      //     ] + lastSearchSuggestion.value.is
                                                      //     [lastSearchSuggestion.value[0]];
                                                      showConfirmPopUp
                                                          .value =
                                                      false;
                                                      widget.onTap(
                                                          p, d);
                                                    },
                                                  ),
                                                  vSizedBox
                                                ],
                                              ),
                                        ),
                                  ),
                                ),
                              )
                                  : Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  vSizedBox,
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal:
                                        globalHorizontalPadding),
                                    child: Center(
                                      child: SubHeadingText(
                                        translate(
                                            "EnteryourPickupanddropofflocation"),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  vSizedBox05,
                                  ValueListenableBuilder(
                                    valueListenable: pickUpAddress,
                                    builder: (context, pick, child) =>
                                        ValueListenableBuilder(
                                          valueListenable: isPickup,
                                          builder: (context, isPickupValue,
                                              child) =>
                                              Padding(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal:
                                                    globalHorizontalPadding),
                                                child: InputTextFieldWidget(
                                                  borderColor:
                                                  Colors.transparent,
                                                  fillColor: MyColors
                                                      .textFillThemeColor(),
                                                  focusNode: focusPickup,
                                                  controller: pickupLocation[
                                                  'controller'],
                                                  obscureText: false,
                                                  onChanged: (v) {
                                                    pickUpAddress.value = v;
                                                    // ⚡ OPTIMISATION: Debounce 400ms + min 3 chars
                                                    _debouncedPickupSearch(v);
                                                  },
                                                  hintText: translate(
                                                      "pickupLocation"),
                                                  preffix: Padding(
                                                    padding:
                                                    const EdgeInsets.all(
                                                        13),
                                                    child: isPickupValue
                                                        ? const Icon(
                                                        Icons.search)
                                                        : Image.asset(
                                                      MyImagesUrl
                                                          .myLocation,
                                                      width: 23,
                                                      color: MyColors
                                                          .blackThemeColor(),
                                                    ),
                                                  ),
                                                  suffix: isPickupValue &&
                                                      pick.isNotEmpty
                                                      ? GestureDetector(
                                                    onTap: () {
                                                      pickupLocation[
                                                      'controller']
                                                          .clear();
                                                      pickupLocation[
                                                      "lat"] = null;
                                                      pickupLocation[
                                                      "lng"] = null;
                                                      pickUpAddress
                                                          .value = "";
                                                    },
                                                    child: Container(
                                                      margin:
                                                      const EdgeInsets
                                                          .all(10),
                                                      decoration: BoxDecoration(
                                                          shape: BoxShape
                                                              .circle,
                                                          color: MyColors
                                                              .whiteThemeColor()),
                                                      child: const Icon(
                                                        Icons
                                                            .close_outlined,
                                                        size: 15,
                                                      ),
                                                    ),
                                                  )
                                                      : null,
                                                ),
                                              ),
                                        ),
                                  ),
                                  Container(
                                    margin:
                                    const EdgeInsets.only(left: 50),
                                    width: 2,
                                    height: 30,
                                    decoration: BoxDecoration(
                                        color:
                                        MyColors.blackThemeColor()),
                                  ),
                                  ValueListenableBuilder(
                                    valueListenable: isPickup,
                                    builder: (context, isPickupValue,
                                        child) =>
                                        ValueListenableBuilder(
                                          valueListenable: dropAddress,
                                          builder:
                                              (context, dropAdd, child) =>
                                              Padding(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal:
                                                    globalHorizontalPadding),
                                                child: InputTextFieldWidget(
                                                  borderColor:
                                                  Colors.transparent,
                                                  focusNode: focusDrop,
                                                  fillColor: MyColors
                                                      .textFillThemeColor(),
                                                  controller: dropLocation[
                                                  'controller'],
                                                  obscureText: false,
                                                  autofocus: true,
                                                  onChanged: (v) {
                                                    dropAddress.value = v;
                                                    // ⚡ OPTIMISATION: Debounce 400ms + min 3 chars
                                                    _debouncedDropSearch(v);
                                                  },
                                                  hintText:
                                                  translate("Whereto"),
                                                  preffix: Padding(
                                                    padding:
                                                    const EdgeInsets.all(
                                                        13),
                                                    child:
                                                    isPickupValue == false
                                                        ? const Icon(
                                                        Icons.search)
                                                        : Image.asset(
                                                      MyImagesUrl
                                                          .location,
                                                      color: MyColors
                                                          .blackThemeColor(),
                                                      width: 20,
                                                    ),
                                                  ),
                                                  suffix: isPickupValue ==
                                                      false &&
                                                      dropAdd.isNotEmpty
                                                      ? GestureDetector(
                                                    onTap: () {
                                                      dropLocation[
                                                      'controller']
                                                          .clear();
                                                      dropLocation[
                                                      "lat"] = null;
                                                      dropLocation[
                                                      "lng"] = null;
                                                      dropAddress.value =
                                                      "";
                                                    },
                                                    child: Container(
                                                      margin:
                                                      const EdgeInsets
                                                          .all(10),
                                                      decoration: BoxDecoration(
                                                          shape: BoxShape
                                                              .circle,
                                                          color: MyColors
                                                              .whiteThemeColor()),
                                                      child: const Icon(
                                                        Icons
                                                            .close_outlined,
                                                        size: 15,
                                                      ),
                                                    ),
                                                  )
                                                      : null,
                                                ),
                                              ),
                                        ),
                                  ),
                                  vSizedBox2,
                                  Container(
                                    decoration: BoxDecoration(
                                        color:
                                        MyColors.whiteThemeColor(),
                                        boxShadow: [
                                          BoxShadow(
                                              color: MyColors
                                                  .blackThemeColor()
                                                  .withOpacity(0.15),
                                              blurRadius: 0.5,
                                              spreadRadius: 0.5,
                                              offset:
                                              const Offset(-1, -3))
                                        ]),
                                    width: double.infinity,
                                    child: vSizedBox,
                                  ),
                                  ValueListenableBuilder(
                                    valueListenable: isPickup,
                                    builder: (context, isPickupValue,
                                        child) =>
                                    isPickupValue
                                        ? Container()
                                        : ValueListenableBuilder(
                                      valueListenable: drop,
                                      builder: (context,
                                          dropList,
                                          child) =>
                                          Container(
                                            padding:
                                            const EdgeInsets
                                                .symmetric(
                                                horizontal:
                                                25,
                                                vertical: 0),
                                            decoration:
                                            BoxDecoration(
                                              borderRadius:
                                              BorderRadius
                                                  .circular(
                                                  13),
                                              color: MyColors
                                                  .whiteThemeColor(),
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                      border: Border(
                                                          bottom: BorderSide(
                                                              color:
                                                              MyColors.textFillThemeColor()))),
                                                  child:
                                                  GestureDetector(
                                                    onTap: () {
                                                      drop.value =
                                                      [];

                                                      FocusScope.of(
                                                          context)
                                                          .unfocus();
                                                      Provider.of<GoogleMapProvider>(
                                                          context,
                                                          listen:
                                                          false)
                                                          .controller!
                                                          .animateCamera(
                                                        CameraUpdate.newLatLng(LatLng(
                                                            currentPosition!.latitude,
                                                            currentPosition!.longitude)),
                                                      );
                                                      dropLocationPickerHideNoti
                                                          .value =
                                                      true;
                                                      pickupLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      if (MyGlobalKeys.homePageKey.currentState != null) {
                                                        MyGlobalKeys
                                                            .homePageKey
                                                            .currentState!
                                                            .updateBottomSheetHeight();
                                                      }
                                                    },
                                                    child:
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical:
                                                          8.0),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: MyColors.textFillThemeColor(),
                                                            ),
                                                            child: Image.asset(
                                                              MyImagesUrl.myLocation,
                                                              width: 20,
                                                              height: 20,
                                                              color: MyColors.blackThemeColorWithOpacity(0.6),
                                                            ),
                                                          ),
                                                          hSizedBox,
                                                          Expanded(
                                                            child:
                                                            ParagraphText(
                                                              translate("Set from map"),
                                                              fontWeight:
                                                              FontWeight.w400,
                                                              color:
                                                              MyColors.blackThemeColorWithOpacity(0.6),
                                                              fontSize:
                                                              14,
                                                              maxLines:
                                                              2,
                                                              textOverflow:
                                                              TextOverflow.ellipsis,
                                                            ),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  decoration: BoxDecoration(
                                                      border: Border(
                                                          bottom: BorderSide(
                                                              color:
                                                              MyColors.textFillThemeColor()))),
                                                  child:
                                                  GestureDetector(
                                                    onTap:
                                                        () async {
                                                      showLoading();
                                                      focusPickup
                                                          .requestFocus();
                                                      dropLocation['controller']
                                                          .text =
                                                          currentFullAddress ??
                                                              '';
                                                      dropAddress
                                                          .value =
                                                          currentFullAddress ??
                                                              '';
                                                      dropLocation[
                                                      'lat'] =
                                                          currentPosition!
                                                              .latitude;
                                                      dropLocation[
                                                      'lng'] =
                                                          currentPosition!
                                                              .longitude;
                                                      drop.value =
                                                      [];
                                                      dropLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      pickupLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      if (dropLocation['lat'] !=
                                                          null &&
                                                          pickupLocation['lat'] !=
                                                              null) {
                                                        var p = {
                                                          "lat": pickupLocation[
                                                          'lat'],
                                                          "lng": pickupLocation[
                                                          'lng'],
                                                          "address":
                                                          pickupLocation['controller'].text,
                                                        };
                                                        var d = {
                                                          "lat": dropLocation[
                                                          'lat'],
                                                          "lng": dropLocation[
                                                          'lng'],
                                                          "address":
                                                          dropLocation['controller'].text,
                                                        };
                                                        if (p['lat'] != null &&
                                                            p['lng'] !=
                                                                null &&
                                                            d['lat'] !=
                                                                null &&
                                                            d['lng'] !=
                                                                null) {
                                                          await DevFestPreferences()
                                                              .setSearchSuggestion({
                                                            "pickup":
                                                            p,
                                                            "drop":
                                                            d
                                                          });
                                                        }
                                                        widget
                                                            .onTap(
                                                            p,
                                                            d);
                                                      }
                                                    },
                                                    child:
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical:
                                                          8.0),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: MyColors.textFillThemeColor(),
                                                            ),
                                                            child: Icon(
                                                              Icons.location_on_outlined,
                                                              size: 18,
                                                              color: MyColors.blackThemeColorWithOpacity(0.6),
                                                            ),
                                                          ),
                                                          hSizedBox,
                                                          Expanded(
                                                            child:
                                                            ParagraphText(
                                                              translate("My location"),
                                                              fontWeight:
                                                              FontWeight.w400,
                                                              color:
                                                              MyColors.blackThemeColorWithOpacity(0.6),
                                                              fontSize:
                                                              14,
                                                              maxLines:
                                                              2,
                                                              textOverflow:
                                                              TextOverflow.ellipsis,
                                                            ),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                ValueListenableBuilder(
                                                  valueListenable:
                                                  lastSearchSuggestion,
                                                  builder: (context,
                                                      lastSearchList,
                                                      child) =>
                                                  dropList.isEmpty &&
                                                      lastSearchList.isNotEmpty
                                                      ? Column(
                                                    mainAxisSize:
                                                    MainAxisSize.min,
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                    children: [
                                                      for (int i = 0; i < lastSearchList.length; i++)
                                                        Container(
                                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: MyColors.textFillThemeColor()))),
                                                          child: GestureDetector(
                                                            onTap: () async {
                                                              dropLocation['controller'].text = lastSearchList[i]['drop']['address'];
                                                              dropAddress.value = lastSearchList[i]['drop']['address'];
                                                              dropLocation['lat'] = lastSearchList[i]['drop']['lat'];
                                                              dropLocation['lng'] = lastSearchList[i]['drop']['lng'];
                                                              drop.value = [];
                                                              dropLocationPickerHideNoti.value = false;
                                                              pickupLocationPickerHideNoti.value = false;
                                                              if (pickupLocation['lat'] != null) {
                                                                // Mise à jour détection aéroport
                                                                _updateAirportDetection();

                                                                // Utiliser _buildLocationMap pour inclure la détection d'aéroport
                                                                var p = _buildLocationMap(pickupLocation);

                                                                // Pour la destination historique, créer un Map temporaire puis utiliser _buildLocationMap
                                                                Map tempDropLocation = {
                                                                  'lat': lastSearchList[i]['drop']['lat'],
                                                                  'lng': lastSearchList[i]['drop']['lng'],
                                                                  'controller': TextEditingController(text: lastSearchList[i]['drop']['address']),
                                                                  'isAirport': lastSearchList[i]['drop']['isAirport'],
                                                                  'flightNumber': lastSearchList[i]['drop']['flightNumber'],
                                                                };
                                                                var d = _buildLocationMap(tempDropLocation);

                                                                if (p['lat'] != null && p['lng'] != null && d['lat'] != null && d['lng'] != null) {
                                                                  await DevFestPreferences().setSearchSuggestion({
                                                                    "pickup": p,
                                                                    "drop": d
                                                                  });

                                                                  widget.onTap(p, d);
                                                                }
                                                              }
                                                            },
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.history_rounded, size: 22, color: MyColors.blackThemeColorWithOpacity(0.7)),
                                                                  hSizedBox,
                                                                  Expanded(
                                                                    child: ParagraphText(
                                                                      "${lastSearchList[i]['drop']['address']}",
                                                                      fontWeight: FontWeight.w400,
                                                                      color: MyColors.blackThemeColorWithOpacity(0.7),
                                                                      fontSize: 14,
                                                                      maxLines: 2,
                                                                      textOverflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                    ],
                                                  )
                                                      : Container(),
                                                ),
                                                for (int i = 0;
                                                i <
                                                    dropList
                                                        .length;
                                                i++)
                                                  Container(
                                                    decoration: BoxDecoration(
                                                        border: Border(
                                                            bottom:
                                                            BorderSide(color: MyColors.textFillThemeColor()))),
                                                    child:
                                                    GestureDetector(
                                                      onTap:
                                                          () async {
                                                        showLoading();
                                                        dropLocationPickerHideNoti
                                                            .value =
                                                        false;
                                                        pickupLocationPickerHideNoti
                                                            .value =
                                                        false;

                                                        dropLocation[
                                                        'controller']
                                                            .text = dropList[
                                                        i]
                                                        [
                                                        'description'];
                                                        var address =
                                                        await getLatLngByPlaceId(dropList[i]
                                                        [
                                                        'place_id']);
                                                        dropLocation[
                                                        'lat'] = address['result']['geometry']
                                                        [
                                                        'location']
                                                        [
                                                        'lat'];
                                                        dropLocation[
                                                        'lng'] = address['result']['geometry']
                                                        [
                                                        'location']
                                                        [
                                                        'lng'];
                                                        drop.value =
                                                        [];
                                                        pickupLocationPickerHideNoti
                                                            .value =
                                                        false;
                                                        showConfirmPopUp
                                                            .value =
                                                        true;
                                                        dropLocationPickerHideNoti
                                                            .value =
                                                        true;

                                                        Provider.of<GoogleMapProvider>(
                                                            context,
                                                            listen: false)
                                                            .controller!
                                                            .animateCamera(
                                                          CameraUpdate.newCameraPosition(
                                                            CameraPosition(
                                                                target: LatLng(
                                                                  dropLocation['lat'],
                                                                  dropLocation['lng'],
                                                                ),
                                                                zoom: 16.50),
                                                          ),
                                                        );

                                                        if (MyGlobalKeys.homePageKey.currentState != null) {
                                                          MyGlobalKeys
                                                              .homePageKey
                                                              .currentState!
                                                              .updateBottomSheetHeight(
                                                              milliseconds: 100);
                                                        }
                                                        hideLoading();
                                                      },
                                                      child:
                                                      Padding(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            vertical:
                                                            8.0),
                                                        child:
                                                        Row(
                                                          children: [
                                                            Icon(
                                                                Icons.location_on_outlined,
                                                                size: 22,
                                                                color: MyColors.blackThemeColorWithOpacity(0.7)),
                                                            hSizedBox,
                                                            Expanded(
                                                              child:
                                                              ParagraphText(
                                                                dropList[i]['description'],
                                                                fontWeight: FontWeight.w400,
                                                                color: MyColors.blackThemeColorWithOpacity(0.7),
                                                                fontSize: 14,
                                                                maxLines: 2,
                                                                textOverflow: TextOverflow.ellipsis,
                                                              ),
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                    ),
                                  ),
                                  ValueListenableBuilder(
                                    valueListenable: isPickup,
                                    builder: (context, isPickupValue,
                                        child) =>
                                    isPickupValue == false
                                        ? Container()
                                        : ValueListenableBuilder(
                                      valueListenable:
                                      pickupLocationSuggestion,
                                      builder: (context,
                                          pickupLocationList,
                                          child) =>
                                          Container(
                                            padding:
                                            const EdgeInsets
                                                .symmetric(
                                                horizontal:
                                                25,
                                                vertical: 0),
                                            decoration:
                                            BoxDecoration(
                                              borderRadius:
                                              BorderRadius
                                                  .circular(
                                                  13),
                                              color: MyColors
                                                  .whiteThemeColor(),
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                      border: Border(
                                                          bottom: BorderSide(
                                                              color:
                                                              MyColors.textFillThemeColor()))),
                                                  child:
                                                  GestureDetector(
                                                    onTap: () {
                                                      pickupLocationSuggestion
                                                          .value = [];

                                                      FocusScope.of(
                                                          context)
                                                          .unfocus();
                                                      Provider.of<GoogleMapProvider>(
                                                          context,
                                                          listen:
                                                          false)
                                                          .controller!
                                                          .animateCamera(
                                                        CameraUpdate.newLatLng(LatLng(
                                                            currentPosition!.latitude,
                                                            currentPosition!.longitude)),
                                                      );
                                                      pickupLocationPickerHideNoti
                                                          .value =
                                                      true;
                                                      dropLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      if (MyGlobalKeys.homePageKey.currentState != null) {
                                                        MyGlobalKeys
                                                            .homePageKey
                                                            .currentState!
                                                            .updateBottomSheetHeight();
                                                      }
                                                    },
                                                    child:
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical:
                                                          8.0),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: MyColors.textFillThemeColor(),
                                                            ),
                                                            child: Image.asset(
                                                              MyImagesUrl.myLocation,
                                                              width: 20,
                                                              height: 20,
                                                              color: MyColors.blackThemeColorWithOpacity(0.6),
                                                            ),
                                                          ),
                                                          hSizedBox,
                                                          Expanded(
                                                            child:
                                                            ParagraphText(
                                                              translate("Set from map"),
                                                              fontWeight:
                                                              FontWeight.w400,
                                                              color:
                                                              MyColors.blackThemeColorWithOpacity(0.6),
                                                              fontSize:
                                                              14,
                                                              maxLines:
                                                              2,
                                                              textOverflow:
                                                              TextOverflow.ellipsis,
                                                            ),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  decoration: BoxDecoration(
                                                      border: Border(
                                                          bottom: BorderSide(
                                                              color:
                                                              MyColors.textFillThemeColor()))),
                                                  child:
                                                  GestureDetector(
                                                    onTap:
                                                        () async {
                                                      focusDrop
                                                          .requestFocus();
                                                      pickupLocation['controller']
                                                          .text =
                                                          currentFullAddress ??
                                                              '';
                                                      pickUpAddress
                                                          .value =
                                                          currentFullAddress ??
                                                              '';
                                                      pickupLocation[
                                                      'lat'] =
                                                          currentPosition!
                                                              .latitude;
                                                      pickupLocation[
                                                      'lng'] =
                                                          currentPosition!
                                                              .longitude;
                                                      pickupLocationSuggestion
                                                          .value = [];
                                                      dropLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      pickupLocationPickerHideNoti
                                                          .value =
                                                      false;
                                                      if (dropLocation['lat'] !=
                                                          null &&
                                                          pickupLocation['lat'] !=
                                                              null) {
                                                        var p = {
                                                          "lat": pickupLocation[
                                                          'lat'],
                                                          "lng": pickupLocation[
                                                          'lng'],
                                                          "address":
                                                          pickupLocation['controller'].text,
                                                        };
                                                        var d = {
                                                          "lat": dropLocation[
                                                          'lat'],
                                                          "lng": dropLocation[
                                                          'lng'],
                                                          "address":
                                                          dropLocation['controller'].text,
                                                        };
                                                        if (p['lat'] != null &&
                                                            p['lng'] !=
                                                                null &&
                                                            d['lat'] !=
                                                                null &&
                                                            d['lng'] !=
                                                                null) {
                                                          await DevFestPreferences()
                                                              .setSearchSuggestion({
                                                            "pickup":
                                                            p,
                                                            "drop":
                                                            d
                                                          });
                                                        }
                                                        widget
                                                            .onTap(
                                                            p,
                                                            d);
                                                      }
                                                    },
                                                    child:
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical:
                                                          8.0),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: MyColors.textFillThemeColor(),
                                                            ),
                                                            child: Icon(
                                                              Icons.location_on_outlined,
                                                              size: 18,
                                                              color: MyColors.blackThemeColorWithOpacity(0.6),
                                                            ),
                                                          ),
                                                          hSizedBox,
                                                          Expanded(
                                                            child:
                                                            ParagraphText(
                                                              translate("My location"),
                                                              fontWeight:
                                                              FontWeight.w400,
                                                              color:
                                                              MyColors.blackThemeColorWithOpacity(0.6),
                                                              fontSize:
                                                              14,
                                                              maxLines:
                                                              2,
                                                              textOverflow:
                                                              TextOverflow.ellipsis,
                                                            ),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                ValueListenableBuilder(
                                                  valueListenable:
                                                  lastSearchSuggestion,
                                                  builder: (context,
                                                      lastSearchList,
                                                      child) =>
                                                  pickupLocationList.isEmpty &&
                                                      lastSearchList.isNotEmpty
                                                      ? Column(
                                                    mainAxisSize:
                                                    MainAxisSize.min,
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                    children: [
                                                      for (int i = 0; i < lastSearchList.length; i++)
                                                        Container(
                                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: MyColors.textFillThemeColor()))),
                                                          child: GestureDetector(
                                                            onTap: () async {
                                                              showLoading();
                                                              pickupLocation['controller'].text = lastSearchList[i]['pickup']['address'];
                                                              pickUpAddress.value = lastSearchList[i]['pickup']['address'];
                                                              pickupLocation['lat'] = lastSearchList[i]['pickup']['lat'];
                                                              pickupLocation['lng'] = lastSearchList[i]['pickup']['lng'];
                                                              pickupLocationSuggestion.value = [];
                                                              dropLocationPickerHideNoti.value = false;
                                                              pickupLocationPickerHideNoti.value = false;

                                                              // 🔧 FIX: Recentrer la carte et recharger les chauffeurs autour du nouveau pickup
                                                              Provider.of<GoogleMapProvider>(
                                                                  context,
                                                                  listen: false)
                                                                  .controller!
                                                                  .animateCamera(
                                                                CameraUpdate.newCameraPosition(
                                                                  CameraPosition(
                                                                      target: LatLng(
                                                                        pickupLocation['lat'],
                                                                        pickupLocation['lng'],
                                                                      ),
                                                                      zoom: 16.50),
                                                                ),
                                                              );
                                                              if (MyGlobalKeys.homePageKey.currentState != null) {
                                                                await MyGlobalKeys
                                                                    .homePageKey
                                                                    .currentState!
                                                                    .refreshDriversAroundPickup(
                                                                      pickupLocation['lat'],
                                                                      pickupLocation['lng'],
                                                                    );
                                                              }

                                                              if (dropLocation['lat'] != null) {
                                                                // Mise à jour détection aéroport
                                                                _updateAirportDetection();

                                                                // Utiliser _buildLocationMap pour inclure la détection d'aéroport
                                                                var p = _buildLocationMap(pickupLocation);
                                                                var d = _buildLocationMap(dropLocation);

                                                                myCustomLogStatements("pickup location is this ${p} ${d}");
                                                                if (p['lat'] != null && p['lng'] != null && d['lat'] != null && d['lng'] != null) {
                                                                  await DevFestPreferences().setSearchSuggestion({
                                                                    "pickup": p,
                                                                    "drop": d
                                                                  });

                                                                  widget.onTap(p, d);
                                                                }
                                                              }else{
                                                                hideLoading();
                                                              }
                                                            },
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.history_rounded, size: 22, color: MyColors.blackThemeColorWithOpacity(0.7)),
                                                                  hSizedBox,
                                                                  Expanded(
                                                                    child: ParagraphText(
                                                                      "${lastSearchList[i]['pickup']['address']}",
                                                                      fontWeight: FontWeight.w400,
                                                                      color: MyColors.blackThemeColorWithOpacity(0.7),
                                                                      fontSize: 14,
                                                                      maxLines: 2,
                                                                      textOverflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  )
                                                      : Container(),
                                                ),
                                                for (int i = 0;
                                                i <
                                                    pickupLocationList
                                                        .length;
                                                i++)
                                                  Container(
                                                    decoration: BoxDecoration(
                                                        border: Border(
                                                            bottom:
                                                            BorderSide(color: MyColors.textFillThemeColor()))),
                                                    child:
                                                    GestureDetector(
                                                      onTap:
                                                          () async {
                                                        showLoading();
                                                        dropLocationPickerHideNoti
                                                            .value =
                                                        false;
                                                        pickupLocationPickerHideNoti
                                                            .value =
                                                        false;

                                                        pickupLocation[
                                                        'controller']
                                                            .text = pickupLocationList[
                                                        i]
                                                        [
                                                        'description'];
                                                        var address =
                                                        await getLatLngByPlaceId(pickupLocationList[i]
                                                        [
                                                        'place_id']);
                                                        pickupLocation[
                                                        'lat'] = address['result']['geometry']
                                                        [
                                                        'location']
                                                        [
                                                        'lat'];
                                                        pickupLocation[
                                                        'lng'] = address['result']['geometry']
                                                        [
                                                        'location']
                                                        [
                                                        'lng'];
                                                        focusDrop
                                                            .requestFocus();
                                                        pickupLocationSuggestion
                                                            .value = [];

                                                        FocusScope.of(
                                                            context)
                                                            .unfocus();

                                                        pickupLocationPickerHideNoti
                                                            .value =
                                                        true;
                                                        showConfirmPopUp
                                                            .value =
                                                        true;
                                                        dropLocationPickerHideNoti
                                                            .value =
                                                        false;

                                                        Provider.of<GoogleMapProvider>(
                                                            context,
                                                            listen: false)
                                                            .controller!
                                                            .animateCamera(
                                                          CameraUpdate.newCameraPosition(
                                                            CameraPosition(
                                                                target: LatLng(
                                                                  pickupLocation['lat'],
                                                                  pickupLocation['lng'],
                                                                ),
                                                                zoom: 16.50),
                                                          ),
                                                        );

                                                        // 🔧 FIX: Recharger les chauffeurs autour du nouveau pickup
                                                        if (MyGlobalKeys.homePageKey.currentState != null) {
                                                          await MyGlobalKeys
                                                              .homePageKey
                                                              .currentState!
                                                              .refreshDriversAroundPickup(
                                                                pickupLocation['lat'],
                                                                pickupLocation['lng'],
                                                              );

                                                          MyGlobalKeys
                                                              .homePageKey
                                                              .currentState!
                                                              .updateBottomSheetHeight(
                                                              milliseconds: 100);
                                                        }
                                                        hideLoading();
                                                      },
                                                      child:
                                                      Padding(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            vertical:
                                                            8.0),
                                                        child:
                                                        Row(
                                                          children: [
                                                            Icon(
                                                                Icons.location_on_outlined,
                                                                size: 22,
                                                                color: MyColors.blackThemeColorWithOpacity(0.7)),
                                                            hSizedBox,
                                                            Expanded(
                                                              child:
                                                              ParagraphText(
                                                                pickupLocationList[i]['description'],
                                                                fontWeight: FontWeight.w400,
                                                                color: MyColors.blackThemeColorWithOpacity(0.7),
                                                                fontSize: 14,
                                                                maxLines: 2,
                                                                textOverflow: TextOverflow.ellipsis,
                                                              ),
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                    ),
                                  ),
                                  vSizedBox2
                                ],
                              ),
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}