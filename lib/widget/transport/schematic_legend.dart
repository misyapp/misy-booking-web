import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/models/schematic_plan.dart';

/// Légende générée du plan schématique CTS : alphabet des symboles + liste
/// des lignes avec leurs pastilles. Chrome en charte Misy (coral/navy/gold,
/// jamais appliquée aux tracés). Repliable — démarre repliée en pilule.
/// Affichée uniquement quand le plan porte `legendLines` (mode CTS).
class SchematicLegend extends StatefulWidget {
  final List<SchLegendLine> lines;

  const SchematicLegend({super.key, required this.lines});

  @override
  State<SchematicLegend> createState() => _SchematicLegendState();
}

class _SchematicLegendState extends State<SchematicLegend> {
  static const Color _coral = Color(0xFFFF5753);
  static const Color _navy = Color(0xFF1D3557);
  static const Color _gold = Color(0xFFFFD166);

  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => setState(() => _open = true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.menu_book_rounded, size: 16, color: _navy),
              SizedBox(width: 6),
              Text('Légende',
                  style: TextStyle(
                      color: _navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 250, maxHeight: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // header charte Misy
          Container(
            color: _navy,
            padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
            child: Row(children: [
              Container(width: 4, height: 16, color: _coral),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Légende',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800)),
              ),
              InkWell(
                onTap: () => setState(() => _open = false),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child:
                      Icon(Icons.close_rounded, size: 17, color: Colors.white),
                ),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _symbolRow(_GlyphKind.stop, 'Arrêt'),
                _symbolRow(_GlyphKind.interchange, 'Correspondance'),
                _symbolRow(_GlyphKind.terminus, 'Terminus'),
                _symbolRow(_GlyphKind.pole, "Pôle d'échange"),
                _symbolRow(_GlyphKind.rail, 'Train / téléphérique'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFE8E3D8)),
                ),
                const Text('LIGNES',
                    style: TextStyle(
                        color: _navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final l in widget.lines) _lineChip(l),
                  ],
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _symbolRow(_GlyphKind kind, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 26,
              height: 16,
              child: CustomPaint(painter: _GlyphPainter(kind))),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF12263A),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _lineChip(SchLegendLine l) {
    final text = l.label.startsWith('TELEPHERIQUE')
        ? 'TPH'
        : (l.label.startsWith('TRAIN') ? 'TCE' : l.label);
    return Tooltip(
      message: l.name ?? l.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: l.color,
          borderRadius: BorderRadius.circular(7),
          border: l.tier == 1 ? Border.all(color: _gold, width: 1.5) : null,
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

enum _GlyphKind { stop, interchange, terminus, pole, rail }

/// Mini-symboles de l'alphabet (mêmes formes que SchematicPainterCts).
class _GlyphPainter extends CustomPainter {
  final _GlyphKind kind;
  const _GlyphPainter(this.kind);

  static const Color _navy = Color(0xFF1D3557);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final line = Paint()
      ..color = const Color(0xFF7B8FA5)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final white = Paint()..color = Colors.white;
    final navyStroke = Paint()
      ..color = _navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(1, c.dy), Offset(size.width - 1, c.dy), line);
    switch (kind) {
      case _GlyphKind.stop:
        canvas.drawRect(
            Rect.fromCenter(center: c, width: 2.2, height: 9), white);
        break;
      case _GlyphKind.interchange:
        canvas.drawCircle(c, 4.4, white);
        canvas.drawCircle(c, 4.4, navyStroke);
        break;
      case _GlyphKind.terminus:
        final rr = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 11, height: 7),
            const Radius.circular(3.5));
        canvas.drawRRect(rr, white);
        canvas.drawRRect(rr, navyStroke);
        break;
      case _GlyphKind.pole:
        canvas.drawCircle(c, 6.4, white);
        canvas.drawCircle(c, 6.4, navyStroke);
        canvas.drawCircle(
            c,
            3.4,
            Paint()
              ..color = _navy
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2);
        break;
      case _GlyphKind.rail:
        final tie = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.4;
        for (final dx in [-6.0, 0.0, 6.0]) {
          canvas.drawLine(Offset(c.dx + dx, c.dy - 2.4),
              Offset(c.dx + dx, c.dy + 2.4), tie);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.kind != kind;
}
