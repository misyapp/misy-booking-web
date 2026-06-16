/// i18n SIX langues : onglet "Transport en commun" + écrans web (clés `web.*`).
///
/// Le legacy `MultiLangStrings` (FR/EN/MG/IT/PL, 954 clés) reste réservé au
/// mobile — migration au cas par cas plus tard. Ici, toutes les clés doivent
/// exister dans les 6 langues (assert en debug) ; en release, repli FR.
///
/// Langues alignées sur le site vitrine (fr/en/it/pl/de/mg — touristes
/// IT (Neos Nosy Be), PL (charters Itaka), DE (hubs Istanbul/Dubaï)).
///
/// Usage côté UI :
/// ```dart
/// final locale = context.watch<LocaleProvider>().locale;
/// Text(TransitStrings.t('lines.title', locale));
/// ```
library;

enum AppLocale { fr, mg, en, it, pl, de }

class TransitStrings {
  TransitStrings._();

  static const Map<String, Map<AppLocale, String>> _strings = {
    // ───────── Switcher de langue ─────────
    'lang.fr': {
      AppLocale.fr: 'Français',
      AppLocale.mg: 'Frantsay',
      AppLocale.en: 'French',
      AppLocale.it: 'Francese',
      AppLocale.pl: 'Francuski',
      AppLocale.de: 'Französisch',
    },
    'lang.mg': {
      AppLocale.fr: 'Malagasy',
      AppLocale.mg: 'Malagasy',
      AppLocale.en: 'Malagasy',
      AppLocale.it: 'Malgascio',
      AppLocale.pl: 'Malgaski',
      AppLocale.de: 'Madagassisch',
    },
    'lang.en': {
      AppLocale.fr: 'Anglais',
      AppLocale.mg: 'Anglisy',
      AppLocale.en: 'English',
      AppLocale.it: 'Inglese',
      AppLocale.pl: 'Angielski',
      AppLocale.de: 'Englisch',
    },
    // Noms natifs invariants pour les nouvelles langues (plus clairs dans un
    // sélecteur que des exonymes traduits).
    'lang.it': {
      AppLocale.fr: 'Italiano',
      AppLocale.mg: 'Italiano',
      AppLocale.en: 'Italiano',
      AppLocale.it: 'Italiano',
      AppLocale.pl: 'Italiano',
      AppLocale.de: 'Italiano',
    },
    'lang.pl': {
      AppLocale.fr: 'Polski',
      AppLocale.mg: 'Polski',
      AppLocale.en: 'Polski',
      AppLocale.it: 'Polski',
      AppLocale.pl: 'Polski',
      AppLocale.de: 'Polski',
    },
    'lang.de': {
      AppLocale.fr: 'Deutsch',
      AppLocale.mg: 'Deutsch',
      AppLocale.en: 'Deutsch',
      AppLocale.it: 'Deutsch',
      AppLocale.pl: 'Deutsch',
      AppLocale.de: 'Deutsch',
    },

    // ───────── Toggle modes ─────────
    'mode.course': {
      AppLocale.fr: 'Course',
      AppLocale.mg: 'Diabe',
      AppLocale.en: 'Ride',
      AppLocale.it: 'Corsa',
      AppLocale.pl: 'Przejazd',
      AppLocale.de: 'Fahrt',
    },
    'mode.public': {
      AppLocale.fr: 'Transport en commun',
      AppLocale.mg: 'Fitaterana iombonana',
      AppLocale.en: 'Public transport',
      AppLocale.it: 'Trasporto pubblico',
      AppLocale.pl: 'Transport publiczny',
      AppLocale.de: 'Öffentlicher Verkehr',
    },
    // Bouton de retour vers la course quand le mode TC a été ouvert depuis
    // la tuile « Transport en commun » du choix de véhicule.
    'panel.backToCourse': {
      AppLocale.fr: 'Revenir à la course (voiture, moto…)',
      AppLocale.mg: 'Hiverina amin\'ny diabe (fiara, môtô…)',
      AppLocale.en: 'Back to your ride (car, bike…)',
      AppLocale.it: 'Torna alla corsa (auto, moto…)',
      AppLocale.pl: 'Wróć do przejazdu (auto, motor…)',
      AppLocale.de: 'Zurück zur Fahrt (Auto, Motorrad…)',
    },

    // ───────── Écrans web (ex-strings codées en dur) ─────────
    'web.chooseVehicle': {
      AppLocale.fr: 'Choisir un véhicule',
      AppLocale.mg: 'Safidio ny fiara',
      AppLocale.en: 'Choose a vehicle',
      AppLocale.it: 'Scegli un veicolo',
      AppLocale.pl: 'Wybierz pojazd',
      AppLocale.de: 'Fahrzeug wählen',
    },
    'web.order': {
      AppLocale.fr: 'Commander',
      AppLocale.mg: 'Hanafatra',
      AppLocale.en: 'Order',
      AppLocale.it: 'Prenota',
      AppLocale.pl: 'Zamów',
      AppLocale.de: 'Bestellen',
    },
    // Réservation à l'avance imposée hors Antananarivo (chauffeurs pas encore
    // présents en instantané) — cf. flag geo-zone webInstantBookingEnabled.
    'web.chooseSlot': {
      AppLocale.fr: 'Choisir un créneau',
      AppLocale.mg: 'Misafidiana fotoana',
      AppLocale.en: 'Pick a time',
      AppLocale.it: 'Scegli un orario',
      AppLocale.pl: 'Wybierz termin',
      AppLocale.de: 'Zeit wählen',
    },
    'web.scheduledOnlyNotice': {
      AppLocale.fr: 'Ici, réservez votre course à l\'avance — un chauffeur vous sera attribué.',
      AppLocale.mg: 'Eto, mamandrika ny dianao mialoha — hmisy mpamily homena anao.',
      AppLocale.en: 'Here, book your ride in advance — a driver will be assigned to you.',
      AppLocale.it: 'Qui, prenota la corsa in anticipo — ti verrà assegnato un autista.',
      AppLocale.pl: 'Tutaj zarezerwuj przejazd z wyprzedzeniem — kierowca zostanie przydzielony.',
      AppLocale.de: 'Hier die Fahrt im Voraus buchen — ein Fahrer wird zugewiesen.',
    },
    'web.transitTileSub': {
      AppLocale.fr: 'Taxi-be — voir l\'itinéraire',
      AppLocale.mg: 'Taxi-be — jereo ny lalana',
      AppLocale.en: 'Taxi-be — see the route',
      AppLocale.it: 'Taxi-be — vedi il percorso',
      AppLocale.pl: 'Taxi-be — zobacz trasę',
      AppLocale.de: 'Taxi-be — Route ansehen',
    },
    'web.signIn': {
      AppLocale.fr: 'Connexion',
      AppLocale.mg: 'Hiditra',
      AppLocale.en: 'Sign in',
      AppLocale.it: 'Accedi',
      AppLocale.pl: 'Zaloguj się',
      AppLocale.de: 'Anmelden',
    },
    'web.signUp': {
      AppLocale.fr: 'S\'inscrire',
      AppLocale.mg: 'Hisoratra anarana',
      AppLocale.en: 'Sign up',
      AppLocale.it: 'Registrati',
      AppLocale.pl: 'Zarejestruj się',
      AppLocale.de: 'Registrieren',
    },
    'web.signOut': {
      AppLocale.fr: 'Se déconnecter',
      AppLocale.mg: 'Hivoaka',
      AppLocale.en: 'Sign out',
      AppLocale.it: 'Esci',
      AppLocale.pl: 'Wyloguj się',
      AppLocale.de: 'Abmelden',
    },
    // ── Menu compte web (refonte façon Uber) ──────────────────────────
    'web.activity': {
      AppLocale.fr: 'Activité',
      AppLocale.mg: 'Tantara',
      AppLocale.en: 'Activity',
      AppLocale.it: 'Attività',
      AppLocale.pl: 'Aktywność',
      AppLocale.de: 'Aktivität',
    },
    'web.wallet': {
      AppLocale.fr: 'Portefeuille',
      AppLocale.mg: 'Kitapom-bola',
      AppLocale.en: 'Wallet',
      AppLocale.it: 'Portafoglio',
      AppLocale.pl: 'Portfel',
      AppLocale.de: 'Wallet',
    },
    'web.help': {
      AppLocale.fr: 'Aide',
      AppLocale.mg: 'Fanampiana',
      AppLocale.en: 'Help',
      AppLocale.it: 'Aiuto',
      AppLocale.pl: 'Pomoc',
      AppLocale.de: 'Hilfe',
    },
    'web.account': {
      AppLocale.fr: 'Compte',
      AppLocale.mg: 'Kaonty',
      AppLocale.en: 'Account',
      AppLocale.it: 'Account',
      AppLocale.pl: 'Konto',
      AppLocale.de: 'Konto',
    },
    'web.manageAccount': {
      AppLocale.fr: 'Gérer le compte',
      AppLocale.mg: 'Hitantana ny kaonty',
      AppLocale.en: 'Manage account',
      AppLocale.it: 'Gestisci account',
      AppLocale.pl: 'Zarządzaj kontem',
      AppLocale.de: 'Konto verwalten',
    },
    'web.fieldEditor': {
      AppLocale.fr: 'Éditeur terrain',
      AppLocale.mg: 'Mpanova lalana',
      AppLocale.en: 'Field editor',
      AppLocale.it: 'Editor sul campo',
      AppLocale.pl: 'Edytor terenowy',
      AppLocale.de: 'Streckeneditor',
    },
    'web.settings': {
      AppLocale.fr: 'Paramètres',
      AppLocale.mg: 'Fandrindrana',
      AppLocale.en: 'Settings',
      AppLocale.it: 'Impostazioni',
      AppLocale.pl: 'Ustawienia',
      AppLocale.de: 'Einstellungen',
    },
    'web.appearance': {
      AppLocale.fr: 'Apparence',
      AppLocale.mg: 'Endrika',
      AppLocale.en: 'Appearance',
      AppLocale.it: 'Aspetto',
      AppLocale.pl: 'Wygląd',
      AppLocale.de: 'Darstellung',
    },
    'web.darkMode': {
      AppLocale.fr: 'Mode sombre',
      AppLocale.mg: 'Endrika maizina',
      AppLocale.en: 'Dark mode',
      AppLocale.it: 'Modalità scura',
      AppLocale.pl: 'Tryb ciemny',
      AppLocale.de: 'Dunkelmodus',
    },
    'web.language': {
      AppLocale.fr: 'Langue',
      AppLocale.mg: 'Fiteny',
      AppLocale.en: 'Language',
      AppLocale.it: 'Lingua',
      AppLocale.pl: 'Język',
      AppLocale.de: 'Sprache',
    },
    'web.date': {
      AppLocale.fr: 'Date',
      AppLocale.mg: 'Daty',
      AppLocale.en: 'Date',
      AppLocale.it: 'Data',
      AppLocale.pl: 'Data',
      AppLocale.de: 'Datum',
    },
    'web.time': {
      AppLocale.fr: 'Heure',
      AppLocale.mg: 'Ora',
      AppLocale.en: 'Time',
      AppLocale.it: 'Ora',
      AppLocale.pl: 'Godzina',
      AppLocale.de: 'Uhrzeit',
    },
    'web.scheduleRide': {
      AppLocale.fr: 'Planifier la course',
      AppLocale.mg: 'Handamina ny dia',
      AppLocale.en: 'Schedule the ride',
      AppLocale.it: 'Programma la corsa',
      AppLocale.pl: 'Zaplanuj przejazd',
      AppLocale.de: 'Fahrt planen',
    },
    'web.errLocation': {
      AppLocale.fr: 'Erreur lors de la localisation',
      AppLocale.mg: 'Nisy olana ny fitadiavana ny toerana misy anao',
      AppLocale.en: 'Could not get your location',
      AppLocale.it: 'Impossibile rilevare la posizione',
      AppLocale.pl: 'Nie udało się ustalić lokalizacji',
      AppLocale.de: 'Standort konnte nicht ermittelt werden',
    },
    'web.errCreateRide': {
      AppLocale.fr: 'Erreur lors de la création de la course',
      AppLocale.mg: 'Nisy olana tamin\'ny famoronana ny dia',
      AppLocale.en: 'Could not create the ride',
      AppLocale.it: 'Impossibile creare la corsa',
      AppLocale.pl: 'Nie udało się utworzyć przejazdu',
      AppLocale.de: 'Fahrt konnte nicht erstellt werden',
    },
    'web.authGoogle': {
      AppLocale.fr: 'Connexion avec Google...',
      AppLocale.mg: 'Fidirana amin\'ny Google...',
      AppLocale.en: 'Signing in with Google...',
      AppLocale.it: 'Accesso con Google...',
      AppLocale.pl: 'Logowanie przez Google...',
      AppLocale.de: 'Anmeldung mit Google...',
    },
    'web.authFacebook': {
      AppLocale.fr: 'Connexion avec Facebook...',
      AppLocale.mg: 'Fidirana amin\'ny Facebook...',
      AppLocale.en: 'Signing in with Facebook...',
      AppLocale.it: 'Accesso con Facebook...',
      AppLocale.pl: 'Logowanie przez Facebook...',
      AppLocale.de: 'Anmeldung mit Facebook...',
    },
    // Singulier de lines.stops.short (« 1 arrêt » vs « 3 arrêts »).
    'lines.stops.one': {
      AppLocale.fr: 'arrêt',
      AppLocale.mg: 'fiantsonana',
      AppLocale.en: 'stop',
      AppLocale.it: 'fermata',
      AppLocale.pl: 'przystanek',
      AppLocale.de: 'Halt',
    },

    // ───────── Sidebar Transport — header ─────────
    'transit.title': {
      AppLocale.fr: 'Réseau taxi-be',
      AppLocale.mg: 'Tambazotra taxi-be',
      AppLocale.en: 'Taxi-be network',
      AppLocale.it: 'Rete taxi-be',
      AppLocale.pl: 'Sieć taxi-be',
      AppLocale.de: 'Taxi-be-Netz',
    },
    'transit.subtitle': {
      AppLocale.fr: 'Antananarivo',
      AppLocale.mg: 'Antananarivo',
      AppLocale.en: 'Antananarivo',
      AppLocale.it: 'Antananarivo',
      AppLocale.pl: 'Antananarivo',
      AppLocale.de: 'Antananarivo',
    },

    // ───────── Liste des lignes ─────────
    'lines.title': {
      AppLocale.fr: 'Lignes',
      AppLocale.mg: 'Tsipika',
      AppLocale.en: 'Lines',
      AppLocale.it: 'Linee',
      AppLocale.pl: 'Linie',
      AppLocale.de: 'Linien',
    },
    'lines.count': {
      AppLocale.fr: 'lignes',
      AppLocale.mg: 'tsipika',
      AppLocale.en: 'lines',
      AppLocale.it: 'linee',
      AppLocale.pl: 'linii',
      AppLocale.de: 'Linien',
    },
    'lines.empty': {
      AppLocale.fr:
          'Le réseau est en cours de chargement. Réessayez dans un instant.',
      AppLocale.mg:
          'Mbola eo am-pampidirana ny tambazotra. Andramo indray.',
      AppLocale.en:
          'Network is loading. Please try again shortly.',
      AppLocale.it:
          'La rete è in caricamento. Riprova tra un istante.',
      AppLocale.pl:
          'Sieć się ładuje. Spróbuj ponownie za chwilę.',
      AppLocale.de:
          'Das Netz wird geladen. Bitte versuchen Sie es gleich erneut.',
    },
    'lines.tap.hint': {
      AppLocale.fr: 'Touchez une ligne pour la mettre en évidence',
      AppLocale.mg: 'Tendreo ny tsipika iray hampiseho azy',
      AppLocale.en: 'Tap a line to highlight it',
      AppLocale.it: 'Tocca una linea per evidenziarla',
      AppLocale.pl: 'Dotknij linię, aby ją wyróżnić',
      AppLocale.de: 'Tippen Sie auf eine Linie, um sie hervorzuheben',
    },
    'lines.show.all': {
      AppLocale.fr: 'Voir toutes les lignes',
      AppLocale.mg: 'Asehoy daholo ny tsipika',
      AppLocale.en: 'Show all lines',
      AppLocale.it: 'Mostra tutte le linee',
      AppLocale.pl: 'Pokaż wszystkie linie',
      AppLocale.de: 'Alle Linien anzeigen',
    },
    'lines.line.label': {
      AppLocale.fr: 'Ligne',
      AppLocale.mg: 'Tsipika',
      AppLocale.en: 'Line',
      AppLocale.it: 'Linea',
      AppLocale.pl: 'Linia',
      AppLocale.de: 'Linie',
    },
    'lines.stops.short': {
      AppLocale.fr: 'arrêts',
      AppLocale.mg: 'fiantsonana',
      AppLocale.en: 'stops',
      AppLocale.it: 'fermate',
      AppLocale.pl: 'przystanki',
      AppLocale.de: 'Halte',
    },

    // ───────── Branches (plan tramway) ─────────
    'branch.aller': {
      AppLocale.fr: 'Aller',
      AppLocale.mg: 'Mandeha',
      AppLocale.en: 'Outbound',
      AppLocale.it: 'Andata',
      AppLocale.pl: 'Tam',
      AppLocale.de: 'Hinfahrt',
    },
    'branch.retour': {
      AppLocale.fr: 'Retour',
      AppLocale.mg: 'Miverina',
      AppLocale.en: 'Return',
      AppLocale.it: 'Ritorno',
      AppLocale.pl: 'Powrót',
      AppLocale.de: 'Rückfahrt',
    },
    'branch.toward': {
      AppLocale.fr: 'vers',
      AppLocale.mg: 'mankany',
      AppLocale.en: 'toward',
      AppLocale.it: 'verso',
      AppLocale.pl: 'w kierunku',
      AppLocale.de: 'Richtung',
    },

    // ───────── Calculateur d'itinéraire ─────────
    'route.title': {
      AppLocale.fr: 'Itinéraire',
      AppLocale.mg: 'Lalana',
      AppLocale.en: 'Route',
      AppLocale.it: 'Percorso',
      AppLocale.pl: 'Trasa',
      AppLocale.de: 'Route',
    },
    'route.origin.placeholder': {
      AppLocale.fr: 'Départ',
      AppLocale.mg: 'Fiandohana',
      AppLocale.en: 'From',
      AppLocale.it: 'Partenza',
      AppLocale.pl: 'Skąd',
      AppLocale.de: 'Start',
    },
    'route.destination.placeholder': {
      AppLocale.fr: 'Arrivée',
      AppLocale.mg: 'Fahatongavana',
      AppLocale.en: 'To',
      AppLocale.it: 'Arrivo',
      AppLocale.pl: 'Dokąd',
      AppLocale.de: 'Ziel',
    },
    'route.calculate': {
      AppLocale.fr: 'Lancer la recherche',
      AppLocale.mg: 'Hikaroka',
      AppLocale.en: 'Search',
      AppLocale.it: 'Cerca',
      AppLocale.pl: 'Szukaj',
      AppLocale.de: 'Suchen',
    },
    'route.modify': {
      AppLocale.fr: 'Modifier la recherche',
      AppLocale.mg: 'Hanova',
      AppLocale.en: 'Modify search',
      AppLocale.it: 'Modifica ricerca',
      AppLocale.pl: 'Zmień wyszukiwanie',
      AppLocale.de: 'Suche ändern',
    },
    'route.when.label': {
      AppLocale.fr: 'QUAND',
      AppLocale.mg: 'OVIANA',
      AppLocale.en: 'WHEN',
      AppLocale.it: 'QUANDO',
      AppLocale.pl: 'KIEDY',
      AppLocale.de: 'WANN',
    },
    'route.when.depart': {
      AppLocale.fr: 'Partir à',
      AppLocale.mg: 'Hiainga amin\'ny',
      AppLocale.en: 'Leave at',
      AppLocale.it: 'Partenza alle',
      AppLocale.pl: 'Wyjazd o',
      AppLocale.de: 'Abfahrt um',
    },
    'route.when.arrive': {
      AppLocale.fr: 'Arriver à',
      AppLocale.mg: 'Tonga amin\'ny',
      AppLocale.en: 'Arrive by',
      AppLocale.it: 'Arrivo entro',
      AppLocale.pl: 'Przyjazd do',
      AppLocale.de: 'Ankunft bis',
    },
    'route.when.now': {
      AppLocale.fr: 'Maintenant',
      AppLocale.mg: 'Izao',
      AppLocale.en: 'Now',
      AppLocale.it: 'Adesso',
      AppLocale.pl: 'Teraz',
      AppLocale.de: 'Jetzt',
    },
    'route.when.today': {
      AppLocale.fr: 'Aujourd\'hui',
      AppLocale.mg: 'Androany',
      AppLocale.en: 'Today',
      AppLocale.it: 'Oggi',
      AppLocale.pl: 'Dziś',
      AppLocale.de: 'Heute',
    },
    'route.when.tomorrow': {
      AppLocale.fr: 'Demain',
      AppLocale.mg: 'Rahampitso',
      AppLocale.en: 'Tomorrow',
      AppLocale.it: 'Domani',
      AppLocale.pl: 'Jutro',
      AppLocale.de: 'Morgen',
    },
    'route.calculating': {
      AppLocale.fr: 'Calcul en cours…',
      AppLocale.mg: 'Eo am-pandinihana…',
      AppLocale.en: 'Calculating…',
      AppLocale.it: 'Calcolo in corso…',
      AppLocale.pl: 'Obliczanie…',
      AppLocale.de: 'Wird berechnet…',
    },
    'route.my.location': {
      AppLocale.fr: 'Ma position',
      AppLocale.mg: 'Misy aho',
      AppLocale.en: 'My location',
      AppLocale.it: 'La mia posizione',
      AppLocale.pl: 'Moja lokalizacja',
      AppLocale.de: 'Mein Standort',
    },
    'route.pick.map': {
      AppLocale.fr: 'Choisir le départ sur la carte',
      AppLocale.mg: 'Mifidiana eo amin\'ny sarintany',
      AppLocale.en: 'Pick origin on the map',
      AppLocale.it: 'Scegli la partenza sulla mappa',
      AppLocale.pl: 'Wskaż początek na mapie',
      AppLocale.de: 'Start auf der Karte wählen',
    },
    'route.swap': {
      AppLocale.fr: 'Inverser départ et arrivée',
      AppLocale.mg: 'Hifamadika',
      AppLocale.en: 'Swap origin and destination',
      AppLocale.it: 'Inverti partenza e arrivo',
      AppLocale.pl: 'Zamień początek i cel',
      AppLocale.de: 'Start und Ziel tauschen',
    },
    'route.no.results': {
      AppLocale.fr: 'Aucun itinéraire trouvé entre ces 2 points.',
      AppLocale.mg: 'Tsy nahitana lalana eo amin\'ireo toerana ireo.',
      AppLocale.en: 'No route found between these 2 points.',
      AppLocale.it: 'Nessun percorso trovato tra questi 2 punti.',
      AppLocale.pl: 'Nie znaleziono trasy między tymi 2 punktami.',
      AppLocale.de: 'Keine Route zwischen diesen 2 Punkten gefunden.',
    },
    'route.transfers.zero': {
      AppLocale.fr: 'Direct',
      AppLocale.mg: 'Mivantana',
      AppLocale.en: 'Direct',
      AppLocale.it: 'Diretto',
      AppLocale.pl: 'Bezpośrednio',
      AppLocale.de: 'Direkt',
    },
    'route.transfer.one': {
      AppLocale.fr: '1 correspondance',
      AppLocale.mg: '1 fifindrana',
      AppLocale.en: '1 transfer',
      AppLocale.it: '1 cambio',
      AppLocale.pl: '1 przesiadka',
      AppLocale.de: '1 Umstieg',
    },
    'route.transfers.many': {
      AppLocale.fr: 'correspondances',
      AppLocale.mg: 'fifindrana',
      AppLocale.en: 'transfers',
      AppLocale.it: 'cambi',
      AppLocale.pl: 'przesiadki',
      AppLocale.de: 'Umstiege',
    },
    'route.minutes.short': {
      AppLocale.fr: 'min',
      AppLocale.mg: 'min',
      AppLocale.en: 'min',
      AppLocale.it: 'min',
      AppLocale.pl: 'min',
      AppLocale.de: 'Min.',
    },
    'route.walking': {
      AppLocale.fr: 'min de marche',
      AppLocale.mg: 'min an-tongotra',
      AppLocale.en: 'min walking',
      AppLocale.it: 'min a piedi',
      AppLocale.pl: 'min pieszo',
      AppLocale.de: 'Min. zu Fuß',
    },
    'route.step.walk.to': {
      AppLocale.fr: 'Marcher vers',
      AppLocale.mg: 'Mandeha amin\'ny',
      AppLocale.en: 'Walk to',
      AppLocale.it: 'A piedi verso',
      AppLocale.pl: 'Idź pieszo do',
      AppLocale.de: 'Zu Fuß nach',
    },
    'route.step.walk.dest': {
      AppLocale.fr: 'Marcher vers la destination',
      AppLocale.mg: 'Mandeha mankany amin\'ny tanjona',
      AppLocale.en: 'Walk to destination',
      AppLocale.it: 'A piedi fino all\'arrivo',
      AppLocale.pl: 'Idź pieszo do celu',
      AppLocale.de: 'Zu Fuß zum Ziel',
    },
    'route.step.transport': {
      AppLocale.fr: 'Prendre la ligne',
      AppLocale.mg: 'Raiso ny tsipika',
      AppLocale.en: 'Take line',
      AppLocale.it: 'Prendi la linea',
      AppLocale.pl: 'Wsiądź w linię',
      AppLocale.de: 'Linie nehmen',
    },
    'route.step.toward': {
      AppLocale.fr: 'direction',
      AppLocale.mg: 'mankany',
      AppLocale.en: 'toward',
      AppLocale.it: 'direzione',
      AppLocale.pl: 'kierunek',
      AppLocale.de: 'Richtung',
    },
    'route.step.descend': {
      AppLocale.fr: 'Descendre à',
      AppLocale.mg: 'Midina amin\'ny',
      AppLocale.en: 'Get off at',
      AppLocale.it: 'Scendi a',
      AppLocale.pl: 'Wysiądź na',
      AppLocale.de: 'Aussteigen bei',
    },

    // ───────── Pont vers le flow Course (legs marche longs) ─────────
    'route.replace.with.ride': {
      AppLocale.fr: 'Remplacer par une course Misy',
      AppLocale.mg: 'Soloy diabe Misy',
      AppLocale.en: 'Replace with a Misy ride',
      AppLocale.it: 'Sostituisci con una corsa Misy',
      AppLocale.pl: 'Zamień na przejazd Misy',
      AppLocale.de: 'Durch eine Misy-Fahrt ersetzen',
    },
    'route.replace.with.ride.short': {
      AppLocale.fr: 'Course Misy',
      AppLocale.mg: 'Diabe Misy',
      AppLocale.en: 'Misy ride',
      AppLocale.it: 'Corsa Misy',
      AppLocale.pl: 'Przejazd Misy',
      AppLocale.de: 'Misy-Fahrt',
    },

    // ───────── Diagramme réseau ─────────
    'network.button': {
      AppLocale.fr: 'Réseau',
      AppLocale.mg: 'Tambazotra',
      AppLocale.en: 'Network',
      AppLocale.it: 'Rete',
      AppLocale.pl: 'Sieć',
      AppLocale.de: 'Netz',
    },
    'network.title': {
      AppLocale.fr: 'Réseau taxi-be · Antananarivo',
      AppLocale.mg: 'Tambazotra taxi-be · Antananarivo',
      AppLocale.en: 'Taxi-be network · Antananarivo',
      AppLocale.it: 'Rete taxi-be · Antananarivo',
      AppLocale.pl: 'Sieć taxi-be · Antananarivo',
      AppLocale.de: 'Taxi-be-Netz · Antananarivo',
    },
    'network.close': {
      AppLocale.fr: 'Fermer',
      AppLocale.mg: 'Hidio',
      AppLocale.en: 'Close',
      AppLocale.it: 'Chiudi',
      AppLocale.pl: 'Zamknij',
      AppLocale.de: 'Schließen',
    },
    'network.centre': {
      AppLocale.fr: 'Centre-ville',
      AppLocale.mg: 'Afovoan-tanàna',
      AppLocale.en: 'City centre',
      AppLocale.it: 'Centro città',
      AppLocale.pl: 'Centrum',
      AppLocale.de: 'Stadtzentrum',
    },
    'network.centre.title': {
      AppLocale.fr: 'Centre-ville · Antananarivo',
      AppLocale.mg: 'Afovoan-tanàna · Antananarivo',
      AppLocale.en: 'City centre · Antananarivo',
      AppLocale.it: 'Centro città · Antananarivo',
      AppLocale.pl: 'Centrum · Antananarivo',
      AppLocale.de: 'Stadtzentrum · Antananarivo',
    },

    // ───────── Stop card ─────────
    'stop.lines.served': {
      AppLocale.fr: 'Lignes desservant cet arrêt',
      AppLocale.mg: 'Tsipika mandalo eto',
      AppLocale.en: 'Lines serving this stop',
      AppLocale.it: 'Linee che servono questa fermata',
      AppLocale.pl: 'Linie obsługujące ten przystanek',
      AppLocale.de: 'Linien an diesem Halt',
    },
    'stop.close': {
      AppLocale.fr: 'Fermer',
      AppLocale.mg: 'Hidio',
      AppLocale.en: 'Close',
      AppLocale.it: 'Chiudi',
      AppLocale.pl: 'Zamknij',
      AppLocale.de: 'Schließen',
    },
    'stop.unnamed': {
      AppLocale.fr: 'Arrêt sans nom',
      AppLocale.mg: 'Fiantsonana tsy misy anarana',
      AppLocale.en: 'Unnamed stop',
      AppLocale.it: 'Fermata senza nome',
      AppLocale.pl: 'Przystanek bez nazwy',
      AppLocale.de: 'Unbenannter Halt',
    },
    'stop.line.one': {
      AppLocale.fr: 'ligne',
      AppLocale.mg: 'tsipika',
      AppLocale.en: 'line',
      AppLocale.it: 'linea',
      AppLocale.pl: 'linia',
      AppLocale.de: 'Linie',
    },
    'stop.line.many': {
      AppLocale.fr: 'lignes',
      AppLocale.mg: 'tsipika',
      AppLocale.en: 'lines',
      AppLocale.it: 'linee',
      AppLocale.pl: 'linie',
      AppLocale.de: 'Linien',
    },

    // ───────── États ─────────
    'state.loading': {
      AppLocale.fr: 'Chargement…',
      AppLocale.mg: 'Mampiditra…',
      AppLocale.en: 'Loading…',
      AppLocale.it: 'Caricamento…',
      AppLocale.pl: 'Ładowanie…',
      AppLocale.de: 'Wird geladen…',
    },
    'state.error': {
      AppLocale.fr: 'Erreur de chargement',
      AppLocale.mg: 'Tsy nahomby ny fampidirana',
      AppLocale.en: 'Loading failed',
      AppLocale.it: 'Caricamento non riuscito',
      AppLocale.pl: 'Ładowanie nie powiodło się',
      AppLocale.de: 'Laden fehlgeschlagen',
    },
    'state.retry': {
      AppLocale.fr: 'Réessayer',
      AppLocale.mg: 'Andramo indray',
      AppLocale.en: 'Retry',
      AppLocale.it: 'Riprova',
      AppLocale.pl: 'Spróbuj ponownie',
      AppLocale.de: 'Erneut versuchen',
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
    // Release : repli FR plutôt que d'afficher la clé brute.
    return value ?? entry?[AppLocale.fr] ?? key;
  }
}
