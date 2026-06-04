// Banc de rendu visuel du pin central — génère des PNG dans /tmp pour
// itérer sur le design du bonhomme sans relancer l'app.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_ride_hailing_app/widgets/center_pin.dart';

void main() {
  testWidgets('render center pin states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 200));
    final keys = {
      'idle': GlobalKey(),
      'grabbed': GlobalKey(),
      'uncovered': GlobalKey(),
    };
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFE5E9EC), // fond charte carte
        body: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RepaintBoundary(
                key: keys['idle'],
                child: const CenterPin(grabbed: false, covered: true)),
            RepaintBoundary(
                key: keys['grabbed'],
                child: const CenterPin(grabbed: true, covered: true)),
            RepaintBoundary(
                key: keys['uncovered'],
                child: const CenterPin(grabbed: false, covered: false)),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // toImage/toByteData = vrais futures → hors de la fake-async zone.
    await tester.runAsync(() async {
      for (final e in keys.entries) {
        final boundary = e.value.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 3);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('/tmp/pin_${e.key}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    });
  });
}
