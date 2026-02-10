import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';

/// Métadonnées d'une direction (aller ou retour) depuis le manifest
class RouteMetadata {
  final String direction;
  final int numStops;
  final String? assetPath;
  final String? remoteUrl;

  const RouteMetadata({
    required this.direction,
    required this.numStops,
    this.assetPath,
    this.remoteUrl,
  });

  factory RouteMetadata.fromJson(Map<String, dynamic> json) {
    return RouteMetadata(
      direction: json['direction'] ?? '',
      numStops: json['num_stops'] ?? 0,
      assetPath: json['asset_path'],
      remoteUrl: json['remote_url'],
    );
  }
}

/// Métadonnées d'une ligne de transport depuis le manifest
class LineMetadata {
  final String lineNumber;
  final String displayName;
  final String transportType;
  final String colorHex;
  final bool isBundled;
  final RouteMetadata? aller;
  final RouteMetadata? retour;

  const LineMetadata({
    required this.lineNumber,
    required this.displayName,
    required this.transportType,
    required this.colorHex,
    required this.isBundled,
    this.aller,
    this.retour,
  });

  factory LineMetadata.fromJson(Map<String, dynamic> json) {
    return LineMetadata(
      lineNumber: json['line_number'],
      displayName: json['display_name'],
      transportType: json['transport_type'],
      colorHex: json['color'],
      isBundled: json['is_bundled'] ?? false,
      aller: json['aller'] != null
          ? RouteMetadata.fromJson(json['aller'])
          : null,
      retour: json['retour'] != null
          ? RouteMetadata.fromJson(json['retour'])
          : null,
    );
  }

  int get colorValue {
    try {
      return int.parse(colorHex.replaceFirst('0x', ''), radix: 16);
    } catch (_) {
      return 0xFF2196F3; // Bleu par défaut
    }
  }
}

/// Service pour charger et gérer les lignes de transport depuis le manifest et GeoJSON
class TransportLinesService {
  static TransportLinesService? _instance;
  static TransportLinesService get instance {
    _instance ??= TransportLinesService._();
    return _instance!;
  }

  TransportLinesService._();

  /// Cache des lignes groupées (toutes les lignes chargées)
  final Map<String, TransportLineGroup> _linesCache = {};

  /// Manifest des lignes disponibles
  Map<String, LineMetadata>? _manifest;

  /// Graphe du réseau pour le calcul d'itinéraire
  TransportGraph? _transportGraph;

  /// Durée cache remote (7 jours)
  static const int _cacheDurationMs = 7 * 24 * 60 * 60 * 1000;

  /// Charge le manifest depuis les assets
  Future<void> _loadManifest() async {
    if (_manifest != null) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/transport_lines/manifest.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final lines = data['lines'] as List<dynamic>;

      _manifest = {};
      for (final lineData in lines) {
        final metadata = LineMetadata.fromJson(lineData as Map<String, dynamic>);
        _manifest![metadata.lineNumber] = metadata;
      }

      myCustomPrintStatement(
        'Manifest chargé: ${_manifest!.length} lignes '
        '(${_manifest!.values.where((m) => m.isBundled).length} embarquées)',
      );
    } catch (e) {
      myCustomPrintStatement('Erreur chargement manifest: $e');
      _manifest = {};
    }
  }

  /// Charge toutes les lignes de transport embarquées (core)
  /// Les lignes remote ne sont pas chargées ici pour performance
  Future<List<TransportLineGroup>> loadAllLines() async {
    // Retourner le cache complet si déjà rempli
    if (_linesCache.isNotEmpty) {
      myCustomPrintStatement('Lignes de transport chargées depuis le cache');
      return _linesCache.values.toList();
    }

    await _loadManifest();
    if (_manifest == null || _manifest!.isEmpty) return [];

    myCustomPrintStatement('Chargement des lignes de transport...');

    // Charger toutes les lignes bundled (core)
    for (final metadata in _manifest!.values.where((m) => m.isBundled)) {
      try {
        final lineGroup = await _loadLineFromMetadata(metadata);
        if (lineGroup != null) {
          _linesCache[metadata.lineNumber] = lineGroup;
        }
      } catch (e) {
        myCustomPrintStatement(
          'Erreur chargement ligne ${metadata.lineNumber}: $e',
        );
      }
    }

    myCustomPrintStatement('${_linesCache.length} lignes core chargées');
    return _linesCache.values.toList();
  }

  /// Charge une ligne spécifique (avec lazy loading pour les remote)
  Future<TransportLineGroup?> loadLine(String lineNumber) async {
    // Vérifier le cache
    if (_linesCache.containsKey(lineNumber)) {
      return _linesCache[lineNumber];
    }

    await _loadManifest();
    final metadata = _manifest?[lineNumber];
    if (metadata == null) return null;

    final lineGroup = await _loadLineFromMetadata(metadata);
    if (lineGroup != null) {
      _linesCache[lineNumber] = lineGroup;
    }

    return lineGroup;
  }

  /// Retourne la liste des métadonnées de toutes les lignes disponibles
  /// (sans charger les GeoJSON, juste les infos du manifest)
  Future<List<LineMetadata>> getAllLineMetadata() async {
    await _loadManifest();
    return _manifest?.values.toList() ?? [];
  }

  /// Charge une ligne depuis ses métadonnées
  Future<TransportLineGroup?> _loadLineFromMetadata(
    LineMetadata metadata,
  ) async {
    try {
      TransportLine? allerLine;
      TransportLine? retourLine;

      if (metadata.aller != null) {
        allerLine = await _loadSingleRoute(
          metadata.lineNumber,
          metadata.aller!,
          metadata.isBundled,
          false,
        );
      }

      if (metadata.retour != null) {
        retourLine = await _loadSingleRoute(
          metadata.lineNumber,
          metadata.retour!,
          metadata.isBundled,
          true,
        );
      }

      if (allerLine == null && retourLine == null) return null;

      return TransportLineGroup(
        lineNumber: metadata.lineNumber,
        displayName: metadata.displayName,
        transportType: allerLine?.transportType ??
            retourLine?.transportType ??
            TransportType.bus,
        aller: allerLine,
        retour: retourLine,
      );
    } catch (e) {
      myCustomPrintStatement(
        'Erreur _loadLineFromMetadata ${metadata.lineNumber}: $e',
      );
      return null;
    }
  }

  /// Charge un tracé unique (aller OU retour)
  Future<TransportLine?> _loadSingleRoute(
    String lineNumber,
    RouteMetadata route,
    bool isBundled,
    bool isRetour,
  ) async {
    try {
      String geojsonContent;
      final direction = isRetour ? 'retour' : 'aller';
      final filename = '${lineNumber}_$direction.geojson';

      if (isBundled && route.assetPath != null) {
        // Charger depuis assets locaux
        geojsonContent = await rootBundle.loadString(route.assetPath!);
      } else if (route.remoteUrl != null) {
        // Charger depuis Firebase Storage (avec cache local)
        geojsonContent = await _fetchRemoteGeoJson(route.remoteUrl!);
      } else {
        return null;
      }

      final geojson = json.decode(geojsonContent) as Map<String, dynamic>;
      return TransportLine.fromGeoJson(geojson, filename);
    } catch (e) {
      myCustomPrintStatement(
        'Erreur _loadSingleRoute $lineNumber: $e',
      );
      return null;
    }
  }

  /// Télécharge un GeoJSON remote avec cache local (SharedPreferences)
  Future<String> _fetchRemoteGeoJson(String url) async {
    // Vérifier le cache local
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'geojson_${url.hashCode}';
    final cached = prefs.getString(cacheKey);

    if (cached != null) {
      final cacheTime = prefs.getInt('${cacheKey}_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - cacheTime < _cacheDurationMs) {
        myCustomPrintStatement('GeoJSON depuis cache: $url');
        return cached;
      }
    }

    // Télécharger depuis remote
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      // Sauvegarder en cache local
      await prefs.setString(cacheKey, response.body);
      await prefs.setInt(
        '${cacheKey}_time',
        DateTime.now().millisecondsSinceEpoch,
      );

      myCustomPrintStatement('GeoJSON téléchargé: $url');
      return response.body;
    }

    throw Exception('Échec téléchargement GeoJSON: ${response.statusCode}');
  }

  /// Génère une clé unique pour grouper les lignes
  String _getGroupKey(String lineNumber) {
    final normalized = lineNumber.toUpperCase().trim();
    if (normalized.contains('TRAIN') || normalized.contains('TCE')) {
      return 'TRAIN_TCE';
    }
    if (normalized.contains('TELEPHERIQUE')) {
      return 'TELEPHERIQUE_ORANGE';
    }
    return normalized;
  }

  /// Filtre les lignes par type de transport
  Future<List<TransportLineGroup>> getLinesByType(TransportType type) async {
    final allLines = await loadAllLines();
    return allLines.where((group) => group.transportType == type).toList();
  }

  /// Récupère un groupe de ligne par son numéro
  Future<TransportLineGroup?> getLineGroup(String lineNumber) async {
    // Essayer d'abord le cache puis charger
    if (_linesCache.containsKey(lineNumber)) {
      return _linesCache[lineNumber];
    }

    // Essayer le lazy loading
    final loaded = await loadLine(lineNumber);
    if (loaded != null) return loaded;

    // Fallback: chercher dans toutes les lignes déjà chargées
    final allLines = await loadAllLines();
    try {
      return allLines.firstWhere(
        (group) =>
            _getGroupKey(group.lineNumber) == _getGroupKey(lineNumber),
      );
    } catch (_) {
      return null;
    }
  }

  /// Vide le cache pour forcer un rechargement
  void clearCache() {
    _linesCache.clear();
    _manifest = null;
    _transportGraph = null;
    myCustomPrintStatement('Cache des lignes de transport vidé');
  }

  /// Récupère la liste des types de transport disponibles
  Future<List<TransportType>> getAvailableTypes() async {
    final allLines = await loadAllLines();
    final types = <TransportType>{};
    for (final group in allLines) {
      types.add(group.transportType);
    }
    return types.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  /// Initialise le graphe du réseau de transport
  Future<void> initializeGraph() async {
    if (_transportGraph != null) return;

    final lines = await loadAllLines();
    _transportGraph = TransportGraph();
    _transportGraph!.buildFromLines(lines);

    myCustomPrintStatement(
      'Graphe initialisé: ${_transportGraph!.nodes.length} arrêts, '
      '${_transportGraph!.edges.length} connexions',
    );
  }

  /// Calcule un itinéraire entre deux positions
  Future<TransportRoute?> findRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    await initializeGraph();

    if (_transportGraph == null) return null;

    final route = _transportGraph!.findRoute(origin, destination);

    if (route != null) {
      myCustomPrintStatement(
        'Itinéraire trouvé: ${route.steps.length} étapes, '
        '${route.totalDurationMinutes} min, '
        '${route.numberOfTransfers} correspondance(s)',
      );
    } else {
      myCustomPrintStatement('Aucun itinéraire trouvé');
    }

    return route;
  }

  /// Calcule plusieurs itinéraires entre deux positions
  Future<List<TransportRoute>> findMultipleRoutes(
    LatLng origin,
    LatLng destination, {
    int maxRoutes = 5,
  }) async {
    await initializeGraph();

    if (_transportGraph == null) return [];

    final routes = _transportGraph!.findMultipleRoutes(
      origin,
      destination,
      maxRoutes: maxRoutes,
    );

    myCustomPrintStatement(
      '${routes.length} itinéraires trouvés entre $origin et $destination',
    );

    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      myCustomPrintStatement(
        '  Option ${i + 1}: ${route.totalDurationMinutes} min, '
        '${route.numberOfTransfers} correspondance(s)',
      );
    }

    return routes;
  }

  /// Trouve l'arrêt le plus proche d'une position
  Future<TransportNode?> findNearestStop(LatLng position) async {
    await initializeGraph();
    return _transportGraph?.findNearestStop(position);
  }

  /// Obtient tous les arrêts du réseau
  Future<List<TransportNode>> getAllStops() async {
    await initializeGraph();
    return _transportGraph?.nodes.values.toList() ?? [];
  }
}
