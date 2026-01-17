import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/pickup_and_drop_location_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/choose_vehicle_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/select_payment_method_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/confirm_destination.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen.dart';

class MyGlobalKeys {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // 🔧 FIX: Utiliser un getter avec une variable réinitialisable
  // pour éviter l'erreur "Duplicate GlobalKey" lors de la reconnexion
  static GlobalKey<HomeScreenState> _homePageKey = GlobalKey<HomeScreenState>();
  static GlobalKey<HomeScreenState> get homePageKey => _homePageKey;

  /// Réinitialise la GlobalKey du HomeScreen.
  /// À appeler avant de créer une nouvelle instance de MainNavigationScreen
  /// (ex: après login, après sortie du mode invité)
  static void resetHomePageKey() {
    _homePageKey = GlobalKey<HomeScreenState>();
  }
  static final GlobalKey<PickupAndDropLocationState>
      chooseDropAndPickAddPageKey = GlobalKey<PickupAndDropLocationState>();
  static final GlobalKey<State<ChooseVehicle>>
      chooseVehiclePageKey = GlobalKey<State<ChooseVehicle>>();
  static final GlobalKey<State<SelectPaymentMethod>>
      selectPaymentMethodPageKey = GlobalKey<State<SelectPaymentMethod>>();
  static final GlobalKey<State<ConfirmDestination>>
      confirmDestinationPageKey = GlobalKey<State<ConfirmDestination>>();
}
