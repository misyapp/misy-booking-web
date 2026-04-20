import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/provider/build_line_flow_provider.dart';
import 'package:rider_ride_hailing_app/services/osm_stops_service.dart';

import 'widgets/osm_base_map.dart';
import 'widgets/osm_stops_layer.dart';
import 'widgets/place_search_field.dart';

/// Résultat retourné par le sub-flow (ou null si l'user annule).
class BuildLineFlowResult {
  final Map<String, dynamic> featureCollection;
  final int numStops;
  final int numVertices;

  BuildLineFlowResult({
    required this.featureCollection,
    required this.numStops,
    required this.numVertices,
  });
}

/// Sub-flow à 4 sous-étapes pour construire (ou refaire) une direction de ligne.
///
/// Appelé depuis le wizard (bouton Modifier/Recommencer) ou depuis le flow
/// "Nouvelle ligne". Retourne un [BuildLineFlowResult] avec le FeatureCollection
/// prêt à être persisté, ou null si l'user annule.
class BuildLineFlowScreen extends StatefulWidget {
  final String lineNumber;
  final String direction; // 'aller' | 'retour'
  final String directionLabel; // "aller" ou "retour" pour l'UI

  const BuildLineFlowScreen({
    super.key,
    required this.lineNumber,
    required this.direction,
    required this.directionLabel,
  });

  @override
  State<BuildLineFlowScreen> createState() => _BuildLineFlowScreenState();
}

class _BuildLineFlowScreenState extends State<BuildLineFlowScreen> {
  final MapController _mapController = MapController();
  MapCamera? _lastCamera;

  @override
  void initState() {
    super.initState();
    // Assure que OsmStopsService est chargé (charge une fois, idempotent)
    OsmStopsService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BuildLineFlowProvider(),
      child: Consumer<BuildLineFlowProvider>(
        builder: (context, p, _) => Scaffold(
          appBar: AppBar(
            title: Text('Construire — Ligne ${widget.lineNumber} (${widget.directionLabel})'),
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _confirmClose(context),
            ),
            actions: [
              IconButton(
                tooltip: p.canUndo
                    ? 'Annuler la dernière action'
                    : 'Rien à annuler',
                icon: const Icon(Icons.undo),
                onPressed: p.canUndo ? p.undo : null,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              _StepperHeader(step: p.step),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 340,
                      child: _SidePanel(
                        step: p.step,
                        onNext: () => _onNext(p),
                        onPrev: () => _onPrev(p),
                        onFinish: () => _onFinish(p),
                        onPlaceSearchSelected: (latLng, desc) =>
                            _onPlaceSearchSelected(p, latLng, desc),
                        onRecomputeWithStops: () => _onRecomputeWithStops(p),
                        onRecomputeWithWaypoints: () =>
                            _onRecomputeWithWaypoints(p),
                      ),
                    ),
                    Expanded(
                      child: OsmBaseMap(
                        controller: _mapController,
                        onTap: (tp, latLng) => _onMapTap(p, latLng),
                        onMapEvent: (e) {
                          // Capture la camera sur tous les events (incluant le
                          // ready initial) pour que le layer OSM s'affiche
                          // dès l'ouverture, pas seulement au premier pan.
                          if (mounted) {
                            setState(() => _lastCamera = e.camera);
                          }
                        },
                        children: [
                          // Les arrêts OSM sont visibles à chaque étape : sert
                          // de référence visuelle pour placer départ/arrivée
                          // près d'arrêts existants, et d'interactif pour
                          // ajouter des arrêts en étape stops.
                          if (_lastCamera != null)
                            OsmStopsLayer(
                              camera: _lastCamera!,
                              onStopTap: (stop) => _onOsmStopTap(p, stop),
                            ),
                          if (p.routeCoords.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: p.routeCoords
                                      .map((c) => LatLng(c[1], c[0]))
                                      .toList(),
                                  strokeWidth: 5,
                                  color: const Color(0xFF1565C0),
                                ),
                              ],
                            ),
                          MarkerLayer(markers: _buildMarkers(p)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (p.error != null)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    p.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _buildMarkers(BuildLineFlowProvider p) {
    final markers = <Marker>[];

    // Le pin "actif" (celui que l'user vient de placer pour l'étape courante)
    // est animé avec un anneau pulsant pour attirer l'œil sur la carte.
    final activeOrigin = p.step == BuildLineStep.origin;
    final activeDest = p.step == BuildLineStep.destination;

    if (p.origin != null) {
      markers.add(_pinMarker(p.origin!, 'D', const Color(0xFF2E7D32),
          pulse: activeOrigin));
    }
    if (p.destination != null) {
      markers.add(_pinMarker(p.destination!, 'A', const Color(0xFFC62828),
          pulse: activeDest));
    }
    for (int i = 0; i < p.stops.length; i++) {
      markers.add(_pinMarker(
        p.stops[i].position,
        '${i + 1}',
        const Color(0xFFFF9800),
      ));
    }
    for (final w in p.waypoints) {
      markers.add(Marker(
        point: w.position,
        width: 18,
        height: 18,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1565C0), width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 3),
            ],
          ),
        ),
      ));
    }
    return markers;
  }

  Marker _pinMarker(LatLng pos, String label, Color color,
      {bool pulse = false}) {
    return Marker(
      point: pos,
      width: 64,
      height: 74,
      alignment: Alignment.topCenter,
      child: _AnimatedPin(label: label, color: color, pulse: pulse),
    );
  }

  // ─────── Handlers ───────

  Future<void> _onMapTap(BuildLineFlowProvider p, LatLng latLng) async {
    switch (p.step) {
      case BuildLineStep.origin:
        await _setTerminusWithPrompt(p, latLng, isOrigin: true);
        break;
      case BuildLineStep.destination:
        await _setTerminusWithPrompt(p, latLng, isOrigin: false);
        break;
      case BuildLineStep.stops:
        final name = await _promptStopName(context);
        if (name != null && name.trim().isNotEmpty) {
          p.addStop(latLng, name.trim());
        }
        break;
      case BuildLineStep.refine:
        p.addWaypoint(latLng);
        break;
    }
  }

  Future<void> _onOsmStopTap(BuildLineFlowProvider p, OsmStop stop) async {
    switch (p.step) {
      case BuildLineStep.origin:
        await _setTerminusWithPrompt(p, stop.position,
            isOrigin: true,
            prefillName: stop.hasName ? stop.name : null);
        return;
      case BuildLineStep.destination:
        await _setTerminusWithPrompt(p, stop.position,
            isOrigin: false,
            prefillName: stop.hasName ? stop.name : null);
        return;
      case BuildLineStep.refine:
        p.addWaypoint(stop.position);
        return;
      case BuildLineStep.stops:
        final name = await _promptStopName(
          context,
          initialName: stop.hasName ? stop.name : '',
          title: stop.hasName
              ? 'Ajouter ${stop.name} ?'
              : 'Nom de l\'arrêt',
        );
        if (name != null && name.trim().isNotEmpty) {
          p.addStop(stop.position, name.trim(), osmId: stop.id);
        }
        return;
    }
  }

  /// Pose le terminus origine (ou destination) avec un dialog pour nommer.
  /// Le nom pré-rempli vient soit d'un arrêt OSM cliqué, soit du nom courant
  /// déjà posé (permet d'ajuster position + nom).
  Future<void> _setTerminusWithPrompt(
    BuildLineFlowProvider p,
    LatLng pos, {
    required bool isOrigin,
    String? prefillName,
  }) async {
    final existing = isOrigin ? p.originName : p.destinationName;
    final initial = prefillName ?? existing ?? '';
    final label = isOrigin ? 'départ' : 'arrivée';
    final name = await _promptStopName(
      context,
      initialName: initial,
      title: 'Nom du point de $label',
    );
    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (isOrigin) {
      p.setOrigin(pos, name: trimmed);
    } else {
      p.setDestination(pos, name: trimmed);
    }
  }

  Future<void> _onPlaceSearchSelected(
      BuildLineFlowProvider p, LatLng latLng, String description) async {
    _mapController.move(latLng, 17);
    if (p.step == BuildLineStep.origin) {
      await _setTerminusWithPrompt(p, latLng,
          isOrigin: true, prefillName: _firstComma(description));
    } else if (p.step == BuildLineStep.destination) {
      await _setTerminusWithPrompt(p, latLng,
          isOrigin: false, prefillName: _firstComma(description));
    }
  }

  String _firstComma(String s) {
    final i = s.indexOf(',');
    return (i > 0 ? s.substring(0, i) : s).trim();
  }

  Future<void> _onNext(BuildLineFlowProvider p) async {
    switch (p.step) {
      case BuildLineStep.origin:
        if (p.origin == null) return;
        p.setStep(BuildLineStep.destination);
        break;
      case BuildLineStep.destination:
        if (p.destination == null) return;
        // Calcul OSRM initial
        final ok = await p.recomputeInitialRoute();
        if (!mounted) return;
        if (!ok) {
          _snack(context, p.error ?? 'OSRM KO');
          return;
        }
        _fitBounds(p);
        p.setStep(BuildLineStep.stops);
        break;
      case BuildLineStep.stops:
        if (p.stops.length < 2) {
          _snack(context, 'Ajoute au moins 2 arrêts');
          return;
        }
        p.setStep(BuildLineStep.refine);
        break;
      case BuildLineStep.refine:
        break;
    }
  }

  void _onPrev(BuildLineFlowProvider p) {
    switch (p.step) {
      case BuildLineStep.origin:
        break;
      case BuildLineStep.destination:
        p.setStep(BuildLineStep.origin);
        break;
      case BuildLineStep.stops:
        p.setStep(BuildLineStep.destination);
        break;
      case BuildLineStep.refine:
        p.setStep(BuildLineStep.stops);
        break;
    }
  }

  Future<void> _onRecomputeWithStops(BuildLineFlowProvider p) async {
    final ok = await p.recomputeFullRoute();
    if (!mounted) return;
    if (!ok) {
      _snack(context, p.error ?? 'OSRM KO');
    }
  }

  Future<void> _onRecomputeWithWaypoints(BuildLineFlowProvider p) async {
    final ok = await p.recomputeFullRoute();
    if (!mounted) return;
    if (!ok) {
      _snack(context, p.error ?? 'OSRM KO');
    }
  }

  void _onFinish(BuildLineFlowProvider p) {
    if (!p.hasRoute || p.stops.length < 2) {
      _snack(context, 'Tracé ou arrêts incomplets');
      return;
    }
    final fc = p.buildFeatureCollection(
      lineNumber: widget.lineNumber,
      direction: widget.direction,
    );
    final numVertices =
        (fc['features'] as List).firstWhere(
              (f) => f['geometry']['type'] == 'LineString',
              orElse: () => null,
            ) !=
                null
            ? ((fc['features'] as List).firstWhere(
                    (f) => f['geometry']['type'] == 'LineString')['geometry']
                    ['coordinates'] as List)
                .length
            : 0;
    final numStops = 2 + p.stops.length;
    Navigator.of(context).pop(
      BuildLineFlowResult(
        featureCollection: fc,
        numStops: numStops,
        numVertices: numVertices,
      ),
    );
  }

  void _fitBounds(BuildLineFlowProvider p) {
    if (p.origin == null || p.destination == null) return;
    final bounds = LatLngBounds.fromPoints([p.origin!, p.destination!]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  Future<String?> _promptStopName(
    BuildContext context, {
    String? initialName,
    String title = 'Nom de l\'arrêt',
  }) {
    final initial = initialName ?? '';
    final controller = TextEditingController(text: initial);
    // Sélectionne tout le texte pré-rempli pour qu'une saisie directe remplace
    // (au lieu d'ajouter à la fin).
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initial.length,
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: Ankadifotsy'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClose(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter ?'),
        content: const Text('Tes modifications seront perdues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─────────────────────── Animated pin ───────────────────────

class _AnimatedPin extends StatefulWidget {
  final String label;
  final Color color;
  final bool pulse;

  const _AnimatedPin({
    required this.label,
    required this.color,
    required this.pulse,
  });

  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedPin old) {
    super.didUpdateWidget(old);
    if (widget.pulse && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat();
    } else if (!widget.pulse && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_controller != null)
                AnimatedBuilder(
                  animation: _controller!,
                  builder: (_, __) {
                    final t = _controller!.value;
                    return Opacity(
                      opacity: (1.0 - t).clamp(0.0, 1.0),
                      child: Container(
                        width: 24 + 32 * t,
                        height: 24 + 32 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: widget.color, width: 3),
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 3,
          height: 12,
          color: widget.color,
        ),
      ],
    );
  }
}

// ─────────────────────── Stepper header ───────────────────────

class _StepperHeader extends StatelessWidget {
  final BuildLineStep step;
  const _StepperHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('① Départ', BuildLineStep.origin),
      ('② Arrivée', BuildLineStep.destination),
      ('③ Arrêts', BuildLineStep.stops),
      ('④ Affiner', BuildLineStep.refine),
    ];
    return Container(
      color: const Color(0xFFE3F2FD),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: steps.map((s) {
          final isCurrent = s.$2 == step;
          final isDone = s.$2.index < step.index;
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF1565C0)
                    : (isDone ? const Color(0xFF66BB6A) : Colors.transparent),
                borderRadius: BorderRadius.circular(4),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                s.$1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: (isCurrent || isDone) ? Colors.white : Colors.black54,
                  fontWeight:
                      isCurrent ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────── Side panel (gauche) ───────────────────────

class _SidePanel extends StatelessWidget {
  final BuildLineStep step;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onFinish;
  final void Function(LatLng, String) onPlaceSearchSelected;
  final VoidCallback onRecomputeWithStops;
  final VoidCallback onRecomputeWithWaypoints;

  const _SidePanel({
    required this.step,
    required this.onNext,
    required this.onPrev,
    required this.onFinish,
    required this.onPlaceSearchSelected,
    required this.onRecomputeWithStops,
    required this.onRecomputeWithWaypoints,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BuildLineFlowProvider>();
    return Material(
      elevation: 4,
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              child: _stepContent(context, p),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: _actionRow(context, p),
          ),
        ],
      ),
    );
  }

  Widget _stepContent(BuildContext context, BuildLineFlowProvider p) {
    switch (step) {
      case BuildLineStep.origin:
      case BuildLineStep.destination:
        final label = step == BuildLineStep.origin
            ? 'Point de départ'
            : 'Point d\'arrivée';
        final hint = step == BuildLineStep.origin
            ? 'Rechercher le terminus de départ'
            : 'Rechercher le terminus d\'arrivée';
        final hasPoint = step == BuildLineStep.origin
            ? p.origin != null
            : p.destination != null;
        final name = step == BuildLineStep.origin
            ? p.originName
            : p.destinationName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            PlaceSearchField(
              hint: hint,
              onPlaceSelected: onPlaceSearchSelected,
            ),
            const SizedBox(height: 10),
            Text(
              hasPoint
                  ? '📍 Position placée${name != null && name.isNotEmpty ? " : $name" : ""}.\n\nTape ailleurs sur la carte pour ajuster.'
                  : '🔎 Tape le nom d\'un lieu, zoom automatique, puis clique sur la carte pour placer le point.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        );
      case BuildLineStep.stops:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arrêts : ${p.stops.length}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              '💡 Clique un marker gris (arrêt OSM) ou ailleurs sur la carte '
              'pour saisir un nom libre. Les arrêts sont ajoutés dans l\'ordre.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (p.isRouting || p.stops.isEmpty)
                    ? null
                    : onRecomputeWithStops,
                icon: p.isRouting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(p.isRouting
                    ? 'Calcul...'
                    : 'Recalculer le tracé'),
              ),
            ),
            const SizedBox(height: 10),
            if (p.stops.isEmpty)
              const Text(
                'Aucun arrêt ajouté pour l\'instant.',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.black45),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < p.stops.length; i++)
                    _StopRow(
                      index: i,
                      stop: p.stops[i],
                      onDelete: () => p.removeStop(i),
                    ),
                ],
              ),
          ],
        );
      case BuildLineStep.refine:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Waypoints : ${p.waypoints.length}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              '💡 Optionnel. Clique entre 2 arrêts sur la carte pour forcer '
              'le bus à passer par un point précis (pas d\'arrêt).',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: p.isRouting ? null : onRecomputeWithWaypoints,
                icon: p.isRouting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(p.isRouting
                    ? 'Calcul...'
                    : 'Recalculer le tracé'),
              ),
            ),
          ],
        );
    }
  }

  Widget _actionRow(BuildContext context, BuildLineFlowProvider p) {
    final isLast = step == BuildLineStep.refine;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: (step == BuildLineStep.origin || p.isRouting)
              ? null
              : onPrev,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Précédent'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isLast
                ? const Color(0xFF2E7D32)
                : const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: (p.isRouting || !p.canGoNext)
              ? null
              : (isLast ? onFinish : onNext),
          icon: Icon(isLast ? Icons.check : Icons.arrow_forward, size: 16),
          label: Text(isLast ? 'Terminer' : 'Suivant'),
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  final int index;
  final FlowStop stop;
  final VoidCallback onDelete;

  const _StopRow({
    required this.index,
    required this.stop,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFFF9800),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stop.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          InkWell(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
