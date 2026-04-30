import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_config.dart';
import 'package:rider_ride_hailing_app/models/routing/raptor/raptor_types.dart';

/// Filtrage et diversification multi-critères sur les journeys produits
/// par le traceback. Objectif : présenter à l'utilisateur 3-5 alternatives
/// vraiment différentes (rapide / peu de correspondances / peu de marche)
/// au lieu d'une demi-douzaine de journeys quasi-identiques.
class RaptorPareto {
  RaptorPareto._();

  /// Filtre + diversifie. Retourne au plus `topN` journeys, déjà triées
  /// par totalMinutes croissant.
  static List<RaptorJourney> filter(
    List<RaptorJourney> journeys,
    RaptorNetwork net, {
    int topN = 5,
  }) {
    if (journeys.isEmpty) return journeys;

    // 1. Bornes de sanité.
    final accepted = <RaptorJourney>[];
    for (final j in journeys) {
      if (j.walkMinutes > RaptorConfig.maxTotalWalkMin) continue;
      var maxSingleWalk = 0;
      for (final l in j.legs) {
        if (l is RaptorWalkLeg && l.durationMin > maxSingleWalk) {
          maxSingleWalk = l.durationMin;
        }
      }
      if (maxSingleWalk > RaptorConfig.maxSingleWalkMin) continue;
      accepted.add(j);
    }
    if (accepted.isEmpty) return journeys.take(topN).toList();

    // 2. Pareto sur (totalMinutes, transfers, walkMinutes).
    final pareto = <RaptorJourney>[];
    for (final j in accepted) {
      var dominated = false;
      for (final other in accepted) {
        if (identical(other, j)) continue;
        final t = other.totalMinutes <= j.totalMinutes;
        final c = other.transfers <= j.transfers;
        final w = other.walkMinutes <= j.walkMinutes;
        final strict = (other.totalMinutes < j.totalMinutes) ||
            (other.transfers < j.transfers) ||
            (other.walkMinutes < j.walkMinutes);
        if (t && c && w && strict) {
          dominated = true;
          break;
        }
      }
      if (!dominated) pareto.add(j);
    }

    // 3. Anti-doublons par signature (séquence ordonnée des lignes).
    final bySig = <String, RaptorJourney>{};
    for (final j in pareto) {
      final sig = _signature(j, net);
      final cur = bySig[sig];
      if (cur == null || j.totalMinutes < cur.totalMinutes) {
        bySig[sig] = j;
      }
    }
    final uniq = bySig.values.toList();

    // 4. Antipattern structurel : route dominée par "ligne plus tard
    //    passe déjà par un stop boarding antérieur". On le détecte ici
    //    car le Pareto+sig peut laisser passer ce cas (mêmes critères
    //    mais signatures différentes). C'est un GARDE-FOU vu que RAPTOR
    //    devrait déjà préférer des chemins plus courts ; ne dégrade pas
    //    la qualité tant qu'il reste des alternatives.
    final practical = uniq.where((j) => _isPractical(j, net)).toList();
    final base = practical.isNotEmpty ? practical : uniq;

    base.sort((a, b) => a.totalMinutes.compareTo(b.totalMinutes));

    // 5. Sélection finale : 1 fastest + 1 fewestTransfers + 1 leastWalk
    //    + alternatives Pareto restantes, jusqu'à topN.
    final selected = <RaptorJourney>[];
    if (base.isNotEmpty) selected.add(base.first); // fastest

    RaptorJourney? fewestTransfers;
    for (final j in base) {
      if (selected.contains(j)) continue;
      if (fewestTransfers == null ||
          j.transfers < fewestTransfers.transfers ||
          (j.transfers == fewestTransfers.transfers &&
              j.totalMinutes < fewestTransfers.totalMinutes)) {
        fewestTransfers = j;
      }
    }
    if (fewestTransfers != null && !selected.contains(fewestTransfers)) {
      selected.add(fewestTransfers);
    }

    RaptorJourney? leastWalk;
    for (final j in base) {
      if (selected.contains(j)) continue;
      if (leastWalk == null ||
          j.walkMinutes < leastWalk.walkMinutes ||
          (j.walkMinutes == leastWalk.walkMinutes &&
              j.totalMinutes < leastWalk.totalMinutes)) {
        leastWalk = j;
      }
    }
    if (leastWalk != null && !selected.contains(leastWalk)) {
      selected.add(leastWalk);
    }

    for (final j in base) {
      if (selected.length >= topN) break;
      if (!selected.contains(j)) selected.add(j);
    }

    selected.sort((a, b) => a.totalMinutes.compareTo(b.totalMinutes));
    return selected.take(topN).toList();
  }

  static String _signature(RaptorJourney j, RaptorNetwork net) {
    final buf = StringBuffer();
    for (final l in j.legs) {
      if (l is RaptorRideLeg) {
        final r = net.routes[l.routeIdx];
        buf
          ..write(r.lineNumber)
          ..write(r.isRetour ? 'R' : 'A')
          ..write('|');
      }
    }
    return buf.toString();
  }

  /// Une journey est "non pratique" si une ligne empruntée plus tard
  /// passe déjà par le stop boarding d'une ligne antérieure → il aurait
  /// suffi de prendre la ligne ultérieure directement. Ce filtre devrait
  /// rarement écarter un résultat car RAPTOR favorise déjà ce chemin
  /// court, mais c'est une garantie supplémentaire.
  static bool _isPractical(RaptorJourney j, RaptorNetwork net) {
    final rides = j.legs.whereType<RaptorRideLeg>().toList();
    if (rides.length < 2) return true;
    for (var i = 0; i < rides.length - 1; i++) {
      final boardStop = net.stops[rides[i].boardStopIdx];
      for (var k = i + 1; k < rides.length; k++) {
        final laterLine = net.routes[rides[k].routeIdx].lineNumber;
        if (boardStop.lineNumbers.contains(laterLine)) {
          return false;
        }
      }
    }
    return true;
  }
}
