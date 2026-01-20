import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Types de transport disponibles
enum TransportType {
  bus,
  urbanTrain,
  telepherique,
}

/// Extension pour obtenir des informations sur le type de transport
extension TransportTypeExtension on TransportType {
  String get displayName {
    switch (this) {
      case TransportType.bus:
        return 'Bus / Taxi-be';
      case TransportType.urbanTrain:
        return 'Train TCE';
      case TransportType.telepherique:
        return 'Téléphérique';
    }
  }

  int get colorValue {
    switch (this) {
      case TransportType.bus:
        return 0xFF2196F3; // Bleu (couleur par défaut, utilisez getLineColor pour les bus)
      case TransportType.urbanTrain:
        return 0xFF4CAF50; // Vert
      case TransportType.telepherique:
        return 0xFFFF9800; // Orange
    }
  }
}

/// Couleurs spécifiques pour chaque ligne de bus
class TransportLineColors {
  static const Map<String, int> _busColors = {
    '015': 0xFF2196F3, // Bleu
    '017': 0xFF9C27B0, // Violet
    '17': 0xFF9C27B0,  // Violet (alias)
    '129': 0xFFE91E63, // Rose/Magenta
  };

  /// Obtient la couleur pour une ligne donnée
  static int getLineColor(String lineNumber, TransportType type) {
    // Pour le train et téléphérique, utiliser la couleur du type
    if (type == TransportType.urbanTrain) return 0xFF4CAF50;
    if (type == TransportType.telepherique) return 0xFFFF9800;

    // Pour les bus, utiliser la couleur spécifique ou la couleur par défaut
    return _busColors[lineNumber] ?? 0xFF2196F3;
  }
}

/// Représente un arrêt sur une ligne de transport
class TransportStop {
  final String name;
  final String stopId;
  final LatLng position;

  const TransportStop({
    required this.name,
    required this.stopId,
    required this.position,
  });

  factory TransportStop.fromGeoJson(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    // stop_id peut être un int ou une string selon les fichiers
    final rawStopId = properties['stop_id'];
    final stopId = rawStopId?.toString() ?? '0';

    return TransportStop(
      name: properties['name'] ?? 'Arrêt',
      stopId: stopId,
      position: LatLng(
        (coordinates[1] as num).toDouble(),
        (coordinates[0] as num).toDouble(),
      ),
    );
  }
}

/// Représente une ligne de transport avec son tracé et ses arrêts
class TransportLine {
  final String lineNumber;
  final String direction;
  final TransportType transportType;
  final List<LatLng> coordinates;
  final List<TransportStop> stops;
  final int numStops;
  final bool isRetour;

  const TransportLine({
    required this.lineNumber,
    required this.direction,
    required this.transportType,
    required this.coordinates,
    required this.stops,
    required this.numStops,
    required this.isRetour,
  });

  factory TransportLine.fromGeoJson(
    Map<String, dynamic> geojson,
    String filename,
  ) {
    final properties = geojson['properties'] as Map<String, dynamic>;
    final features = geojson['features'] as List<dynamic>;

    // Déterminer le type de transport et le numéro de ligne
    final lineNumber = properties['line'] as String;
    final isRetour = filename.contains('retour');
    final transportType = _getTransportType(lineNumber);

    // Extraire les coordonnées du LineString
    List<LatLng> coordinates = [];
    List<TransportStop> stops = [];

    for (final feature in features) {
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final geometryType = geometry['type'] as String;

      if (geometryType == 'LineString') {
        final coords = geometry['coordinates'] as List<dynamic>;
        coordinates = coords.map((coord) {
          final c = coord as List<dynamic>;
          return LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          );
        }).toList();
      } else if (geometryType == 'Point') {
        final featureProperties = feature['properties'] as Map<String, dynamic>?;
        if (featureProperties != null && featureProperties['type'] == 'stop') {
          stops.add(TransportStop.fromGeoJson(feature as Map<String, dynamic>));
        }
      }
    }

    return TransportLine(
      lineNumber: lineNumber,
      direction: properties['direction'] ?? '',
      transportType: transportType,
      coordinates: coordinates,
      stops: stops,
      numStops: properties['num_stops'] ?? stops.length,
      isRetour: isRetour,
    );
  }

  static TransportType _getTransportType(String lineNumber) {
    if (lineNumber.toUpperCase().contains('TRAIN') ||
        lineNumber.toUpperCase().contains('TCE')) {
      return TransportType.urbanTrain;
    } else if (lineNumber.toUpperCase().contains('TELEPHERIQUE')) {
      return TransportType.telepherique;
    }
    return TransportType.bus;
  }

  /// Obtient le nom d'affichage de la ligne
  String get displayName {
    switch (transportType) {
      case TransportType.urbanTrain:
        return 'Train TCE';
      case TransportType.telepherique:
        return 'Téléphérique Orange';
      case TransportType.bus:
        return 'Ligne $lineNumber';
    }
  }

  /// Obtient la description de la direction
  String get directionLabel => isRetour ? 'Retour' : 'Aller';
}

/// Groupe une ligne avec ses directions aller et retour
class TransportLineGroup {
  final String lineNumber;
  final String displayName;
  final TransportType transportType;
  final TransportLine? aller;
  final TransportLine? retour;

  const TransportLineGroup({
    required this.lineNumber,
    required this.displayName,
    required this.transportType,
    this.aller,
    this.retour,
  });

  /// Obtient toutes les lignes disponibles (aller et/ou retour)
  List<TransportLine> get lines {
    final result = <TransportLine>[];
    if (aller != null) result.add(aller!);
    if (retour != null) result.add(retour!);
    return result;
  }

  /// Crée une copie avec des valeurs mises à jour
  TransportLineGroup copyWith({
    TransportLine? aller,
    TransportLine? retour,
  }) {
    return TransportLineGroup(
      lineNumber: lineNumber,
      displayName: displayName,
      transportType: transportType,
      aller: aller ?? this.aller,
      retour: retour ?? this.retour,
    );
  }
}
