import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Style de rendu d'un marker d'arrêt, choisi en fonction du zoom courant.
///
/// - [dot] : point blanc avec anneau couleur de la ligne, pas de numéro.
///   Affiché à zoom intermédiaire — donne la position sans saturer la carte.
/// - [label] : carré arrondi couleur de la ligne avec le numéro en blanc.
///   Affiché à zoom élevé quand l'utilisateur regarde un quartier précis.
/// - [largeLabel] : variante agrandie de [label], pour le stop sélectionné.
enum StopMarkerStyle { dot, label, largeLabel }

/// Génère des [BitmapDescriptor] pour les arrêts du réseau de bus.
///
/// Cache par `(label, color, scale, style)` pour ne payer le coût de
/// rastérisation qu'une seule fois par variante.
class StopMarkerFactory {
  StopMarkerFactory._();

  static final Map<String, BitmapDescriptor> _cache = {};

  // Tailles logiques (× devicePixelRatio en sortie). Calibrées pour rester
  // lisibles sans saturer la carte type IDF Mobilités.
  static const double _dotSize = 12; // diamètre extérieur (anneau)
  static const double _labelWidth = 17;
  static const double _labelHeight = 13;
  static const double _largeWidth = 30;
  static const double _largeHeight = 21;

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

    final large = style == StopMarkerStyle.largeLabel;
    final w = (large ? _largeWidth : _labelWidth) * devicePixelRatio;
    final h = (large ? _largeHeight : _labelHeight) * devicePixelRatio;
    final radius = (large ? 5.0 : 3.0) * devicePixelRatio;
    final borderWidth = (large ? 1.8 : 1.1) * devicePixelRatio;
    final fontSize = (large ? 11.0 : 7.5) * devicePixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Drop shadow douce sous le carré.
    final shadowRect = Rect.fromLTWH(0, h * 0.04, w, h);
    final shadowRRect =
        RRect.fromRectAndRadius(shadowRect, Radius.circular(radius));
    canvas.drawRRect(
      shadowRRect,
      Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * devicePixelRatio),
    );

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
    final descriptor = BitmapDescriptor.fromBytes(bytes);
    _cache[key] = descriptor;
    return descriptor;
  }

  /// Petit point blanc avec anneau couleur de la ligne. Utilisé à zoom
  /// intermédiaire (14-15) pour montrer la position des arrêts sans
  /// encombrer la carte avec les numéros.
  static Future<BitmapDescriptor> _renderDot(
      Color color, double devicePixelRatio) async {
    final size = _dotSize * devicePixelRatio;
    final ringWidth = 2.0 * devicePixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final center = Offset(size / 2, size / 2);
    final outerRadius = size / 2;
    final innerRadius = outerRadius - ringWidth;

    // Drop shadow.
    canvas.drawCircle(
      center.translate(0, ringWidth * 0.3),
      outerRadius,
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ringWidth * 0.6),
    );
    // Anneau couleur de ligne.
    canvas.drawCircle(center, outerRadius, Paint()..color = color);
    // Centre blanc.
    canvas.drawCircle(center, innerRadius, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  /// Renvoie noir ou blanc selon la luminance du fond (contrast WCAG-ish).
  /// Sur les couleurs très claires (jaunes, pastels) on bascule en noir.
  static Color _bestTextColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.6 ? const Color(0xFF1D3557) : Colors.white;
  }

  static void clearCache() => _cache.clear();
}
