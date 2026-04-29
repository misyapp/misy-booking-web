import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
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
    myCustomPrintStatement(
      'PublicTransportService: ${_linesCache.length}/${lines.length} lignes chargées',
    );
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
