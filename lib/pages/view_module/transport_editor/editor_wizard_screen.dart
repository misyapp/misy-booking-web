import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/models/transport_line_validation.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/build_line_flow_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/editable_polyline_layer.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/editable_stops_layer.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/osm_base_map.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/tutorial_helpers.dart';
import 'package:rider_ride_hailing_app/provider/transport_editor_provider.dart';
import 'package:showcaseview/showcaseview.dart';

/// Wizard 2 étapes : tracé aller → tracé retour.
/// Chaque étape couvre tracé + arrêts de la direction (gérés ensemble via
/// le sub-flow `BuildLineFlowScreen`). 2 actions : Valider tel quel /
/// Construire la ligne XXX.
class EditorWizardScreen extends StatelessWidget {
  final String lineNumber;
  final EditorStep initialStep;

  const EditorWizardScreen({
    super.key,
    required this.lineNumber,
    this.initialStep = EditorStep.aller,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TransportEditorProvider()..loadLine(lineNumber,
          initialStep: initialStep),
      child: ShowCaseWidget(
        builder: (ctx) => const _WizardBody(),
      ),
    );
  }
}

class _WizardBody extends StatefulWidget {
  const _WizardBody();

  @override
  State<_WizardBody> createState() => _WizardBodyState();
}

class _WizardBodyState extends State<_WizardBody> {
  final MapController _mapController = MapController();

  final GlobalKey _stepperKey = GlobalKey();
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _toolbarKey = GlobalKey();
  final GlobalKey _modifyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    TutorialHelper.autoStartOnce(
      context: context,
      tourId: 'wizard_v1',
      keys: [_stepperKey, _mapKey, _modifyKey],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransportEditorProvider>(
      builder: (ctx, p, _) {
        if (p.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (p.error != null) {
          return Scaffold(
            appBar: AppBar(title: Text('Ligne ${p.lineNumber}')),
            body: Center(child: Text(p.error!)),
          );
        }
        return Scaffold(
          appBar: _buildAppBar(p),
          body: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 340,
                      child: _buildSidePanel(p),
                    ),
                    Expanded(child: _buildMap(p)),
                  ],
                ),
              ),
              // Stepper en bas pour libérer le haut de la carte.
              _buildStepper(p),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(TransportEditorProvider p) {
    return AppBar(
      backgroundColor: const Color(0xFF1565C0),
      foregroundColor: Colors.white,
      title: Text(
        '${p.editedDoc?['display_name'] ?? 'Ligne ${p.lineNumber}'}'
        ' · ${p.step.label}',
      ),
      actions: [
        IconButton(
          tooltip: 'Revoir le tuto',
          icon: const Icon(Icons.school_outlined),
          onPressed: () async {
            await TutorialHelper.reset('wizard_v1');
            if (!mounted) return;
            ShowCaseWidget.of(context).startShowCase(
              [_stepperKey, _mapKey, _modifyKey],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStepper(TransportEditorProvider p) {
    return TutoStep(
      stepKey: _stepperKey,
      title: 'Les 2 étapes',
      description:
          'Pour chaque ligne : vérifie le tracé aller, puis le tracé retour. '
          'Chaque étape couvre à la fois le tracé et les arrêts. Tape un '
          'chiffre pour sauter à une étape.',
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            for (final s in EditorStep.values) ...[
              Expanded(child: _stepChip(p, s)),
              if (s != EditorStep.values.last)
                const SizedBox(
                  width: 60,
                  child: Divider(thickness: 1.5, color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepChip(TransportEditorProvider p, EditorStep s) {
    final isCurrent = p.step == s;
    final idx = s.index + 1;
    return InkWell(
      onTap: () {
        p.setStep(s);
        _recenterMap(p);
      },
      borderRadius: BorderRadius.circular(30),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF1565C0) : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$idx',
              style: TextStyle(
                color: isCurrent ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            s.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent ? const Color(0xFF1565C0) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(TransportEditorProvider p) {
    final color = _lineColor(p);
    final center = _computeCenter(p);
    return TutoStep(
      stepKey: _mapKey,
      title: 'Carte OSM',
      description:
          'Visualisation de la direction (tracé + arrêts). Pour modifier, '
          'utilise le bouton "Construire la ligne" qui ouvre le sub-flow '
          'guidé départ → arrivée → arrêts → affiner.',
      child: OsmBaseMap(
        controller: _mapController,
        initialCenter: center,
        initialZoom: 14,
        children: [
          EditablePolylineLayer(
            vertices: p.vertices,
            color: color,
            editable: false,
          ),
          EditableStopsLayer(
            stops: p.stops,
            editable: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(TransportEditorProvider p) {
    return TutoStep(
      stepKey: _toolbarKey,
      title: 'Barre d\'actions',
      description:
          'Reconstruis la direction via "Construire la ligne" (départ → '
          'arrivée → arrêts → affiner). Le tracé affiché n\'est qu\'un '
          'repère visuel, pas une validation possible.',
      child: Material(
        elevation: 4,
        color: const Color(0xFFFAFAFA),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: _buildSidebarHeader(p),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: _buildSidebarBody(p),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
              child: _viewActions(p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(TransportEditorProvider p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.route,
              size: 18,
              color: Color(0xFF1565C0),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p.step.label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Comment cette direction te paraît (tracé + arrêts) ?',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildSidebarBody(TransportEditorProvider p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tracé : ${p.vertices.length} point(s)',
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          'Arrêts : ${p.stops.length}',
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
        if (p.stops.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Liste des arrêts',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < p.stops.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.stops[i].name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _viewActions(TransportEditorProvider p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TutoStep(
          stepKey: _modifyKey,
          title: 'Construire la ligne ${p.lineNumber ?? ""}',
          description:
              'Le tracé affiché en fond n\'est qu\'un repère visuel. Tu dois '
              'tout reconstruire via le sub-flow guidé (départ → arrivée → '
              'arrêts → affiner). Pas de validation "tel quel".',
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: p.isSaving ? null : () => _launchBuildFlow(p),
            icon: const Icon(Icons.edit_road),
            label: Text('Construire la ligne ${p.lineNumber ?? ""}'),
          ),
        ),
        if (p.step.next != null) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () {
              p.setStep(p.step.next!);
              _recenterMap(p);
            },
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Passer à l\'étape suivante'),
          ),
        ],
      ],
    );
  }

  // ─────────── Actions ───────────

  /// Lance le sub-flow "Construire la ligne" pour la direction courante et
  /// persiste le résultat à la fin. Remplace l'ancien mode édition drag-drop.
  /// Passe la FC actuelle comme référence pour qu'elle apparaisse en
  /// arrière-fond semi-transparent dans le sub-flow (toggle-able).
  Future<void> _launchBuildFlow(TransportEditorProvider p) async {
    final line = p.lineNumber;
    if (line == null) return;
    final direction = p.step.isAller ? 'aller' : 'retour';
    final directionLabel = p.step.isAller ? 'aller' : 'retour';

    final dir = p.editedDoc?[direction] as Map<String, dynamic>?;
    final referenceFc = dir?['feature_collection'] as Map<String, dynamic>?;
    final colorHex = p.editedDoc?['color'] as String?;

    final result = await Navigator.of(context).push<BuildLineFlowResult>(
      MaterialPageRoute(
        builder: (_) => BuildLineFlowScreen(
          lineNumber: line,
          direction: direction,
          directionLabel: directionLabel,
          referenceFeatureCollection: referenceFc,
          referenceColorHex: colorHex,
        ),
      ),
    );
    if (!mounted || result == null) return;

    final ok = await p.commitReplaceDirection(
      direction: direction,
      featureCollection: result.featureCollection,
      numStops: result.numStops,
      numVertices: result.numVertices,
    );
    if (!mounted) return;
    if (!ok) {
      _snack(context, p.error ?? 'Sauvegarde impossible');
      return;
    }
    _snack(context, 'Direction $directionLabel mise à jour ✓');
    // Après une reconstruction complète, route + stops de la direction sont
    // tous deux modifiés → on saute à la prochaine étape pending de l'autre
    // direction (ou fin du wizard).
    _goToNextDirection(p);
  }

  /// Passe à la direction suivante, ou ferme le wizard si on a fini.
  void _goToNextDirection(TransportEditorProvider p) => _goToNextStep(p);

  void _goToNextStep(TransportEditorProvider p) {
    final next = p.step.next;
    if (next != null) {
      p.setStep(next);
      _recenterMap(p);
    } else {
      _snack(context, 'Ligne entièrement vérifiée 🎉');
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _recenterMap(TransportEditorProvider p) {
    final center = _computeCenter(p);
    if (center == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(center, 13);
      } catch (_) {}
    });
  }

  LatLng? _computeCenter(TransportEditorProvider p) {
    if (p.vertices.isNotEmpty) {
      double sumLat = 0, sumLng = 0;
      for (final v in p.vertices) {
        sumLat += v.latitude;
        sumLng += v.longitude;
      }
      return LatLng(sumLat / p.vertices.length, sumLng / p.vertices.length);
    }
    if (p.stops.isNotEmpty) {
      double sumLat = 0, sumLng = 0;
      for (final s in p.stops) {
        sumLat += s.position.latitude;
        sumLng += s.position.longitude;
      }
      return LatLng(sumLat / p.stops.length, sumLng / p.stops.length);
    }
    return null;
  }

  Color _lineColor(TransportEditorProvider p) {
    final hex = p.editedDoc?['color']?.toString();
    if (hex == null) return const Color(0xFF1565C0);
    try {
      return Color(int.parse(hex.replaceFirst('0x', ''), radix: 16));
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}
