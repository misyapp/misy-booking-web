// Aperçu offscreen du SchematicMapView → PNG (sanity visuelle hors-app).
// NB : en `flutter test`, les polices sont fictives (labels = rectangles) ;
// ce rendu sert à valider la GÉOMÉTRIE (traits, faisceaux, arrêts, eau, carré).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_ride_hailing_app/models/schematic_plan.dart';
import 'package:rider_ride_hailing_app/widget/transport/schematic_map_view.dart';

void main() {
  testWidgets('preview centre + global', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final f in ['misy_octilineaire_centre', 'misy_octilineaire']) {
      final plan = SchematicPlan.fromJson(jsonDecode(
              File('web/transport_schema/$f.json').readAsStringSync())
          as Map<String, dynamic>);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 1200,
              height: 1200,
              child: SchematicMapView(plan: plan, showCentreRect: f.endsWith('aire')),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/$f.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      // ignore: avoid_print
      print('WROTE /tmp/$f.png');
    }
  });
}
