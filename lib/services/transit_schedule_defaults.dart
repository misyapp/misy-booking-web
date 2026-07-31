import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';

/// Horaires du réseau d'Antananarivo, par MODE.
///
/// Pourquoi par mode et pas par ligne : le manifeste ne porte aujourd'hui
/// aucun `schedule` (0 ligne sur 100), et pour les taxi-be il n'existe tout
/// simplement pas d'horaire par ligne — ils partent **à la remplissage**, pas à
/// l'heure. La seule donnée vraie est une amplitude de service commune.
///
/// Une ligne qui porterait son propre `schedule` (renseigné par l'éditeur puis
/// publié dans le bundle) l'emporte toujours : voir [scheduleFor].
///
/// ⚠️ Sources et date de relevé — 31/07/2026. À revérifier, le réseau bouge :
/// - Taxi-be : service ~05h–20h, se raréfiant le soir (CODATU, Wikipédia).
/// - Train urbain : 3 rotations/jour depuis le 24/06/2026 (L'Express, 2424.mg).
///   Soarano → Ambohimanambola et retour, pas de service le dimanche.
/// - Téléphérique : NON RENSEIGNÉ volontairement. L'ouverture d'août 2025 était
///   limitée à 07h–09h et 16h–18h, et le passage à plein régime annoncé pour
///   janvier 2026 n'a pas de source confirmant les horaires réels. Mieux vaut
///   ne rien afficher qu'afficher une amplitude fausse.
class TransitScheduleDefaults {
  TransitScheduleDefaults._();

  /// Amplitude commune des taxi-be. Pas de fréquence : elle dépend du
  /// remplissage et de l'heure, annoncer un chiffre serait inventer.
  static const LineSchedule taxiBe = LineSchedule(
    firstDeparture: '05:00',
    lastDeparture: '20:00',
    notes: 'Départs au remplissage, sans horaire fixe. '
        'Service plus rare en soirée.',
  );

  /// Train urbain Soarano ↔ Ambohimanambola (16 km, 8 gares).
  static const LineSchedule urbanTrain = LineSchedule(
    departures: ['05:30', '13:00', '17:30'],
    saturdayDepartures: ['08:30', '11:30', '16:00'],
    daysOfOperation: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'],
    notes: 'Retours depuis Ambohimanambola : 06h30, 14h00, 18h30 '
        '(samedi : 09h45, 12h45, 17h15). Pas de service le dimanche.',
  );

  /// Horaires applicables à une ligne : les siens s'ils existent, sinon le
  /// défaut de son mode. Renvoie `null` quand on ne sait rien — l'UI n'affiche
  /// alors pas de bloc horaires plutôt que d'inventer.
  static LineSchedule? scheduleFor(LineMetadata? meta) {
    if (meta == null) return null;
    final own = meta.schedule;
    if (own != null && !own.isEmpty) return own;
    switch (meta.transportType) {
      case 'urbanTrain':
        return urbanTrain;
      case 'bus':
        return taxiBe;
      // 'telepherique' inclus : rien de fiable à afficher pour l'instant.
      default:
        return null;
    }
  }

  /// Résumé court pour l'affichage : « Départs 05h30 · 13h00 · 17h30 » ou
  /// « Service 05h–20h ».
  static String? summary(LineSchedule? s) {
    if (s == null || s.isEmpty) return null;
    if (s.departures.isNotEmpty) {
      return 'Départs ${s.departures.map(_hm).join(' · ')}';
    }
    final a = s.firstDeparture, b = s.lastDeparture;
    if (a != null && b != null) return 'Service ${_hm(a)} – ${_hm(b)}';
    if (s.frequencyMin != null) return 'Toutes les ${s.frequencyMin} min';
    return null;
  }

  static String _hm(String hhmm) => hhmm.replaceFirst(':', 'h');
}
