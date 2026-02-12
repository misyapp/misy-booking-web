import 'package:flutter/painting.dart';
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

/// Couleurs des lignes de taxi-be d'Antananarivo
///
/// Sources :
/// - Taxi-Boky (Agence des Transports Terrestres, 2013)
/// - Moovit : variantes BLEU/ROUGE/VERT des lignes
/// - OpenStreetMap : tags Manga (bleu) / Mena (rouge)
/// - voyage-madagascar.org : bandes de couleur
///
/// Convention : quand une ligne a plusieurs variantes de couleur
/// (ex: 147 Manga/Mena), on utilise la couleur dominante (Manga=bleu).
/// Les sous-variantes (A, B, C) héritent d'une nuance proche du parent.
class TransportLineColors {
  static const Map<String, int> _fixedColors = {
    // === Lignes principales (chaque couleur est UNIQUE) ===
    '009':  0xFF00897B, // Sarcelle foncé
    '015':  0xFF1565C0, // Bleu cobalt
    '017':  0xFF7B1FA2, // Violet
    '17':   0xFF7B1FA2, // Violet (alias de 017)
    '103':  0xFF2E7D32, // Vert forêt
    '104':  0xFF880E4F, // Bordeaux
    '105':  0xFFD32F2F, // Rouge (bande rouge confirmée)
    '106':  0xFFE65100, // Orange brûlé
    '107':  0xFF00838F, // Cyan foncé
    '109':  0xFF1976D2, // Bleu (variante Manga)
    '110':  0xFF6A1B9A, // Violet foncé
    '112':  0xFF558B2F, // Vert olive
    '113':  0xFFD84315, // Vermillon
    '114':  0xFF388E3C, // Vert (bande verte confirmée)
    '115':  0xFF4527A0, // Indigo foncé
    '116':  0xFFE91E63, // Rose framboise
    '117':  0xFF00695C, // Sarcelle profond
    '119':  0xFFFF8F00, // Ambre
    '120':  0xFF283593, // Bleu nuit
    '122':  0xFF6D4C41, // Brun café
    '123':  0xFF0D47A1, // Bleu marine (Manga)
    '125':  0xFFB71C1C, // Rouge foncé
    '126':  0xFF00796B, // Vert émeraude
    '128':  0xFF8E24AA, // Orchidée foncé
    '129':  0xFFC2185B, // Rose foncé
    '133':  0xFF5D4037, // Chocolat
    '134':  0xFFAD1457, // Magenta foncé
    '135':  0xFFE53935, // Rouge vif (variante ROUGE)
    '136':  0xFF0097A7, // Cyan
    '137':  0xFF827717, // Vert kaki foncé
    '138':  0xFF43A047, // Vert prairie
    '139':  0xFFF57F17, // Jaune moutarde
    '140':  0xFF546E7A, // Bleu-gris
    '141':  0xFF1E88E5, // Bleu royal (Manga)
    '142':  0xFF33691E, // Vert mousse
    '143':  0xFFEF6C00, // Orange vif
    '144':  0xFF512DA8, // Violet profond
    '146':  0xFF0277BD, // Bleu azur (Manga)
    '147':  0xFF0D47A9, // Bleu marine profond (Manga)
    '150':  0xFFD81B60, // Rose vif
    '151':  0xFF26A69A, // Turquoise
    '153':  0xFF795548, // Brun terreux
    '154':  0xFF00ACC1, // Turquoise clair
    '159':  0xFF9C27B0, // Mauve
    '160':  0xFF37474F, // Gris ardoise
    '161':  0xFF009688, // Vert d'eau
    '162':  0xFF7E57C2, // Lavande foncé
    '163':  0xFF1B5E20, // Vert foncé
    '164':  0xFF4E342E, // Brun foncé
    '165':  0xFF8D6E63, // Brun clair
    '166':  0xFFEC407A, // Rose bonbon
    '172':  0xFF0288D1, // Bleu ciel foncé
    '178':  0xFF2979FF, // Bleu électrique (Manga)
    '182':  0xFFBF360C, // Roux
    '184':  0xFF00BFA5, // Vert marin clair
    '187':  0xFF9C27B8, // Aubergine
    '190':  0xFF3E2723, // Brun très foncé
    '191':  0xFF039BE5, // Bleu ciel
    '192':  0xFF42A5F5, // Bleu pervenche (variante Bleue)
    '194':  0xFF0B3D91, // Bleu encre (variante BLEU)
    '196':  0xFFC62828, // Rouge cramoisi
    '199':  0xFF4A148C, // Violet nuit

    // === Sous-variantes (nuance proche du parent) ===
    '127A': 0xFFE64A19, // Orange terre cuite
    '133A': 0xFF6F5744, // Chocolat moyen
    '133B': 0xFF7D5F51, // Brun moyen
    '133C': 0xFF9E8E82, // Brun sable
    '135A': 0xFFC62838, // Rouge profond
    '135_': 0xFFEF5350, // Rouge corail (ROUGE)
    '150B': 0xFFF06292, // Rose clair
    '154A': 0xFF00869B, // Cyan foncé
    '154B': 0xFF00B8D4, // Cyan moyen
    '154C': 0xFF00BCD4, // Cyan clair
    '157A': 0xFFAB47BC, // Violet clair
    '157B': 0xFF9B30A8, // Violet moyen
    '163B': 0xFF4CAF50, // Vert pomme
    '180A': 0xFFFFA000, // Or
    '180B': 0xFFFFB300, // Or clair
    '183A': 0xFF455A64, // Gris bleuté
    '183B': 0xFF607D8B, // Gris bleuté clair
    '186A': 0xFF9E9D24, // Vert lime foncé
    '192A': 0xFF5C6BC0, // Indigo moyen
    '192B': 0xFF3F51B5, // Indigo
    '193A': 0xFF66BB6A, // Vert clair
    '147BIS': 0xFF1A5FC7, // Bleu (Manga)

    // === Lignes suburbaines (lettres) ===
    'A':    0xFFFF5252, // Rouge vif
    'D':    0xFFF4511E, // Orange rouge
    'E':    0xFF2E8B57, // Vert mer
    'G':    0xFF6B18A1, // Pourpre
    'H':    0xFF008C8C, // Sarcelle sombre
    'J':    0xFFD50071, // Fuchsia
    'KOFIMI':             0xFF6B4226, // Brun acajou
    'MAHITSY':            0xFF357A38, // Vert sapin
    'AMBOHIDRATRIMO':     0xFF1A3F7A, // Bleu nuit profond
    'AMBOHITRIMANJAKA':   0xFF5B148C, // Violet profond

    // === Transports spéciaux ===
    'TRAIN_TCE':          0xFF1B8C32, // Vert rail
    'TELEPHERIQUE_Orange': 0xFFE65108, // Orange câble
  };

  /// Couleur de repli pour les lignes non répertoriées
  static int _generateColor(String lineNumber) {
    int hash = 0;
    for (int i = 0; i < lineNumber.length; i++) {
      hash = lineNumber.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = (hash.abs() % 360).toDouble();
    final saturation = 0.50 + (hash.abs() % 15) / 100.0;
    final lightness = 0.38 + (hash.abs() % 8) / 100.0;
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness)
        .toColor()
        .value;
  }

  /// Obtient la couleur pour une ligne donnée
  static int getLineColor(String lineNumber, TransportType type) {
    if (type == TransportType.urbanTrain) return 0xFF2E7D32;
    if (type == TransportType.telepherique) return 0xFFE65100;
    return _fixedColors[lineNumber] ?? _generateColor(lineNumber);
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
