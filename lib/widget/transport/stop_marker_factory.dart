import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Style de rendu d'un marker d'arrêt, choisi en fonction du zoom courant.
///
/// - [dot] : point blanc avec anneau couleur de la ligne, pas de numéro.
///   Affiché à zoom intermédiaire (~13-14.5).
/// - [label] : petit carré arrondi avec numéro. Zoom moyen (~14.5-15.5).
/// - [bigLabel] : version intermédiaire agrandie. Zoom proche (>= 15.5).
/// - [largeLabel] : version maximale, pour le stop sélectionné ou survolé.
enum StopMarkerStyle { dot, label, bigLabel, largeLabel }

/// Génère des [BitmapDescriptor] pour les arrêts du réseau de bus.
///
/// Cache par `(label, color, scale, style)` pour ne payer le coût de
/// rastérisation qu'une seule fois par variante.
class StopMarkerFactory {
  StopMarkerFactory._();

  static final Map<String, BitmapDescriptor> _cache = {};

  // Tailles logiques (× devicePixelRatio en sortie). Calibrées pour rester
  // lisibles sans saturer la carte type IDF Mobilités. Volontairement
  // petites pour que les markers ne masquent pas le trait de la ligne.
  static const double _dotSize = 9; // diamètre extérieur (anneau)
  static const double _labelWidth = 17;
  static const double _labelHeight = 13;
  static const double _bigLabelWidth = 24;
  static const double _bigLabelHeight = 17;
  static const double _largeWidth = 32;
  static const double _largeHeight = 22;

  static Future<BitmapDescriptor> create({
    required String label,
    required Color color,
    required double devicePixelRatio,
    StopMarkerStyle style = StopMarkerStyle.label,
  }) async {
    final key =
        '${label}_${color.value.toRadixString(16)}_${devicePixelRatio.toStringAsFixed(1)}_${style.name}';
    final cached = _cache[key];
    if (cached != null) return cached;

    if (style == StopMarkerStyle.dot) {
      final descriptor = await _renderDot(color, devicePixelRatio);
      _cache[key] = descriptor;
      return descriptor;
    }

    // Dimensions par tier (label / bigLabel / largeLabel).
    final double baseW;
    final double baseH;
    final double baseRadius;
    final double baseBorder;
    final double baseFont;
    switch (style) {
      case StopMarkerStyle.label:
        baseW = _labelWidth;
        baseH = _labelHeight;
        baseRadius = 3.0;
        baseBorder = 1.1;
        baseFont = 7.5;
        break;
      case StopMarkerStyle.bigLabel:
        baseW = _bigLabelWidth;
        baseH = _bigLabelHeight;
        baseRadius = 4.0;
        baseBorder = 1.4;
        baseFont = 9.5;
        break;
      case StopMarkerStyle.largeLabel:
        baseW = _largeWidth;
        baseH = _largeHeight;
        baseRadius = 5.0;
        baseBorder = 1.8;
        baseFont = 12.0;
        break;
      case StopMarkerStyle.dot:
        // Déjà géré au-dessus.
        baseW = _labelWidth;
        baseH = _labelHeight;
        baseRadius = 3.0;
        baseBorder = 1.1;
        baseFont = 7.5;
        break;
    }
    final w = baseW * devicePixelRatio;
    final h = baseH * devicePixelRatio;
    final radius = baseRadius * devicePixelRatio;
    final borderWidth = baseBorder * devicePixelRatio;
    final fontSize = baseFont * devicePixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Pas de drop shadow : un shadow décalé vers le bas (même léger)
    // décentre visuellement le marker par rapport à son centre géométrique
    // (utilisé comme ancre par Google Maps), donc le numéro se retrouve
    // visuellement à côté du trait de la ligne au lieu d'être pile dessus.
    // Fond couleur de la ligne.
    final fillRect = Rect.fromLTWH(0, 0, w, h);
    final fillRRect =
        RRect.fromRectAndRadius(fillRect, Radius.circular(radius));
    canvas.drawRRect(fillRRect, Paint()..color = color);

    // Bordure blanche.
    canvas.drawRRect(
      fillRRect.deflate(borderWidth / 2),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    // Numéro de ligne au centre, blanc, gras.
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )
      ..text = TextSpan(
        text: label,
        style: TextStyle(
          color: _bestTextColor(color),
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          height: 1.0,
          letterSpacing: -0.3,
        ),
      )
      ..layout(maxWidth: w - borderWidth * 4);

    textPainter.paint(
      canvas,
      Offset(
        (w - textPainter.width) / 2,
        (h - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    // BitmapDescriptor.bytes avec width/height EXPLICITES en pixels
    // logiques. Sans width/height, gmaps web tente de fetch les dims du
    // bitmap via une img tag async ; si ce fetch échoue ou retourne 0,
    // _setIconAnchor n'est jamais appelé et l'anchor de notre Marker
    // (0.5, 0.5) est silencieusement ignoré → marker décalé. Avec
    // width/height, _getBitmapSize court-circuite immédiatement et
    // l'anchor est posé correctement.
    final descriptor = BitmapDescriptor.bytes(
      bytes,
      width: baseW,
      height: baseH,
    );
    _cache[key] = descriptor;
    return descriptor;
  }

  /// Point blanc avec fine bordure noire — neutre, lisible quelle que
  /// soit la couleur de la ligne. Posé directement sur la polyline (qui
  /// a elle-même un contour noir), donne un effet "stop blanc dans la
  /// ligne" type plan métro.
  static Future<BitmapDescriptor> _renderDot(
      Color color, double devicePixelRatio) async {
    final size = _dotSize * devicePixelRatio;
    final ringWidth = 1.0 * devicePixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final center = Offset(size / 2, size / 2);
    final outerRadius = size / 2;
    final innerRadius = outerRadius - ringWidth;

    canvas.drawCircle(center, outerRadius, Paint()..color = Colors.black);
    canvas.drawCircle(center, innerRadius, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: _dotSize,
      height: _dotSize,
    );
  }

  /// Renvoie noir ou blanc selon la luminance du fond (contrast WCAG-ish).
  /// Sur les couleurs très claires (jaunes, pastels) on bascule en noir.
  static Color _bestTextColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.6 ? const Color(0xFF1D3557) : Colors.white;
  }

  static void clearCache() => _cache.clear();
}
