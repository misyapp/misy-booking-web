import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/services/nominatim_service.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';

/// Calculateur d'itinéraire multimodal pour le bandeau Transport en commun.
///
/// Form 2 champs (origine + destination) avec autocomplétion par nom
/// d'arrêt depuis le bundle, bouton "Ma position" (geoloc browser),
/// bouton inversion ⇅, bouton Calculer. Les résultats apparaissent
/// sous le form sous forme de cards style IDF.
///
/// Sur tap d'une card, le callback [onRouteSelected] est appelé pour
/// que le parent (panel/home) puisse afficher la timeline et surligner
/// l'itinéraire sur la carte.
class RouteCalculator extends StatefulWidget {
  final ValueChanged<TransportRoute>? onRouteSelected;

  const RouteCalculator({super.key, this.onRouteSelected});

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
  String? _error;

  // Autocomplete state.
  String? _activeField; // 'origin' | 'destination' | null
  List<_Suggestion> _suggestions = const [];
  Timer? _debounce;
  String _lastFetchedQuery = '';

  @override
  void initState() {
    super.initState();
    _originFocus.addListener(_onFocusChange);
    _destFocus.addListener(_onFocusChange);
    // Garantit que le bundle public est chargé avant les recherches —
    // évite "0 résultat" si le user tape avant la fin du load initial.
    PublicTransportService.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      // Si l'utilisateur a déjà tapé pendant le load, refresh.
      final activeText = _activeField == 'origin'
          ? _originCtrl.text
          : (_activeField == 'destination' ? _destCtrl.text : '');
      if (activeText.isNotEmpty) {
        setState(() => _refreshSuggestions(activeText));
      }
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    _debounce?.cancel();
    super.dispose();
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
    // Pas de else { _activeField = null } pour laisser le tap sur une
    // suggestion fonctionner (sinon le blur cache la liste avant que le
    // tap propage). Cleared via _hideSuggestions().
  }

  void _refreshSuggestions(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      _suggestions = const [];
      _debounce?.cancel();
      return;
    }
    // 1. Suggestions immédiates depuis le bundle (sync, rapide).
    _suggestions = _searchBundleStops(q);
    // 2. En parallèle, fetch Nominatim avec debounce 400 ms et merge.
    _debounce?.cancel();
    if (q.length >= 3) {
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _fetchNominatim(q);
      });
    }
  }

  List<_Suggestion> _searchBundleStops(String query) {
    final svc = PublicTransportService.instance;
    final groups = svc.allLines;
    final q = query.toLowerCase();
    final seen = <String>{};
    final hits = <_Suggestion>[];
    for (final group in groups) {
      for (final stop in [...?group.aller?.stops, ...?group.retour?.stops]) {
        final n = stop.name.trim();
        if (n.isEmpty) continue;
        final lower = n.toLowerCase();
        if (!lower.contains(q)) continue;
        if (seen.contains(lower)) continue;
        seen.add(lower);
        hits.add(_Suggestion(
          label: n,
          subtitle: null,
          position: stop.position,
          isStop: true,
        ));
        if (hits.length >= 6) break;
      }
      if (hits.length >= 6) break;
    }
    return hits;
  }

  Future<void> _fetchNominatim(String query) async {
    if (query == _lastFetchedQuery) return;
    _lastFetchedQuery = query;
    try {
      final results =
          await NominatimService.instance.search(query, limit: 5);
      if (!mounted) return;
      // Merge : on garde les hits bundle au-dessus puis les adresses
      // Nominatim. Pas de dédup sur la position (les noms d'arrêts et
      // d'adresses sont des concepts différents même si proches).
      final merged = <_Suggestion>[
        ..._searchBundleStops(query),
        for (final r in results)
          _Suggestion(
            label: r.shortName,
            subtitle: r.displayName,
            position: LatLng(r.lat, r.lon),
            isStop: false,
          ),
      ];
      // Ne mettre à jour que si la query est toujours la même.
      final activeText = _activeField == 'origin'
          ? _originCtrl.text.trim()
          : (_activeField == 'destination'
              ? _destCtrl.text.trim()
              : '');
      if (activeText != query) return;
      setState(() => _suggestions = merged);
    } catch (_) {
      // Silencieux — l'utilisateur garde au moins les suggestions bundle.
    }
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
      });
    } catch (_) {
      // Silencieux : si la geoloc fail, le user remplit manuellement.
    }
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
  }

  void _selectSuggestion(_Suggestion s) {
    setState(() {
      if (_activeField == 'origin') {
        _originCtrl.text = s.label;
        _originPos = s.position;
      } else if (_activeField == 'destination') {
        _destCtrl.text = s.label;
        _destPos = s.position;
      }
      _activeField = null;
      _suggestions = const [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _calculate() async {
    final origin = _originPos;
    final dest = _destPos;
    if (origin == null || dest == null) return;
    setState(() {
      _calculating = true;
      _error = null;
    });
    try {
      final svc = PublicTransportService.instance;
      await svc.ensureLoaded();
      final graph = svc.getGraph();
      final routes = graph.findMultipleRoutes(origin, dest, maxRoutes: 4);
      if (!mounted) return;
      setState(() {
        _results = routes;
        _calculating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calculating = false;
        _error = e.toString();
      });
    }
  }

  bool get _canCalculate =>
      _originPos != null && _destPos != null && !_calculating;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ origine.
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
              _originPos = null; // reset jusqu'à sélection d'une suggestion
              _refreshSuggestions(v);
            }),
          ),
          const SizedBox(height: 6),
          // Bouton swap au milieu.
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
          // Champ destination.
          _buildField(
            controller: _destCtrl,
            focusNode: _destFocus,
            placeholder: TransitStrings.t('route.destination.placeholder', locale),
            iconColor: const Color(0xFFFF5357),
            iconLabel: 'D',
            onChanged: (v) => setState(() {
              _destPos = null;
              _refreshSuggestions(v);
            }),
          ),
          // Suggestions overlay (juste sous le champ actif).
          if (_activeField != null && _suggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildSuggestions(),
          ],
          const SizedBox(height: 10),
          // Bouton Calculer.
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
          // Résultats.
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final route in _results) _buildResultCard(route, locale),
          ],
          if (!_calculating && _results.isEmpty && _canCalculate) ...[
            // Quand l'user a entré 2 points et qu'on n'a pas encore calculé.
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
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
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

  Widget _buildResultCard(TransportRoute route, AppLocale locale) {
    final svc = PublicTransportService.instance;
    final transferLabel = route.numberOfTransfers == 0
        ? TransitStrings.t('route.transfers.zero', locale)
        : route.numberOfTransfers == 1
            ? TransitStrings.t('route.transfer.one', locale)
            : '${route.numberOfTransfers} ${TransitStrings.t('route.transfers.many', locale)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => widget.onRouteSelected?.call(route),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
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
                // Pictos lignes empruntées.
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
              ],
            ),
          ),
        ),
      ),
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

/// Suggestion d'autocomplete polymorphe : soit un arrêt du bundle (isStop=true),
/// soit une adresse OSM via Nominatim (isStop=false). Pour le calcul
/// d'itinéraire, on a juste besoin de la position. Le `subtitle` n'est
/// rempli que pour les adresses Nominatim (display_name complet) — il
/// disparaît une fois sélectionné.
class _Suggestion {
  final String label;
  final String? subtitle;
  final LatLng position;
  final bool isStop;

  const _Suggestion({
    required this.label,
    required this.subtitle,
    required this.position,
    required this.isStop,
  });
}
