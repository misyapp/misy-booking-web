import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Génère des [BitmapDescriptor] pour les arrêts du réseau de bus, avec un
/// rendu type IDF Mobilités : carré à coins arrondis, fond couleur de la
/// ligne, numéro de ligne en blanc gras, bordure blanche pour pop sur la carte.
///
/// Les bitmaps sont mis en cache par `(label, color, scale, large)` pour ne
/// payer le coût de rastérisation qu'une fois par variante.
class StopMarkerFactory {
  StopMarkerFactory._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Taille de référence (logique) en pixels logiques. Sera multipliée par
  /// le devicePixelRatio. Calibré pour rester lisible sans saturer la carte
  /// quand 200+ stops sont visibles à la fois.
  static const double _baseWidth = 26;
  static const double _baseHeight = 18;
  static const double _largeWidth = 42;
  static const double _largeHeight = 28;

  static Future<BitmapDescriptor> create({
    required String label,
    required Color color,
    required double devicePixelRatio,
    bool large = false,
  }) async {
    final key =
        '${label}_${color.value.toRadixString(16)}_${devicePixelRatio.toStringAsFixed(1)}_$large';
    final cached = _cache[key];
    if (cached != null) return cached;

    final w = (large ? _largeWidth : _baseWidth) * devicePixelRatio;
    final h = (large ? _largeHeight : _baseHeight) * devicePixelRatio;
    final radius = (large ? 6.0 : 4.0) * devicePixelRatio;
    final borderWidth = (large ? 2.0 : 1.4) * devicePixelRatio;
    final fontSize = (large ? 13.0 : 9.0) * devicePixelRatio;

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

  /// Renvoie noir ou blanc selon la luminance du fond (contrast WCAG-ish).
  /// Sur les couleurs très claires (jaunes, pastels) on bascule en noir.
  static Color _bestTextColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.6 ? const Color(0xFF1D3557) : Colors.white;
  }

  static void clearCache() => _cache.clear();
}
