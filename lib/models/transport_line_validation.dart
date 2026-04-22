import 'package:cloud_firestore/cloud_firestore.dart';

/// Statut de validation d'un élément d'une ligne (tracé ou arrêts).
enum ValidationStatus { pending, validated, modified }

extension ValidationStatusX on ValidationStatus {
  String get label {
    switch (this) {
      case ValidationStatus.pending:
        return 'À vérifier';
      case ValidationStatus.validated:
        return 'Validé';
      case ValidationStatus.modified:
        return 'Modifié';
    }
  }

  String get code {
    switch (this) {
      case ValidationStatus.pending:
        return 'pending';
      case ValidationStatus.validated:
        return 'validated';
      case ValidationStatus.modified:
        return 'modified';
    }
  }

  static ValidationStatus fromCode(String? code) {
    switch (code) {
      case 'validated':
        return ValidationStatus.validated;
      case 'modified':
        return ValidationStatus.modified;
      default:
        return ValidationStatus.pending;
    }
  }

  bool get isDone =>
      this == ValidationStatus.validated || this == ValidationStatus.modified;
}

/// Les 2 étapes du wizard de validation par ligne.
/// Chaque étape couvre tracé + arrêts de la direction (gérés ensemble par
/// `BuildLineFlowScreen`).
enum EditorStep { aller, retour }

extension EditorStepX on EditorStep {
  String get label {
    switch (this) {
      case EditorStep.aller:
        return 'Tracé aller';
      case EditorStep.retour:
        return 'Tracé retour';
    }
  }

  String get fieldKey {
    switch (this) {
      case EditorStep.aller:
        return 'aller';
      case EditorStep.retour:
        return 'retour';
    }
  }

  bool get isAller => this == EditorStep.aller;

  EditorStep? get next {
    final idx = index + 1;
    if (idx >= EditorStep.values.length) return null;
    return EditorStep.values[idx];
  }
}

class TransportLineValidation {
  final String lineNumber;
  final ValidationStatus aller;
  final ValidationStatus retour;
  final DateTime? updatedAt;
  final String? updatedBy;

  const TransportLineValidation({
    required this.lineNumber,
    this.aller = ValidationStatus.pending,
    this.retour = ValidationStatus.pending,
    this.updatedAt,
    this.updatedBy,
  });

  factory TransportLineValidation.empty(String lineNumber) =>
      TransportLineValidation(lineNumber: lineNumber);

  /// Lit les 2 nouvelles clés (`aller`, `retour`). Fallback sur l'ancien
  /// schéma 4-clés (`aller_route` + `aller_stops` → merge) pour compat avec
  /// les docs créés avant le refactor 2-étapes.
  factory TransportLineValidation.fromFirestore(
    String lineNumber,
    Map<String, dynamic> data,
  ) {
    final ts = data['updated_at'];
    return TransportLineValidation(
      lineNumber: lineNumber,
      aller: _readStatus(data, 'aller', 'aller_route', 'aller_stops'),
      retour: _readStatus(data, 'retour', 'retour_route', 'retour_stops'),
      updatedAt: ts is Timestamp ? ts.toDate() : null,
      updatedBy: data['updated_by'] as String?,
    );
  }

  static ValidationStatus _readStatus(
    Map<String, dynamic> data,
    String newKey,
    String legacyRouteKey,
    String legacyStopsKey,
  ) {
    final fresh = data[newKey];
    if (fresh is String) return ValidationStatusX.fromCode(fresh);
    final r = ValidationStatusX.fromCode(data[legacyRouteKey] as String?);
    final s = ValidationStatusX.fromCode(data[legacyStopsKey] as String?);
    // Modified l'emporte (au moins un changé = direction modifiée). Validated
    // seulement si les 2 l'étaient.
    if (r == ValidationStatus.modified || s == ValidationStatus.modified) {
      return ValidationStatus.modified;
    }
    if (r == ValidationStatus.validated && s == ValidationStatus.validated) {
      return ValidationStatus.validated;
    }
    return ValidationStatus.pending;
  }

  ValidationStatus statusFor(EditorStep step) {
    switch (step) {
      case EditorStep.aller:
        return aller;
      case EditorStep.retour:
        return retour;
    }
  }

  bool get isFullyValidated => aller.isDone && retour.isDone;

  /// Étape non-validée la plus précoce (reprise du wizard).
  EditorStep get nextPendingStep {
    for (final step in EditorStep.values) {
      if (!statusFor(step).isDone) return step;
    }
    return EditorStep.aller;
  }

  int get completedCount =>
      [aller, retour].where((s) => s.isDone).length;
}
