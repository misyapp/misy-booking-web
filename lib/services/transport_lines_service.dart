import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';

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
}
