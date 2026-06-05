// Aperçu offscreen du rendu CTS → PNG (sanity visuelle hors-app).
// À lancer AVEC le flag : flutter test --dart-define=SCHEMATIC_CTS=true \
//   test/schema_preview_cts_test.dart
// Sans le flag, le test échoue volontairement (garde-fou : il validerait
// le rendu legacy en silence). NB : polices fictives en flutter test
// (labels = rectangles) ; ce rendu valide la GÉOMÉTRIE + la symbologie.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_ride_hailing_app/models/schematic_plan.dart';
import 'package:rider_ride_hailing_app/widget/transport/schematic_map_view.dart';

void main() {
  const cts = bool.fromEnvironment('SCHEMATIC_CTS');

  testWidgets('preview CTS centre + global', (tester) async {
    expect(cts, isTrue,
        reason:
            'Lancer avec --dart-define=SCHEMATIC_CTS=true (sinon ce test '
            'rendrait le legacy)');
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final f in ['misy_cts_centre', 'misy_cts']) {
      final plan = SchematicPlan.fromJson(jsonDecode(
              File('web/transport_schema/$f.json').readAsStringSync())
          as Map<String, dynamic>);
      expect(plan.legendLines, isNotNull, reason: 'artefact CTS attendu');
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 1200,
              height: 1200,
              child: SchematicMapView(
                  plan: plan, showCentreRect: f == 'misy_cts'),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // toImage/toByteData touchent le GPU thread → runAsync obligatoire en
      // widget test (sans lui : Future jamais complété, hang 10 min).
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('/tmp/${f}_preview.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('WROTE /tmp/${f}_preview.png');
    }
  });
}
