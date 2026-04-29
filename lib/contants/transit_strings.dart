/// i18n trilingue dédiée au nouvel onglet "Transport en commun".
///
/// Le legacy `MultiLangStrings.frenchStrings` reste FR-only — migration au cas
/// par cas plus tard. Ici, **toutes** les clés sont présentes dans les 3
/// langues. Pas de fallback FR : si une clé manque dans une langue, c'est un
/// bug à fixer immédiatement.
///
/// Usage côté UI :
/// ```dart
/// final locale = context.watch<LocaleProvider>().locale;
/// Text(TransitStrings.t('lines.title', locale));
/// ```
library;

enum AppLocale { fr, mg, en }

class TransitStrings {
  TransitStrings._();

  static const Map<String, Map<AppLocale, String>> _strings = {
    // ───────── Switcher de langue ─────────
    'lang.fr': {
      AppLocale.fr: 'Français',
      AppLocale.mg: 'Frantsay',
      AppLocale.en: 'French',
    },
    'lang.mg': {
      AppLocale.fr: 'Malagasy',
      AppLocale.mg: 'Malagasy',
      AppLocale.en: 'Malagasy',
    },
    'lang.en': {
      AppLocale.fr: 'Anglais',
      AppLocale.mg: 'Anglisy',
      AppLocale.en: 'English',
    },

    // ───────── Toggle modes ─────────
    'mode.course': {
      AppLocale.fr: 'Course',
      AppLocale.mg: 'Diabe',
      AppLocale.en: 'Ride',
    },
    'mode.public': {
      AppLocale.fr: 'Transport en commun',
      AppLocale.mg: 'Fitaterana iombonana',
      AppLocale.en: 'Public transport',
    },

    // ───────── Sidebar Transport — header ─────────
    'transit.title': {
      AppLocale.fr: 'Réseau taxi-be',
      AppLocale.mg: 'Tambazotra taxi-be',
      AppLocale.en: 'Taxi-be network',
    },
    'transit.subtitle': {
      AppLocale.fr: 'Antananarivo',
      AppLocale.mg: 'Antananarivo',
      AppLocale.en: 'Antananarivo',
    },

    // ───────── Liste des lignes ─────────
    'lines.title': {
      AppLocale.fr: 'Lignes',
      AppLocale.mg: 'Tsipika',
      AppLocale.en: 'Lines',
    },
    'lines.count': {
      AppLocale.fr: 'lignes validées',
      AppLocale.mg: 'tsipika voamarina',
      AppLocale.en: 'validated lines',
    },
    'lines.empty': {
      AppLocale.fr:
          'Aucune ligne validée pour le moment. Le réseau s\'enrichit progressivement à mesure que les consultants terrain valident les tracés.',
      AppLocale.mg:
          'Mbola tsy misy tsipika voamarina. Hihamaro tsikelikely ny tambazotra.',
      AppLocale.en:
          'No validated lines yet. The network grows as field consultants validate routes.',
    },
    'lines.tap.hint': {
      AppLocale.fr: 'Touchez une ligne pour la mettre en évidence',
      AppLocale.mg: 'Tendreo ny tsipika iray hampiseho azy',
      AppLocale.en: 'Tap a line to highlight it',
    },
    'lines.show.all': {
      AppLocale.fr: 'Voir toutes les lignes',
      AppLocale.mg: 'Asehoy daholo ny tsipika',
      AppLocale.en: 'Show all lines',
    },
    'lines.line.label': {
      AppLocale.fr: 'Ligne',
      AppLocale.mg: 'Tsipika',
      AppLocale.en: 'Line',
    },
    'lines.stops.short': {
      AppLocale.fr: 'arrêts',
      AppLocale.mg: 'fiantsonana',
      AppLocale.en: 'stops',
    },

    // ───────── États ─────────
    'state.loading': {
      AppLocale.fr: 'Chargement…',
      AppLocale.mg: 'Mampiditra…',
      AppLocale.en: 'Loading…',
    },
    'state.error': {
      AppLocale.fr: 'Erreur de chargement',
      AppLocale.mg: 'Tsy nahomby ny fampidirana',
      AppLocale.en: 'Loading failed',
    },
    'state.retry': {
      AppLocale.fr: 'Réessayer',
      AppLocale.mg: 'Andramo indray',
      AppLocale.en: 'Retry',
    },
  };

  /// Récupère la traduction d'une clé. Throw assert en debug si la clé ou la
  /// locale manque — on veut savoir tout de suite, pas un fallback silencieux.
  static String t(String key, AppLocale locale) {
    final entry = _strings[key];
    assert(entry != null, 'TransitStrings: clé inconnue "$key"');
    final value = entry?[locale];
    assert(
      value != null,
      'TransitStrings: clé "$key" manque en ${locale.name}',
    );
    return value ?? key;
  }
}
