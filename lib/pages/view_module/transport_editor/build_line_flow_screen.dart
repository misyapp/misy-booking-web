import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
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

/// Sub-flow à 5 sous-étapes pour construire (ou refaire) une direction de ligne.
///
/// Appelé depuis le wizard (bouton Modifier/Reconstruire) ou depuis le flow
/// "Nouvelle ligne". Retourne un [BuildLineFlowResult] avec le FeatureCollection
/// prêt à être persisté, ou null si l'user annule.
///
/// **Mode "édition rapide"** : si [prefilledFeatureCollection] est non-null,
/// le state du provider est hydraté depuis ce FC et on saute directement à
/// [initialStep] (typiquement [BuildLineStep.review]). Le consultant peut
/// ainsi déplacer un arrêt ou l'arrivée sans repasser par les 4 étapes.
class BuildLineFlowScreen extends StatefulWidget {
  final String lineNumber;
  final String direction; // 'aller' | 'retour'
  final String directionLabel; // "aller" ou "retour" pour l'UI

  /// FeatureCollection de la direction actuelle (si on reconstruit une
  /// ligne existante). Rendu en arrière-fond semi-transparent comme repère
  /// visuel, toggle-able via un bouton dans l'AppBar. `null` = nouvelle
  /// ligne from scratch, pas de référence.
  final Map<String, dynamic>? referenceFeatureCollection;

  /// Couleur de la ligne (format "0xFFRRGGBB" ou "#RRGGBB"). Sert à teinter
  /// le calque de référence pour le rendre reconnaissable. Fallback : bleu.
  final String? referenceColorHex;

  /// Si non-null, hydrate le provider avec ce FC (origin/destination/stops/
  /// route) au lieu de partir d'un état vide. Couplé à [initialStep] pour
  /// ouvrir directement à l'étape Vérifier.
  final Map<String, dynamic>? prefilledFeatureCollection;

  /// Étape de départ. Ignoré si [prefilledFeatureCollection] est null.
  final BuildLineStep initialStep;

  const BuildLineFlowScreen({
    super.key,
    required this.lineNumber,
    required this.direction,
    required this.directionLabel,
    this.referenceFeatureCollection,
    this.referenceColorHex,
    this.prefilledFeatureCollection,
    this.initialStep = BuildLineStep.origin,
  });

  @override
  State<BuildLineFlowScreen> createState() => _BuildLineFlowScreenState();
}

class _BuildLineFlowScreenState extends State<BuildLineFlowScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  MapCamera? _lastCamera;

  // Référence (tracé actuel affiché en arrière-fond)
  List<LatLng> _refLinePoints = const [];
  List<({LatLng pos, String name})> _refStops = const [];
  bool _showReference = true;
  bool _didFitReference = false;

  // Pulse d'opacité pour faire ressortir la référence sans la rendre dominante.
  // Orange clignotant (fade in/out) → signal visuel "repère seulement".
  late final AnimationController _pulseCtrl;
  static const Color _refColor = Color(0xFFFF9800); // orange Material
  // Plage d'opacité basse intentionnellement : pas une donnée à copier.
  static const double _pulseMin = 0.15;
  static const double _pulseMax = 0.45;

  // Nom pré-rempli hérité de la dernière recherche. Non-null quand l'user
  // vient de sélectionner une prédiction et n'a pas encore cliqué sur la carte
  // pour confirmer la position. Le prochain clic carte (étape origin /
  // destination) consomme ce nom comme prefill du dialog.
  String? _pendingSearchName;

  @override
  void initState() {
    super.initState();
    // Assure que OsmStopsService est chargé (charge une fois, idempotent)
    OsmStopsService.instance.load();
    _parseReference();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// Opacité courante dérivée du pulse (triangulaire avec reverse).
  double get _pulseOpacity =>
      _pulseMin + (_pulseMax - _pulseMin) * _pulseCtrl.value;

  void _parseReference() {
    final fc = widget.referenceFeatureCollection;
    if (fc == null) return;
    final linePoints = <LatLng>[];
    final stops = <({LatLng pos, String name})>[];
    for (final f in (fc['features'] as List? ?? [])) {
      final g = f['geometry'] as Map?;
      if (g == null) continue;
      if (g['type'] == 'LineString') {
        for (final c in (g['coordinates'] as List? ?? [])) {
          linePoints.add(LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ));
        }
      } else if (g['type'] == 'Point') {
        final props = (f['properties'] as Map?) ?? const {};
        // Les waypoints (type == 'waypoint') ne sont pas des arrêts visibles,
        // on les ignore côté référence.
        if (props['type'] == 'waypoint') continue;
        final c = g['coordinates'] as List;
        stops.add((
          pos: LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ),
          name: (props['name'] as String?) ?? '',
        ));
      }
    }
    _refLinePoints = linePoints;
    _refStops = stops;
  }

  bool get _hasReference =>
      _refLinePoints.isNotEmpty || _refStops.isNotEmpty;

  /// Construit les layers de référence (polyline + stops) enveloppés dans
  /// des AnimatedBuilder qui se rebuildent à chaque tick du pulse, faisant
  /// ainsi pulser l'opacité sans toucher le reste de la carte.
  List<Widget> _buildPulsingReference() {
    return [
      if (_refLinePoints.isNotEmpty)
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) {
            final op = _pulseOpacity;
            return PolylineLayer(
              polylines: [
                Polyline(
                  points: _refLinePoints,
                  strokeWidth: 6,
                  color: _refColor.withOpacity(op),
                  borderStrokeWidth: 1.5,
                  borderColor: Colors.white.withOpacity(op * 0.6),
                ),
              ],
            );
          },
        ),
      if (_refStops.isNotEmpty)
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) {
            final op = _pulseOpacity;
            return MarkerLayer(
              markers: [
                for (final s in _refStops)
                  Marker(
                    point: s.pos,
                    width: 12,
                    height: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _refColor.withOpacity(op + 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(op * 0.8),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
    ];
  }

  /// Cadre la carte sur la référence (tracé + arrêts) au premier rendu.
  /// Évite d'ouvrir le sub-flow sur un centrage Tana par défaut qui peut
  /// laisser la ligne hors viewport.
  void _maybeFitReference() {
    if (_didFitReference || !_hasReference) return;
    final pts = <LatLng>[
      ..._refLinePoints,
      for (final s in _refStops) s.pos,
    ];
    if (pts.isEmpty) return;
    _didFitReference = true;
    // Schedule après le frame pour que MapController soit prêt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pts),
            padding: const EdgeInsets.all(60),
          ),
        );
      } catch (_) {
        // MapController pas encore prêt → le prochain onMapEvent réessaiera
        _didFitReference = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final p = BuildLineFlowProvider();
        // Mode "édition rapide" : on saute directement à l'étape demandée
        // (typiquement Vérifier) avec la ligne pré-chargée.
        final pre = widget.prefilledFeatureCollection;
        if (pre != null) {
          p.hydrateFromFeatureCollection(
            fc: pre,
            startStep: widget.initialStep,
          );
        }
        return p;
      },
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
              if (_hasReference)
                IconButton(
                  tooltip: _showReference
                      ? 'Masquer le tracé actuel'
                      : 'Afficher le tracé actuel',
                  icon: Icon(
                    _showReference ? Icons.layers : Icons.layers_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _showReference = !_showReference),
                ),
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
                        // Étape review : les 2 boutons de la liste appellent
                        // les mêmes handlers que tap/longpress sur les pins
                        // de la carte, pour cohérence.
                        onStopDelete: (i) => _onReviewStopLongPress(p, i),
                        onStopRename: (i) => _onReviewStopTap(p, i),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          OsmBaseMap(
                            controller: _mapController,
                            onTap: (tp, latLng) => _onMapTap(p, latLng),
                            onMapEvent: (e) {
                              // Capture la camera sur tous les events (incluant
                              // le ready initial) pour que le layer OSM
                              // s'affiche dès l'ouverture, pas seulement au
                              // premier pan.
                              if (mounted) {
                                setState(() => _lastCamera = e.camera);
                              }
                              _maybeFitReference();
                            },
                            children: [
                              // Calque référence (EN BAS pour rester derrière)
                              // : simple repère visuel, PAS une donnée à
                              // revalider. Orange clignotant (pulse d'opacité)
                              // pour le rendre repérable tout en restant
                              // low-intensity.
                              if (_showReference && _hasReference)
                                ..._buildPulsingReference(),
                              // Arrêts OSM bundlés par-dessus la référence pour
                              // rester cliquables quand on pose départ/arrivée
                              // ou arrêts.
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
                              // En étape review : stops draggables pour les
                              // repositionner, avec tap=renommer et
                              // longpress=supprimer. DragMarkers doit venir
                              // après MarkerLayer pour rester au-dessus.
                              if (p.step == BuildLineStep.review) ...[
                                _buildReviewStopsDragLayer(p),
                                // D et A draggables aussi (cas "déplacer
                                // l'arrivée sans tout refaire").
                                _buildReviewTerminiDragLayer(p),
                              ],
                            ],
                          ),
                          if (_pendingSearchName != null)
                            Positioned(
                              top: 12,
                              left: 12,
                              right: 12,
                              child: _SearchHintBanner(
                                name: _pendingSearchName!,
                                isOrigin: p.step == BuildLineStep.origin,
                                onDismiss: () => setState(
                                    () => _pendingSearchName = null),
                              ),
                            ),
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
    final isReview = p.step == BuildLineStep.review;

    // En étape review, D/A et arrêts sont rendus via DragMarkers (drag).
    // Voir _buildReviewTerminiDragLayer + _buildReviewStopsDragLayer.
    if (!isReview) {
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

  /// Layer DragMarkers pour D et A en étape review : permet au consultant de
  /// déplacer le départ ou l'arrivée sans repasser par les étapes 1/2.
  /// Marque la route comme dirty → "Recalculer le tracé" devient nécessaire.
  Widget _buildReviewTerminiDragLayer(BuildLineFlowProvider p) {
    return DragMarkers(
      alignment: Alignment.topCenter,
      markers: [
        if (p.origin != null)
          DragMarker(
            key: const ValueKey('review-origin'),
            point: p.origin!,
            size: const Size(64, 74),
            alignment: Alignment.topCenter,
            builder: (ctx, pos, isDragging) => _AnimatedPin(
              label: 'D',
              color: isDragging
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFF2E7D32),
              pulse: false,
            ),
            onDragEnd: (_, newPos) =>
                p.setOrigin(newPos, name: p.originName),
          ),
        if (p.destination != null)
          DragMarker(
            key: const ValueKey('review-destination'),
            point: p.destination!,
            size: const Size(64, 74),
            alignment: Alignment.topCenter,
            builder: (ctx, pos, isDragging) => _AnimatedPin(
              label: 'A',
              color: isDragging
                  ? const Color(0xFFEF5350)
                  : const Color(0xFFC62828),
              pulse: false,
            ),
            onDragEnd: (_, newPos) =>
                p.setDestination(newPos, name: p.destinationName),
          ),
      ],
    );
  }

  /// Layer DragMarkers spécifique à l'étape review : chaque arrêt peut être
  /// déplacé (drag), renommé (tap), supprimé (long press). La clé du marker
  /// inclut le nom pour forcer un re-layout si l'user renomme (sinon
  /// flutter_map_dragmarker garde le même widget et le label bouge pas).
  Widget _buildReviewStopsDragLayer(BuildLineFlowProvider p) {
    return DragMarkers(
      alignment: Alignment.topCenter,
      markers: [
        for (int i = 0; i < p.stops.length; i++)
          DragMarker(
            key: ValueKey('review-stop-$i-${p.stops[i].name}'),
            point: p.stops[i].position,
            size: const Size(64, 74),
            alignment: Alignment.topCenter,
            builder: (ctx, pos, isDragging) {
              return _AnimatedPin(
                label: '${i + 1}',
                color: isDragging
                    ? Colors.orange
                    : const Color(0xFFFF9800),
                pulse: false,
              );
            },
            onDragEnd: (_, newPos) => p.moveStop(i, newPos),
            onTap: (_) => _onReviewStopTap(p, i),
            onLongPress: (_) => _onReviewStopLongPress(p, i),
          ),
      ],
    );
  }

  // ─────── Handlers ───────

  Future<void> _onMapTap(BuildLineFlowProvider p, LatLng latLng) async {
    switch (p.step) {
      case BuildLineStep.origin:
        await _setTerminusWithPrompt(p, latLng,
            isOrigin: true, prefillName: _consumePendingSearchName());
        break;
      case BuildLineStep.destination:
        await _setTerminusWithPrompt(p, latLng,
            isOrigin: false, prefillName: _consumePendingSearchName());
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
      case BuildLineStep.review:
        await _onReviewInsertStop(p, latLng);
        break;
    }
  }

  /// Renvoie le nom en attente (recherche Nominatim) et le reset à `null`.
  /// Utilisé par le prochain clic carte pour pré-remplir le dialog de nommage.
  String? _consumePendingSearchName() {
    final n = _pendingSearchName;
    if (n != null) {
      setState(() => _pendingSearchName = null);
    }
    return n;
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
      case BuildLineStep.review:
        await _onReviewInsertStop(p, stop.position,
            prefillName: stop.hasName ? stop.name : null,
            osmId: stop.id);
        return;
    }
  }

  // ─────── Handlers étape Vérifier ───────

  /// Insère un arrêt au segment le plus proche du clic. Utilisé par
  /// _onMapTap et _onOsmStopTap en étape review.
  Future<void> _onReviewInsertStop(
    BuildLineFlowProvider p,
    LatLng pos, {
    String? prefillName,
    String? osmId,
  }) async {
    final name = await _promptStopName(
      context,
      initialName: prefillName ?? '',
      title: 'Insérer un arrêt',
    );
    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final insertedAt =
        p.insertStopAtClosestSegment(pos, trimmed, osmId: osmId);
    if (!mounted) return;
    _snack(context,
        'Arrêt inséré en position ${insertedAt + 1} — recalcule le tracé avant de terminer');
  }

  /// Tap sur un pin existant en étape review : éditer nom + numéro.
  /// Permet de réordonner sans drag — utile quand on ajoute un arrêt oublié
  /// entre deux autres (l'arrêt s'insère selon la géométrie ; si OSRM le
  /// numérote mal, on corrige ici puis on recalcule le tracé).
  Future<void> _onReviewStopTap(BuildLineFlowProvider p, int index) async {
    final stop = p.stops[index];
    final result = await _promptStopRenameAndReorder(
      context,
      initialName: stop.name,
      currentOrder: index + 1,
      totalStops: p.stops.length,
    );
    if (result == null) return;

    final nameChanged = result.name != stop.name;
    if (nameChanged) p.renameStop(index, result.name);

    final desiredIdx = result.order - 1;
    if (desiredIdx != index) {
      p.setStopOrder(index, desiredIdx);
      if (mounted) {
        _snack(context,
            'Arrêt déplacé en position ${result.order} — recalcule le tracé avant de terminer');
      }
    }
  }

  /// Dialog combiné nom + numéro pour réordonner un arrêt sans drag.
  /// Le numéro est clampé sur `[1, totalStops]` au submit.
  Future<({String name, int order})?> _promptStopRenameAndReorder(
    BuildContext context, {
    required String initialName,
    required int currentOrder,
    required int totalStops,
  }) {
    final nameController = TextEditingController(text: initialName);
    nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initialName.length,
    );
    final orderController =
        TextEditingController(text: currentOrder.toString());

    void submit(BuildContext ctx) {
      final name = nameController.text.trim();
      if (name.isEmpty) return;
      final parsed = int.tryParse(orderController.text.trim());
      final order = (parsed ?? currentOrder).clamp(1, totalStops);
      Navigator.of(ctx).pop((name: name, order: order));
    }

    return showDialog<({String name, int order})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier l\'arrêt $currentOrder'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  hintText: 'Ex: Ankadifotsy',
                ),
                onSubmitted: (_) => submit(ctx),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: orderController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Numéro (1 à $totalStops)',
                  helperText:
                      'Modifie le numéro pour réordonner sans déplacer le pin',
                  helperMaxLines: 2,
                ),
                onSubmitted: (_) => submit(ctx),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => submit(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Long press sur un pin existant en étape review : supprimer (avec confirm).
  Future<void> _onReviewStopLongPress(
      BuildLineFlowProvider p, int index) async {
    final name = p.stops[index].name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet arrêt ?'),
        content: Text(
          'L\'arrêt ${index + 1} « $name » sera supprimé.\n\n'
          'Les arrêts suivants seront renumérotés. Tu devras recalculer le tracé avant de terminer.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    p.removeStop(index);
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
      // Auto-advance vers l'étape arrivée : le clic "Ajouter" du dialog est
      // un commitment clair. Sans ça, le consultant suppose qu'il peut
      // cliquer directement sur la carte pour poser l'arrivée — et re-bouge
      // son départ à la place. Pour corriger la position du départ, utiliser
      // le bouton Précédent (reste sur la même étape avec le pin placé).
      if (mounted && p.step == BuildLineStep.origin) {
        p.setStep(BuildLineStep.destination);
        _snack(context, 'Départ placé ✓  — place maintenant l\'arrivée');
      }
    } else {
      p.setDestination(pos, name: trimmed);
    }
  }

  /// Sélection d'une prédiction de recherche : on zoom sur la zone et on
  /// mémorise le nom comme prefill. **Ne pose pas** le pin ni n'ouvre de dialog
  /// — l'user doit cliquer sur la carte pour confirmer la position exacte
  /// (la géolocalisation Nominatim est approximative selon le type de lieu).
  void _onPlaceSearchSelected(
      BuildLineFlowProvider p, LatLng latLng, String description) {
    _mapController.move(latLng, 17);
    if (p.step != BuildLineStep.origin &&
        p.step != BuildLineStep.destination) {
      return;
    }
    setState(() => _pendingSearchName = _firstComma(description));
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
        // Auto-recalcul du tracé complet avec les arrêts. Évite à l'user
        // de cliquer "Recalculer" manuellement avant "Suivant". Si OSRM
        // échoue, on avance quand même — l'user verra le banner dirty à
        // l'étape suivante et pourra retenter.
        if (p.isRouteDirty) {
          final ok = await p.recomputeFullRoute();
          if (!mounted) return;
          if (!ok) {
            _snack(context,
                'OSRM KO — tu pourras recalculer à l\'étape suivante');
          }
        }
        p.setStep(BuildLineStep.refine);
        break;
      case BuildLineStep.refine:
        // Même logique qu'au-dessus : auto-recalcul si l'user a touché
        // aux waypoints, puis on avance vers Vérifier.
        if (p.isRouteDirty) {
          final ok = await p.recomputeFullRoute();
          if (!mounted) return;
          if (!ok) {
            _snack(context,
                'OSRM KO — recalcule manuellement à l\'étape Vérifier');
          }
        }
        p.setStep(BuildLineStep.review);
        break;
      case BuildLineStep.review:
        // Le bouton "Suivant" n'existe pas à cette étape (c'est "Terminer").
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
      case BuildLineStep.review:
        p.setStep(BuildLineStep.refine);
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

  Future<void> _onFinish(BuildLineFlowProvider p) async {
    if (!p.hasRoute || p.stops.length < 2) {
      _snack(context, 'Tracé ou arrêts incomplets');
      return;
    }
    // Si dirty : tente un dernier recompute OSRM. Si échec, demande
    // confirmation à l'user (route périmée mais sauvable quand même).
    if (p.isRouteDirty) {
      final ok = await p.recomputeFullRoute();
      if (!mounted) return;
      if (!ok) {
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Tracé non recalculé'),
                content: const Text(
                    'OSRM n\'a pas pu recalculer le tracé. Le tracé '
                    'actuellement affiché peut ne pas refléter exactement la '
                    'séquence des arrêts.\n\nSauver quand même ?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Annuler')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Sauver tel quel'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!confirmed || !mounted) return;
      }
    }
    final fc = p.buildFeatureCollection(
      lineNumber: widget.lineNumber,
      direction: widget.direction,
    );
    final lsFeature = (fc['features'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (f) => (f['geometry'] as Map?)?['type'] == 'LineString',
          orElse: () => const {},
        );
    final numVertices =
        ((lsFeature['geometry'] as Map?)?['coordinates'] as List?)?.length ??
            0;
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
      ('⑤ Vérifier', BuildLineStep.review),
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
  // Callbacks spécifiques à l'étape review : delete + rename sur un arrêt.
  // Optionnels pour que les autres étapes n'aient pas à les passer.
  final void Function(int index)? onStopDelete;
  final void Function(int index)? onStopRename;

  const _SidePanel({
    required this.step,
    required this.onNext,
    required this.onPrev,
    required this.onFinish,
    required this.onPlaceSearchSelected,
    required this.onRecomputeWithStops,
    required this.onRecomputeWithWaypoints,
    this.onStopDelete,
    this.onStopRename,
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
                  ? (step == BuildLineStep.origin
                      // Cas atteint uniquement via Précédent depuis l'arrivée.
                      // On rappelle que l'étape suivante est l'arrivée et que
                      // le re-clic carte ajuste la position du départ.
                      ? '📍 Départ${name != null && name.isNotEmpty ? " : $name" : ""}.\n\nRe-clique sur la carte pour corriger la position, puis repasse à l\'arrivée via Suivant.'
                      // Destination : on pointe explicitement vers le bouton
                      // Suivant (qui déclenche OSRM). Le re-clic carte ajuste
                      // la position, mais l'action principale est Suivant.
                      : '📍 Arrivée${name != null && name.isNotEmpty ? " : $name" : ""}.\n\nClique « Suivant » en bas pour calculer le tracé.\n(Re-clic sur la carte pour ajuster la position.)')
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
      case BuildLineStep.review:
        return _ReviewPanel(
          provider: p,
          onRecompute: onRecomputeWithWaypoints,
          onStopDelete: onStopDelete,
          onStopRename: onStopRename,
        );
    }
  }

  Widget _actionRow(BuildContext context, BuildLineFlowProvider p) {
    // "Terminer" est désormais à l'étape review (la 5e et dernière). Les
    // étapes précédentes affichent "Suivant".
    final isLast = step == BuildLineStep.review;
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

/// Banner affiché en haut de la carte quand l'user vient de sélectionner une
/// prédiction de recherche mais n'a pas encore cliqué sur la carte pour
/// poser le point. Rappelle que le clic valide la position exacte.
class _SearchHintBanner extends StatelessWidget {
  final String name;
  final bool isOrigin;
  final VoidCallback onDismiss;

  const _SearchHintBanner({
    required this.name,
    required this.isOrigin,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final label = isOrigin ? 'départ' : 'arrivée';
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xFF1565C0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.touch_app, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Clique sur la carte pour placer le point de $label',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '« $name » — la position exacte vient de ton clic',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              tooltip: 'Annuler',
              onPressed: onDismiss,
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final int index;
  final FlowStop stop;
  final VoidCallback onDelete;
  /// Optionnel. Quand fourni, le nom devient tappable (tap = renommer) et
  /// un bouton crayon ✏️ apparaît. Utilisé dans l'étape review où l'user
  /// peut corriger un arrêt sans refaire tout le flow.
  final VoidCallback? onRename;

  const _StopRow({
    required this.index,
    required this.stop,
    required this.onDelete,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final nameWidget = Text(
      stop.name,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    );
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
            child: onRename != null
                ? InkWell(onTap: onRename, child: nameWidget)
                : nameWidget,
          ),
          if (onRename != null)
            InkWell(
              onTap: onRename,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.edit, size: 14, color: Colors.black54),
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

// ─────────────────────── Review panel (étape ⑤) ───────────────────────

/// Panneau latéral de l'étape « Vérifier » : liste des arrêts avec
/// rename/delete, bouton recalculer (prominent si dirty), bannière warning
/// tracé obsolète, et récap origin/destination en bas (read-only).
class _ReviewPanel extends StatelessWidget {
  final BuildLineFlowProvider provider;
  final VoidCallback onRecompute;
  final void Function(int index)? onStopDelete;
  final void Function(int index)? onStopRename;

  const _ReviewPanel({
    required this.provider,
    required this.onRecompute,
    required this.onStopDelete,
    required this.onStopRename,
  });

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🧐 Vérification finale',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        Text(
          '${p.stops.length} arrêt${p.stops.length > 1 ? "s" : ""}'
          ' · ${p.waypoints.length} waypoint${p.waypoints.length > 1 ? "s" : ""}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        // Aide concise. Les 3 modes d'édition directe sur la carte et les
        // 2 depuis la liste sont listés ici pour que l'user n'ait pas à
        // deviner.
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Comment modifier :\n'
            '• Drag un pin pour le déplacer\n'
            '• Tap un pin pour le renommer\n'
            '• Long press un pin pour le supprimer\n'
            '• Clic libre sur la carte = insérer un arrêt (auto-placé entre les 2 plus proches)',
            style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        if (p.isRouteDirty) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFF9800)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber,
                    size: 16, color: Color(0xFFE65100)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tracé obsolète depuis ta modif. Recalcule avant de terminer.',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFFE65100)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: p.isRouteDirty
                  ? const Color(0xFFFF9800)
                  : Colors.grey[300],
              foregroundColor:
                  p.isRouteDirty ? Colors.white : Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: p.isRouting ? null : onRecompute,
            icon: p.isRouting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync, size: 16),
            label: Text(p.isRouting ? 'Calcul...' : 'Recalculer le tracé'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Arrêts (dans l\'ordre)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        if (p.stops.isEmpty)
          const Text(
            'Aucun arrêt.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.black45,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < p.stops.length; i++)
                _StopRow(
                  index: i,
                  stop: p.stops[i],
                  onDelete: () => onStopDelete?.call(i),
                  onRename: () => onStopRename?.call(i),
                ),
            ],
          ),
        const SizedBox(height: 12),
        const Divider(),
        Text('Départ : ${p.originName ?? "?"}',
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text('Arrivée : ${p.destinationName ?? "?"}',
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 2),
        const Text(
          '(pour corriger départ/arrivée, clique Précédent jusqu\'aux étapes ①②)',
          style: TextStyle(
            fontSize: 10,
            color: Colors.black45,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
