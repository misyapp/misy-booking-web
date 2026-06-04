import 'dart:math' as math;
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
  static final Map<String, ({BitmapDescriptor descriptor, Offset anchor})>
      _pinnedCache = {};

  // Tailles logiques (× devicePixelRatio en sortie). Calibrées pour rester
  // lisibles sans saturer la carte type IDF Mobilités. Volontairement
  // petites pour que les markers ne masquent pas le trait de la ligne.
  static const double _dotSize = 10; // diamètre extérieur (anneau couleur ligne)
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

  /// Badge d'arrêt CIRCULAIRE pour la vue « ligne sélectionnée » : disque
  /// couleur de la ligne entouré d'une bordure blanche, libellé court centré
  /// (numéro sur 3 chiffres ou initiale, cf. _shortLineLabel côté appelant).
  /// Ancre = centre (0.5, 0.5). Cache par (label, couleur, dpr, big).
  static Future<BitmapDescriptor> createCircleBadge({
    required String label,
    required Color color,
    required double devicePixelRatio,
    bool big = false,
  }) async {
    final key =
        'circle_${label}_${color.value.toRadixString(16)}_${devicePixelRatio.toStringAsFixed(1)}_$big';
    final cached = _cache[key];
    if (cached != null) return cached;

    final double baseD = big ? 27.0 : 21.0; // diamètre logique
    final double baseBorder = big ? 2.6 : 2.2;
    final double baseFont = big ? 9.5 : 7.5;
    final d = baseD * devicePixelRatio;
    final borderWidth = baseBorder * devicePixelRatio;
    final fontSize = baseFont * devicePixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(d / 2, d / 2);

    // Disque blanc plein (= la bordure), puis disque couleur de la ligne.
    canvas.drawCircle(center, d / 2, Paint()..color = Colors.white);
    canvas.drawCircle(center, d / 2 - borderWidth, Paint()..color = color);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )
      ..text = TextSpan(
        text: label,
        style: TextStyle(
          color: _bestTextColor(color),
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          height: 1.0,
          letterSpacing: -0.4,
        ),
      )
      ..layout(maxWidth: d);
    textPainter.paint(
      canvas,
      Offset((d - textPainter.width) / 2, (d - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(d.toInt(), d.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final descriptor =
        BitmapDescriptor.bytes(bytes, width: baseD, height: baseD);
    _cache[key] = descriptor;
    return descriptor;
  }

  /// Tuile d'arrêt « plan de métro » : un point blanc posé sur le tracé +
  /// la pastille du n° de ligne décalée PERPENDICULAIREMENT au tracé. Le point
  /// sert d'ancre géographique (reste pile sur la polyline) ; la pastille flotte
  /// à côté, du côté pointant vers le haut de l'écran (sinon vers la droite).
  /// Retourne le descriptor ET l'anchor fractionnaire à poser sur le Marker —
  /// l'anchor reste dans [0,1] car le point est inclus dans le bitmap (gmaps web
  /// gère mal les ancres hors bornes). [withDot] faux = pastille seule (utile
  /// quand un point d'arrêt est déjà dessiné par ailleurs, ex. itinéraire).
  static Future<({BitmapDescriptor descriptor, Offset anchor})> createPinnedLabel({
    required String label,
    required Color color,
    required double devicePixelRatio,
    required double bearingDeg,
    StopMarkerStyle style = StopMarkerStyle.label,
    bool withDot = true,
  }) async {
    final bb = ((bearingDeg / 5).round() * 5) % 360; // bucket 5° (cache borné)
    final key = 'pinned_${label}_${color.value.toRadixString(16)}_'
        '${devicePixelRatio.toStringAsFixed(1)}_${style.name}_${bb}_$withDot';
    final cached = _pinnedCache[key];
    if (cached != null) return cached;

    final double baseW;
    final double baseH;
    final double baseRadius;
    final double baseBorder;
    final double baseFont;
    switch (style) {
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
      case StopMarkerStyle.label:
      case StopMarkerStyle.dot:
        baseW = _labelWidth;
        baseH = _labelHeight;
        baseRadius = 3.0;
        baseBorder = 1.1;
        baseFont = 7.5;
        break;
    }

    // Direction du décalage à l'écran (nord = haut). On part de la normale au
    // tracé (cos, sin) puis on retient le côté pointant vers le haut (y < 0),
    // sinon vers la droite (x > 0).
    final rad = bb * math.pi / 180;
    var px = math.cos(rad);
    var py = math.sin(rad);
    if (py > 1e-3 || (py.abs() <= 1e-3 && px < 0)) {
      px = -px;
      py = -py;
    }

    // Géométrie logique : le point est à l'origine (0,0), la pastille à `dist`.
    const dotDia = _dotSize;
    const gap = 2.0;
    final half = (px.abs() * baseW + py.abs() * baseH) / 2;
    final dist = dotDia / 2 + gap + half;
    final chipCx = px * dist;
    final chipCy = py * dist;
    final minX = math.min(-dotDia / 2, chipCx - baseW / 2);
    final maxX = math.max(dotDia / 2, chipCx + baseW / 2);
    final minY = math.min(-dotDia / 2, chipCy - baseH / 2);
    final maxY = math.max(dotDia / 2, chipCy + baseH / 2);
    final logicalW = maxX - minX;
    final logicalH = maxY - minY;
    final anchor = Offset((0 - minX) / logicalW, (0 - minY) / logicalH);

    final s = devicePixelRatio;
    final w = logicalW * s;
    final h = logicalH * s;
    final origin = Offset((0 - minX) * s, (0 - minY) * s);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Pastille couleur de la ligne + liseré blanc.
    final chipCenter = Offset(origin.dx + chipCx * s, origin.dy + chipCy * s);
    final chipRect = Rect.fromCenter(
        center: chipCenter, width: baseW * s, height: baseH * s);
    final chipRR =
        RRect.fromRectAndRadius(chipRect, Radius.circular(baseRadius * s));
    canvas.drawRRect(chipRR, Paint()..color = color);
    canvas.drawRRect(
      chipRR.deflate(baseBorder * s / 2),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseBorder * s,
    );

    final tp = TextPainter(
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
          fontSize: baseFont * s,
          height: 1.0,
          letterSpacing: -0.3,
        ),
      )
      ..layout(maxWidth: baseW * s - baseBorder * s * 4);
    tp.paint(
      canvas,
      Offset(chipCenter.dx - tp.width / 2, chipCenter.dy - tp.height / 2),
    );

    // Bille couleur de ligne posée sur le tracé (à l'origine = ancre géo) :
    // liseré blanc → anneau couleur → cœur blanc, cohérent avec _renderDot.
    if (withDot) {
      final dotR = dotDia / 2 * s;
      final whiteKeyline = 0.6 * s;
      final colorBand = 1.7 * s;
      canvas.drawCircle(origin, dotR, Paint()..color = Colors.white);
      canvas.drawCircle(origin, dotR - whiteKeyline, Paint()..color = color);
      canvas.drawCircle(
          origin, dotR - whiteKeyline - colorBand, Paint()..color = Colors.white);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.round(), h.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final result = (
      descriptor: BitmapDescriptor.bytes(
        byteData!.buffer.asUint8List(),
        width: logicalW,
        height: logicalH,
      ),
      anchor: anchor,
    );
    _pinnedCache[key] = result;
    return result;
  }

  /// Marker "pôle de correspondance" : capsule blanche contenant une rangée
  /// de chips (numéro de ligne sur sa couleur), style M réso. Cappé à 3 chips
  /// + "+N" si davantage de lignes desservent le pôle.
  static Future<BitmapDescriptor> createPole({
    required List<({String label, Color color})> lines,
    required double devicePixelRatio,
    bool big = false,
  }) async {
    const maxChips = 3;
    final shown = lines.take(maxChips).toList();
    final extra = lines.length - shown.length;
    final cacheKey = 'pole_'
        '${shown.map((e) => '${e.label}:${e.color.value.toRadixString(16)}').join('|')}'
        '_${extra}_${devicePixelRatio.toStringAsFixed(1)}_$big';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    // Dimensions logiques (× devicePixelRatio en sortie).
    final chipH = big ? 14.0 : 11.0;
    final chipW = big ? 20.0 : 16.0;
    const gap = 2.0;
    const pad = 2.5;
    final radius = big ? 5.0 : 4.0;
    final font = big ? 8.5 : 7.0;
    final chipRadius = big ? 3.0 : 2.5;
    final s = devicePixelRatio;

    final count = shown.length + (extra > 0 ? 1 : 0);
    final logicalW = count * chipW + (count - 1) * gap + pad * 2;
    final logicalH = chipH + pad * 2;
    final w = logicalW * s;
    final h = logicalH * s;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Capsule blanche bordée gris.
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(radius * s),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.white);
    canvas.drawRRect(
      bg.deflate(0.6 * s),
      Paint()
        ..color = const Color(0xFF9E9E9E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * s,
    );

    var x = pad * s;
    final y = pad * s;
    void drawChip(String label, Color color) {
      final rect = Rect.fromLTWH(x, y, chipW * s, chipH * s);
      final rr =
          RRect.fromRectAndRadius(rect, Radius.circular(chipRadius * s));
      canvas.drawRRect(rr, Paint()..color = color);
      final tp = TextPainter(
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
            fontSize: font * s,
            height: 1.0,
            letterSpacing: -0.3,
          ),
        )
        ..layout(maxWidth: chipW * s - 2 * s);
      tp.paint(
        canvas,
        Offset(x + (chipW * s - tp.width) / 2, y + (chipH * s - tp.height) / 2),
      );
      x += chipW * s + gap * s;
    }

    for (final e in shown) {
      drawChip(e.label, e.color);
    }
    if (extra > 0) drawChip('+$extra', const Color(0xFF607D8B));

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: logicalW,
      height: logicalH,
    );
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Flèche de sens (chevron plein) ORIENTÉE selon [bearingDeg] (cap
  /// nord-horaire du déplacement). La rotation est cuite dans le bitmap car
  /// google_maps_flutter **web** ignore `Marker.rotation`. Couleur de la
  /// ligne + liseré blanc. Sert aux tronçons à sens unique (aller ≠ retour).
  static Future<BitmapDescriptor> createArrow({
    required Color color,
    required double bearingDeg,
    required double devicePixelRatio,
  }) async {
    final b = ((bearingDeg / 5).round() * 5) % 360; // bucket 5° (cache borné)
    final key =
        'arrow_${color.value.toRadixString(16)}_${b}_${devicePixelRatio.toStringAsFixed(1)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    const logical = 15.0;
    final size = logical * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.translate(size / 2, size / 2);
    canvas.rotate(b * math.pi / 180); // pointe vers le cap du déplacement
    final r = size * 0.36;
    // Chevron pointant vers le haut (−y) une fois la rotation appliquée.
    final path = Path()
      ..moveTo(0, -r)
      ..lineTo(r * 0.95, r * 0.55)
      ..lineTo(0, r * 0.16)
      ..lineTo(-r * 0.95, r * 0.55)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * devicePixelRatio
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = color);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: logical,
      height: logical,
    );
    _cache[key] = descriptor;
    return descriptor;
  }

  /// Cap de terminus = dernier arrêt : gros point PLEIN à la couleur de la
  /// ligne, cœur blanc + fin liseré blanc extérieur, posé au bout de la
  /// polyligne pour "fermer" le tracé. Plus gros que le nœud de correspondance.
  static Future<BitmapDescriptor> createTerminusCap({
    required Color color,
    required double devicePixelRatio,
  }) async {
    final key =
        'termcap_${color.value.toRadixString(16)}_${devicePixelRatio.toStringAsFixed(1)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    const logical = 15.0;
    final size = logical * devicePixelRatio;
    final s = devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(size / 2, size / 2);
    final r = size / 2;
    final whiteKeyline = 0.8 * s; // liseré blanc extérieur
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(c, r - whiteKeyline, Paint()..color = color);
    canvas.drawCircle(c, r * 0.40, Paint()..color = Colors.white); // cœur

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: logical,
      height: logical,
    );
    _cache[key] = descriptor;
    return descriptor;
  }

  /// Bille « couleur de ligne » : fin liseré blanc extérieur → anneau à la
  /// couleur de la ligne → cœur blanc. Le liseré détache l'arrêt du trait
  /// (même couleur dessous) et des lignes voisines, et garde le point lisible
  /// sur les couleurs claires (jaune/pastel). Effet station premium type Apple
  /// Plans / Citymapper, posé pile sur la polyline.
  static Future<BitmapDescriptor> _renderDot(
      Color color, double devicePixelRatio) async {
    final size = _dotSize * devicePixelRatio;
    final s = devicePixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final center = Offset(size / 2, size / 2);
    final r = size / 2;
    final whiteKeyline = 0.6 * s; // liseré blanc extérieur
    final colorBand = 1.7 * s; // épaisseur de l'anneau couleur

    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(center, r - whiteKeyline, Paint()..color = color);
    canvas.drawCircle(
        center, r - whiteKeyline - colorBand, Paint()..color = Colors.white);

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

  static void clearCache() {
    _cache.clear();
    _pinnedCache.clear();
  }
}
