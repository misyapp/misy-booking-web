/// Catégorisation des véhicules pour le tracking analytics moto / VTC.
///
/// Source de vérité primaire : whitelist d'IDs Firestore (collection
/// `vehicleType` du projet `misy-95336`). Fallback regex sur le nom pour
/// catcher les nouveaux types moto avant que la liste ne soit mise à jour.
///
/// Utilisé exclusivement par `AnalyticsService` pour distinguer les events
/// `moto_ride_booked` / `vtc_ride_booked`. Ne pas utiliser pour de la logique
/// métier (pricing, matching, etc.) — c'est purement de l'instrumentation.
class VehicleCategories {
  /// Whitelist d'IDs Firestore — source de vérité primaire.
  /// Snapshot prod 2026-05-11 : seul `misy Moto` (`b1ecd4da2820438bb565`).
  static const List<String> motoIds = ['b1ecd4da2820438bb565'];

  /// Regex de secours — catche les nouveaux types moto avant que la liste
  /// soit mise à jour. Bornes `\b` pour éviter les faux positifs
  /// (ex: "Comoto" ne matche pas, "Moto Premium" matche).
  static final RegExp motoNameFallback = RegExp(
    r'\b(moto|scooter)\b',
    caseSensitive: false,
  );

  /// Retourne `true` si le véhicule est de catégorie moto.
  static bool isMoto({required String id, required String name}) {
    if (id.isNotEmpty && motoIds.contains(id)) return true;
    if (name.isNotEmpty && motoNameFallback.hasMatch(name)) return true;
    return false;
  }
}
