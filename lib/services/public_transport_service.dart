import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';

/// Source de données pour l'onglet public "Transport en commun" sur
/// book.misy.app. Lit UNIQUEMENT le bundle local
/// `assets/transport_lines_public/` qui contient les lignes admin-approved
/// (générées par `node scripts/transport_editor_pull_cli.js publish-bundle`).
///
/// Distinct du [TransportLinesService] (utilisé par les outils admin) qui
/// lit Firestore en priorité et inclut les lignes en cours d'édition. Ici,
/// zéro Firestore runtime — propagation des nouvelles validations admin se
/// fait via régénération du bundle + rebuild + rsync.
class PublicTransportService {
  PublicTransportService._();

  static final PublicTransportService instance = PublicTransportService._();

  static const String _manifestAsset =
      'assets/transport_lines_public/manifest.json';

  Map<String, LineMetadata>? _manifest;
  final Map<String, TransportLineGroup> _linesCache = {};
  TransportGraph? _graph;
  Future<void>? _loadFuture;

  /// Lignes triées par "importance" (longueur totale en km, aller + retour).
  /// Calculé une fois après le chargement complet. Sert au filtrage par zoom.
  List<String> _linesByImportance = const [];

  List<String> get linesByImportance => _linesByImportance;


  /// Charge le manifest + tous les GeoJSON. Idempotent grâce au futur partagé.
  Future<void> ensureLoaded() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString(_manifestAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final lines = (json['lines'] as List? ?? [])
        .map((e) => LineMetadata.fromJson(e as Map<String, dynamic>))
        .toList();
    _manifest = {for (final m in lines) m.lineNumber: m};

    await Future.wait(lines.map(_loadLine));
    _computeImportance();
    _computeAllBranches();
    _computeAllSchematics();
    _buildSearchIndex();
    myCustomPrintStatement(
      'PublicTransportService: ${_linesCache.length}/${lines.length} lignes chargées',
    );
  }

  /// Classe les lignes par longueur totale aller+retour décroissante. Sert
  /// au filtrage zoom-dependent (les axes longs N-S / E-O sont toujours
  /// affichés, les petites lignes locales n'apparaissent qu'au zoom élevé).
  void _computeImportance() {
    final scored = <MapEntry<String, double>>[];
    for (final group in _linesCache.values) {
      var total = 0.0;
      for (final line in group.lines) {
        total += _polylineLengthKm(line.coordinates);
      }
      scored.add(MapEntry(group.lineNumber, total));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    _linesByImportance = scored.map((e) => e.key).toList(growable: false);
  }

  static double _polylineLengthKm(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      total += _haversineKm(pts[i], pts[i + 1]);
    }
    return total;
  }

  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  /// Sous-ensemble des lignes à afficher pour un niveau de zoom donné.
  /// Plus on dezoom, moins de lignes — on garde les axes longs en priorité.
  ///
  /// Seuils calibrés pour Tana (95 lignes max, on en a 40 admin-validées en
  /// production actuellement) :
  ///   - zoom <  11   : top 5 (vue régionale, axes principaux)
  ///   - zoom 11-12   : top 10
  ///   - zoom 12-13   : top 20
  ///   - zoom 13-14   : top 30
  ///   - zoom >= 14   : toutes les lignes
  Set<String> visibleLineNumbersForZoom(double zoom) {
    final all = _linesByImportance;
    if (all.isEmpty) return const {};
    int cap;
    if (zoom < 11) {
      cap = 5;
    } else if (zoom < 12) {
      cap = 10;
    } else if (zoom < 13) {
      cap = 20;
    } else if (zoom < 14) {
      cap = 30;
    } else {
      cap = all.length;
    }
    if (cap >= all.length) return all.toSet();
    return all.take(cap).toSet();
  }

  Future<void> _loadLine(LineMetadata m) async {
    try {
      TransportLine? aller;
      TransportLine? retour;
      if (m.aller?.assetPath != null) {
        aller = await _loadGeoJson(m.aller!.assetPath!, false);
      }
      if (m.retour?.assetPath != null) {
        retour = await _loadGeoJson(m.retour!.assetPath!, true);
      }
      if (aller == null && retour == null) return;
      _linesCache[m.lineNumber] = TransportLineGroup(
        lineNumber: m.lineNumber,
        displayName: m.displayName,
        transportType: aller?.transportType ??
            retour?.transportType ??
            TransportType.bus,
        aller: aller,
        retour: retour,
      );
    } catch (e) {
      myCustomPrintStatement(
        'PublicTransportService: erreur ligne ${m.lineNumber}: $e',
      );
    }
  }

  Future<TransportLine?> _loadGeoJson(String assetPath, bool isRetour) async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final filename = assetPath.split('/').last;
    return TransportLine.fromGeoJson(json, filename);
  }

  /// Métadonnées de toutes les lignes validées (pour la sidebar liste).
  List<LineMetadata> get allMetadata {
    final list = (_manifest?.values.toList() ?? [])..sort(_compareLine);
    return list;
  }

  /// Métadonnées d'une ligne donnée (couleur, nom).
  LineMetadata? metadataFor(String lineNumber) => _manifest?[lineNumber];

  /// Lignes chargées triées par numéro.
  List<TransportLineGroup> get allLines {
    final list = _linesCache.values.toList()
      ..sort((a, b) => _compareLine(
            LineMetadata(
              lineNumber: a.lineNumber,
              displayName: a.displayName,
              transportType: '',
              colorHex: '',
              isBundled: true,
            ),
            LineMetadata(
              lineNumber: b.lineNumber,
              displayName: b.displayName,
              transportType: '',
              colorHex: '',
              isBundled: true,
            ),
          ));
    return list;
  }

  TransportLineGroup? getLineGroup(String lineNumber) =>
      _linesCache[lineNumber];

  /// Renvoie la liste des arrêts UNIQUES de la ligne, dans l'ordre :
  /// stops de l'aller en premier, puis stops du retour qui ne sont pas
  /// déjà couverts (par nom identique ou par proximité 35m). Utilisé par
  /// la sidebar pour afficher le nombre + la liste cliquable d'arrêts.
  List<String> uniqueStopNamesFor(String lineNumber) {
    final group = _linesCache[lineNumber];
    if (group == null) return const [];
    final result = <String>[];
    final seen = <_SeenStop>[];

    void process(List<TransportStop>? stops) {
      if (stops == null) return;
      for (final stop in stops) {
        final nameNorm = _normalizeName(stop.name);
        var matched = false;
        for (final s in seen) {
          final dist = _haversineKm(s.position, stop.position) * 1000;
          final sameName = nameNorm.isNotEmpty &&
              s.nameNorm.isNotEmpty &&
              s.nameNorm == nameNorm;
          if (sameName && dist <= 250.0) {
            matched = true;
            break;
          }
          if (dist <= 35.0) {
            matched = true;
            break;
          }
        }
        if (!matched) {
          seen.add(_SeenStop(nameNorm, stop.position));
          final display = stop.name.trim().isEmpty ? '—' : stop.name;
          result.add(display);
        }
      }
    }

    process(group.aller?.stops);
    process(group.retour?.stops);
    return result;
  }

  int uniqueStopCountFor(String lineNumber) =>
      uniqueStopNamesFor(lineNumber).length;

  /// Index de recherche d'arrêts pré-calculé au chargement. Évite le
  /// O(N²) à chaque frappe (avant : pour chaque match, re-scan de toutes
  /// les lignes pour trouver celles qui le desservent).
  ///
  /// Chaque entrée : un nom d'arrêt unique (normalisé) avec sa 1ʳᵉ position
  /// rencontrée, son nom d'affichage, et l'ensemble des lignes qui le
  /// desservent (par identité de nom OU proximité ≤ 80m d'au moins un de
  /// leurs arrêts).
  List<PublicSearchableStop> _searchIndex = const [];
  List<PublicSearchableStop> get searchIndex => _searchIndex;

  /// Cache des branches calculées (linéaire vs circulaire) par lineNumber.
  /// Rempli au load. Évite la détection à chaque expand de la sidebar.
  final Map<String, LineBranches> _branchesCache = {};

  /// Cache des schémas topologiques (linear / trunk-loop / loop-only / complex)
  /// par lineNumber. Couche au-dessus de [_branchesCache] qui enrichit la
  /// détection avec un découpage trunk vs boucle.
  final Map<String, LineSchematic> _schematicCache = {};

  /// Renvoie le schéma topologique de la ligne pour le rendu sidebar :
  /// trunk commun + boucle divergente (rectangle), ou linéaire pure, ou
  /// tout-boucle, ou complex (fallback).
  LineSchematic lineSchematicFor(String lineNumber) {
    return _schematicCache[lineNumber] ?? LineSchematic.empty();
  }

  /// Construit l'index de recherche d'arrêts. O(N) total au chargement,
  /// puis chaque recherche est un simple `where` sur le nom normalisé.
  void _buildSearchIndex() {
    // Bucket par nom normalisé pour dédupliquer aller/retour et arrêts
    // d'autres lignes au même nom.
    final byName = <String, _SearchableBuilder>{};
    final groups = _linesCache.values.toList();
    for (final group in groups) {
      for (final stop in [
        ...?group.aller?.stops,
        ...?group.retour?.stops
      ]) {
        final raw = stop.name.trim();
        if (raw.isEmpty) continue;
        final norm = _normalizeName(raw);
        final entry = byName.putIfAbsent(
            norm,
            () => _SearchableBuilder(
                  norm: norm,
                  display: raw,
                  position: stop.position,
                ));
        entry.lines.add(group.lineNumber);
      }
    }
    // 2e passe : pour chaque arrêt unique, ajouter les lignes dont l'un
    // des stops est à ≤ 80m (cluster physique). Exécution O(stops × lignes
    // × stops_par_ligne) MAIS exécutée une seule fois au chargement.
    for (final entry in byName.values) {
      for (final group in groups) {
        if (entry.lines.contains(group.lineNumber)) continue;
        outer:
        for (final stop in [
          ...?group.aller?.stops,
          ...?group.retour?.stops
        ]) {
          if (_haversineKm(entry.position, stop.position) * 1000 <= 80) {
            entry.lines.add(group.lineNumber);
            break outer;
          }
        }
      }
    }
    _searchIndex = byName.values
        .map((b) => PublicSearchableStop(
              name: b.display,
              normalized: b.norm,
              position: b.position,
              lines: b.lines.toList()..sort(_compareLineNumber),
            ))
        .toList(growable: false);
  }

  static int _compareLineNumber(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  }

  /// Recherche d'arrêts par substring sur le nom normalisé.
  /// Limit hard à 8 résultats pour éviter de saturer l'autocomplete.
  List<PublicSearchableStop> searchStops(String query, {int limit = 8}) {
    final q = _normalizeName(query.trim());
    if (q.isEmpty) return const [];
    final out = <PublicSearchableStop>[];
    for (final s in _searchIndex) {
      if (s.normalized.contains(q)) {
        out.add(s);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  void _computeAllSchematics() {
    for (final group in _linesCache.values) {
      _schematicCache[group.lineNumber] = _computeSchematic(group);
    }
  }

  /// Détecte la topologie d'une ligne (linear / trunk-loop / loop-only /
  /// complex) à partir des stops aller et retour.
  ///
  /// Algorithme :
  /// 1. Pairing greedy first-fit aller→retour : pour chaque aller[i], on
  ///    cherche le 1er retour[j] non encore apparié qui matche
  ///    (`_stopsLikelySame` : même nom normalisé OU distance ≤ 80m).
  /// 2. Si ratio commun ≥ 0.80 → linear (= aller suffit).
  /// 3. Si ratio = 0 → loop-only.
  /// 4. Si pattern de aller_common = T...TF...F (1 transition T→F au début)
  ///    → trunk-loop avec trunk au début + boucle à la fin.
  /// 5. Si pattern de aller_common = F...FT...T (1 transition F→T au début)
  ///    → trunk-loop normalisé (on fait porter le trunk au début dans le
  ///    schéma : trunk = stops T, aller loop = stops F au début).
  /// 6. Si pattern T...TF...FT...T (2 transitions, F au milieu)
  ///    → trunk-loop avec trunk avant + après.
  /// 7. Sinon (multi-loops) → complex (fallback rendu legacy).
  static LineSchematic _computeSchematic(TransportLineGroup group) {
    final aller = group.aller?.stops ?? const <TransportStop>[];
    final retour = group.retour?.stops ?? const <TransportStop>[];

    BranchStop wrap(TransportStop s) =>
        BranchStop(name: s.name, position: s.position);

    if (aller.isEmpty && retour.isEmpty) return LineSchematic.empty();

    if (aller.isEmpty) {
      return LineSchematic.linear(retour.map(wrap).toList());
    }
    if (retour.isEmpty) {
      return LineSchematic.linear(aller.map(wrap).toList());
    }

    // Greedy first-fit pairing aller → retour.
    final allerCommon = List<bool>.filled(aller.length, false);
    final retourUsed = List<bool>.filled(retour.length, false);
    for (var i = 0; i < aller.length; i++) {
      for (var j = 0; j < retour.length; j++) {
        if (retourUsed[j]) continue;
        if (_stopsLikelySame(aller[i], retour[j])) {
          allerCommon[i] = true;
          retourUsed[j] = true;
          break;
        }
      }
    }

    final maxLen = aller.length > retour.length ? aller.length : retour.length;
    final commonCount = allerCommon.where((c) => c).length;
    final ratio = commonCount / maxLen;

    if (ratio >= 0.80) {
      return LineSchematic.linear(aller.map(wrap).toList());
    }

    if (commonCount == 0) {
      return LineSchematic.loopOnly(
        allerLoopStops: aller.map(wrap).toList(),
        retourLoopStops: retour.map(wrap).toList(),
      );
    }

    // Compte les transitions dans aller_common.
    var transitions = 0;
    for (var i = 1; i < allerCommon.length; i++) {
      if (allerCommon[i] != allerCommon[i - 1]) transitions++;
    }

    // Helper : extrait les retour-only en ordre naturel du retour.
    List<BranchStop> retourLoop() {
      final out = <BranchStop>[];
      for (var j = 0; j < retour.length; j++) {
        if (!retourUsed[j]) out.add(wrap(retour[j]));
      }
      return out;
    }

    // Cas 1 : trunk-then-loop (T...TF...F)
    if (transitions == 1 && allerCommon.first) {
      final firstFalse = allerCommon.indexOf(false);
      final trunk = <BranchStop>[];
      for (var i = 0; i < firstFalse; i++) {
        trunk.add(wrap(aller[i]));
      }
      final allerLoop = <BranchStop>[];
      for (var i = firstFalse; i < aller.length; i++) {
        allerLoop.add(wrap(aller[i]));
      }
      return LineSchematic.trunkLoop(
        trunkBeforeLoop: trunk,
        trunkAfterLoop: const [],
        allerLoopStops: allerLoop,
        retourLoopStops: retourLoop(),
      );
    }

    // Cas 2 : loop-then-trunk (F...FT...T) — on normalise pour mettre le
    // trunk en haut du schéma. Le sens "naturel" de l'aller commence dans
    // la boucle et finit sur le trunk ; visuellement on peut représenter
    // le trunk en haut et la boucle en bas indistinctement.
    if (transitions == 1 && !allerCommon.first) {
      final firstTrue = allerCommon.indexOf(true);
      final allerLoop = <BranchStop>[];
      for (var i = 0; i < firstTrue; i++) {
        allerLoop.add(wrap(aller[i]));
      }
      final trunk = <BranchStop>[];
      for (var i = firstTrue; i < aller.length; i++) {
        trunk.add(wrap(aller[i]));
      }
      return LineSchematic.trunkLoop(
        trunkBeforeLoop: trunk,
        trunkAfterLoop: const [],
        allerLoopStops: allerLoop,
        retourLoopStops: retourLoop(),
      );
    }

    // Cas 3 : trunk-loop-trunk (T...TF...FT...T) — 2 transitions.
    if (transitions == 2 && allerCommon.first && allerCommon.last) {
      final firstFalse = allerCommon.indexOf(false);
      var lastFalse = -1;
      for (var i = allerCommon.length - 1; i >= 0; i--) {
        if (!allerCommon[i]) {
          lastFalse = i;
          break;
        }
      }
      final trunkBefore = <BranchStop>[];
      for (var i = 0; i < firstFalse; i++) {
        trunkBefore.add(wrap(aller[i]));
      }
      final allerLoop = <BranchStop>[];
      for (var i = firstFalse; i <= lastFalse; i++) {
        allerLoop.add(wrap(aller[i]));
      }
      final trunkAfter = <BranchStop>[];
      for (var i = lastFalse + 1; i < aller.length; i++) {
        trunkAfter.add(wrap(aller[i]));
      }
      return LineSchematic.trunkLoop(
        trunkBeforeLoop: trunkBefore,
        trunkAfterLoop: trunkAfter,
        allerLoopStops: allerLoop,
        retourLoopStops: retourLoop(),
      );
    }

    // Topologie non gérée V1 : multi-loops, alternances complexes → fallback.
    return LineSchematic.complex(
      fullAller: aller.map(wrap).toList(),
      fullRetour: retour.map(wrap).toList(),
    );
  }

  /// Renvoie le découpage de la ligne en branches pour le rendu type "plan
  /// tramway" dans la sidebar. Linéaire = aller ≈ retour inversé →
  /// 1 branche unique. Circulaire = aller et retour empruntent des routes
  /// différentes (boucle, fourche) → 2 branches explicites.
  ///
  /// Voir [_computeBranches] pour l'algorithme de détection (ratio de
  /// match aller[i] vs retour[len-1-i] sur nom + proximité).
  LineBranches lineBranchesFor(String lineNumber) {
    return _branchesCache[lineNumber] ?? LineBranches.empty();
  }

  void _computeAllBranches() {
    for (final group in _linesCache.values) {
      _branchesCache[group.lineNumber] = _computeBranches(group);
    }
  }

  static LineBranches _computeBranches(TransportLineGroup group) {
    final aller = group.aller?.stops ?? const <TransportStop>[];
    final retour = group.retour?.stops ?? const <TransportStop>[];

    BranchStop wrap(TransportStop s) =>
        BranchStop(name: s.name, position: s.position);

    if (aller.isEmpty && retour.isEmpty) return LineBranches.empty();

    if (aller.isEmpty) {
      return LineBranches.linear(retour.map(wrap).toList());
    }
    if (retour.isEmpty) {
      return LineBranches.linear(aller.map(wrap).toList());
    }

    // Détection : aller ≈ retour inversé ?
    final retourReversed = retour.reversed.toList();
    final maxLen = aller.length > retour.length ? aller.length : retour.length;
    final minLen = aller.length < retour.length ? aller.length : retour.length;
    var matches = 0;
    for (var i = 0; i < minLen; i++) {
      if (_stopsLikelySame(aller[i], retourReversed[i])) matches++;
    }
    final ratio = matches / maxLen;

    if (ratio >= 0.80) {
      // Linéaire : on prend l'aller comme représentation canonique (ordre
      // origine → terminus). Le retour est juste le sens inverse.
      return LineBranches.linear(aller.map(wrap).toList());
    }

    // Circulaire : 2 branches distinctes.
    return LineBranches.split(
      allerBranch: aller.map(wrap).toList(),
      retourBranch: retour.map(wrap).toList(),
    );
  }

  static bool _stopsLikelySame(TransportStop a, TransportStop b) {
    final na = _normalizeName(a.name);
    final nb = _normalizeName(b.name);
    if (na.isNotEmpty && nb.isNotEmpty && na == nb) return true;
    return _haversineKm(a.position, b.position) * 1000 <= 80.0;
  }

  static String _normalizeName(String name) {
    var s = name.trim().toLowerCase();
    if (s.isEmpty) return s;
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final buf = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      buf.write(accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Construit (lazy) le TransportGraph multimodal pour le calculateur
  /// d'itinéraires (Phase 2). Réutilise la classe [TransportGraph] existante.
  TransportGraph getGraph() {
    if (_graph != null) return _graph!;
    final g = TransportGraph();
    g.buildFromLines(allLines);
    return _graph = g;
  }

  /// Tri "naturel" : 015, 17, 105, 109, ... (numérique avant lex).
  static int _compareLine(LineMetadata a, LineMetadata b) {
    final na = int.tryParse(a.lineNumber);
    final nb = int.tryParse(b.lineNumber);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.lineNumber.compareTo(b.lineNumber);
  }
}

/// Stop déjà vu lors du dédupage par ligne (interne à
/// [PublicTransportService.uniqueStopNamesFor]).
class _SeenStop {
  final String nameNorm;
  final LatLng position;
  const _SeenStop(this.nameNorm, this.position);
}

/// Arrêt indexé pour la recherche autocomplete : nom d'affichage,
/// nom normalisé pour matching, position canonique, et set des lignes
/// qui le desservent (par identité de nom OU proximité ≤ 80m).
class PublicSearchableStop {
  final String name;
  final String normalized;
  final LatLng position;
  final List<String> lines;

  const PublicSearchableStop({
    required this.name,
    required this.normalized,
    required this.position,
    required this.lines,
  });
}

/// Builder mutable pour [PublicSearchableStop] pendant la construction
/// de l'index. Utilisé en interne par `_buildSearchIndex`.
class _SearchableBuilder {
  final String norm;
  final String display;
  final LatLng position;
  final Set<String> lines = <String>{};
  _SearchableBuilder(
      {required this.norm, required this.display, required this.position});
}

/// Topologie d'une ligne — guide le rendu du schéma dans la sidebar.
enum LineTopology { empty, linear, trunkLoop, loopOnly, complex }

/// Découpage topologique d'une ligne pour le rendu type "plan tramway"
/// dans la sidebar (image de référence : Nice Tramway L2).
///
/// - [linear] : aller ≈ retour inversé, les arrêts sont rendus en 1 colonne.
/// - [trunkLoop] : trunk commun (1 colonne) + boucle (rectangle 2 colonnes).
///   Le trunk peut être avant la boucle, après, ou les 2 (trunk-loop-trunk).
/// - [loopOnly] : que la boucle, sans trunk commun.
/// - [complex] : topologie multi-loops non gérée V1 → fallback rendu legacy
///   "2 sections empilées".
class LineSchematic {
  final LineTopology topology;
  final List<BranchStop> linearStops;
  final List<BranchStop> trunkBeforeLoop;
  final List<BranchStop> trunkAfterLoop;
  final List<BranchStop> allerLoopStops;
  final List<BranchStop> retourLoopStops;
  final List<BranchStop> fullAller;
  final List<BranchStop> fullRetour;

  const LineSchematic._({
    required this.topology,
    this.linearStops = const [],
    this.trunkBeforeLoop = const [],
    this.trunkAfterLoop = const [],
    this.allerLoopStops = const [],
    this.retourLoopStops = const [],
    this.fullAller = const [],
    this.fullRetour = const [],
  });

  factory LineSchematic.empty() =>
      const LineSchematic._(topology: LineTopology.empty);

  factory LineSchematic.linear(List<BranchStop> stops) => LineSchematic._(
        topology: LineTopology.linear,
        linearStops: stops,
      );

  factory LineSchematic.trunkLoop({
    required List<BranchStop> trunkBeforeLoop,
    required List<BranchStop> trunkAfterLoop,
    required List<BranchStop> allerLoopStops,
    required List<BranchStop> retourLoopStops,
  }) =>
      LineSchematic._(
        topology: LineTopology.trunkLoop,
        trunkBeforeLoop: trunkBeforeLoop,
        trunkAfterLoop: trunkAfterLoop,
        allerLoopStops: allerLoopStops,
        retourLoopStops: retourLoopStops,
      );

  factory LineSchematic.loopOnly({
    required List<BranchStop> allerLoopStops,
    required List<BranchStop> retourLoopStops,
  }) =>
      LineSchematic._(
        topology: LineTopology.loopOnly,
        allerLoopStops: allerLoopStops,
        retourLoopStops: retourLoopStops,
      );

  factory LineSchematic.complex({
    required List<BranchStop> fullAller,
    required List<BranchStop> fullRetour,
  }) =>
      LineSchematic._(
        topology: LineTopology.complex,
        fullAller: fullAller,
        fullRetour: fullRetour,
      );
}

/// Représentation d'un arrêt dans une branche (subset minimaliste de
/// [TransportStop]) pour le rendu sidebar type "plan tramway".
class BranchStop {
  final String name;
  final LatLng position;
  const BranchStop({required this.name, required this.position});
}

/// Découpage d'une ligne en branches pour le rendu type plan tramway.
///
/// - [isLinear] true quand aller ≈ retour inversé : on n'affiche qu'1 seule
///   colonne d'arrêts (= [mainBranch]). [allerBranch] / [retourBranch] sont
///   alors vides.
/// - [isLinear] false quand la ligne est circulaire / branchée : on rend 2
///   sections explicites avec [allerBranch] et [retourBranch] dans leur
///   propre ordre.
class LineBranches {
  final bool isLinear;
  final List<BranchStop> mainBranch;
  final List<BranchStop> allerBranch;
  final List<BranchStop> retourBranch;

  const LineBranches._({
    required this.isLinear,
    required this.mainBranch,
    required this.allerBranch,
    required this.retourBranch,
  });

  factory LineBranches.empty() => const LineBranches._(
        isLinear: true,
        mainBranch: [],
        allerBranch: [],
        retourBranch: [],
      );

  factory LineBranches.linear(List<BranchStop> stops) => LineBranches._(
        isLinear: true,
        mainBranch: stops,
        allerBranch: const [],
        retourBranch: const [],
      );

  factory LineBranches.split({
    required List<BranchStop> allerBranch,
    required List<BranchStop> retourBranch,
  }) =>
      LineBranches._(
        isLinear: false,
        mainBranch: const [],
        allerBranch: allerBranch,
        retourBranch: retourBranch,
      );

  /// Nom du dernier arrêt de l'aller (terminus) — utilisé comme header de
  /// la branche dans la sidebar. Null si la liste est vide ou le nom vide.
  String? get allerTerminusName {
    if (allerBranch.isEmpty) return null;
    final n = allerBranch.last.name.trim();
    return n.isEmpty ? null : n;
  }

  String? get retourTerminusName {
    if (retourBranch.isEmpty) return null;
    final n = retourBranch.last.name.trim();
    return n.isEmpty ? null : n;
  }
}
