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

/// Les 4 étapes du wizard de validation par ligne.
enum EditorStep { allerRoute, retourRoute, allerStops, retourStops }

extension EditorStepX on EditorStep {
  String get label {
    switch (this) {
      case EditorStep.allerRoute:
        return 'Tracé aller';
      case EditorStep.retourRoute:
        return 'Tracé retour';
      case EditorStep.allerStops:
        return 'Arrêts aller';
      case EditorStep.retourStops:
        return 'Arrêts retour';
    }
  }

  String get fieldKey {
    switch (this) {
      case EditorStep.allerRoute:
        return 'aller_route';
      case EditorStep.retourRoute:
        return 'retour_route';
      case EditorStep.allerStops:
        return 'aller_stops';
      case EditorStep.retourStops:
        return 'retour_stops';
    }
  }

  bool get isAller =>
      this == EditorStep.allerRoute || this == EditorStep.allerStops;

  bool get isRoute =>
      this == EditorStep.allerRoute || this == EditorStep.retourRoute;

  EditorStep? get next {
    final idx = index + 1;
    if (idx >= EditorStep.values.length) return null;
    return EditorStep.values[idx];
  }
}

class TransportLineValidation {
  final String lineNumber;
  final ValidationStatus allerRoute;
  final ValidationStatus retourRoute;
  final ValidationStatus allerStops;
  final ValidationStatus retourStops;
  final DateTime? updatedAt;
  final String? updatedBy;

  const TransportLineValidation({
    required this.lineNumber,
    this.allerRoute = ValidationStatus.pending,
    this.retourRoute = ValidationStatus.pending,
    this.allerStops = ValidationStatus.pending,
    this.retourStops = ValidationStatus.pending,
    this.updatedAt,
    this.updatedBy,
  });

  factory TransportLineValidation.empty(String lineNumber) =>
      TransportLineValidation(lineNumber: lineNumber);

  factory TransportLineValidation.fromFirestore(
    String lineNumber,
    Map<String, dynamic> data,
  ) {
    final ts = data['updated_at'];
    return TransportLineValidation(
      lineNumber: lineNumber,
      allerRoute: ValidationStatusX.fromCode(data['aller_route'] as String?),
      retourRoute: ValidationStatusX.fromCode(data['retour_route'] as String?),
      allerStops: ValidationStatusX.fromCode(data['aller_stops'] as String?),
      retourStops: ValidationStatusX.fromCode(data['retour_stops'] as String?),
      updatedAt: ts is Timestamp ? ts.toDate() : null,
      updatedBy: data['updated_by'] as String?,
    );
  }

  ValidationStatus statusFor(EditorStep step) {
    switch (step) {
      case EditorStep.allerRoute:
        return allerRoute;
      case EditorStep.retourRoute:
        return retourRoute;
      case EditorStep.allerStops:
        return allerStops;
      case EditorStep.retourStops:
        return retourStops;
    }
  }

  bool get isFullyValidated =>
      allerRoute.isDone &&
      retourRoute.isDone &&
      allerStops.isDone &&
      retourStops.isDone;

  /// Étape non-validée la plus précoce (reprise du wizard).
  EditorStep get nextPendingStep {
    for (final step in EditorStep.values) {
      if (!statusFor(step).isDone) return step;
    }
    return EditorStep.allerRoute;
  }

  int get completedCount =>
      [allerRoute, retourRoute, allerStops, retourStops]
          .where((s) => s.isDone)
          .length;
}
