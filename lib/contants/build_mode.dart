/// Mode de build courant : booking (default) ou taxibe.
///
/// Set par [main_taxibe.dart] avant l'appel à [bootstrap]. Les écrans
/// partagés (home_screen_web notamment) lisent ce flag pour adapter leur
/// UI : taxibe.misy.app force le mode transport public et masque le
/// toggle / la recherche booking.
enum BuildMode { booking, taxibe }

class BuildModeFlag {
  BuildModeFlag._();
  static BuildMode current = BuildMode.booking;
  static bool get isTaxibe => current == BuildMode.taxibe;
  static bool get isBooking => current == BuildMode.booking;
}
