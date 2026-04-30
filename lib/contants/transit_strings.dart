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
      AppLocale.fr: 'lignes',
      AppLocale.mg: 'tsipika',
      AppLocale.en: 'lines',
    },
    'lines.empty': {
      AppLocale.fr:
          'Le réseau est en cours de chargement. Réessayez dans un instant.',
      AppLocale.mg:
          'Mbola eo ampampidirana ny tambazotra. Andramo indray.',
      AppLocale.en:
          'Network is loading. Please try again shortly.',
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

    // ───────── Branches (plan tramway) ─────────
    'branch.aller': {
      AppLocale.fr: 'Aller',
      AppLocale.mg: 'Mandeha',
      AppLocale.en: 'Outbound',
    },
    'branch.retour': {
      AppLocale.fr: 'Retour',
      AppLocale.mg: 'Miverina',
      AppLocale.en: 'Return',
    },
    'branch.toward': {
      AppLocale.fr: 'vers',
      AppLocale.mg: 'mankany',
      AppLocale.en: 'toward',
    },

    // ───────── Calculateur d'itinéraire ─────────
    'route.title': {
      AppLocale.fr: 'Itinéraire',
      AppLocale.mg: 'Lalana',
      AppLocale.en: 'Route',
    },
    'route.origin.placeholder': {
      AppLocale.fr: 'Départ',
      AppLocale.mg: 'Fiandohana',
      AppLocale.en: 'From',
    },
    'route.destination.placeholder': {
      AppLocale.fr: 'Arrivée',
      AppLocale.mg: 'Fahatongavana',
      AppLocale.en: 'To',
    },
    'route.calculate': {
      AppLocale.fr: 'Lancer la recherche',
      AppLocale.mg: 'Hikaroka',
      AppLocale.en: 'Search',
    },
    'route.modify': {
      AppLocale.fr: 'Modifier la recherche',
      AppLocale.mg: 'Hanova',
      AppLocale.en: 'Modify search',
    },
    'route.when.label': {
      AppLocale.fr: 'QUAND',
      AppLocale.mg: 'OVIANA',
      AppLocale.en: 'WHEN',
    },
    'route.when.depart': {
      AppLocale.fr: 'Partir à',
      AppLocale.mg: 'Hiainga amin\'ny',
      AppLocale.en: 'Leave at',
    },
    'route.when.arrive': {
      AppLocale.fr: 'Arriver à',
      AppLocale.mg: 'Tonga amin\'ny',
      AppLocale.en: 'Arrive by',
    },
    'route.when.now': {
      AppLocale.fr: 'Maintenant',
      AppLocale.mg: 'Izao',
      AppLocale.en: 'Now',
    },
    'route.when.today': {
      AppLocale.fr: 'Aujourd\'hui',
      AppLocale.mg: 'Androany',
      AppLocale.en: 'Today',
    },
    'route.when.tomorrow': {
      AppLocale.fr: 'Demain',
      AppLocale.mg: 'Rahampitso',
      AppLocale.en: 'Tomorrow',
    },
    'route.calculating': {
      AppLocale.fr: 'Calcul en cours…',
      AppLocale.mg: 'Eo ampandinihana…',
      AppLocale.en: 'Calculating…',
    },
    'route.my.location': {
      AppLocale.fr: 'Ma position',
      AppLocale.mg: 'Misy aho',
      AppLocale.en: 'My location',
    },
    'route.swap': {
      AppLocale.fr: 'Inverser départ et arrivée',
      AppLocale.mg: 'Hifamadika',
      AppLocale.en: 'Swap origin and destination',
    },
    'route.no.results': {
      AppLocale.fr: 'Aucun itinéraire trouvé entre ces 2 points.',
      AppLocale.mg: 'Tsy nahitana lalana eo amin\'ireo toerana ireo.',
      AppLocale.en: 'No route found between these 2 points.',
    },
    'route.transfers.zero': {
      AppLocale.fr: 'Direct',
      AppLocale.mg: 'Mivantana',
      AppLocale.en: 'Direct',
    },
    'route.transfer.one': {
      AppLocale.fr: '1 correspondance',
      AppLocale.mg: '1 fifindrana',
      AppLocale.en: '1 transfer',
    },
    'route.transfers.many': {
      AppLocale.fr: 'correspondances',
      AppLocale.mg: 'fifindrana',
      AppLocale.en: 'transfers',
    },
    'route.minutes.short': {
      AppLocale.fr: 'min',
      AppLocale.mg: 'min',
      AppLocale.en: 'min',
    },
    'route.walking': {
      AppLocale.fr: 'min de marche',
      AppLocale.mg: 'min an-tongotra',
      AppLocale.en: 'min walking',
    },
    'route.step.walk.to': {
      AppLocale.fr: 'Marcher vers',
      AppLocale.mg: 'Mandeha amin\'ny',
      AppLocale.en: 'Walk to',
    },
    'route.step.walk.dest': {
      AppLocale.fr: 'Marcher vers la destination',
      AppLocale.mg: 'Mandeha mankany amin\'ny tanjona',
      AppLocale.en: 'Walk to destination',
    },
    'route.step.transport': {
      AppLocale.fr: 'Prendre la ligne',
      AppLocale.mg: 'Raiso ny tsipika',
      AppLocale.en: 'Take line',
    },
    'route.step.toward': {
      AppLocale.fr: 'direction',
      AppLocale.mg: 'mankany',
      AppLocale.en: 'toward',
    },
    'route.step.descend': {
      AppLocale.fr: 'Descendre à',
      AppLocale.mg: 'Midina amin\'ny',
      AppLocale.en: 'Get off at',
    },

    // ───────── Diagramme réseau ─────────
    'network.button': {
      AppLocale.fr: 'Réseau',
      AppLocale.mg: 'Tambazotra',
      AppLocale.en: 'Network',
    },
    'network.title': {
      AppLocale.fr: 'Réseau taxi-be · Antananarivo',
      AppLocale.mg: 'Tambazotra taxi-be · Antananarivo',
      AppLocale.en: 'Taxi-be network · Antananarivo',
    },
    'network.close': {
      AppLocale.fr: 'Fermer',
      AppLocale.mg: 'Hidio',
      AppLocale.en: 'Close',
    },

    // ───────── Stop card ─────────
    'stop.lines.served': {
      AppLocale.fr: 'Lignes desservant cet arrêt',
      AppLocale.mg: 'Tsipika mandalo eto',
      AppLocale.en: 'Lines serving this stop',
    },
    'stop.close': {
      AppLocale.fr: 'Fermer',
      AppLocale.mg: 'Hidio',
      AppLocale.en: 'Close',
    },
    'stop.unnamed': {
      AppLocale.fr: 'Arrêt sans nom',
      AppLocale.mg: 'Fiantsonana tsy misy anarana',
      AppLocale.en: 'Unnamed stop',
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
