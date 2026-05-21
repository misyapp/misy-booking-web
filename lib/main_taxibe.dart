import 'package:rider_ride_hailing_app/contants/build_mode.dart';
import 'package:rider_ride_hailing_app/main.dart' as booking;

/// Entry point pour taxibe.misy.app — site dédié au transport en commun
/// (et aux outils editor / admin associés). Réutilise tout le boot de
/// [booking.bootstrap] : init Firebase, providers, MaterialApp. Le flag
/// [BuildModeFlag.current = BuildMode.taxibe] est posé en amont pour que
/// les écrans partagés (home_screen_web notamment) adaptent leur UI.
///
/// Build :
///   flutter build web --release --target lib/main_taxibe.dart
void main() {
  BuildModeFlag.current = BuildMode.taxibe;
  booking.bootstrap();
}
