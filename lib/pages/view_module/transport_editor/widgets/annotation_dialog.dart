import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/models/transport_line_validation.dart';

/// Résultat d'`AnnotationDialog.show()`. `null` = l'user a annulé.
/// Si l'user a cliqué "Effacer", retourne `AnnotationResult(note: null, flag: null)`.
class AnnotationResult {
  final String? note;
  final ConsultantFlag? flag;
  const AnnotationResult({this.note, this.flag});
}

/// Dialog réutilisable : note libre (200 chars) + drapeau couleur (5 options
/// + aucun). Utilisé depuis le dashboard et la sidebar du wizard pour annoter
/// une direction (aller/retour) d'une ligne.
class AnnotationDialog extends StatefulWidget {
  final String lineNumber;
  final String directionLabel; // "aller" / "retour"
  final String? initialNote;
  final ConsultantFlag? initialFlag;

  const AnnotationDialog({
    super.key,
    required this.lineNumber,
    required this.directionLabel,
    this.initialNote,
    this.initialFlag,
  });

  /// Helper. Retourne `null` si annulé, sinon `AnnotationResult` (note/flag
  /// peuvent être `null` chacun = effacé).
  static Future<AnnotationResult?> show({
    required BuildContext context,
    required String lineNumber,
    required String directionLabel,
    String? initialNote,
    ConsultantFlag? initialFlag,
  }) {
    return showDialog<AnnotationResult>(
      context: context,
      builder: (_) => AnnotationDialog(
        lineNumber: lineNumber,
        directionLabel: directionLabel,
        initialNote: initialNote,
        initialFlag: initialFlag,
      ),
    );
  }

  @override
  State<AnnotationDialog> createState() => _AnnotationDialogState();
}

class _AnnotationDialogState extends State<AnnotationDialog> {
  late final TextEditingController _ctrl;
  ConsultantFlag? _flag;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote ?? '');
    _flag = widget.initialFlag;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasInitial =
        widget.initialNote != null || widget.initialFlag != null;
    return AlertDialog(
      title: Text(
        'Note · Ligne ${widget.lineNumber} (${widget.directionLabel})',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Drapeau couleur (visible dans la liste pour toi et pour l\'admin) :',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _flagChip(null, 'Aucun', Colors.grey.shade400),
                for (final f in ConsultantFlag.values)
                  _flagChip(f, f.label, f.color),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Note (optionnelle, max 200 caractères) :',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText:
                    'Ex: « Terminus changé en avril, à reconfirmer sur place »',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (hasInitial)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Effacer'),
            onPressed: () => Navigator.pop(
              context,
              const AnnotationResult(note: null, flag: null),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final note = _ctrl.text.trim();
            Navigator.pop(
              context,
              AnnotationResult(
                note: note.isEmpty ? null : note,
                flag: _flag,
              ),
            );
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _flagChip(ConsultantFlag? flag, String label, Color color) {
    final selected = _flag == flag;
    return InkWell(
      onTap: () => setState(() => _flag = flag),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
