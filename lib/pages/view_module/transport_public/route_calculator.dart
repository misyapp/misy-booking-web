import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:latlong2/latlong.dart' as ll2;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/services/nominatim_service.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';
import 'package:rider_ride_hailing_app/services/transport_osrm_service.dart';

/// Calculateur d'itinéraire multimodal pour le bandeau Transport en commun.
///
/// - 2 champs avec autocomplétion combinée arrêts du bundle + adresses
///   Nominatim. Les arrêts sont en tête avec leurs badges de lignes.
/// - "Ma position" via geoloc browser sur le champ origine.
/// - Inversion ⇅ entre origine et destination.
/// - QUAND : toggle Partir/Arriver, date+heure (UX V1, le moteur ne
///   prend pas l'heure en compte pour l'instant).
/// - Bouton "Lancer la recherche" lance findMultipleRoutes.
///
/// Callbacks vers le parent :
/// - [onPointsChanged] dès que origin ou destination est fixé
///   (pour pan/fit la carte).
/// - [onRouteSelected] quand l'utilisateur tape une card de résultat.
class RouteCalculator extends StatefulWidget {
  /// Appelé avec un itinéraire à mettre en avant sur la carte, ou `null`
  /// pour revenir à l'affichage du réseau complet.
  final ValueChanged<TransportRoute?>? onRouteSelected;
  final void Function(LatLng? origin, LatLng? destination)? onPointsChanged;
  /// Émis quand l'état de visibilité des résultats change. Le panel s'en
  /// sert pour cacher la liste des lignes une fois la recherche lancée.
  final ValueChanged<bool>? onResultsVisibilityChanged;
  /// Notifier pushé par le map.onTap. Le calculateur l'écoute pour
  /// ajuster le DERNIER point posé (origin ou destination) à l'endroit
  /// où l'utilisateur clique sur la carte.
  final ValueListenable<LatLng?>? mapTapNotifier;

  const RouteCalculator({
    super.key,
    this.onRouteSelected,
    this.onPointsChanged,
    this.onResultsVisibilityChanged,
    this.mapTapNotifier,
  });

  @override
  State<RouteCalculator> createState() => _RouteCalculatorState();
}

class _RouteCalculatorState extends State<RouteCalculator> {
  final TextEditingController _originCtrl = TextEditingController();
  final TextEditingController _destCtrl = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  LatLng? _originPos;
  LatLng? _destPos;

  List<TransportRoute> _results = const [];
  bool _calculating = false;
  bool _searched = false; // true dès qu'un calcul a abouti (utile pour
                          // afficher "aucun résultat" plutôt qu'un état vide).
  String? _error;
  /// Index du résultat actuellement déplié (timeline visible). Initialisé
  /// au 1er résultat dès que les routes arrivent, puis modifié au tap.
  int? _expandedResultIdx;

  // Autocomplete state.
  String? _activeField; // 'origin' | 'destination' | null
  List<_Suggestion> _suggestions = const [];
  Timer? _debounce;
  String? _lastFetchedQuery;

  // QUAND.
  bool _isDeparture = true;
  DateTime _scheduledTime = DateTime.now();

  /// Dernier champ qu'un map-tap doit ajuster. Mis à jour quand l'user
  /// pose un point (autocomplete OU map-tap). Permet à l'user de cliquer
  /// sur la carte pour affiner le point qu'il vient de fixer.
  String? _lastAdjustedField;

  @override
  void initState() {
    super.initState();
    _originFocus.addListener(_onFocusChange);
    _destFocus.addListener(_onFocusChange);
    widget.mapTapNotifier?.addListener(_handleMapTap);
    PublicTransportService.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      final activeText = _activeField == 'origin'
          ? _originCtrl.text
          : (_activeField == 'destination' ? _destCtrl.text : '');
      if (activeText.isNotEmpty) {
        setState(() => _refreshSuggestions(activeText));
      }
    });
  }

  @override
  void didUpdateWidget(covariant RouteCalculator old) {
    super.didUpdateWidget(old);
    if (old.mapTapNotifier != widget.mapTapNotifier) {
      old.mapTapNotifier?.removeListener(_handleMapTap);
      widget.mapTapNotifier?.addListener(_handleMapTap);
    }
  }

  @override
  void dispose() {
    widget.mapTapNotifier?.removeListener(_handleMapTap);
    _originCtrl.dispose();
    _destCtrl.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Quand l'user clique sur la carte en mode public, on ajuste le
  /// dernier point posé (`_lastAdjustedField`). Si rien n'a encore été
  /// posé, le clic remplit l'origine par défaut.
  void _handleMapTap() {
    final pos = widget.mapTapNotifier?.value;
    if (pos == null || !mounted) return;
    final target = _lastAdjustedField ??
        (_originPos == null ? 'origin' : 'destination');
    final coordsLabel =
        '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
    setState(() {
      if (target == 'origin') {
        _originPos = pos;
        _originCtrl.text = coordsLabel;
      } else {
        _destPos = pos;
        _destCtrl.text = coordsLabel;
      }
      _lastAdjustedField = target;
      _activeField = null;
      _suggestions = const [];
    });
    _notifyPoints();
    // Reverse-geocode en parallèle pour enrichir le label texte.
    _reverseGeocodeLabel(target, pos, coordsLabel);
  }

  Future<void> _reverseGeocodeLabel(
      String target, LatLng pos, String fallback) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=jsonv2&zoom=18&addressdetails=0');
      final resp =
          await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode != 200 || !mounted) return;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final display = data['display_name']?.toString() ?? '';
      if (display.isEmpty) return;
      final i = display.indexOf(',');
      final short = i > 0 ? display.substring(0, i).trim() : display;
      // Re-applique seulement si le user n'a pas changé le champ entre temps.
      final currentText =
          target == 'origin' ? _originCtrl.text : _destCtrl.text;
      if (currentText != fallback) return;
      setState(() {
        if (target == 'origin') {
          _originCtrl.text = short;
        } else {
          _destCtrl.text = short;
        }
      });
    } catch (_) {}
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_originFocus.hasFocus) {
      setState(() {
        _activeField = 'origin';
        _refreshSuggestions(_originCtrl.text);
      });
    } else if (_destFocus.hasFocus) {
      setState(() {
        _activeField = 'destination';
        _refreshSuggestions(_destCtrl.text);
      });
    }
  }

  void _refreshSuggestions(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      _suggestions = const [];
      _debounce?.cancel();
      return;
    }
    _suggestions = _searchBundleStops(q);
    _debounce?.cancel();
    if (q.length >= 3) {
      // 200ms : assez court pour que les résultats Nominatim apparaissent
      // au rythme de la frappe (UX type Google), mais reste sous le seuil
      // de saturation de l'usage policy public Nominatim (~1 req/sec).
      _debounce = Timer(const Duration(milliseconds: 200), () {
        _fetchNominatim(q);
      });
    }
  }

  /// Recherche autocomplete via l'index pré-calculé du service. O(N) sur
  /// le nombre d'arrêts uniques (~250) au lieu de O(N²) précédemment.
  List<_Suggestion> _searchBundleStops(String query) {
    final hits = PublicTransportService.instance.searchStops(query, limit: 8);
    return [
      for (final h in hits)
        _Suggestion(
          label: h.name,
          subtitle: null,
          position: h.position,
          isStop: true,
          stopLines: h.lines,
        ),
    ];
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    const piOver180 = 3.141592653589793 / 180.0;
    final dLat = (b.latitude - a.latitude) * piOver180;
    final dLng = (b.longitude - a.longitude) * piOver180;
    final lat1 = a.latitude * piOver180;
    final lat2 = b.latitude * piOver180;
    final h = math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.cos(lat1) *
            math.cos(lat2) *
            math.pow(math.sin(dLng / 2), 2).toDouble();
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return r * c;
  }

  Future<void> _fetchNominatim(String query) async {
    if (query == _lastFetchedQuery) return;
    try {
      final results =
          await NominatimService.instance.search(query, limit: 5);
      if (!mounted) return;
      _lastFetchedQuery = query; // ne marquer fetched qu'après succès
      final merged = <_Suggestion>[
        ..._searchBundleStops(query),
        for (final r in results)
          _Suggestion(
            label: r.shortName,
            subtitle: r.displayName,
            position: LatLng(r.lat, r.lon),
            isStop: false,
            stopLines: const [],
          ),
      ];
      final activeText = _activeField == 'origin'
          ? _originCtrl.text.trim()
          : (_activeField == 'destination'
              ? _destCtrl.text.trim()
              : '');
      if (activeText != query) return;
      setState(() => _suggestions = merged);
    } catch (_) {}
  }

  Future<void> _useMyLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _originPos = LatLng(pos.latitude, pos.longitude);
        final locale = context.read<LocaleProvider>().locale;
        _originCtrl.text = TransitStrings.t('route.my.location', locale);
        _activeField = null;
        _suggestions = const [];
        _lastAdjustedField = 'origin';
      });
      _notifyPoints();
    } catch (_) {}
  }

  void _swap() {
    setState(() {
      final tmpText = _originCtrl.text;
      _originCtrl.text = _destCtrl.text;
      _destCtrl.text = tmpText;
      final tmpPos = _originPos;
      _originPos = _destPos;
      _destPos = tmpPos;
      _results = const [];
      _error = null;
    });
    _notifyPoints();
  }

  void _selectSuggestion(_Suggestion s) {
    setState(() {
      if (_activeField == 'origin') {
        _originCtrl.text = s.label;
        _originPos = s.position;
        _lastAdjustedField = 'origin';
      } else if (_activeField == 'destination') {
        _destCtrl.text = s.label;
        _destPos = s.position;
        _lastAdjustedField = 'destination';
      }
      _activeField = null;
      _suggestions = const [];
    });
    FocusScope.of(context).unfocus();
    _notifyPoints();
  }

  void _notifyPoints() {
    widget.onPointsChanged?.call(_originPos, _destPos);
  }

  Future<void> _calculate() async {
    final origin = _originPos;
    final dest = _destPos;
    if (origin == null || dest == null) return;
    // Pre-flight : si origin et dest sont à plus de 50km, on ne couvre
    // pas le réseau Tana ; on évite d'appeler le moteur (qui retournerait
    // de toute façon des walks absurdes vers le 1er stop atteignable).
    if (_haversineMeters(origin, dest) > 50000) {
      setState(() {
        _calculating = false;
        _results = const [];
        _error = null;
        _expandedResultIdx = null;
        _searched = true;
      });
      widget.onResultsVisibilityChanged?.call(false);
      return;
    }
    setState(() {
      _calculating = true;
      _error = null;
    });
    try {
      final svc = PublicTransportService.instance;
      await svc.ensureLoaded();
      final graph = svc.getGraph();
      final rawRoutes = graph.findMultipleRoutes(origin, dest, maxRoutes: 6);
      // Filtre des antipatterns du moteur Dijkstra :
      //   - même ligne empruntée 2× dans des steps transport séparés
      //     (ex : 137→172→137 → le passager peut juste rester sur 137).
      //   - transit step ≤ 1 arrêt suivi d'une correspondance (« prendre
      //     le bus pour 1 arrêt » → quasiment toujours sub-optimal vs
      //     marcher un poil plus loin).
      //   - > 2 correspondances (peu réalistes en pratique à Tana).
      final practical =
          rawRoutes.where(_isPracticalRoute).toList();
      final routes = practical.isNotEmpty
          ? practical.take(4).toList()
          : rawRoutes.take(4).toList();
      // Enrichissement OSRM piéton : tracé réel rues + durée. On lance en
      // parallèle pour ne pas linéariser le temps total.
      final enrichedRaw = await _enrichWithOsrmFoot(routes);
      // Coalesce les marches consécutives : Dijkstra produit parfois 2-3
      // micro-walk steps adjacents (descente du bus → transfer → arrivée)
      // qu'on présente comme un seul "Marcher vers ..." pour la lisibilité.
      final enriched = enrichedRaw.map(_coalesceWalks).toList();
      // Filtre 2 niveaux :
      //   1. Hard filter > 60 min : route absurde (probablement le moteur
      //      a accroché un stop très éloigné). On les drop toujours.
      //   2. Soft filter > 20 min : itinéraires longs à pied, on les
      //      cache si on a mieux. Si tous dépassent, on garde les meilleurs
      //      du hard-filter.
      const hardWalkMin = 60;
      const softWalkMin = 20;
      final reasonable = enriched
          .where((r) => r.walkingTimeMinutes <= hardWalkMin)
          .toList();
      final acceptable = reasonable
          .where((r) => r.walkingTimeMinutes <= softWalkMin)
          .toList();
      final filtered =
          acceptable.isNotEmpty ? acceptable : reasonable;
      if (!mounted) return;
      setState(() {
        _results = filtered;
        _calculating = false;
        _searched = true;
        _expandedResultIdx = filtered.isEmpty ? null : 0;
      });
      if (filtered.isNotEmpty) {
        widget.onResultsVisibilityChanged?.call(true);
        widget.onRouteSelected?.call(filtered.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calculating = false;
        _error = e.toString();
      });
    }
  }

  /// Fusionne les RouteStep de marche consécutifs en un seul. Le type
  /// final est celui du dernier walk fusionné (donc walkFromStop si on
  /// approche de la destination, walkTransfer entre 2 transports, etc.).
  TransportRoute _coalesceWalks(TransportRoute r) {
    final out = <RouteStep>[];
    int i = 0;
    while (i < r.steps.length) {
      final s = r.steps[i];
      if (!s.isWalking) {
        out.add(s);
        i++;
        continue;
      }
      // Accumule les walks consécutifs.
      var j = i;
      var totalMin = 0;
      var totalMeters = 0;
      final path = <LatLng>[];
      RouteStep last = s;
      while (j < r.steps.length && r.steps[j].isWalking) {
        final w = r.steps[j];
        totalMin += w.durationMinutes;
        totalMeters += w.distanceMeters;
        if (w.pathCoordinates.isNotEmpty) {
          if (path.isNotEmpty &&
              path.last.latitude == w.pathCoordinates.first.latitude &&
              path.last.longitude == w.pathCoordinates.first.longitude) {
            path.addAll(w.pathCoordinates.skip(1));
          } else {
            path.addAll(w.pathCoordinates);
          }
        }
        last = w;
        j++;
      }
      out.add(RouteStep(
        type: last.type,
        startStop: s.startStop,
        endStop: last.endStop,
        intermediateStops: const [],
        durationMinutes: math.max(1, totalMin),
        distanceKm: totalMeters / 1000.0,
        distanceMeters: totalMeters,
        walkStartPosition: s.walkStartPosition,
        walkEndPosition: last.walkEndPosition,
        pathCoordinates: path,
      ));
      i = j;
    }
    return TransportRoute(
      steps: out,
      totalDurationMinutes: r.totalDurationMinutes,
      totalDistanceKm: r.totalDistanceKm,
      numberOfTransfers: r.numberOfTransfers,
      origin: r.origin,
      destination: r.destination,
      walkingTimeMinutes: r.walkingTimeMinutes,
      walkingDistanceMeters: r.walkingDistanceMeters,
      transportTimeMinutes: r.transportTimeMinutes,
      departureTime: r.departureTime,
      arrivalTime: r.arrivalTime,
    );
  }

  /// Filtre des routes "non-pratiques" produites par Dijkstra mais
  /// absurdes pour un humain : même ligne reprise après transfert,
  /// transit ultra-court (≤ 1 arrêt) suivi d'un transfert, > 2
  /// correspondances. Ces routes existent parce que le moteur minimise
  /// le temps total sans tenir compte du coût mental d'une correspondance.
  bool _isPracticalRoute(TransportRoute r) {
    final transportSteps =
        r.steps.where((s) => s.type == RouteStepType.transport).toList();
    // > 2 correspondances = > 3 segments transport.
    if (transportSteps.length > 3) return false;
    // Même ligne utilisée dans 2+ segments séparés.
    final lines = transportSteps
        .map((s) => s.lineNumber)
        .where((n) => n != null)
        .toList();
    if (lines.toSet().length < lines.length) return false;
    // Route dominée : une ligne empruntée *plus tard* passe déjà par
    // l'arrêt où on prend une ligne *avant*. Le passager pourrait
    // attraper la ligne ultérieure directement et se passer de la 1re.
    for (var i = 0; i < transportSteps.length - 1; i++) {
      final earlier = transportSteps[i];
      final earlierStop = earlier.startStop;
      if (earlierStop == null) continue;
      for (var j = i + 1; j < transportSteps.length; j++) {
        final laterLine = transportSteps[j].lineNumber;
        if (laterLine == null) continue;
        if (earlierStop.lineNumbers.contains(laterLine)) {
          return false;
        }
      }
    }
    // Transit step ≤ 1 arrêt intermédiaire suivi d'une correspondance.
    for (var i = 0; i < r.steps.length - 1; i++) {
      final s = r.steps[i];
      if (s.type != RouteStepType.transport) continue;
      if (s.intermediateStops.length > 1) continue;
      final hasFollowup = r.steps
          .skip(i + 1)
          .any((x) => x.type == RouteStepType.transport);
      if (hasFollowup) return false;
    }
    return true;
  }

  /// Pour chaque RouteStep de marche de chaque route, fetch OSRM en mode
  /// piéton et remplace `pathCoordinates` + `durationMinutes`. Recompute
  /// les totaux. Si OSRM rate, on garde le step d'origine (best-effort).
  Future<List<TransportRoute>> _enrichWithOsrmFoot(
      List<TransportRoute> routes) async {
    if (routes.isEmpty) return routes;
    // Map (routeIdx, stepIdx) -> futures.
    final futures = <Future<void>>[];
    final updates = <int,
        Map<int,
            ({List<LatLng> path, int durationMin, int distanceMeters})>>{};
    for (var ri = 0; ri < routes.length; ri++) {
      updates[ri] = {};
      for (var si = 0; si < routes[ri].steps.length; si++) {
        final s = routes[ri].steps[si];
        if (!s.isWalking) continue;
        final start = s.walkStartPosition ?? s.startStop?.position;
        final end = s.walkEndPosition ?? s.endStop?.position;
        if (start == null || end == null) continue;
        // Skip OSRM pour les marches très courtes (< 80m) : le coût HTTP
        // dépasse l'utilité du tracé rues. On garde la ligne droite.
        final straightDist = _haversineMeters(start, end);
        if (straightDist < 80) continue;
        futures.add(() async {
          try {
            final res = await TransportOsrmService.instance.routeFoot(
              ll2.LatLng(start.latitude, start.longitude),
              ll2.LatLng(end.latitude, end.longitude),
            );
            if (res == null) return;
            final path =
                res.geometry.map((c) => LatLng(c[1], c[0])).toList();
            final durationMin = math.max(1, (res.durationSec / 60).ceil());
            updates[ri]![si] = (
              path: path,
              durationMin: durationMin,
              distanceMeters: res.distanceMeters.round(),
            );
          } catch (_) {}
        }());
      }
    }
    await Future.wait(futures);
    return [
      for (var ri = 0; ri < routes.length; ri++)
        _rebuildRoute(routes[ri], updates[ri] ?? const {}),
    ];
  }

  TransportRoute _rebuildRoute(
      TransportRoute r,
      Map<int,
              ({List<LatLng> path, int durationMin, int distanceMeters})>
          stepUpdates) {
    if (stepUpdates.isEmpty) return r;
    final newSteps = <RouteStep>[];
    var walkMin = 0;
    var transportMin = 0;
    for (var i = 0; i < r.steps.length; i++) {
      final s = r.steps[i];
      final upd = stepUpdates[i];
      if (s.isWalking && upd != null) {
        newSteps.add(RouteStep(
          type: s.type,
          startStop: s.startStop,
          endStop: s.endStop,
          lineNumber: s.lineNumber,
          lineName: s.lineName,
          transportType: s.transportType,
          intermediateStops: s.intermediateStops,
          durationMinutes: upd.durationMin,
          distanceKm: upd.distanceMeters / 1000.0,
          distanceMeters: upd.distanceMeters,
          direction: s.direction,
          walkStartPosition: s.walkStartPosition,
          walkEndPosition: s.walkEndPosition,
          pathCoordinates: upd.path,
        ));
        walkMin += upd.durationMin;
      } else {
        newSteps.add(s);
        if (s.isWalking) {
          walkMin += s.durationMinutes;
        } else {
          transportMin += s.durationMinutes;
        }
      }
    }
    return TransportRoute(
      steps: newSteps,
      totalDurationMinutes: walkMin + transportMin,
      totalDistanceKm: r.totalDistanceKm,
      numberOfTransfers: r.numberOfTransfers,
      origin: r.origin,
      destination: r.destination,
      walkingTimeMinutes: walkMin,
      walkingDistanceMeters: r.walkingDistanceMeters,
      transportTimeMinutes: transportMin,
      departureTime: r.departureTime,
      arrivalTime: r.arrivalTime,
    );
  }

  void _clearResults() {
    setState(() {
      _results = const [];
      _expandedResultIdx = null;
      _error = null;
      _searched = false;
    });
    widget.onResultsVisibilityChanged?.call(false);
    widget.onRouteSelected?.call(null);
  }

  void _selectResult(int i) {
    if (i < 0 || i >= _results.length) return;
    setState(() => _expandedResultIdx = i);
    widget.onRouteSelected?.call(_results[i]);
  }

  bool get _canCalculate =>
      _originPos != null && _destPos != null && !_calculating;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledTime,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 7)),
    );
    if (picked == null) return;
    setState(() {
      _scheduledTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime),
    );
    if (picked == null) return;
    setState(() {
      _scheduledTime = DateTime(
        _scheduledTime.year,
        _scheduledTime.month,
        _scheduledTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  String _dateLabel(AppLocale locale) {
    final now = DateTime.now();
    final isToday = _scheduledTime.year == now.year &&
        _scheduledTime.month == now.month &&
        _scheduledTime.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = _scheduledTime.year == tomorrow.year &&
        _scheduledTime.month == tomorrow.month &&
        _scheduledTime.day == tomorrow.day;
    if (isToday) return TransitStrings.t('route.when.today', locale);
    if (isTomorrow) return TransitStrings.t('route.when.tomorrow', locale);
    final dd = _scheduledTime.day.toString().padLeft(2, '0');
    final mm = _scheduledTime.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  String _timeLabel() {
    final hh = _scheduledTime.hour.toString().padLeft(2, '0');
    final mm = _scheduledTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildField(
            controller: _originCtrl,
            focusNode: _originFocus,
            placeholder: TransitStrings.t('route.origin.placeholder', locale),
            iconColor: const Color(0xFF43A047),
            iconLabel: 'O',
            trailing: IconButton(
              icon: const Icon(Icons.my_location, size: 18),
              tooltip: TransitStrings.t('route.my.location', locale),
              onPressed: _useMyLocation,
              color: const Color(0xFF1565C0),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            onChanged: (v) => setState(() {
              if (_originPos != null) {
                _originPos = null;
                _notifyPoints();
              }
              _refreshSuggestions(v);
            }),
          ),
          // Suggestions juste sous le champ actif pour éviter la confusion
          // (sinon la liste tombait sous "Arrivée" même quand on tapait
          // "Départ").
          if (_activeField == 'origin' && _suggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildSuggestions(),
          ],
          const SizedBox(height: 6),
          Center(
            child: IconButton(
              icon: const Icon(Icons.swap_vert, size: 20),
              tooltip: TransitStrings.t('route.swap', locale),
              onPressed: _swap,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              color: const Color(0xFF1D3557),
            ),
          ),
          const SizedBox(height: 6),
          _buildField(
            controller: _destCtrl,
            focusNode: _destFocus,
            placeholder:
                TransitStrings.t('route.destination.placeholder', locale),
            iconColor: const Color(0xFFFF5357),
            iconLabel: 'D',
            onChanged: (v) => setState(() {
              if (_destPos != null) {
                _destPos = null;
                _notifyPoints();
              }
              _refreshSuggestions(v);
            }),
          ),
          if (_activeField == 'destination' &&
              _suggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildSuggestions(),
          ],
          const SizedBox(height: 12),
          _buildWhenBlock(locale),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5357),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _canCalculate ? _calculate : null,
              child: _calculating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      TransitStrings.t('route.calculate', locale),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 14),
            // Bouton retour : reset les résultats, restaure la liste des
            // lignes côté panel et le réseau complet sur la carte.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _clearResults,
                icon: const Icon(Icons.arrow_back, size: 14),
                label: Text(
                  TransitStrings.t('route.modify', locale),
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1D3557),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < _results.length; i++)
              _buildResultCard(_results[i], i, locale),
          ],
          if (!_calculating && _results.isEmpty && _searched) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                TransitStrings.t('route.no.results', locale),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholder,
    required Color iconColor,
    required String iconLabel,
    Widget? trailing,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.3),
                  blurRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              iconLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle:
                    const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final svc = PublicTransportService.instance;
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        itemBuilder: (ctx, i) {
          final s = _suggestions[i];
          return InkWell(
            onTap: () => _selectSuggestion(s),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    s.isStop
                        ? Icons.directions_bus_outlined
                        : Icons.location_on_outlined,
                    size: 14,
                    color: s.isStop
                        ? const Color(0xFFFF5357)
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF1D3557)),
                        ),
                        if (s.subtitle != null && s.subtitle!.isNotEmpty)
                          Text(
                            s.subtitle!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (s.isStop && s.stopLines.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 3,
                            runSpacing: 3,
                            children: [
                              for (final ln in s.stopLines.take(5))
                                _miniLineBadge(svc, ln),
                              if (s.stopLines.length > 5)
                                Text(
                                  '+${s.stopLines.length - 5}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniLineBadge(PublicTransportService svc, String lineNumber) {
    final meta = svc.metadataFor(lineNumber);
    final color =
        meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        lineNumber,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  /// Bloc QUAND : toggle Partir/Arriver + date + heure. UX-only en V1 ;
  /// la valeur n'est pas encore passée au moteur de routage.
  Widget _buildWhenBlock(AppLocale locale) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TransitStrings.t('route.when.label', locale),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _whenToggle(
                  label: TransitStrings.t('route.when.depart', locale),
                  active: _isDeparture,
                  onTap: () => setState(() => _isDeparture = true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _whenToggle(
                  label: TransitStrings.t('route.when.arrive', locale),
                  active: !_isDeparture,
                  onTap: () => setState(() => _isDeparture = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _whenChip(
                  icon: Icons.calendar_today_outlined,
                  label: _dateLabel(locale),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _whenChip(
                  icon: Icons.access_time,
                  label: _timeLabel(),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _whenToggle({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1D3557) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF1D3557) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF1D3557),
          ),
        ),
      ),
    );
  }

  Widget _whenChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF1D3557)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D3557),
                ),
              ),
            ),
            const Icon(Icons.expand_more,
                size: 14, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(TransportRoute route, int index, AppLocale locale) {
    final svc = PublicTransportService.instance;
    final transferLabel = route.numberOfTransfers == 0
        ? TransitStrings.t('route.transfers.zero', locale)
        : route.numberOfTransfers == 1
            ? TransitStrings.t('route.transfer.one', locale)
            : '${route.numberOfTransfers} ${TransitStrings.t('route.transfers.many', locale)}';
    final isExpanded = _expandedResultIdx == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _selectResult(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isExpanded
                    ? const Color(0xFF1D3557)
                    : Colors.grey.shade200,
                width: isExpanded ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${route.totalDurationMinutes}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D3557),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      TransitStrings.t('route.minutes.short', locale),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      transferLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final ln in route.usedLines) _lineBadge(svc, ln),
                  ],
                ),
                if (route.walkingTimeMinutes > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.directions_walk,
                          size: 12, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        '${route.walkingTimeMinutes} ${TransitStrings.t('route.walking', locale)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isExpanded) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _buildInlineTimeline(route, locale),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Timeline schématique inline rendue dans la tuile dépliée. Inspirée
  /// de `RouteItineraryScreen` mais condensée pour une largeur sidebar.
  Widget _buildInlineTimeline(TransportRoute route, AppLocale locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < route.steps.length; i++)
          _buildTimelineStep(
            route.steps[i],
            isFirst: i == 0,
            isLast: i == route.steps.length - 1,
            locale: locale,
          ),
      ],
    );
  }

  Widget _buildTimelineStep(
    RouteStep step, {
    required bool isFirst,
    required bool isLast,
    required AppLocale locale,
  }) {
    final svc = PublicTransportService.instance;
    final isWalking = step.isWalking;
    final color = !isWalking && step.lineNumber != null
        ? (svc.metadataFor(step.lineNumber!) != null
            ? Color(svc.metadataFor(step.lineNumber!)!.colorValue)
            : const Color(0xFF1565C0))
        : const Color(0xFF6B7280);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: isFirst ? 12 : 0,
                      bottom: isLast ? 12 : 0,
                    ),
                    child: Center(
                      child: isWalking
                          ? CustomPaint(
                              painter: _TimelineDashedPainter(
                                color: const Color(0xFF6B7280),
                              ),
                              child: const SizedBox(width: 2),
                            )
                          : Container(width: 3, color: color),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isWalking
                          ? Icons.directions_walk
                          : Icons.directions_bus,
                      size: 10,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: isWalking
                  ? _buildTimelineWalk(step, locale)
                  : _buildTimelineTransport(step, color, locale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineWalk(RouteStep step, AppLocale locale) {
    final label = step.type == RouteStepType.walkFromStop
        ? TransitStrings.t('route.step.walk.dest', locale)
        : '${TransitStrings.t('route.step.walk.to', locale)} ${step.endStop?.name ?? step.startStop?.name ?? ""}';
    final dist = step.distanceMeters > 0
        ? ' · ${(step.distanceMeters / 1000).toStringAsFixed(1)} km'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1D3557),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '${step.durationMinutes} ${TransitStrings.t('route.minutes.short', locale)}$dist',
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildTimelineTransport(
      RouteStep step, Color color, AppLocale locale) {
    final lineNumber = step.lineNumber ?? '?';
    final terminus = step.direction ?? step.endStop?.name ?? '';
    final stopsCount = step.intermediateStops.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                lineNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (terminus.isNotEmpty)
              Expanded(
                child: Text(
                  '${TransitStrings.t('route.step.toward', locale)} $terminus',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D3557),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (step.startStop != null)
          Text(
            step.startStop!.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D3557),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '${stopsCount > 0 ? "$stopsCount ${TransitStrings.t('lines.stops.short', locale)} · " : ""}${step.durationMinutes} ${TransitStrings.t('route.minutes.short', locale)}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          ),
        ),
        if (step.endStop != null)
          Row(
            children: [
              const Icon(Icons.flag, size: 10, color: Color(0xFF6B7280)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  '${TransitStrings.t('route.step.descend', locale)} ${step.endStop!.name}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D3557),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _lineBadge(PublicTransportService svc, String lineNumber) {
    final meta = svc.metadataFor(lineNumber);
    final color =
        meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        lineNumber,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Painter trait pointillé vertical pour la timeline schématique des
/// étapes de marche.
class _TimelineDashedPainter extends CustomPainter {
  final Color color;
  _TimelineDashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + 4).clamp(0, size.height)),
        paint,
      );
      y += 8;
    }
  }

  @override
  bool shouldRepaint(_TimelineDashedPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Suggestion d'autocomplete polymorphe : soit un arrêt du bundle (isStop=true)
/// avec ses lignes desservantes, soit une adresse OSM via Nominatim
/// (isStop=false, stopLines vide).
class _Suggestion {
  final String label;
  final String? subtitle;
  final LatLng position;
  final bool isStop;
  final List<String> stopLines;

  const _Suggestion({
    required this.label,
    required this.subtitle,
    required this.position,
    required this.isStop,
    required this.stopLines,
  });
}
