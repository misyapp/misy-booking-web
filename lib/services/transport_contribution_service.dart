import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/transport_contribution.dart';

/// Service pour gérer les contributions utilisateur sur les lignes de transport
class TransportContributionService {
  static final CollectionReference _contributions =
      FirebaseFirestore.instance.collection('transport_contributions');

  /// Soumettre une contribution (signalement + édition)
  static Future<bool> submitContribution({
    required String lineNumber,
    required ContributionType contributionType,
    required String description,
    required LatLng location,
    EditData? editData,
    List<String>? attachmentUrls,
    String? contributorName,
  }) async {
    try {
      final user = userData.value;

      final Map<String, dynamic> data = {
        'user_id': user?.id ?? 'anonymous',
        'user_name': contributorName ?? user?.fullName ?? 'Utilisateur',
        'line_number': lineNumber,
        'contribution_type': contributionType.name,
        'description': description,
        'location': GeoPoint(location.latitude, location.longitude),
        'submitted_at': FieldValue.serverTimestamp(),
        'status': 'pending',
        'attachments': attachmentUrls ?? [],
        'votes': 0,
        'moderator_notes': '',
        'reviewed_by': null,
        'reviewed_at': null,
      };

      if (editData != null) {
        data['edit_data'] = editData.toJson();
      }

      await _contributions.add(data);
      myCustomPrintStatement('Contribution soumise: ligne $lineNumber');
      return true;
    } catch (e) {
      myCustomPrintStatement('Erreur soumission contribution: $e');
      return false;
    }
  }

  /// Récupérer contributions d'une ligne
  static Stream<List<TransportContribution>> getLineContributions(
    String lineNumber,
  ) {
    return _contributions
        .where('line_number', isEqualTo: lineNumber)
        .orderBy('submitted_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransportContribution.fromFirestore(doc))
            .toList());
  }

  /// Récupérer contributions de l'utilisateur connecté
  static Stream<List<TransportContribution>> getUserContributions() {
    final user = userData.value;
    if (user == null) return const Stream.empty();

    return _contributions
        .where('user_id', isEqualTo: user.id)
        .orderBy('submitted_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransportContribution.fromFirestore(doc))
            .toList());
  }

  /// Mettre à jour statut contribution (admin)
  static Future<bool> updateContributionStatus({
    required String contributionId,
    required String status,
    String? moderatorNotes,
  }) async {
    try {
      final user = userData.value;
      await _contributions.doc(contributionId).update({
        'status': status,
        'moderator_notes': moderatorNotes ?? '',
        'reviewed_by': user?.id,
        'reviewed_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      myCustomPrintStatement('Erreur update contribution: $e');
      return false;
    }
  }
}
