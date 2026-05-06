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
  final TextEditingController priceCtrl = TextEditingController();
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
    priceCtrl.dispose();
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
    priceCtrl.text = m.priceAriary?.toString() ?? '';
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

  /// Lit le prix saisi en Ariary, ou null si vide / non parsable.
  int? get priceAriary {
    final s = priceCtrl.text.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
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

  /// Codes déjà utilisés (manifest + Firestore). Quand fourni en mode
  /// création (`!numberLocked`), un widget en dessous du champ filtre les
  /// codes existants qui matchent la saisie pour éviter les collisions.
  /// Null → pas de suggestion (mode édition ou liste pas chargée).
  final Set<String>? existingCodes;

  /// Appelé à chaque changement utile pour que le parent rebuild la barre
  /// d'actions / l'état de validation.
  final VoidCallback? onChanged;

  const LineMetadataForm({
    super.key,
    required this.controller,
    this.numberLocked = false,
    this.existingCodes,
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
            hintText: 'ex: 201, 201bis, 201-Anosibe, TCE2…',
            border: const OutlineInputBorder(),
            helperText: widget.numberLocked
                ? 'Le numéro est la clé de la ligne, non modifiable ici.'
                : 'Le code doit être unique. Si plusieurs lignes ont le même '
                    'numéro public, ajoute un suffixe (bis, A, B, nom de '
                    'quartier…).',
            helperMaxLines: 3,
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => _bumped(),
        ),
        if (!widget.numberLocked && widget.existingCodes != null)
          _ExistingCodesSuggestion(
            query: c.numberCtrl.text,
            existingCodes: widget.existingCodes!,
          ),
        const SizedBox(height: 12),
        TextField(
          controller: c.nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom affiché',
            hintText: 'ex: Ligne 201 — Anosibe → Ambohibao',
            border: OutlineInputBorder(),
            helperText:
                'Doit être unique. Si tu vois un doublon avec une ligne '
                'existante, précise (couleur, quartier, opérateur…).',
            helperMaxLines: 3,
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
        TextField(
          controller: c.priceCtrl,
          decoration: const InputDecoration(
            labelText: 'Prix du trajet (Ar)',
            hintText: 'ex: 600',
            border: OutlineInputBorder(),
            suffixText: 'Ar',
            helperText: 'Tarif unique en Ariary. Laisse vide si inconnu.',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

/// Affiche sous le champ "Numéro / code" une liste filtrée de codes déjà
/// utilisés qui matchent la saisie courante (substring, case-insensitive).
/// Aide le consultant à choisir un code disponible sans tâtonner.
///
/// Affiche au maximum 8 codes pour rester compact. Vide quand le champ est
/// vide ou qu'aucun code ne match.
class _ExistingCodesSuggestion extends StatelessWidget {
  final String query;
  final Set<String> existingCodes;

  const _ExistingCodesSuggestion({
    required this.query,
    required this.existingCodes,
  });

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const SizedBox.shrink();
    final matches = existingCodes
        .where((c) => c.toLowerCase().contains(q))
        .toList()
      ..sort();
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF66BB6A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Code disponible.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final exact = matches.any((c) => c.toLowerCase() == q);
    final shown = matches.take(8).toList();
    final remaining = matches.length - shown.length;
    final color = exact ? const Color(0xFFE53935) : const Color(0xFFFB8C00);
    final bg = exact ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    exact ? Icons.error_outline : Icons.warning_amber_outlined,
                    size: 14,
                    color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exact
                        ? '⚠ Le code « $query » est DÉJÀ utilisé. Ajoute un suffixe.'
                        : 'Codes déjà utilisés contenant « $query » :',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final c in shown)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Text(c,
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w500)),
                  ),
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('+$remaining autres',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ],
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
