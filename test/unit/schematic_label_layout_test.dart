import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_ride_hailing_app/models/schematic_plan.dart';
import 'package:rider_ride_hailing_app/widget/transport/schematic_label_layout.dart';

/// Mesure déterministe : 7 px/caractère (8 en gras), hauteur 12.
Size fakeMeasure(String text, {required bool bold}) =>
    Size(text.length * (bold ? 8.0 : 7.0), 12.0);

SchStation st(String name, String kind, {int n = 2, int tier = 2}) =>
    SchStation(pos: Offset.zero, name: name, kind: kind, tier: tier, n: n);

const viewport = Rect.fromLTWH(0, 0, 800, 600);

List<PlacedLabel> run(
  Map<SchStation, Offset> pos, {
  List<ScreenSegment> segments = const [],
}) {
  final sorted = pos.keys.toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));
  return SchematicLabelLayout.layoutLabels(
    stationsByPriority: sorted,
    edgeSegments: segments,
    screenPos: pos,
    viewport: viewport,
    measure: fakeMeasure,
  );
}

void main() {
  test('station isolée : placée au 1er candidat (droite), angle 0', () {
    final a = st('Anosy', 'interchange', n: 20);
    final placed = run({a: const Offset(400, 300)});
    expect(placed, hasLength(1));
    expect(placed.first.angleDeg, 0);
    expect(placed.first.bold, isTrue);
    expect(placed.first.anchor.dx, greaterThan(400)); // à droite du point
  });

  test('jamais tronqué : la bbox couvre tout le texte mesuré', () {
    final a = st('Nom Extrêmement Long De Station Taxi-Be', 'stop');
    final placed = run({a: const Offset(400, 300)});
    expect(placed, hasLength(1));
    expect(placed.first.aabb.width,
        closeTo(fakeMeasure(a.name, bold: false).width, 0.001));
  });

  test('deux stations proches : pas de chevauchement, candidats alternatifs',
      () {
    final a = st('Mahamasina', 'interchange', n: 23);
    final b = st('Mahamasina Est', 'interchange', n: 9);
    final placed = run({
      a: const Offset(400, 300),
      b: const Offset(404, 300), // quasi superposées
    });
    expect(placed, hasLength(2));
    expect(placed[0].aabb.overlaps(placed[1].aabb), isFalse);
  });

  test('arrêt simple sans place : MASQUÉ (jamais posé en collision)', () {
    // Un mur de stations majeures sature tout l'espace autour du stop.
    final pos = <SchStation, Offset>{};
    for (var i = 0; i < 24; i++) {
      pos[st('Major Hub Numéro $i', 'interchange', n: 25 - i)] = Offset(
        380 + (i % 6) * 14.0,
        280 + (i ~/ 6) * 12.0,
      );
    }
    final simple = st('Petit Arrêt', 'stop', n: 1);
    pos[simple] = const Offset(400, 300);
    final placed = run(pos);
    for (var i = 0; i < placed.length; i++) {
      for (var j = i + 1; j < placed.length; j++) {
        expect(placed[i].aabb.overlaps(placed[j].aabb), isFalse,
            reason: 'aucune paire posée ne se chevauche');
      }
    }
  });

  test('label ne chevauche pas un tracé (segment) → bascule de côté', () {
    final a = st('Ampefiloha', 'interchange', n: 12);
    // Mur vertical de segments juste à droite : tous les candidats droite
    // sont bloqués → le label part à gauche.
    final segs = [
      for (var y = 250; y <= 350; y += 4)
        ScreenSegment(Offset(415, y.toDouble()), Offset(560, y.toDouble())),
    ];
    final placed = run({a: const Offset(400, 300)}, segments: segs);
    expect(placed, hasLength(1));
    expect(placed.first.anchor.dx, lessThan(400),
        reason: 'bascule côté gauche');
  });

  test('candidats 45° : AABB tournée correcte (jamais vertical)', () {
    final r = SchematicLabelLayout.aabbFor(
        const Offset(100, 100), const Size(70, 12), 45);
    // largeur attendue ≈ (w+h)/√2, à ±1
    expect(r.width, closeTo((70 + 12) * 0.7071, 1.0));
    expect(r.height, closeTo((70 + 12) * 0.7071, 1.0));
    // pas d'angle hors {0,±45} dans l'API
    final a = st('Diag', 'stop');
    final placed = run({a: const Offset(400, 300)});
    expect([0, -45, 45], contains(placed.first.angleDeg));
  });

  test('priorité : les majeurs sont posés avant les stops', () {
    final hub = st('Soarano', 'pole', n: 17);
    final stop = st('Soarano Annexe', 'stop', n: 1);
    // Même position : le hub doit gagner la meilleure place.
    final placed = run({
      stop: const Offset(400, 300),
      hub: const Offset(400, 300),
    });
    final hubLabel =
        placed.where((p) => p.station.kind == 'pole').firstOrNull;
    expect(hubLabel, isNotNull);
    expect(hubLabel!.bold, isTrue);
  });

  test('force-directed léger : un majeur coincé finit par être posé', () {
    final pos = <SchStation, Offset>{};
    // Anneau serré de stops prioritaires saturant les 8 candidats proches.
    for (var i = 0; i < 8; i++) {
      pos[st('Voisin $i', 'interchange', n: 24)] = Offset(
        400 + 18 * (i.isEven ? 1 : -1) * ((i ~/ 2) + 1) / 2,
        300 + 14 * (i < 4 ? 1 : -1),
      );
    }
    final hub = st('Hub Central Important', 'pole', n: 30);
    pos[hub] = const Offset(400, 300);
    final placed = run(pos);
    final hubPlaced = placed.any((p) => p.station == hub);
    // Le hub est priorisé en tête : il obtient une place (1er servi) OU le
    // force-directed le replace — dans les deux cas il doit être présent.
    expect(hubPlaced, isTrue);
  });
}
