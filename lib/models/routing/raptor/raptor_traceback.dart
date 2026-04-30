import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_query.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_types.dart';

/// Reconstruit la liste des journeys (un par round k) à partir d'un
/// `RaptorQueryResult`. Pour chaque round où le destStop a été atteint,
/// on remonte les pointeurs `fromTrip` / `fromFoot`.
class RaptorTraceback {
  RaptorTraceback._();

  /// Renvoie la liste des journeys candidates (1 par round atteignable),
  /// non encore filtrées par Pareto. Une journey peut commencer par un
  /// walk leg si l'origine n'était pas pile sur un stop (modélisé via
  /// `originAccessTimeMin > 0` côté query).
  static List<RaptorJourney> traceAll({
    required RaptorNetwork net,
    required RaptorQueryResult result,
    required int destStopIdx,
    required Set<int> originStopIdxs,
  }) {
    final journeys = <RaptorJourney>[];
    for (var k = 0; k <= result.kMax; k++) {
      if (result.arr[k][destStopIdx].isFinite) {
        final journey = _trace(
          net: net,
          result: result,
          destStopIdx: destStopIdx,
          finalRound: k,
          originStopIdxs: originStopIdxs,
        );
        if (journey != null) journeys.add(journey);
      }
    }
    return journeys;
  }

  static RaptorJourney? _trace({
    required RaptorNetwork net,
    required RaptorQueryResult result,
    required int destStopIdx,
    required int finalRound,
    required Set<int> originStopIdxs,
  }) {
    final legs = <RaptorLeg>[];
    var s = destStopIdx;
    var k = finalRound;

    // Garde-fou anti-boucle (théoriquement impossible avec arr décroissant
    // strictement à chaque maj, mais on borne).
    var safety = (result.kMax + 1) * 4 + 10;

    while (safety-- > 0) {
      // Cas 1 : stop atteint via foot AU round k.
      final footFrom = result.fromFoot[k][s];
      if (footFrom >= 0) {
        // Vérifie que ce foot label correspond bien à arr[k][s] courant.
        // (Sinon on remonte par le trip.)
        final fromTime = result.arr[k][footFrom];
        // Distance et durée du foot leg.
        int walkDur = 0;
        int walkDist = 0;
        for (final fp in net.footpaths[footFrom]) {
          if (fp.toStopIdx == s) {
            walkDur = fp.durationMin;
            walkDist = fp.distanceMeters;
            break;
          }
        }
        if ((fromTime + walkDur - result.arr[k][s]).abs() < 0.001) {
          legs.add(RaptorWalkLeg(
            fromStopIdx: footFrom,
            toStopIdx: s,
            durationMin: walkDur,
            distanceMeters: walkDist,
          ));
          s = footFrom;
          // Le foot ne consomme pas un round (k inchangé).
          if (originStopIdxs.contains(s) && _isStartArr(result, s, k)) {
            break;
          }
          continue;
        }
      }

      // Cas 2 : stop atteint via trip AU round k.
      final tripFrom = result.fromTrip[k][s];
      if (tripFrom != null) {
        final route = net.routes[tripFrom.routeIdx];
        // Durée embarquée = somme des travelMin entre boardStopOrder et alightStopOrder
        var rideDur = 0;
        for (var i = tripFrom.boardStopOrder;
            i < tripFrom.alightStopOrder;
            i++) {
          rideDur += route.travelMin[i];
        }
        final wait = (route.headwayMin / 2.0).round();
        legs.add(RaptorRideLeg(
          routeIdx: tripFrom.routeIdx,
          boardStopIdx: tripFrom.boardStopIdx,
          alightStopIdx: s,
          boardStopOrder: tripFrom.boardStopOrder,
          alightStopOrder: tripFrom.alightStopOrder,
          durationMin: rideDur,
          waitMin: wait,
        ));
        s = tripFrom.boardStopIdx;
        k -= 1;
        if (k < 0) break;
        if (originStopIdxs.contains(s) && _isStartArr(result, s, k)) {
          break;
        }
        continue;
      }

      // Aucun pointeur : on est revenu à un stop d'accès initial.
      if (originStopIdxs.contains(s)) break;
      // Cas pathologique : pointeur manquant alors qu'on n'est pas à
      // l'origine. Abort avec null pour éviter un journey corrompu.
      return null;
    }

    if (legs.isEmpty) return null;
    final reversed = legs.reversed.toList();

    var rideMin = 0;
    var walkMin = 0;
    var transfers = 0;
    var rideCount = 0;
    for (final l in reversed) {
      if (l is RaptorRideLeg) {
        rideMin += l.durationMin + l.waitMin;
        rideCount++;
      } else if (l is RaptorWalkLeg) {
        walkMin += l.durationMin;
      }
    }
    transfers = rideCount > 0 ? rideCount - 1 : 0;
    final total = rideMin + walkMin;

    return RaptorJourney(
      legs: reversed,
      totalMinutes: total,
      transfers: transfers,
      walkMinutes: walkMin,
      rideMinutes: rideMin,
      boardingRound: finalRound,
    );
  }

  /// Le stop `s` correspond-il à un point de départ (pas atteint par un
  /// pointeur further back) ? On considère que oui si `arr[k][s]` est
  /// l'access initial (foot[k][s] = -1 ET trip[k][s] = null), et qu'on
  /// est revenu à un origin candidate.
  static bool _isStartArr(RaptorQueryResult result, int s, int k) {
    return result.fromTrip[k][s] == null && result.fromFoot[k][s] < 0;
  }
}
