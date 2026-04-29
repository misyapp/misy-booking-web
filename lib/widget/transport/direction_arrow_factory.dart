import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Génère des [BitmapDescriptor] pour les flèches de sens de circulation,
/// posées sur les portions divergentes (= boucles de lignes circulaires).
///
/// Pointe vers le HAUT à 0° de rotation. La rotation appliquée au [Marker]
/// est ensuite égale au bearing de la portion (calculé par
/// [LineGeometryAnalyzer.bearingDegrees]).
class DirectionArrowFactory {
  DirectionArrowFactory._();

  static final Map<String, BitmapDescriptor> _cache = {};

  static const double _baseSize = 18.0;

  static Future<BitmapDescriptor> create({
    required Color color,
    required double devicePixelRatio,
  }) async {
    final key = '${color.value.toRadixString(16)}_${devicePixelRatio.toStringAsFixed(1)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final size = _baseSize * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fillPaint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * devicePixelRatio
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Triangle pointant vers le haut, centré, légèrement allongé pour que
    // le sens soit lisible même petit. Coordonnées en pixels logiques × dpr.
    final s = size;
    final path = Path()
      ..moveTo(s * 0.5, s * 0.10) // pointe haut
      ..lineTo(s * 0.92, s * 0.78) // bas droit
      ..lineTo(s * 0.5, s * 0.62) // creux central
      ..lineTo(s * 0.08, s * 0.78) // bas gauche
      ..close();

    // Drop shadow douce pour pop sur les fonds clairs.
    canvas.drawShadow(path, Colors.black.withOpacity(0.35), 1.2 * devicePixelRatio, true);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(s.toInt(), s.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor =
        BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    _cache[key] = descriptor;
    return descriptor;
  }

  static void clearCache() => _cache.clear();
}
