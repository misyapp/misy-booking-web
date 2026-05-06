import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/build_line_flow_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/line_metadata_form.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/tutorial_helpers.dart';
import 'package:rider_ride_hailing_app/services/transport_editor_service.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';
import 'package:showcaseview/showcaseview.dart';

/// Création d'une nouvelle ligne de bus de A à Z.
///
/// Flow imposé : 1. infos → 2. tracé aller → 3. tracé retour → 4. créer.
/// Le bandeau "Étapes" en haut affiche dynamiquement quelle étape bloque
/// la suivante — important parce que les retours consultant ont signalé
/// qu'il n'était pas évident de comprendre pourquoi "Créer la ligne"
/// restait grisé.
class EditorNewLineScreen extends StatefulWidget {
  const EditorNewLineScreen({super.key});

  @override
  State<EditorNewLineScreen> createState() => _EditorNewLineScreenState();
}

class _EditorNewLineScreenState extends State<EditorNewLineScreen> {
  final LineMetadataFormController _form = LineMetadataFormController();

  Map<String, dynamic>? _allerFC;
  int _allerStops = 0;
  Map<String, dynamic>? _retourFC;
  int _retourStops = 0;

  bool _submitting = false;

  /// Snapshot des codes/noms déjà utilisés (manifest + Firestore). Chargé
  /// une fois au mount pour alimenter la suggestion live sous le champ
  /// numéro et les pré-checks d'unicité.
  Set<String> _existingCodes = {};
  Map<String, String> _existingNamesByCode = {};

  final GlobalKey _tutoMetaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadExistingCodes();
    TutorialHelper.autoStartOnce(
      context: context,
      tourId: 'new_line_v3_steps',
      keys: [_tutoMetaKey],
    );
  }

  Future<void> _loadExistingCodes() async {
    try {
      final snap = await TransportLinesService.instance
          .getExistingCodesAndDisplayNames();
      if (!mounted) return;
      setState(() {
        _existingCodes = snap.codes;
        _existingNamesByCode = snap.namesByCode;
      });
    } catch (_) {
      // Tant pis : on perd juste la suggestion live, le check serveur
      // (createNewLine) reste autoritatif.
    }
  }

  @override
  void dispose() {
    _form.disposeAll();
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
              _buildStepBanner(),
              const SizedBox(height: 16),
              _buildMetadataSection(),
              const SizedBox(height: 24),
              _buildDirectionSection(
                title: '2. Tracé aller',
                fc: _allerFC,
                numStops: _allerStops,
                onBuild: () => _launchFlow('aller'),
                disabledHint: !_hasMinimalMetadata()
                    ? 'Renseigne d\'abord le numéro et le nom de la ligne'
                    : null,
              ),
              const SizedBox(height: 12),
              _buildDirectionSection(
                title: '3. Tracé retour',
                fc: _retourFC,
                numStops: _retourStops,
                onBuild: () => _launchFlow('retour'),
                disabledHint: _allerFC == null
                    ? 'Construis d\'abord le tracé aller'
                    : null,
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  /* ───────────────── Banner ───────────────── */

  Widget _buildStepBanner() {
    final steps = [
      _BannerStep('Infos', _hasMinimalMetadata()),
      _BannerStep('Aller', _allerFC != null),
      _BannerStep('Retour', _retourFC != null),
      _BannerStep('Créer', false),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Étapes pour créer une ligne',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                _stepDot(i + 1, steps[i].label, steps[i].done),
                if (i < steps.length - 1)
                  Container(
                    width: 18,
                    height: 1.5,
                    color: Colors.grey.shade400,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _nextActionHint(),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int idx, String label, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: done ? const Color(0xFF2E7D32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done ? const Color(0xFF2E7D32) : Colors.grey.shade400,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done)
            const Icon(Icons.check, size: 14, color: Colors.white)
          else
            Text('$idx',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: done ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _nextActionHint() {
    if (!_hasMinimalMetadata()) {
      return '➜ Commence par remplir le numéro et le nom de la ligne ci-dessous.';
    }
    if (_allerFC == null) return '➜ Construis le tracé aller.';
    if (_retourFC == null) return '➜ Construis le tracé retour.';
    return '✓ Tout est prêt — clique sur "Créer la ligne" en bas.';
  }

  /* ───────────────── Form ───────────────── */

  Widget _buildMetadataSection() {
    return TutoStep(
      stepKey: _tutoMetaKey,
      title: 'Identité + horaires',
      description:
          'Renseigne ici le numéro, le nom, le type, la coopérative, la '
          'couleur, le prix et les horaires. Tous les champs autres que '
          'numéro / nom sont optionnels — tu pourras revenir les compléter '
          'plus tard.',
      child: LineMetadataForm(
        controller: _form,
        existingCodes: _existingCodes,
        onChanged: () => setState(() {}),
      ),
    );
  }

  /* ───────────────── Tracés ───────────────── */

  Widget _buildDirectionSection({
    required String title,
    required Map<String, dynamic>? fc,
    required int numStops,
    required VoidCallback onBuild,
    String? disabledHint,
  }) {
    final done = fc != null;
    final hint = disabledHint;
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
        subtitle: Text(
          done
              ? '✓ $numStops arrêts, tracé calculé'
              : (hint ?? 'Pas encore construit'),
          style: TextStyle(
            color: hint != null ? const Color(0xFFE65100) : null,
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                done ? Colors.orange : const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          // Au lieu de griser le bouton, on garde le clic actif et on pousse
          // un snack explicatif — moins frustrant que "rien ne se passe".
          onPressed: hint != null ? () => _snack(hint) : onBuild,
          child: Text(done ? 'Refaire' : 'Construire'),
        ),
      ),
    );
  }

  /* ───────────────── Submit ───────────────── */

  Widget _buildSubmitButton() {
    final canSubmit = _canSubmit();
    String? blocker;
    if (!canSubmit) {
      if (!_hasMinimalMetadata()) {
        blocker = 'Numéro et nom à compléter';
      } else if (_allerFC == null) {
        blocker = 'Tracé aller manquant';
      } else if (_retourFC == null) {
        blocker = 'Tracé retour manquant';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: canSubmit && !_submitting
                ? _submit
                : (blocker != null ? () => _snack(blocker!) : null),
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
        if (blocker != null) ...[
          const SizedBox(height: 6),
          Text(
            'Bloquant : $blocker',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFFE65100), height: 1.3),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  bool _hasMinimalMetadata() =>
      _form.numberCtrl.text.trim().isNotEmpty &&
      _form.nameCtrl.text.trim().isNotEmpty;

  bool _canSubmit() =>
      _hasMinimalMetadata() && _allerFC != null && _retourFC != null;

  Future<void> _launchFlow(String direction) async {
    final line = _form.numberCtrl.text.trim();
    if (line.isEmpty) {
      _snack('Renseigne le numéro de ligne d\'abord');
      return;
    }
    final referenceFc =
        (direction == 'retour' && _allerFC != null) ? _allerFC : null;

    final result = await Navigator.of(context).push<BuildLineFlowResult>(
      MaterialPageRoute(
        builder: (_) => BuildLineFlowScreen(
          lineNumber: line,
          direction: direction,
          directionLabel: direction,
          referenceFeatureCollection: referenceFc,
          referenceColorHex: _form.colorHex,
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
    final code = _form.numberCtrl.text.trim();
    final name = _form.nameCtrl.text.trim();

    // Pré-check côté UI pour fail-fast avant le round-trip Firestore. Le
    // serveur (createNewLine) re-vérifie de toute façon avec autorité.
    if (_existingCodes.contains(code)) {
      _showCodeCollisionDialog(code);
      return;
    }
    final norm = TransportEditorService.normalizeName(name);
    final owner = _existingNamesByCode[norm];
    if (owner != null) {
      _showNameCollisionDialog(name, owner);
      return;
    }

    setState(() => _submitting = true);
    try {
      await TransportEditorService.instance.createNewLine(
        lineNumber: code,
        displayName: name,
        transportType: _form.transportType,
        colorHex: _form.colorHex,
        cooperative: _form.coopCtrl.text,
        schedule: _form.buildScheduleJson(),
        priceAriary: _form.priceAriary,
        allerFeatureCollection: _allerFC!,
        retourFeatureCollection: _retourFC!,
      );
      if (!mounted) return;
      _snack('Ligne $code créée ✓');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop();
      });
    } on LineCodeExistsException {
      if (!mounted) return;
      _showCodeCollisionDialog(code);
    } on LineDisplayNameExistsException catch (e) {
      if (!mounted) return;
      _showNameCollisionDialog(name, e.conflictingCode);
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showCodeCollisionDialog(String code) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.error_outline, color: Color(0xFFE53935)),
          SizedBox(width: 8),
          Text('Code déjà utilisé'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Le code « $code » existe déjà.',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            const Text('Ajoute un suffixe pour distinguer cette nouvelle ligne :',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final suffix in const [
                  'bis',
                  'A',
                  'B',
                  'Rouge',
                  'Bleu',
                  '-Anosibe'
                ])
                  ActionChip(
                    label: Text('$code$suffix',
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      _form.numberCtrl.text = '$code$suffix';
                      _form.numberCtrl.selection = TextSelection.collapsed(
                          offset: '$code$suffix'.length);
                      Navigator.of(ctx).pop();
                      setState(() {});
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNameCollisionDialog(
      String name, String conflictingCode) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.error_outline, color: Color(0xFFE53935)),
          SizedBox(width: 8),
          Text('Nom déjà utilisé'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le nom « $name » est déjà utilisé par la ligne '
              '$conflictingCode.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              'Si c\'est la même ligne : annule cette création et édite '
              'l\'existante depuis le dashboard.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sinon, précise le nom (ex : ajoute la couleur, le quartier, '
              'l\'opérateur).',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK, je modifie'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _BannerStep {
  final String label;
  final bool done;
  const _BannerStep(this.label, this.done);
}
