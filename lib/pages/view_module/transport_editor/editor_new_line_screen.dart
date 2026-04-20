import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/build_line_flow_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/tutorial_helpers.dart';
import 'package:rider_ride_hailing_app/services/transport_editor_service.dart';
import 'package:showcaseview/showcaseview.dart';

/// Création d'une nouvelle ligne de bus de A à Z.
/// Flow : métadonnées → sub-flow aller → sub-flow retour → review/save.
class EditorNewLineScreen extends StatefulWidget {
  const EditorNewLineScreen({super.key});

  @override
  State<EditorNewLineScreen> createState() => _EditorNewLineScreenState();
}

class _EditorNewLineScreenState extends State<EditorNewLineScreen> {
  final _numberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _transportType = 'bus';
  int _colorValue = 0xFF1565C0;

  Map<String, dynamic>? _allerFC;
  int _allerStops = 0;
  Map<String, dynamic>? _retourFC;
  int _retourStops = 0;

  bool _submitting = false;

  final GlobalKey _tutoMetaKey = GlobalKey();

  static const List<int> _presetColors = [
    0xFFE53935,
    0xFF1565C0,
    0xFF43A047,
    0xFFFB8C00,
    0xFF6A1B9A,
    0xFF00838F,
    0xFFEF6C00,
    0xFFD81B60,
  ];

  @override
  void initState() {
    super.initState();
    TutorialHelper.autoStartOnce(
      context: context,
      tourId: 'new_line_v2',
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
          title: const Text('Nouvelle ligne'),
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetadataSection(),
              const SizedBox(height: 24),
              _buildDirectionSection(
                title: '1. Direction aller',
                fc: _allerFC,
                numStops: _allerStops,
                onBuild: () => _launchFlow('aller'),
              ),
              const SizedBox(height: 12),
              _buildDirectionSection(
                title: '2. Direction retour',
                fc: _retourFC,
                numStops: _retourStops,
                onBuild: () => _launchFlow('retour'),
                enabled: _allerFC != null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _canSubmit() && !_submitting ? _submit : null,
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
        ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    return TutoStep(
      stepKey: _tutoMetaKey,
      title: 'Métadonnées',
      description:
          'Numéro, nom et couleur — ces infos apparaissent partout dans l\'app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Métadonnées de la ligne',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _numberCtrl,
            decoration: const InputDecoration(
              labelText: 'Numéro / code',
              hintText: 'ex: 201, TCE2…',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom affiché',
              hintText: 'ex: Ligne 201',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
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
          const Text('Couleur',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presetColors.map(_colorSwatch).toList(),
          ),
        ],
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

  Widget _buildDirectionSection({
    required String title,
    required Map<String, dynamic>? fc,
    required int numStops,
    required VoidCallback onBuild,
    bool enabled = true,
  }) {
    final done = fc != null;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              done ? const Color(0xFF2E7D32) : Colors.grey.shade400,
          child: Icon(
            done ? Icons.check : Icons.route,
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(title),
        subtitle: Text(done
            ? '✓ $numStops arrêts, tracé calculé'
            : 'Pas encore construit'),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                done ? Colors.orange : const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          onPressed: enabled ? onBuild : null,
          child: Text(done ? 'Refaire' : 'Construire'),
        ),
      ),
    );
  }

  bool _canSubmit() {
    return _numberCtrl.text.trim().isNotEmpty &&
        _nameCtrl.text.trim().isNotEmpty &&
        _allerFC != null &&
        _retourFC != null;
  }

  Future<void> _launchFlow(String direction) async {
    final line = _numberCtrl.text.trim();
    if (line.isEmpty) {
      _snack('Renseigne le numéro de ligne d\'abord');
      return;
    }
    final result = await Navigator.of(context).push<BuildLineFlowResult>(
      MaterialPageRoute(
        builder: (_) => BuildLineFlowScreen(
          lineNumber: line,
          direction: direction,
          directionLabel: direction,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (direction == 'aller') {
        _allerFC = result.featureCollection;
        _allerStops = result.numStops;
      } else {
        _retourFC = result.featureCollection;
        _retourStops = result.numStops;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final lineNumber = _numberCtrl.text.trim();
      final displayName = _nameCtrl.text.trim();
      final colorHex =
          '0x${_colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}';

      await TransportEditorService.instance.createNewLine(
        lineNumber: lineNumber,
        displayName: displayName,
        transportType: _transportType,
        colorHex: colorHex,
        allerFeatureCollection: _allerFC!,
        retourFeatureCollection: _retourFC!,
      );
      if (!mounted) return;
      _snack('Ligne $lineNumber créée ✓');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
