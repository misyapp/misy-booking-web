import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/build_line_flow_screen.dart';
import 'package:rider_ride_hailing_app/provider/build_line_flow_provider.dart';
import 'package:rider_ride_hailing_app/services/transport_editor_service.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';

/// Vue admin « Lignes en prod ».
///
/// Liste toutes les lignes telles qu'elles sont servies en production
/// (manifest bundlé + overrides publiés via [TransportLinesService.loadAllLines]),
/// les rend sur une carte OSM, et permet de lancer une correction d'une
/// direction : ouvre [BuildLineFlowScreen] à l'étape review pré-chargée avec la
/// FeatureCollection publiée (fallback : LineString reconstruit depuis les
/// coordonnées prod), puis republie via
/// [TransportEditorService.adminEditAndPublish] au retour.
class ProdLinesViewerScreen extends StatefulWidget {
  const ProdLinesViewerScreen({super.key});

  @override
  State<ProdLinesViewerScreen> createState() => _ProdLinesViewerScreenState();
}

class _ProdLinesViewerScreenState extends State<ProdLinesViewerScreen> {
  static const _accent = Color(0xFF5E35B1);

  List<TransportLineGroup> _groups = [];
  Map<String, LineMetadata> _meta = {};
  bool _loading = true;
  bool _busy = false;
  bool _publishedOnly = true;
  String _query = '';
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await TransportLinesService.instance.loadAllLines();
    final metaList =
        await TransportLinesService.instance.getAllLineMetadataForEditor();
    if (!mounted) return;
    setState(() {
      _groups = [...groups]
        ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
      _meta = {for (final m in metaList) m.lineNumber: m};
      _loading = false;
    });
  }

  LineMetadata? _metaFor(String ln) => _meta[ln];

  bool _isPublished(String ln) =>
      _metaFor(ln)?.publicationState == LinePublicationState.published;

  List<TransportLineGroup> get _visible {
    final q = _query.trim().toLowerCase();
    return _groups.where((g) {
      if (_publishedOnly && !_isPublished(g.lineNumber)) return false;
      if (q.isNotEmpty &&
          !g.lineNumber.toLowerCase().contains(q) &&
          !g.displayName.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Color _colorOf(String ln) {
    final m = _metaFor(ln);
    return m != null ? Color(m.colorValue) : _accent;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────── Corriger ───────────────────────────

  /// Reconstruit une FeatureCollection minimale (LineString) à partir des
  /// coordonnées prod, quand aucune FC publiée n'existe (ligne bundlée jamais
  /// éditée). Permet au flow review de s'ouvrir sur la géométrie réelle.
  Map<String, dynamic>? _lineStringFc(TransportLineGroup g, String direction) {
    final line = direction == 'aller' ? g.aller : g.retour;
    if (line == null || line.coordinates.length < 2) return null;
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'line': g.lineNumber},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final c in line.coordinates) [c.longitude, c.latitude],
            ],
          },
        },
      ],
    };
  }

  Future<void> _corriger(TransportLineGroup g, String direction) async {
    if (_busy) return;
    final meta = _metaFor(g.lineNumber);
    var fc = await TransportEditorService.instance
        .loadPublishedFeatureCollection(g.lineNumber, direction);
    fc ??= _lineStringFc(g, direction);
    if (fc == null) {
      _snack('Aucune géométrie disponible pour cette direction.');
      return;
    }
    if (!mounted) return;
    final result = await Navigator.of(context).push<BuildLineFlowResult>(
      MaterialPageRoute(
        builder: (_) => BuildLineFlowScreen(
          lineNumber: g.lineNumber,
          direction: direction,
          directionLabel: direction,
          referenceFeatureCollection: fc,
          prefilledFeatureCollection: fc,
          referenceColorHex: meta?.colorHex,
          initialStep: BuildLineStep.review,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await TransportEditorService.instance.adminEditAndPublish(
        lineNumber: g.lineNumber,
        direction: direction,
        featureCollection: result.featureCollection,
        lineMetadata: meta == null
            ? null
            : {
                'display_name': meta.displayName,
                'transport_type': meta.transportType,
                'color': meta.colorHex,
                'importance_tier': meta.importanceTier,
              },
        numStops: result.numStops,
        numVertices: result.numVertices,
      );
      if (!mounted) return;
      _snack('Ligne ${g.lineNumber} ($direction) corrigée et publiée ✓');
      await _load();
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─────────────────────────── Build ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final publishedCount =
        _groups.where((g) => _isPublished(g.lineNumber)).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Lignes en prod ($publishedCount)'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                LayoutBuilder(
                  builder: (ctx, c) {
                    final wide = c.maxWidth >= 900;
                    final list = _buildList(visible);
                    final map = _buildMap(visible);
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 360, child: list),
                          const VerticalDivider(width: 1),
                          Expanded(child: map),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(flex: 5, child: map),
                        const Divider(height: 1),
                        Expanded(flex: 4, child: list),
                      ],
                    );
                  },
                ),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildList(List<TransportLineGroup> visible) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: 'Filtrer (numéro ou nom)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text('${visible.length} ligne(s)',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ),
              const Text('Publiées seul.', style: TextStyle(fontSize: 12)),
              Switch(
                value: _publishedOnly,
                activeColor: _accent,
                onChanged: (v) => setState(() => _publishedOnly = v),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('Aucune ligne'))
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => _tile(visible[i]),
                ),
        ),
      ],
    );
  }

  Widget _tile(TransportLineGroup g) {
    final selected = g.lineNumber == _selected;
    final published = _isPublished(g.lineNumber);
    return Container(
      color: selected ? _accent.withOpacity(0.08) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            onTap: () =>
                setState(() => _selected = selected ? null : g.lineNumber),
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: _colorOf(g.lineNumber), shape: BoxShape.circle),
            ),
            title: Text('Ligne ${g.lineNumber} — ${g.displayName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Row(
              children: [
                Icon(_typeIcon(g.transportType),
                    size: 13, color: Colors.black45),
                const SizedBox(width: 4),
                _statusChip(published),
              ],
            ),
            trailing: Icon(
                selected ? Icons.expand_less : Icons.chevron_right,
                size: 18),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
              child: Row(
                children: [
                  if (g.aller != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_road, size: 16),
                        label: const Text('Corriger aller',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _corriger(g, 'aller'),
                      ),
                    ),
                  if (g.aller != null && g.retour != null)
                    const SizedBox(width: 8),
                  if (g.retour != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_road, size: 16),
                        label: const Text('Corriger retour',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _corriger(g, 'retour'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(bool published) {
    final c = published ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(published ? 'Publié' : 'Non publié',
          style: TextStyle(
              fontSize: 10, color: c, fontWeight: FontWeight.w600)),
    );
  }

  IconData _typeIcon(TransportType t) {
    switch (t) {
      case TransportType.urbanTrain:
        return Icons.train;
      case TransportType.telepherique:
        return Icons.cable;
      case TransportType.bus:
        return Icons.directions_bus;
    }
  }

  // ─────────────────────────── Map ───────────────────────────

  List<LatLng> _ptsOf(TransportLine? line) {
    if (line == null) return const [];
    return [for (final c in line.coordinates) LatLng(c.latitude, c.longitude)];
  }

  Widget _buildMap(List<TransportLineGroup> visible) {
    final polylines = <Polyline>[];
    final fitPoints = <LatLng>[];

    if (_selected == null) {
      // Vue d'ensemble : toutes les lignes visibles, fines.
      for (final g in visible) {
        final col = _colorOf(g.lineNumber).withOpacity(0.55);
        for (final dir in [g.aller, g.retour]) {
          final pts = _ptsOf(dir);
          if (pts.length >= 2) {
            polylines.add(Polyline(points: pts, color: col, strokeWidth: 2));
          }
        }
      }
    } else {
      final g = _groups.firstWhere(
        (e) => e.lineNumber == _selected,
        orElse: () => visible.isNotEmpty
            ? visible.first
            : _groups.first,
      );
      final col = _colorOf(g.lineNumber);
      final aller = _ptsOf(g.aller);
      final retour = _ptsOf(g.retour);
      if (aller.length >= 2) {
        polylines.add(Polyline(points: aller, color: col, strokeWidth: 5));
        fitPoints.addAll(aller);
      }
      if (retour.length >= 2) {
        polylines.add(Polyline(
          points: retour,
          color: col.withOpacity(0.9),
          strokeWidth: 3.5,
          pattern: StrokePattern.dashed(segments: const [12, 10]),
        ));
        fitPoints.addAll(retour);
      }
    }

    final fit = fitPoints.isNotEmpty
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(fitPoints),
            padding: const EdgeInsets.all(48),
          )
        : null;

    return FlutterMap(
      key: ValueKey('prod-lines-map-${_selected ?? "all"}'),
      options: MapOptions(
        initialCenter: const LatLng(-18.8792, 47.5079),
        initialZoom: 12,
        initialCameraFit: fit,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'app.misy.book',
        ),
        PolylineLayer(polylines: polylines),
      ],
    );
  }
}
