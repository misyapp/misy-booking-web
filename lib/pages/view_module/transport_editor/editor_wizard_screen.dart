import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/models/transport_line_validation.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/editable_polyline_layer.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/editable_stops_layer.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/osm_base_map.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/tutorial_helpers.dart';
import 'package:rider_ride_hailing_app/provider/transport_editor_provider.dart';
import 'package:showcaseview/showcaseview.dart';

/// Wizard 4 étapes : tracé aller → tracé retour → arrêts aller → arrêts retour.
/// Chaque étape affiche la carte OSM + les éléments concernés, avec 3 actions :
/// Valider tel quel / Modifier / Recommencer.
class EditorWizardScreen extends StatelessWidget {
  final String lineNumber;
  final EditorStep initialStep;

  const EditorWizardScreen({
    super.key,
    required this.lineNumber,
    this.initialStep = EditorStep.allerRoute,
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
  final GlobalKey _validateKey = GlobalKey();
  final GlobalKey _modifyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    TutorialHelper.autoStartOnce(
      context: context,
      tourId: 'wizard_v1',
      keys: [_stepperKey, _mapKey, _validateKey, _modifyKey],
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
          body: Stack(
            children: [
              Positioned.fill(child: _buildMap(p)),
              if (!p.step.isRoute)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 210,
                  width: 260,
                  child: Material(
                    elevation: 4,
                    child: StopsListPanel(
                      stops: p.stops,
                      editable: p.isEditing,
                      onReorder: p.reorderStops,
                      onRename: p.renameStop,
                      onDelete: (i) async {
                        if (await _confirmDelete(context,
                            'Supprimer l\'arrêt ${p.stops[i].name} ?')) {
                          p.removeStop(i);
                        }
                      },
                      onFocus: (i) => _mapController.move(
                          p.stops[i].position, 17),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildStepper(p),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildToolbar(p),
              ),
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
              [_stepperKey, _mapKey, _validateKey, _modifyKey],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStepper(TransportEditorProvider p) {
    return TutoStep(
      stepKey: _stepperKey,
      title: 'Les 4 étapes',
      description:
          'Pour chaque ligne, tu valides dans l\'ordre : tracé aller, '
          'tracé retour, arrêts aller, arrêts retour. Tape un chiffre pour '
          'sauter à une étape.',
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              _stepChip(p, s),
              if (s != EditorStep.values.last)
                const Expanded(
                    child: Divider(thickness: 1.5, color: Colors.grey)),
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
      onTap: p.isEditing
          ? null
          : () {
              p.setStep(s);
              _recenterMap(p);
            },
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 2),
          Text(
            s.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
      description: p.step.isRoute
          ? 'Le tracé actuel est affiché. En mode Modifier, tire les points '
              'pour les déplacer. Les petits + au milieu permettent d\'ajouter '
              'un point. Appuie longtemps sur un point pour le supprimer.'
          : 'Les arrêts sont les pins rouges numérotés. En mode Modifier, tire '
              'les pins pour les déplacer, tape un pin pour le renommer, '
              'appuie longtemps pour le supprimer, tape sur la carte vide '
              'pour ajouter un arrêt.',
      child: OsmBaseMap(
        controller: _mapController,
        initialCenter: center,
        initialZoom: 14,
        onTap: (_, latlng) => _onMapTap(p, latlng),
        children: [
          EditablePolylineLayer(
            vertices: p.vertices,
            color: color,
            editable: p.isEditing && p.step.isRoute,
            onVertexMoved: p.moveVertex,
            onVertexRemoved: p.removeVertex,
            onVertexInserted: (idx, pos) => p.insertVertex(pos, afterIndex: idx),
          ),
          EditableStopsLayer(
            stops: p.stops,
            editable: p.isEditing && !p.step.isRoute,
            onStopMoved: p.moveStop,
            onStopTapped: (i) => _onStopTapped(p, i),
            onStopLongPressed: (i) async {
              if (await _confirmDelete(
                  context, 'Supprimer l\'arrêt ${p.stops[i].name} ?')) {
                p.removeStop(i);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(TransportEditorProvider p) {
    return TutoStep(
      stepKey: _toolbarKey,
      title: 'Barre d\'actions',
      description:
          'Tes 3 actions : Valider tel quel si l\'existant est correct, '
          'Modifier pour ajuster, Recommencer pour repartir de zéro.',
      child: Material(
        elevation: 8,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: p.isEditing ? _editingActions(p) : _viewActions(p),
        ),
      ),
    );
  }

  Widget _viewActions(TransportEditorProvider p) {
    final status = _statusForCurrentStep(p);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.isDone
                    ? 'Étape déjà ${status.label.toLowerCase()} — tu peux la '
                        'revalider ou passer à la suivante.'
                    : 'Comment l\'${p.step.isRoute ? "tracé" : "liste d\'arrêts"} '
                        'te paraît ?',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
            if (p.step.next != null)
              TextButton.icon(
                onPressed: () {
                  p.setStep(p.step.next!);
                  _recenterMap(p);
                },
                icon: const Icon(Icons.skip_next),
                label: const Text('Passer'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TutoStep(
                stepKey: _validateKey,
                title: 'Valider tel quel',
                description:
                    'Si le tracé / les arrêts sont corrects, valide et passe '
                    'à l\'étape suivante.',
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: p.isSaving ? null : () => _onValidateAsIs(p),
                  icon: const Icon(Icons.check),
                  label: const Text('Valider tel quel'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TutoStep(
                stepKey: _modifyKey,
                title: 'Modifier',
                description:
                    'Mode édition interactif pour corriger les erreurs sans '
                    'tout refaire.',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: p.isSaving
                      ? null
                      : () => p.setMode(EditorMode.modifying),
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.red,
                ),
                onPressed: p.isSaving
                    ? null
                    : () async {
                        if (await _confirmDelete(context,
                            'Effacer et repartir de zéro pour cette étape ?')) {
                          p.setMode(EditorMode.restarting);
                        }
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Recommencer'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _editingActions(TransportEditorProvider p) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Annuler la dernière action',
          onPressed: p.canUndo ? p.undo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Refaire',
          onPressed: p.canRedo ? p.redo : null,
          icon: const Icon(Icons.redo),
        ),
        if (p.step.isRoute)
          TextButton.icon(
            onPressed: () => _onAutoRoute(p),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Tracer auto A→B'),
          ),
        if (!p.step.isRoute)
          TextButton.icon(
            onPressed: () => _onAddStopDialog(p),
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Ajouter un arrêt'),
          ),
        const Spacer(),
        TextButton(
          onPressed: p.isSaving
              ? null
              : () {
                  p.setMode(EditorMode.view);
                  // Recharge depuis le doc pour annuler les modifs non-committées
                  p.setStep(p.step);
                },
          child: const Text('Annuler'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          onPressed: p.isSaving ? null : () => _onCommitEdit(p),
          icon: p.isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save),
          label: const Text('Valider cette étape'),
        ),
      ],
    );
  }

  // ─────────── Actions ───────────

  Future<void> _onValidateAsIs(TransportEditorProvider p) async {
    final ok = await p.validateAsIs();
    if (!mounted) return;
    if (!ok) {
      _snack(context, p.error ?? 'Validation impossible');
      return;
    }
    _snack(context, '${p.step.label} validé ✓');
    _goToNextStep(p);
  }

  Future<void> _onCommitEdit(TransportEditorProvider p) async {
    final ok = await p.commitEdit();
    if (!mounted) return;
    if (!ok) {
      _snack(context, p.error ?? 'Sauvegarde impossible');
      return;
    }
    _snack(context, '${p.step.label} enregistré ✓');
    _goToNextStep(p);
  }

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

  Future<void> _onAutoRoute(TransportEditorProvider p) async {
    if (p.vertices.length < 2) {
      _snack(context,
          'Pose d\'abord au moins 2 points pour définir A et B.');
      return;
    }
    _snack(context, 'Calcul du tracé routier via OSRM…');
    final ok = await p.autoRouteBetween(
        [p.vertices.first, p.vertices.last]);
    if (!mounted) return;
    _snack(context,
        ok ? 'Tracé auto appliqué' : 'OSRM indisponible, réessaie.');
  }

  void _onMapTap(TransportEditorProvider p, LatLng latlng) {
    if (!p.isEditing) return;
    if (p.step.isRoute) {
      // Ajoute un vertex à la fin
      p.insertVertex(latlng);
    } else {
      // Ajoute un arrêt
      _onAddStopFromTap(p, latlng);
    }
  }

  Future<void> _onAddStopFromTap(
      TransportEditorProvider p, LatLng pos) async {
    final name = await _promptStopName(context);
    if (name == null || name.isEmpty) return;
    p.addStop(pos, name);
  }

  Future<void> _onAddStopDialog(TransportEditorProvider p) async {
    _snack(context, 'Tape sur la carte pour poser un arrêt.');
  }

  Future<void> _onStopTapped(TransportEditorProvider p, int i) async {
    final current = p.stops[i].name;
    final name = await _promptStopName(context, initial: current);
    if (name == null || name.isEmpty) return;
    p.renameStop(i, name);
  }

  Future<String?> _promptStopName(BuildContext ctx, {String? initial}) {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(initial == null ? 'Nouvel arrêt' : 'Renommer'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom de l\'arrêt',
            hintText: 'ex: Analakely',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext ctx, String message) async {
    final res = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    return res == true;
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

  ValidationStatus _statusForCurrentStep(TransportEditorProvider p) {
    // On ne fetch pas en live dans le wizard (simplifié) : retourne pending
    return ValidationStatus.pending;
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
