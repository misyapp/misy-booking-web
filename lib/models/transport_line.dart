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

/// Horaires et informations de service pour les transports
class TransportScheduleInfo {
  /// Horaires du Train Urbain TCE (Soarano - Ambohimanambola)
  static const trainSchedule = TrainSchedule(
    departures: [
      TrainDeparture(time: '05:00', from: 'Soarano', to: 'Ambohimanambola'),
      TrainDeparture(time: '06:00', from: 'Ambohimanambola', to: 'Soarano'),
      TrainDeparture(time: '17:30', from: 'Soarano', to: 'Ambohimanambola'),
    ],
    operatingDays: 'Lundi - Samedi',
    duration: '45-65 min',
    fare: '3 000 Ar',
    frequency: '2 allers-retours/jour',
  );

  /// Horaires du Téléphérique Orange (Anosy - Ambatobe)
  static const telepheriqueSchedule = TelepheriqueSchedule(
    morningStart: '07:00',
    morningEnd: '09:00',
    afternoonStart: '16:00',
    afternoonEnd: '18:00',
    operatingDays: 'Tous les jours',
    duration: '< 30 min',
    fare: '3 000 Ar',
    frequency: 'Continu aux heures de pointe',
  );

  /// Vérifie si un type de transport est disponible à une heure donnée
  static bool isAvailableAt(TransportType type, DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    final weekday = time.weekday; // 1 = Monday, 7 = Sunday

    if (type == TransportType.urbanTrain) {
      // Train: pas le dimanche
      if (weekday == 7) return false;

      // Vérifier si l'heure est proche d'un départ (±45 min pour avoir le temps)
      final departureTimes = [5 * 60, 6 * 60, 17 * 60 + 30]; // 05:00, 06:00, 17:30
      for (final dep in departureTimes) {
        // On peut prendre le train si on est entre 30min avant et 45min après le départ
        if (minutes >= dep - 30 && minutes <= dep + 45) return true;
      }
      return false;
    } else if (type == TransportType.telepherique) {
      // Téléphérique: heures de pointe uniquement
      // Matin: 07:00 - 09:00
      // Après-midi: 16:00 - 18:00
      return (minutes >= 7 * 60 && minutes < 9 * 60) ||
             (minutes >= 16 * 60 && minutes < 18 * 60);
    }

    // Bus: toujours disponible (approximation - en réalité dépend des lignes)
    return true;
  }

  /// Obtient le prochain créneau disponible pour un type de transport
  static DateTime? getNextAvailableTime(TransportType type, DateTime from) {
    final minutes = from.hour * 60 + from.minute;
    var checkDate = DateTime(from.year, from.month, from.day);

    if (type == TransportType.urbanTrain) {
      // Chercher le prochain départ de train
      final departureTimes = [5 * 60, 6 * 60, 17 * 60 + 30];

      // D'abord vérifier aujourd'hui (si pas dimanche)
      if (checkDate.weekday != 7) {
        for (final dep in departureTimes) {
          if (dep > minutes) {
            return DateTime(checkDate.year, checkDate.month, checkDate.day, dep ~/ 60, dep % 60);
          }
        }
      }

      // Sinon demain (ou lundi si dimanche)
      checkDate = checkDate.add(const Duration(days: 1));
      while (checkDate.weekday == 7) {
        checkDate = checkDate.add(const Duration(days: 1));
      }
      return DateTime(checkDate.year, checkDate.month, checkDate.day, 5, 0);
    } else if (type == TransportType.telepherique) {
      // Chercher le prochain créneau téléphérique
      if (minutes < 7 * 60) {
        return DateTime(checkDate.year, checkDate.month, checkDate.day, 7, 0);
      } else if (minutes < 9 * 60) {
        return from; // Déjà dans le créneau matin
      } else if (minutes < 16 * 60) {
        return DateTime(checkDate.year, checkDate.month, checkDate.day, 16, 0);
      } else if (minutes < 18 * 60) {
        return from; // Déjà dans le créneau après-midi
      } else {
        // Demain matin
        checkDate = checkDate.add(const Duration(days: 1));
        return DateTime(checkDate.year, checkDate.month, checkDate.day, 7, 0);
      }
    }

    return from; // Bus: disponible immédiatement
  }

  /// Obtient les prochains départs pour un type de transport
  static List<String> getNextDepartures(TransportType type) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    if (type == TransportType.urbanTrain) {
      // Train: départs fixes
      final departureTimes = [
        {'time': '05:00', 'minutes': 5 * 60},
        {'time': '06:00', 'minutes': 6 * 60},
        {'time': '17:30', 'minutes': 17 * 60 + 30},
      ];

      final nextDepartures = <String>[];
      for (final dep in departureTimes) {
        if ((dep['minutes'] as int) > currentMinutes) {
          nextDepartures.add(dep['time'] as String);
        }
      }
      return nextDepartures.isEmpty ? ['Demain 05:00'] : nextDepartures;
    } else if (type == TransportType.telepherique) {
      // Téléphérique: heures de pointe
      if (currentMinutes >= 7 * 60 && currentMinutes < 9 * 60) {
        return ['En service (jusqu\'à 09:00)'];
      } else if (currentMinutes >= 16 * 60 && currentMinutes < 18 * 60) {
        return ['En service (jusqu\'à 18:00)'];
      } else if (currentMinutes < 7 * 60) {
        return ['Prochain: 07:00'];
      } else if (currentMinutes < 16 * 60) {
        return ['Prochain: 16:00'];
      } else {
        return ['Demain 07:00'];
      }
    }

    return ['Fréquence variable'];
  }

  /// Vérifie si le transport est actuellement en service
  static bool isCurrentlyOperating(TransportType type) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday

    if (type == TransportType.urbanTrain) {
      // Train: pas le dimanche
      if (weekday == 7) return false;
      // Vérifier si on est proche d'un horaire de départ (±30 min)
      final departureTimes = [5 * 60, 6 * 60, 17 * 60 + 30];
      for (final dep in departureTimes) {
        if ((currentMinutes - dep).abs() <= 30) return true;
      }
      return false;
    } else if (type == TransportType.telepherique) {
      // Téléphérique: heures de pointe
      return (currentMinutes >= 7 * 60 && currentMinutes < 9 * 60) ||
             (currentMinutes >= 16 * 60 && currentMinutes < 18 * 60);
    }

    return true; // Bus: toujours considéré comme en service
  }

  /// Obtient le message de statut pour un type de transport
  static String getStatusMessage(TransportType type) {
    if (isCurrentlyOperating(type)) {
      return 'En service';
    }

    final nextDepartures = getNextDepartures(type);
    if (nextDepartures.isNotEmpty) {
      return nextDepartures.first;
    }
    return 'Hors service';
  }
}

/// Horaires du train
class TrainSchedule {
  final List<TrainDeparture> departures;
  final String operatingDays;
  final String duration;
  final String fare;
  final String frequency;

  const TrainSchedule({
    required this.departures,
    required this.operatingDays,
    required this.duration,
    required this.fare,
    required this.frequency,
  });
}

/// Départ de train
class TrainDeparture {
  final String time;
  final String from;
  final String to;

  const TrainDeparture({
    required this.time,
    required this.from,
    required this.to,
  });
}

/// Horaires du téléphérique
class TelepheriqueSchedule {
  final String morningStart;
  final String morningEnd;
  final String afternoonStart;
  final String afternoonEnd;
  final String operatingDays;
  final String duration;
  final String fare;
  final String frequency;

  const TelepheriqueSchedule({
    required this.morningStart,
    required this.morningEnd,
    required this.afternoonStart,
    required this.afternoonEnd,
    required this.operatingDays,
    required this.duration,
    required this.fare,
    required this.frequency,
  });

  String get morningSlot => '$morningStart - $morningEnd';
  String get afternoonSlot => '$afternoonStart - $afternoonEnd';
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
