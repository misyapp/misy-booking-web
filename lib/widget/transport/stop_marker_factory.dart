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

    // Point blanc bord noir posé sur le tracé (à l'origine = ancre géo).
    if (withDot) {
      final dotR = dotDia / 2 * s;
      final ring = 1.0 * s;
      canvas.drawCircle(origin, dotR, Paint()..color = Colors.black);
      canvas.drawCircle(origin, dotR - ring, Paint()..color = Colors.white);
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

  /// Tiret d'arrêt style M réso : barre dessinée HORIZONTALEMENT (donc
  /// perpendiculaire au tracé une fois le marker tourné par `rotation` = cap,
  /// avec `flat: true`). [twoWay] vrai → tiret plein centré (croise le trait,
  /// arrêt desservi dans les 2 sens) ; faux → demi-tiret d'un seul côté
  /// (arrêt à sens unique). Liseré blanc pour rester lisible sur le trait.
  static Future<BitmapDescriptor> createTick({
    required Color color,
    required bool twoWay,
    required double bearingDeg,
    required double devicePixelRatio,
  }) async {
    final b = ((bearingDeg / 5).round() * 5) % 360; // bucket 5° (cache borné)
    final key =
        'tick_${color.value.toRadixString(16)}_${twoWay}_${b}_${devicePixelRatio.toStringAsFixed(1)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    const logical = 14.0;
    final size = logical * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // On tourne le repère selon le cap : la barre, dessinée le long de l'axe x
    // local, devient ainsi perpendiculaire au tracé (rotation cuite car
    // google_maps_flutter web ignore Marker.rotation).
    canvas.translate(size / 2, size / 2);
    canvas.rotate(b * math.pi / 180);
    final thickness = 3.4 * devicePixelRatio;
    final len = size * 0.46; // dépasse le trait pour bien se voir
    // Plein (2 sens) : croise le trait (−len..+len). Demi (1 sens) : un côté.
    final left = twoWay ? -len : 0.0;
    final rect = Rect.fromLTRB(left, -thickness / 2, len, thickness / 2);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(thickness / 2));

    // Liseré sombre + cœur BLANC : un tiret blanc ressort sur le trait coloré
    // (un tiret de la couleur de la ligne s'y fondrait → invisible).
    canvas.drawRRect(
      rr.inflate(1.4 * devicePixelRatio),
      Paint()..color = const Color(0xFF37474F),
    );
    canvas.drawRRect(rr, Paint()..color = Colors.white);

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

  /// Nœud de correspondance : petit point blanc cerclé de sombre, posé PILE
  /// sur le tracé (à l'intérieur du trait) pour matérialiser la position de
  /// l'arrêt du pôle. La capsule listant les lignes, elle, flotte au-dessus.
  static Future<BitmapDescriptor> createNode({
    required double devicePixelRatio,
  }) async {
    final key = 'node_${devicePixelRatio.toStringAsFixed(1)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    const logical = 10.0;
    final size = logical * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(size / 2, size / 2);
    final ring = 1.8 * devicePixelRatio;
    canvas.drawCircle(c, size / 2, Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(c, size / 2 - ring, Paint()..color = Colors.white);

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

  /// Cap de terminus = dernier arrêt : gros point blanc cerclé de sombre posé
  /// au bout de la polyligne pour "fermer" le tracé. Plus gros que le nœud de
  /// correspondance.
  static Future<BitmapDescriptor> createTerminusCap({
    required double devicePixelRatio,
  }) async {
    final key = 'termcap_${devicePixelRatio.toStringAsFixed(1)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    const logical = 15.0;
    final size = logical * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(size / 2, size / 2);
    final ring = 2.4 * devicePixelRatio;
    canvas.drawCircle(c, size / 2, Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(c, size / 2 - ring, Paint()..color = Colors.white);

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

  static void clearCache() {
    _cache.clear();
    _pinnedCache.clear();
  }
}
