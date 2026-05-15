import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';

/// Rangée de chips "tags" résumant les métadonnées d'une ligne :
/// couleur(s) + type + opérateur + prix + horaires. Partagée entre le
/// dashboard consultant et l'écran de review admin pour rester cohérent.
class LineTagChips extends StatelessWidget {
  final LineMetadata line;

  /// Si vide (aucun tag à afficher), affiche un message gris invitant à
  /// renseigner les métadonnées. Désactivable pour l'admin où le placeholder
  /// n'a pas de sens.
  final bool showEmptyHint;

  const LineTagChips({
    super.key,
    required this.line,
    this.showEmptyHint = true,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    // Swatch couleur(s) — toujours en premier pour repérage visuel rapide.
    chips.add(_ColorSwatchChip(
      colorValue: line.colorValue,
      colorValue2: line.colorValue2,
    ));

    chips.add(_textChip(
      icon: _iconForTransportType(line.transportType),
      label: _labelForTransportType(line.transportType),
      color: const Color(0xFF1565C0),
    ));

    final coop = line.cooperative?.trim();
    if (coop != null && coop.isNotEmpty) {
      chips.add(_textChip(
        icon: Icons.business,
        label: coop,
        color: const Color(0xFF6A1B9A),
      ));
    }

    if (line.priceAriary != null) {
      chips.add(_textChip(
        icon: Icons.payments_outlined,
        label: '${line.priceAriary} Ar',
        color: const Color(0xFF2E7D32),
      ));
    }

    final sched = line.schedule;
    if (sched != null && !sched.isEmpty) {
      final s = _formatScheduleSummary(sched);
      if (s.isNotEmpty) {
        chips.add(_textChip(
          icon: Icons.schedule,
          label: s,
          color: const Color(0xFF00838F),
        ));
      }
    }

    // chips contient au minimum le swatch + le type, donc jamais "vide" au sens
    // strict. Le placeholder s'affiche quand SEULS ces 2 chips structurels
    // existent et qu'on a demandé l'indicateur.
    final hasUserData = coop != null && coop.isNotEmpty ||
        line.priceAriary != null ||
        (sched != null && !sched.isEmpty);
    if (showEmptyHint && !hasUserData) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          Text(
            ' — métadonnées non renseignées',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _textChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForTransportType(String type) {
    switch (type) {
      case 'urbanTrain':
        return Icons.train;
      case 'telepherique':
        return Icons.airline_stops;
      case 'bus':
      default:
        return Icons.directions_bus;
    }
  }

  String _labelForTransportType(String type) {
    switch (type) {
      case 'urbanTrain':
        return 'Train urbain';
      case 'telepherique':
        return 'Téléphérique';
      case 'bus':
      default:
        return 'Bus / Taxi-be';
    }
  }

  String _formatScheduleSummary(LineSchedule s) {
    final parts = <String>[];
    if (s.firstDeparture != null && s.lastDeparture != null) {
      parts.add('${s.firstDeparture}–${s.lastDeparture}');
    } else if (s.firstDeparture != null) {
      parts.add('dès ${s.firstDeparture}');
    } else if (s.lastDeparture != null) {
      parts.add('jusqu\'à ${s.lastDeparture}');
    }
    if (s.frequencyMin != null) parts.add('toutes les ${s.frequencyMin} min');
    if (s.daysOfOperation.length < 7) {
      const labels = {
        'mon': 'Lun',
        'tue': 'Mar',
        'wed': 'Mer',
        'thu': 'Jeu',
        'fri': 'Ven',
        'sat': 'Sam',
        'sun': 'Dim',
      };
      parts.add(s.daysOfOperation.map((d) => labels[d] ?? d).join('/'));
    }
    return parts.join(' · ');
  }
}

/// Chip "couleur" — pastille mono ou bi-color (split diagonal). Sans texte,
/// uniquement le visuel. Permet de retrouver d'un coup d'œil la ligne sur
/// la carte.
class _ColorSwatchChip extends StatelessWidget {
  final int colorValue;
  final int? colorValue2;

  const _ColorSwatchChip({required this.colorValue, this.colorValue2});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: colorValue2 == null
                ? _solidDot(Color(colorValue))
                : CustomPaint(
                    painter: _DiagonalSplitPainter(
                      Color(colorValue),
                      Color(colorValue2!),
                    ),
                  ),
          ),
          if (colorValue2 != null) ...[
            const SizedBox(width: 4),
            Text(
              'bi-color',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _solidDot(Color c) {
    return Container(
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

class _DiagonalSplitPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  _DiagonalSplitPainter(this.color1, this.color2);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;
    final center = Offset(r, r);

    // Clip dans un cercle pour garder l'apparence "pastille".
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));

    // Triangle haut-gauche → color1
    final p1 = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p1, Paint()..color = color1);

    // Triangle bas-droit → color2
    final p2 = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p2, Paint()..color = color2);

    canvas.restore();

    // Contour léger
    canvas.drawCircle(
      center,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.grey.shade400,
    );
  }

  @override
  bool shouldRepaint(_DiagonalSplitPainter old) =>
      old.color1 != color1 || old.color2 != color2;
}
