/// Centralise la règle d'arrondi des prix Misy.
///
/// Règle unifiée riderapp ↔ driverapp ↔ web : **ceil au multiple de 500 MGA**.
/// Garantit la cohérence : le rider voit le même prix que le driver propose,
/// jamais 500 Ar de plus à l'arrivée.
class PriceRounding {
  static const int step = 500;

  /// Arrondit vers le haut au multiple de [step] (default 500).
  /// Retourne 0 si [price] est négatif ou nul.
  static double up(double price, {int? customStep}) {
    if (price <= 0) return 0;
    final s = (customStep ?? step).toDouble();
    return (price / s).ceil() * s;
  }
}
