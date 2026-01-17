import 'package:flutter/material.dart';

/// Modèle représentant une période d'embouteillages avec horaires et jours de la semaine
/// 
/// Utilisé pour déterminer si une demande de course est effectuée pendant
/// les heures d'embouteillages où s'applique une majoration tarifaire.
/// 
/// Exemple d'usage :
/// ```dart
/// final morningRush = TrafficPeriod(
///   startTime: TimeOfDay(hour: 7, minute: 0),
///   endTime: TimeOfDay(hour: 9, minute: 59),
///   daysOfWeek: [1, 2, 3, 4, 5], // Lundi à Vendredi
/// );
/// 
/// final mondayMorning = DateTime(2025, 1, 6, 8, 30);
/// print(morningRush.isTrafficTime(mondayMorning)); // true
/// ```
class TrafficPeriod {
  /// Heure de début de la période d'embouteillages (ex: 07:00)
  final TimeOfDay startTime;
  
  /// Heure de fin de la période d'embouteillages (ex: 09:59)
  final TimeOfDay endTime;
  
  /// Jours de la semaine où s'applique cette période
  /// Format : 1=Lundi, 2=Mardi, ..., 7=Dimanche
  final List<int> daysOfWeek;
  
  const TrafficPeriod({
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
  });
  
  /// Vérifie si une DateTime donnée est dans cette période d'embouteillage
  /// 
  /// Retourne true si :
  /// - Le jour de la semaine correspond à un jour configuré
  /// - L'heure est comprise entre startTime et endTime (inclus)
  /// 
  /// [dateTime] La date/heure à vérifier
  /// Retourne true si c'est une période d'embouteillages
  bool isTrafficTime(DateTime dateTime) {
    // Vérifier le jour de la semaine (1=Lundi, 7=Dimanche)
    if (!daysOfWeek.contains(dateTime.weekday)) {
      return false;
    }
    
    // Vérifier l'heure
    final currentTime = TimeOfDay.fromDateTime(dateTime);
    
    // Conversion en minutes pour comparaison plus facile
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }
  
  /// Sérialisation vers JSON pour stockage Firestore
  /// 
  /// Format de sortie :
  /// ```json
  /// {
  ///   "startTime": "07:00",
  ///   "endTime": "09:59", 
  ///   "daysOfWeek": [1, 2, 3, 4, 5]
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'startTime': _formatTimeOfDay(startTime),
      'endTime': _formatTimeOfDay(endTime),
      'daysOfWeek': daysOfWeek,
    };
  }
  
  /// Désérialisation depuis JSON
  /// 
  /// [json] Map contenant les données JSON
  /// Retourne une instance de TrafficPeriod
  factory TrafficPeriod.fromJson(Map<String, dynamic> json) {
    return TrafficPeriod(
      startTime: _parseTimeOfDay(json['startTime']),
      endTime: _parseTimeOfDay(json['endTime']),
      daysOfWeek: List<int>.from(json['daysOfWeek'] ?? []),
    );
  }
  
  /// Formate un TimeOfDay au format "HH:MM"
  static String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  /// Parse une chaîne "HH:MM" vers TimeOfDay
  static TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
  
  /// Représentation textuelle pour debug/affichage
  /// 
  /// Format : "07:00 - 09:59 (Lun, Mar, Mer, Jeu, Ven)"
  @override
  String toString() {
    final daysNames = {
      1: 'Lun', 2: 'Mar', 3: 'Mer', 4: 'Jeu', 
      5: 'Ven', 6: 'Sam', 7: 'Dim'
    };
    
    final daysList = daysOfWeek.map((d) => daysNames[d]).join(', ');
    
    return '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)} ($daysList)';
  }
  
  /// Validation des données
  /// 
  /// Vérifie que :
  /// - Les jours de la semaine sont valides (1-7)
  /// - L'heure de fin est après l'heure de début
  /// - La liste des jours n'est pas vide
  bool isValid() {
    // Vérifier que les jours sont valides (1-7)
    if (daysOfWeek.isEmpty || daysOfWeek.any((day) => day < 1 || day > 7)) {
      return false;
    }
    
    // Vérifier que l'heure de fin est après l'heure de début
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    
    if (endMinutes <= startMinutes) {
      return false;
    }
    
    return true;
  }
  
  /// Création d'une copie avec modifications
  TrafficPeriod copyWith({
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<int>? daysOfWeek,
  }) {
    return TrafficPeriod(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    );
  }
  
  /// Opérateur d'égalité
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is TrafficPeriod &&
           other.startTime == startTime &&
           other.endTime == endTime &&
           _listEquals(other.daysOfWeek, daysOfWeek);
  }
  
  /// Hash code
  @override
  int get hashCode {
    return startTime.hashCode ^ 
           endTime.hashCode ^ 
           daysOfWeek.fold(0, (prev, element) => prev ^ element.hashCode);
  }
  
  /// Helper pour comparer des listes d'entiers
  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}