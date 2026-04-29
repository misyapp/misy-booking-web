import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';

/// État interne d'un formulaire métadonnées (création ou édition d'une ligne).
/// Le parent peut récupérer les valeurs via [LineMetadataFormController].
class LineMetadataFormController {
  // Champs édités. Le parent y accède pour lire / valider.
  final TextEditingController numberCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController coopCtrl = TextEditingController();
  final TextEditingController firstCtrl = TextEditingController();
  final TextEditingController lastCtrl = TextEditingController();
  final TextEditingController frequencyCtrl = TextEditingController();
  final TextEditingController scheduleNotesCtrl = TextEditingController();

  String transportType = 'bus';
  int colorValue = 0xFF1565C0;
  Set<String> daysOfOperation = {
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun'
  };

  void disposeAll() {
    numberCtrl.dispose();
    nameCtrl.dispose();
    coopCtrl.dispose();
    firstCtrl.dispose();
    lastCtrl.dispose();
    frequencyCtrl.dispose();
    scheduleNotesCtrl.dispose();
  }

  /// Préremplit depuis une `LineMetadata` (mode édition d'une ligne existante).
  void hydrateFrom(LineMetadata m) {
    numberCtrl.text = m.lineNumber;
    nameCtrl.text = m.displayName;
    coopCtrl.text = m.cooperative ?? '';
    transportType = m.transportType;
    colorValue = m.colorValue;
    final s = m.schedule;
    if (s != null) {
      firstCtrl.text = s.firstDeparture ?? '';
      lastCtrl.text = s.lastDeparture ?? '';
      frequencyCtrl.text = s.frequencyMin?.toString() ?? '';
      scheduleNotesCtrl.text = s.notes ?? '';
      daysOfOperation = s.daysOfOperation.toSet();
    }
  }

  String get colorHex =>
      '0x${colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// Construit l'objet `schedule` à persister, ou `null` si tous les champs
  /// sont vides (pour effacement côté Firestore).
  Map<String, dynamic>? buildScheduleJson() {
    final first = firstCtrl.text.trim();
    final last = lastCtrl.text.trim();
    final freq = int.tryParse(frequencyCtrl.text.trim());
    final notes = scheduleNotesCtrl.text.trim();
    final empty = first.isEmpty &&
        last.isEmpty &&
        freq == null &&
        notes.isEmpty;
    if (empty) return null;
    return {
      if (first.isNotEmpty) 'first_departure': first,
      if (last.isNotEmpty) 'last_departure': last,
      if (freq != null) 'frequency_min': freq,
      'days_of_operation': daysOfOperation.toList()..sort(_dayOrder),
      if (notes.isNotEmpty) 'notes': notes,
    };
  }

  static int _dayOrder(String a, String b) {
    const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return order.indexOf(a).compareTo(order.indexOf(b));
  }
}

/// Formulaire commun à `EditorNewLineScreen` et au dialog "Modifier les infos"
/// du wizard. Affiche : numéro, nom, type, coopérative, couleur, horaires
/// (premier/dernier départ, fréquence, jours, notes).
class LineMetadataForm extends StatefulWidget {
  final LineMetadataFormController controller;

  /// True : la ligne existe déjà → numéro non éditable (clé Firestore).
  final bool numberLocked;

  /// Appelé à chaque changement utile pour que le parent rebuild la barre
  /// d'actions / l'état de validation.
  final VoidCallback? onChanged;

  const LineMetadataForm({
    super.key,
    required this.controller,
    this.numberLocked = false,
    this.onChanged,
  });

  @override
  State<LineMetadataForm> createState() => _LineMetadataFormState();
}

class _LineMetadataFormState extends State<LineMetadataForm> {
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

  static const List<({String code, String label})> _days = [
    (code: 'mon', label: 'Lun'),
    (code: 'tue', label: 'Mar'),
    (code: 'wed', label: 'Mer'),
    (code: 'thu', label: 'Jeu'),
    (code: 'fri', label: 'Ven'),
    (code: 'sat', label: 'Sam'),
    (code: 'sun', label: 'Dim'),
  ];

  void _bumped() {
    widget.onChanged?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Identité de la ligne',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: c.numberCtrl,
          enabled: !widget.numberLocked,
          decoration: InputDecoration(
            labelText: 'Numéro / code',
            hintText: 'ex: 201, TCE2…',
            border: const OutlineInputBorder(),
            helperText: widget.numberLocked
                ? 'Le numéro est la clé de la ligne, non modifiable.'
                : null,
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => _bumped(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: c.nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom affiché',
            hintText: 'ex: Ligne 201 — Anosibe → Ambohibao',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _bumped(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: c.coopCtrl,
          decoration: const InputDecoration(
            labelText: 'Coopérative / opérateur',
            hintText: 'ex: Kofifa, Cotrabe…',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _bumped(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: c.transportType,
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
          onChanged: (v) {
            c.transportType = v ?? 'bus';
            _bumped();
          },
        ),
        const SizedBox(height: 16),
        const Text('Couleur', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _presetColors.map(_colorSwatch).toList(),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 16),
        const Text('Horaires (optionnel)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Renseigne ce que tu connais. Tout est facultatif — tu peux y revenir plus tard.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: c.firstCtrl,
                decoration: const InputDecoration(
                  labelText: 'Premier départ',
                  hintText: '05:30',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [_HhmmFormatter()],
                onChanged: (_) => _bumped(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: c.lastCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dernier départ',
                  hintText: '19:00',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [_HhmmFormatter()],
                onChanged: (_) => _bumped(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: c.frequencyCtrl,
          decoration: const InputDecoration(
            labelText: 'Fréquence (minutes)',
            hintText: 'ex: 10',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _bumped(),
        ),
        const SizedBox(height: 12),
        const Text('Jours d\'exploitation',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _days.map((d) {
            final selected = c.daysOfOperation.contains(d.code);
            return FilterChip(
              label: Text(d.label),
              selected: selected,
              onSelected: (v) {
                if (v) {
                  c.daysOfOperation.add(d.code);
                } else {
                  c.daysOfOperation.remove(d.code);
                }
                _bumped();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: c.scheduleNotesCtrl,
          decoration: const InputDecoration(
            labelText: 'Notes horaires (libre)',
            hintText: 'ex: pas de service les jours fériés',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (_) => _bumped(),
        ),
      ],
    );
  }

  Widget _colorSwatch(int c) {
    final selected = widget.controller.colorValue == c;
    return InkWell(
      onTap: () {
        widget.controller.colorValue = c;
        _bumped();
      },
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
}

/// Force le format HH:mm pendant la frappe (insère ":" après 2 chiffres).
class _HhmmFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var t = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.length > 4) t = t.substring(0, 4);
    String formatted;
    if (t.length <= 2) {
      formatted = t;
    } else {
      formatted = '${t.substring(0, 2)}:${t.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
