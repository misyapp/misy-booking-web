import 'dart:typed_data';

import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_config.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_types.dart';

/// Résultat brut d'une requête RAPTOR : pour chaque round k ∈ 0..K, la
/// matrice `arr[k][stopIdx]` de meilleurs temps d'arrivée + les labels
/// `fromTrip` / `fromFoot` pour reconstruire les chemins.
class RaptorQueryResult {
  /// `arr[k][stopIdx]` = meilleur temps d'arrivée (min depuis l'instant
  /// du calcul) en utilisant ≤ k boardings. `double.infinity` si
  /// inaccessible.
  final List<Float64List> arr;

  /// Backward-pointer trip : quand un stop a été atteint au round k via
  /// un boarding, on garde la route + indices.
  final List<List<RaptorTripBack?>> fromTrip;

  /// Backward-pointer foot : si on a atteint ce stop par marche au
  /// round k, l'index du stop précédent.
  final List<List<int>> fromFoot;

  /// Pour chaque round k, marqueur "foot uniquement" (true) vs "trip
  /// arrivé puis foot" pour distinguer les transitions sans boarding
  /// au round k. Utilisé seulement pour debug.
  final int kMax;

  RaptorQueryResult({
    required this.arr,
    required this.fromTrip,
    required this.fromFoot,
    required this.kMax,
  });
}

/// Cœur RAPTOR. Une query depuis un stop d'origine (déjà résolu via
/// `findNearestStops`) jusqu'au reste du réseau.
///
/// Spec : Delling, Pajor, Werneck — Microsoft Research 2012.
/// https://www.microsoft.com/en-us/research/wp-content/uploads/2012/01/raptor_alenex.pdf
///
/// Adaptation frequency-based : pas de stop_times exact → on injecte
/// `wait = headway/2` (espérance d'attente uniforme) UNE SEULE FOIS au
/// boarding. Le re-board sur la même route depuis un stop intermédiaire
/// (rare avec frequencies identiques mais théoriquement possible) est
/// supporté pour la correction.
class RaptorQuery {
  final RaptorNetwork net;
  final int kMax;
  final double accessTimeFromOrigin;

  RaptorQuery({
    required this.net,
    this.kMax = RaptorConfig.kMax,
    this.accessTimeFromOrigin = 0.0,
  });

  /// Lance la query. `originStops` = stops d'accès (l'utilisateur peut
  /// marcher vers chacun, avec le `accessTimeMin` correspondant). Cela
  /// modélise plusieurs candidats de "1er stop" sans pénalité.
  RaptorQueryResult run({
    required List<int> originStopIdxs,
    required List<int> originAccessTimeMin,
    required int destStopIdx,
  }) {
    final n = net.stops.length;
    const inf = double.infinity;

    final arr = List<Float64List>.generate(
        kMax + 1, (_) => Float64List(n)..fillRange(0, n, inf));
    final fromTrip = List<List<RaptorTripBack?>>.generate(
        kMax + 1, (_) => List<RaptorTripBack?>.filled(n, null));
    final fromFoot = List<List<int>>.generate(
        kMax + 1, (_) => List<int>.filled(n, -1));

    // best[s] = meilleur arrival_time toutes rondes confondues. Sert au
    // pruning early-termination.
    final best = Float64List(n)..fillRange(0, n, inf);

    // marked = stops à scanner au prochain round.
    final marked = Uint8List(n);
    final markedQueue = <int>[];

    void mark(int s) {
      if (marked[s] == 0) {
        marked[s] = 1;
        markedQueue.add(s);
      }
    }

    // Round 0 : initialisation depuis les stops d'accès + footpath relax.
    for (var i = 0; i < originStopIdxs.length; i++) {
      final s = originStopIdxs[i];
      final t = originAccessTimeMin[i].toDouble();
      if (t < arr[0][s]) {
        arr[0][s] = t;
        if (t < best[s]) best[s] = t;
        mark(s);
      }
    }
    // Footpath relax depuis les stops d'accès (uniquement round 0,
    // pas de boarding à compter).
    final round0Foot = List<int>.from(markedQueue);
    for (final s in round0Foot) {
      final fps = net.footpaths[s];
      for (final fp in fps) {
        final cand = arr[0][s] + fp.durationMin;
        if (cand < arr[0][fp.toStopIdx]) {
          arr[0][fp.toStopIdx] = cand;
          if (cand < best[fp.toStopIdx]) best[fp.toStopIdx] = cand;
          fromFoot[0][fp.toStopIdx] = s;
          mark(fp.toStopIdx);
        }
      }
    }

    // Rounds successifs.
    for (var k = 1; k <= kMax; k++) {
      // Init arr[k] = arr[k-1].
      arr[k].setAll(0, arr[k - 1]);

      // Q : routeIdx -> (boardOrder, boardStop) — earliest boarding.
      final qBoardOrder = <int, int>{};
      final qBoardStop = <int, int>{};

      // Snapshot des stops marqués au round k-1.
      final markedSnapshot = List<int>.from(markedQueue);
      for (final s in markedSnapshot) {
        marked[s] = 0;
      }
      markedQueue.clear();

      for (final s in markedSnapshot) {
        final entries = net.stopToRoutes[s];
        for (final e in entries) {
          final cur = qBoardOrder[e.routeIdx];
          if (cur == null || e.stopOrder < cur) {
            qBoardOrder[e.routeIdx] = e.stopOrder;
            qBoardStop[e.routeIdx] = s;
          }
        }
      }

      // Scan routes : un seul passage par route par round.
      qBoardOrder.forEach((routeIdx, boardOrder) {
        final route = net.routes[routeIdx];
        final boardStop = qBoardStop[routeIdx]!;
        final wait = route.headwayMin / 2.0;
        var currentTime = arr[k - 1][boardStop] + wait;
        var currentBoardStop = boardStop;
        var currentBoardOrder = boardOrder;

        // Early termination : si on dépasse déjà best[dest], stop.
        if (currentTime >= best[destStopIdx]) return;

        for (var p = boardOrder + 1; p < route.stops.length; p++) {
          currentTime += route.travelMin[p - 1];
          if (currentTime >= best[destStopIdx]) {
            // Plus aucun stop futur ne peut améliorer.
            break;
          }
          final s = route.stops[p];
          if (currentTime < arr[k][s]) {
            arr[k][s] = currentTime;
            if (currentTime < best[s]) best[s] = currentTime;
            fromTrip[k][s] = RaptorTripBack(
              routeIdx: routeIdx,
              boardStopIdx: currentBoardStop,
              boardStopOrder: currentBoardOrder,
              alightStopOrder: p,
            );
            mark(s);
          }
          // Re-board possible plus tôt depuis ce stop ?
          final earlierBoard = arr[k - 1][s] + wait;
          if (earlierBoard < currentTime) {
            currentTime = earlierBoard;
            currentBoardOrder = p;
            currentBoardStop = s;
          }
        }
      });

      // Footpath relax intra-round.
      final tripMarked = List<int>.from(markedQueue);
      for (final s in tripMarked) {
        final fps = net.footpaths[s];
        for (final fp in fps) {
          final cand = arr[k][s] + fp.durationMin;
          if (cand < arr[k][fp.toStopIdx]) {
            arr[k][fp.toStopIdx] = cand;
            if (cand < best[fp.toStopIdx]) best[fp.toStopIdx] = cand;
            fromFoot[k][fp.toStopIdx] = s;
            mark(fp.toStopIdx);
          }
        }
      }

      if (markedQueue.isEmpty) break;
    }

    return RaptorQueryResult(
      arr: arr,
      fromTrip: fromTrip,
      fromFoot: fromFoot,
      kMax: kMax,
    );
  }
}
