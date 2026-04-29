import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/services/network_diagram_layout.dart';

/// Peintre du diagramme réseau type plan tramway. Dessine :
/// 1. Les lignes octilinéaires (paths construites par
///    [NetworkDiagramLayout]).
/// 2. Les pastilles d'arrêts ordinaires (cercle blanc + bordure couleur ligne).
/// 3. Les pastilles de correspondance (cercle blanc plus large + bordure
///    noire) pour les nœuds desservis par 2+ lignes.
/// 4. Les labels des terminus (1er et dernier arrêt de chaque ligne) avec
///    le numéro de ligne dans une pastille colorée + nom de l'arrêt à côté.
class NetworkDiagramPainter extends CustomPainter {
  final NetworkDiagramLayout layout;

  NetworkDiagramPainter({required this.layout});

  // Dimensions visuelles (pixels logiques sur le canvas — ne dépendent pas
  // du zoom de l'InteractiveViewer puisque la transformation est appliquée
  // par-dessus). Si le diagramme paraît trop épais à fort zoom, ajuster ici.
  static const double _lineWidth = 5.0;
  static const double _stopRadius = 5.0;
  static const double _interchangeRadius = 9.0;
  static const double _stopBorderWidth = 2.0;
  static const double _interchangeBorderWidth = 2.5;
  static const double _terminusBadgeWidth = 32;
  static const double _terminusBadgeHeight = 16;
  static const Color _interchangeBorder = Color(0xFF1D3557);
  static const Color _terminusTextColor = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Lignes (en dessous, pour que les bullets passent au-dessus).
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _lineWidth;

    for (final line in layout.lines) {
      if (line.points.length < 2) continue;
      final path = Path()..moveTo(line.points.first.dx, line.points.first.dy);
      for (var i = 1; i < line.points.length; i++) {
        path.lineTo(line.points[i].dx, line.points[i].dy);
      }
      linePaint.color = line.color.withOpacity(0.92);
      canvas.drawPath(path, linePaint);
    }

    // 2. Bullets standards + correspondances (au-dessus des lignes).
    for (final node in layout.nodes) {
      if (node.isInterchange) {
        // Pastille de correspondance : grand cercle blanc + bordure foncée.
        canvas.drawCircle(
          node.canvas,
          _interchangeRadius,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          node.canvas,
          _interchangeRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _interchangeBorderWidth
            ..color = _interchangeBorder,
        );
      } else {
        // Pastille standard : petit cercle blanc + bordure couleur ligne.
        canvas.drawCircle(
          node.canvas,
          _stopRadius,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          node.canvas,
          _stopRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stopBorderWidth
            ..color = node.primaryColor,
        );
      }
    }

    // 3. Labels des terminus : pastille avec numéro de ligne + nom de
    //    l'arrêt en gras à côté. Pour chaque ligne, marquer le 1er et le
    //    dernier nœud du path.
    for (final line in layout.lines) {
      if (line.stopIndices.isEmpty) continue;
      final firstStopPos = line.points[line.stopIndices.first];
      final lastStopPos = line.points[line.stopIndices.last];
      final firstNode = _nodeAt(firstStopPos);
      final lastNode = _nodeAt(lastStopPos);
      _drawTerminus(canvas, line, firstStopPos, firstNode);
      if (lastStopPos != firstStopPos) {
        _drawTerminus(canvas, line, lastStopPos, lastNode);
      }
    }

    // 4. Labels des correspondances (nom seul, pas de pastille de ligne).
    for (final node in layout.nodes) {
      if (!node.isInterchange) continue;
      _drawInterchangeLabel(canvas, node);
    }
  }

  DiagramNode? _nodeAt(Offset pos) {
    for (final node in layout.nodes) {
      if ((node.canvas - pos).distance < 0.5) return node;
    }
    return null;
  }

  void _drawTerminus(
    Canvas canvas,
    DiagramLinePath line,
    Offset position,
    DiagramNode? node,
  ) {
    // Pastille colorée avec numéro de ligne, posée à droite du bullet.
    final badgeOrigin = Offset(
      position.dx + _interchangeRadius + 4,
      position.dy - _terminusBadgeHeight / 2,
    );
    final badgeRect = Rect.fromLTWH(
      badgeOrigin.dx,
      badgeOrigin.dy,
      _terminusBadgeWidth,
      _terminusBadgeHeight,
    );
    final badgeRRect =
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(3));
    canvas.drawRRect(badgeRRect, Paint()..color = line.color);
    canvas.drawRRect(
      badgeRRect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 1.0,
    );

    final lineLabel = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )
      ..text = TextSpan(
        text: line.lineNumber,
        style: const TextStyle(
          color: _terminusTextColor,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: -0.2,
        ),
      )
      ..layout(maxWidth: _terminusBadgeWidth);
    lineLabel.paint(
      canvas,
      Offset(
        badgeOrigin.dx + (_terminusBadgeWidth - lineLabel.width) / 2,
        badgeOrigin.dy + (_terminusBadgeHeight - lineLabel.height) / 2,
      ),
    );

    // Nom de l'arrêt terminus à droite de la pastille (si dispo).
    if (node != null && node.name.trim().isNotEmpty) {
      final stopName = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )
        ..text = TextSpan(
          text: node.name,
          style: const TextStyle(
            color: _interchangeBorder,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        )
        ..layout(maxWidth: 180);
      stopName.paint(
        canvas,
        Offset(
          badgeOrigin.dx + _terminusBadgeWidth + 4,
          position.dy - stopName.height / 2,
        ),
      );
    }
  }

  void _drawInterchangeLabel(Canvas canvas, DiagramNode node) {
    if (node.name.trim().isEmpty) return;
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )
      ..text = TextSpan(
        text: node.name,
        style: const TextStyle(
          color: _interchangeBorder,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      )
      ..layout(maxWidth: 160);
    // Label sous la pastille.
    tp.paint(
      canvas,
      Offset(
        node.canvas.dx - tp.width / 2,
        node.canvas.dy + _interchangeRadius + 2,
      ),
    );
  }

  @override
  bool shouldRepaint(NetworkDiagramPainter oldDelegate) =>
      oldDelegate.layout != layout;
}

