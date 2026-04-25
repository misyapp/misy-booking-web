import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Color;

/// Drapeau couleur perso posé par le consultant sur une direction. Sert de
/// signal visuel dans la liste des lignes (dashboard) et dans la queue admin.
enum ConsultantFlag { red, orange, yellow, green, blue }

extension ConsultantFlagX on ConsultantFlag {
  String get code {
    switch (this) {
      case ConsultantFlag.red:
        return 'red';
      case ConsultantFlag.orange:
        return 'orange';
      case ConsultantFlag.yellow:
        return 'yellow';
      case ConsultantFlag.green:
        return 'green';
      case ConsultantFlag.blue:
        return 'blue';
    }
  }

  String get label {
    switch (this) {
      case ConsultantFlag.red:
        return 'À revoir / problème';
      case ConsultantFlag.orange:
        return 'À vérifier sur place';
      case ConsultantFlag.yellow:
        return 'À discuter';
      case ConsultantFlag.green:
        return 'Confirmé';
      case ConsultantFlag.blue:
        return 'Note neutre';
    }
  }

  Color get color {
    switch (this) {
      case ConsultantFlag.red:
        return const Color(0xFFE53935);
      case ConsultantFlag.orange:
        return const Color(0xFFFB8C00);
      case ConsultantFlag.yellow:
        return const Color(0xFFFDD835);
      case ConsultantFlag.green:
        return const Color(0xFF43A047);
      case ConsultantFlag.blue:
        return const Color(0xFF1E88E5);
    }
  }

  static ConsultantFlag? fromCode(String? code) {
    switch (code) {
      case 'red':
        return ConsultantFlag.red;
      case 'orange':
        return ConsultantFlag.orange;
      case 'yellow':
        return ConsultantFlag.yellow;
      case 'green':
        return ConsultantFlag.green;
      case 'blue':
        return ConsultantFlag.blue;
      default:
        return null;
    }
  }
}

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

/// Statut admin par direction (workflow review/publication).
enum AdminStatus { pending, approved, rejected }

extension AdminStatusX on AdminStatus {
  String get code {
    switch (this) {
      case AdminStatus.pending:
        return 'pending';
      case AdminStatus.approved:
        return 'approved';
      case AdminStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case AdminStatus.pending:
        return 'À reviewer';
      case AdminStatus.approved:
        return 'Validé admin';
      case AdminStatus.rejected:
        return 'À refaire';
    }
  }

  static AdminStatus fromCode(String? code) {
    switch (code) {
      case 'approved':
        return AdminStatus.approved;
      case 'rejected':
        return AdminStatus.rejected;
      default:
        return AdminStatus.pending;
    }
  }
}

/// Review admin pour une direction donnée.
class AdminReview {
  final AdminStatus status;
  final DateTime? reviewedAt;
  final String? reviewedByEmail;
  final String? rejectionReason;

  const AdminReview({
    this.status = AdminStatus.pending,
    this.reviewedAt,
    this.reviewedByEmail,
    this.rejectionReason,
  });

  static AdminReview fromFirestore(Map<String, dynamic> data, String direction) {
    final ts = data['${direction}_reviewed_at'];
    return AdminReview(
      status: AdminStatusX.fromCode(data['${direction}_admin_status'] as String?),
      reviewedAt: ts is Timestamp ? ts.toDate() : null,
      reviewedByEmail: data['${direction}_reviewed_by_email'] as String?,
      rejectionReason: data['${direction}_rejection_reason'] as String?,
    );
  }
}

class TransportLineValidation {
  final String lineNumber;
  final ValidationStatus aller;
  final ValidationStatus retour;
  final AdminReview allerAdmin;
  final AdminReview retourAdmin;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? updatedByEmail;
  // Annotations consultant par direction (note libre + drapeau couleur).
  // Visibles dans la liste dashboard ET dans la queue admin pour signaler
  // les directions à revoir/discuter sans changer leur statut.
  final String? allerNote;
  final String? retourNote;
  final ConsultantFlag? allerFlag;
  final ConsultantFlag? retourFlag;

  const TransportLineValidation({
    required this.lineNumber,
    this.aller = ValidationStatus.pending,
    this.retour = ValidationStatus.pending,
    this.allerAdmin = const AdminReview(),
    this.retourAdmin = const AdminReview(),
    this.updatedAt,
    this.updatedBy,
    this.updatedByEmail,
    this.allerNote,
    this.retourNote,
    this.allerFlag,
    this.retourFlag,
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
      allerAdmin: AdminReview.fromFirestore(data, 'aller'),
      retourAdmin: AdminReview.fromFirestore(data, 'retour'),
      updatedAt: ts is Timestamp ? ts.toDate() : null,
      updatedBy: data['updated_by'] as String?,
      updatedByEmail: data['updated_by_email'] as String?,
      allerNote: _readNote(data['aller_consultant_note']),
      retourNote: _readNote(data['retour_consultant_note']),
      allerFlag:
          ConsultantFlagX.fromCode(data['aller_consultant_flag'] as String?),
      retourFlag:
          ConsultantFlagX.fromCode(data['retour_consultant_flag'] as String?),
    );
  }

  static String? _readNote(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
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

  AdminReview adminReviewFor(EditorStep step) {
    switch (step) {
      case EditorStep.aller:
        return allerAdmin;
      case EditorStep.retour:
        return retourAdmin;
    }
  }

  String? noteFor(EditorStep step) =>
      step.isAller ? allerNote : retourNote;

  ConsultantFlag? flagFor(EditorStep step) =>
      step.isAller ? allerFlag : retourFlag;

  bool hasAnnotationFor(EditorStep step) =>
      noteFor(step) != null || flagFor(step) != null;

  bool get isFullyValidated => aller.isDone && retour.isDone;

  /// True seulement si les 2 directions ont été validées par l'admin et sont
  /// donc publiées en prod. Distinct de [isFullyValidated] qui retourne vrai
  /// dès que le consultant a modifié les 2 (mais pas encore reviewé).
  bool get isPublished =>
      allerAdmin.status == AdminStatus.approved &&
      retourAdmin.status == AdminStatus.approved;

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
