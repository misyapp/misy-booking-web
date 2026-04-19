import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/editable_polyline_layer.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/editable_stops_layer.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/osm_base_map.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/tutorial_helpers.dart';
import 'package:rider_ride_hailing_app/provider/transport_editor_provider.dart';
import 'package:rider_ride_hailing_app/services/transport_editor_service.dart';
import 'package:rider_ride_hailing_app/services/transport_osrm_service.dart';
import 'package:showcaseview/showcaseview.dart';

enum _NewStep { meta, allerRoute, allerStops, retourRoute, retourStops, review }

class EditorNewLineScreen extends StatefulWidget {
  const EditorNewLineScreen({super.key});

  @override
  State<EditorNewLineScreen> createState() => _EditorNewLineScreenState();
}

class _EditorNewLineScreenState extends State<EditorNewLineScreen> {
  _NewStep _step = _NewStep.meta;

  // Metadata
  final _numberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _transportType = 'bus';
  int _colorValue = 0xFF1565C0;

  // Geometry working state
  List<LatLng> _allerVertices = [];
  List<EditableStop> _allerStops = [];
  List<LatLng> _retourVertices = [];
  List<EditableStop> _retourStops = [];

  final MapController _mapCtrl = MapController();
  bool _submitting = false;

  final GlobalKey _tutoMetaKey = GlobalKey();
  final GlobalKey _tutoMapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    TutorialHelper.autoStartOnce(
      context: context,
      tourId: 'new_line_v1',
      keys: [_tutoMetaKey],
    );
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          title: Text('Nouvelle ligne · ${_stepLabel(_step)}'),
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
        ),
        body: _buildStepBody(),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case _NewStep.meta:
        return _buildMetaForm();
      case _NewStep.allerRoute:
        return _buildRouteEditor(
          vertices: _allerVertices,
          onUpdate: (v) => setState(() => _allerVertices = v),
          hint:
              'Aller — tape sur la carte pour poser les points clés du tracé, '
              'puis "Tracer auto" suit les routes OSM.',
        );
      case _NewStep.allerStops:
        return _buildStopsEditor(
          vertices: _allerVertices,
          stops: _allerStops,
          onUpdate: (s) => setState(() => _allerStops = s),
          hint: 'Arrêts aller — tape la carte pour poser chaque arrêt.',
        );
      case _NewStep.retourRoute:
        return _buildRouteEditor(
          vertices: _retourVertices,
          onUpdate: (v) => setState(() => _retourVertices = v),
          hint:
              'Retour — tu peux copier l\'aller inversé ou tracer différemment.',
          mirrorFromAller: true,
        );
      case _NewStep.retourStops:
        return _buildStopsEditor(
          vertices: _retourVertices,
          stops: _retourStops,
          onUpdate: (s) => setState(() => _retourStops = s),
          hint: 'Arrêts retour — option miroir de l\'aller disponible.',
          mirrorFromAller: true,
        );
      case _NewStep.review:
        return _buildReview();
    }
  }

  Widget _buildMetaForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TutoStep(
        stepKey: _tutoMetaKey,
        title: 'Métadonnées',
        description:
            'Renseigne d\'abord le numéro, le nom et la couleur de la ligne. '
            'Ces infos apparaîtront partout dans l\'app.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InfoCard(
              icon: Icons.info_outline,
              text:
                  'Tu es en train de créer une nouvelle ligne de bus. '
                  'Elle sera marquée "à importer" et Misy la récupérera '
                  'dans les sources en fin de session.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numberCtrl,
              decoration: const InputDecoration(
                labelText: 'Numéro / code',
                hintText: 'ex: 201, TCE2…',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom affiché',
                hintText: 'ex: Ligne 201',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _transportType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'bus', child: Text('Bus / Taxi-be')),
                DropdownMenuItem(
                    value: 'urbanTrain', child: Text('Train urbain')),
                DropdownMenuItem(
                    value: 'telepherique', child: Text('Téléphérique')),
              ],
              onChanged: (v) => setState(() => _transportType = v ?? 'bus'),
            ),
            const SizedBox(height: 16),
            const Text('Couleur de la ligne',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetColors.map(_colorSwatch).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorSwatch(int c) {
    final selected = _colorValue == c;
    return InkWell(
      onTap: () => setState(() => _colorValue = c),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Color(c),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.grey.shade300,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteEditor({
    required List<LatLng> vertices,
    required ValueChanged<List<LatLng>> onUpdate,
    required String hint,
    bool mirrorFromAller = false,
  }) {
    return Column(
      children: [
        _hintBar(hint),
        Expanded(
          child: TutoStep(
            stepKey: _tutoMapKey,
            title: 'Dessin du tracé',
            description:
                'Tape sur la carte pour poser des points. Le bouton "Tracer '
                'auto" calcule un tracé routier entre le premier et le dernier '
                'point via OSRM.',
            child: OsmBaseMap(
              controller: _mapCtrl,
              onTap: (_, latlng) {
                final v = List<LatLng>.of(vertices)..add(latlng);
                onUpdate(v);
              },
              children: [
                EditablePolylineLayer(
                  vertices: vertices,
                  color: Color(_colorValue),
                  editable: true,
                  onVertexMoved: (i, p) {
                    final v = List<LatLng>.of(vertices);
                    v[i] = p;
                    onUpdate(v);
                  },
                  onVertexRemoved: (i) {
                    if (vertices.length <= 2) return;
                    final v = List<LatLng>.of(vertices)..removeAt(i);
                    onUpdate(v);
                  },
                  onVertexInserted: (i, p) {
                    final v = List<LatLng>.of(vertices)..insert(i + 1, p);
                    onUpdate(v);
                  },
                ),
              ],
            ),
          ),
        ),
        _buildRouteToolbar(vertices, onUpdate, mirrorFromAller),
      ],
    );
  }

  Widget _buildRouteToolbar(
    List<LatLng> vertices,
    ValueChanged<List<LatLng>> onUpdate,
    bool mirrorFromAller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Text('${vertices.length} points',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: vertices.length < 2
                ? null
                : () async {
                    final coords = await TransportOsrmService.instance
                        .routeDriving(
                            [vertices.first, vertices.last]);
                    if (!mounted) return;
                    if (coords == null) {
                      _snack('OSRM indisponible');
                      return;
                    }
                    onUpdate(
                        coords.map((c) => LatLng(c[1], c[0])).toList());
                  },
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Tracer auto'),
          ),
          if (mirrorFromAller && _allerVertices.isNotEmpty)
            TextButton.icon(
              onPressed: () =>
                  onUpdate(_allerVertices.reversed.toList()),
              icon: const Icon(Icons.swap_vert),
              label: const Text('Copier aller inversé'),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: vertices.isEmpty
                ? null
                : () async {
                    if (await _confirm('Effacer le tracé ?')) {
                      onUpdate([]);
                    }
                  },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Effacer'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildStopsEditor({
    required List<LatLng> vertices,
    required List<EditableStop> stops,
    required ValueChanged<List<EditableStop>> onUpdate,
    required String hint,
    bool mirrorFromAller = false,
  }) {
    return Column(
      children: [
        _hintBar(hint),
        Expanded(
          child: OsmBaseMap(
            controller: _mapCtrl,
            onTap: (_, latlng) async {
              final name = await _promptName('Nom du nouvel arrêt');
              if (name == null || name.isEmpty) return;
              final next = List<EditableStop>.of(stops)
                ..add(EditableStop(name: name, position: latlng));
              onUpdate(next);
            },
            children: [
              EditablePolylineLayer(
                vertices: vertices,
                color: Color(_colorValue).withOpacity(0.6),
                editable: false,
              ),
              EditableStopsLayer(
                stops: stops,
                editable: true,
                onStopMoved: (i, pos) {
                  final next = List<EditableStop>.of(stops);
                  next[i].position = pos;
                  onUpdate(next);
                },
                onStopTapped: (i) async {
                  final name = await _promptName(
                      'Renommer l\'arrêt', initial: stops[i].name);
                  if (name == null) return;
                  final next = List<EditableStop>.of(stops);
                  next[i].name = name;
                  onUpdate(next);
                },
                onStopLongPressed: (i) async {
                  if (await _confirm(
                      'Supprimer l\'arrêt ${stops[i].name} ?')) {
                    final next = List<EditableStop>.of(stops)..removeAt(i);
                    onUpdate(next);
                  }
                },
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Text('${stops.length} arrêts',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (mirrorFromAller && _allerStops.isNotEmpty)
                TextButton.icon(
                  onPressed: () => onUpdate(_allerStops
                      .reversed
                      .map((s) => EditableStop(
                          name: s.name, position: s.position))
                      .toList()),
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('Miroir arrêts aller'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Récapitulatif',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _reviewRow('Numéro', _numberCtrl.text.trim()),
          _reviewRow('Nom affiché', _nameCtrl.text.trim()),
          _reviewRow('Type', _transportType),
          _reviewRow('Couleur',
              '#${_colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}'),
          const Divider(height: 32),
          _reviewRow('Tracé aller', '${_allerVertices.length} points'),
          _reviewRow('Arrêts aller', '${_allerStops.length}'),
          _reviewRow('Tracé retour', '${_retourVertices.length} points'),
          _reviewRow('Arrêts retour', '${_retourStops.length}'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Créer la ligne'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _hintBar(String hint) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF8E1),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_outlined,
              color: Color(0xFFF57F17), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(hint, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    final canNext = _stepIsValid();
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          children: [
            if (_step != _NewStep.meta)
              OutlinedButton.icon(
                onPressed: () => _gotoStep(_prevStep(_step)),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour'),
              ),
            const Spacer(),
            if (_step != _NewStep.review)
              ElevatedButton.icon(
                onPressed: canNext ? () => _gotoStep(_nextStep(_step)) : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Suivant'),
              ),
          ],
        ),
      ),
    );
  }

  bool _stepIsValid() {
    switch (_step) {
      case _NewStep.meta:
        return _numberCtrl.text.trim().isNotEmpty &&
            _nameCtrl.text.trim().isNotEmpty;
      case _NewStep.allerRoute:
        return _allerVertices.length >= 2;
      case _NewStep.allerStops:
        return _allerStops.length >= 2;
      case _NewStep.retourRoute:
        return _retourVertices.length >= 2;
      case _NewStep.retourStops:
        return _retourStops.length >= 2;
      case _NewStep.review:
        return true;
    }
  }

  _NewStep _nextStep(_NewStep s) {
    final idx = _NewStep.values.indexOf(s);
    return _NewStep.values[
        (idx + 1).clamp(0, _NewStep.values.length - 1)];
  }

  _NewStep _prevStep(_NewStep s) {
    final idx = _NewStep.values.indexOf(s);
    return _NewStep.values[(idx - 1).clamp(0, _NewStep.values.length - 1)];
  }

  String _stepLabel(_NewStep s) {
    switch (s) {
      case _NewStep.meta:
        return '1/6 · Infos ligne';
      case _NewStep.allerRoute:
        return '2/6 · Tracé aller';
      case _NewStep.allerStops:
        return '3/6 · Arrêts aller';
      case _NewStep.retourRoute:
        return '4/6 · Tracé retour';
      case _NewStep.retourStops:
        return '5/6 · Arrêts retour';
      case _NewStep.review:
        return '6/6 · Récap';
    }
  }

  void _gotoStep(_NewStep s) {
    setState(() => _step = s);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final lineNumber = _numberCtrl.text.trim();
      final displayName = _nameCtrl.text.trim();
      final colorHex =
          '0x${_colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}';

      final allerFC = GeoJsonHelpers.emptyFeatureCollection(
        lineNumber: lineNumber,
        direction: 'aller',
      );
      final allerWithLine = GeoJsonHelpers.replaceLineString(
        allerFC,
        _allerVertices.map((v) => [v.longitude, v.latitude]).toList(),
      );
      final allerFull = GeoJsonHelpers.replaceStops(
        allerWithLine,
        _allerStops
            .map((s) => GeoJsonHelpers.makeStopFeature(
                  lng: s.position.longitude,
                  lat: s.position.latitude,
                  name: s.name,
                ))
            .toList(),
      );

      final retourFC = GeoJsonHelpers.emptyFeatureCollection(
        lineNumber: lineNumber,
        direction: 'retour',
      );
      final retourWithLine = GeoJsonHelpers.replaceLineString(
        retourFC,
        _retourVertices.map((v) => [v.longitude, v.latitude]).toList(),
      );
      final retourFull = GeoJsonHelpers.replaceStops(
        retourWithLine,
        _retourStops
            .map((s) => GeoJsonHelpers.makeStopFeature(
                  lng: s.position.longitude,
                  lat: s.position.latitude,
                  name: s.name,
                ))
            .toList(),
      );

      await TransportEditorService.instance.createNewLine(
        lineNumber: lineNumber,
        displayName: displayName,
        transportType: _transportType,
        colorHex: colorHex,
        allerFeatureCollection: allerFull,
        retourFeatureCollection: retourFull,
      );

      if (!mounted) return;
      _snack('Ligne $lineNumber créée ✓');
      Navigator.of(context).pop();
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String?> _promptName(String title, {String? initial}) {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<bool> _confirm(String msg) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return res == true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

const List<int> _presetColors = [
  0xFF1565C0, 0xFF2E7D32, 0xFFD32F2F, 0xFFE65100,
  0xFF6A1B9A, 0xFF00695C, 0xFFAD1457, 0xFF283593,
  0xFF5D4037, 0xFFF57F17, 0xFF00838F, 0xFF546E7A,
];

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
