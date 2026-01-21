import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';

/// Service pour charger et gérer les lignes de transport depuis les fichiers GeoJSON
class TransportLinesService {
  static TransportLinesService? _instance;
  static TransportLinesService get instance {
    _instance ??= TransportLinesService._();
    return _instance!;
  }

  TransportLinesService._();

  /// Cache des lignes groupées
  Map<String, TransportLineGroup>? _cachedLineGroups;

  /// Graphe du réseau pour le calcul d'itinéraire
  TransportGraph? _transportGraph;

  /// Liste des fichiers GeoJSON à charger
  static const List<String> _geojsonFiles = [
    '015_aller.geojson',
    '015_retour.geojson',
    '17_aller.geojson',
    '17_retour.geojson',
    '129_aller.geojson',
    '129_retour.geojson',
    'TELEPHERIQUE_Orange_aller.geojson',
    'TELEPHERIQUE_Orange_retour.geojson',
    'TRAIN_TCE_aller.geojson',
    'TRAIN_TCE_retour.geojson',
  ];

  /// Charge toutes les lignes de transport depuis les assets
  Future<List<TransportLineGroup>> loadAllLines() async {
    // Retourner le cache si disponible
    if (_cachedLineGroups != null) {
      myCustomPrintStatement('Lignes de transport chargées depuis le cache');
      return _cachedLineGroups!.values.toList();
    }

    myCustomPrintStatement('Chargement des lignes de transport depuis les assets...');

    final Map<String, TransportLineGroup> lineGroups = {};

    for (final filename in _geojsonFiles) {
      try {
        final line = await _loadGeoJsonFile(filename);
        if (line != null) {
          final groupKey = _getGroupKey(line.lineNumber);

          if (lineGroups.containsKey(groupKey)) {
            // Ajouter à un groupe existant
            final existingGroup = lineGroups[groupKey]!;
            if (line.isRetour) {
              lineGroups[groupKey] = existingGroup.copyWith(retour: line);
            } else {
              lineGroups[groupKey] = existingGroup.copyWith(aller: line);
            }
          } else {
            // Créer un nouveau groupe
            lineGroups[groupKey] = TransportLineGroup(
              lineNumber: line.lineNumber,
              displayName: line.displayName,
              transportType: line.transportType,
              aller: line.isRetour ? null : line,
              retour: line.isRetour ? line : null,
            );
          }
        }
      } catch (e) {
        myCustomPrintStatement('Erreur lors du chargement de $filename: $e');
      }
    }

    _cachedLineGroups = lineGroups;
    myCustomPrintStatement('${lineGroups.length} groupes de lignes chargés');

    return lineGroups.values.toList();
  }

  /// Charge un fichier GeoJSON spécifique
  Future<TransportLine?> _loadGeoJsonFile(String filename) async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/transport_lines/$filename',
      );
      final Map<String, dynamic> geojson = json.decode(jsonString);
      return TransportLine.fromGeoJson(geojson, filename);
    } catch (e) {
      myCustomPrintStatement('Erreur lors du parsing de $filename: $e');
      return null;
    }
  }

  /// Génère une clé unique pour grouper les lignes
  String _getGroupKey(String lineNumber) {
    // Normaliser le numéro de ligne pour le regroupement
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
    final allLines = await loadAllLines();
    try {
      return allLines.firstWhere(
        (group) => _getGroupKey(group.lineNumber) == _getGroupKey(lineNumber),
      );
    } catch (_) {
      return null;
    }
  }

  /// Vide le cache pour forcer un rechargement
  void clearCache() {
    _cachedLineGroups = null;
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
  Future<TransportRoute?> findRoute(LatLng origin, LatLng destination) async {
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
  /// Retourne une liste triée du plus rapide au moins de correspondances
  Future<List<TransportRoute>> findMultipleRoutes(LatLng origin, LatLng destination, {int maxRoutes = 5}) async {
    await initializeGraph();

    if (_transportGraph == null) return [];

    final routes = _transportGraph!.findMultipleRoutes(origin, destination, maxRoutes: maxRoutes);

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
