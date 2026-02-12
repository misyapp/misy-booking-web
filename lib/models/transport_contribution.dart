import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Types de contribution possibles
enum ContributionType {
  stop_edit,
  route_edit,
  line_info,
  schedule_update,
  general_issue,
}

/// Statuts d'une contribution
enum ContributionStatus {
  pending,
  reviewed,
  implemented,
  rejected,
}

/// Actions d'édition possibles
enum EditAction {
  add_stop,
  move_stop,
  delete_stop,
  modify_route,
}

/// Données d'édition associées à une contribution
class EditData {
  final EditAction action;
  final String? stopName;
  final String? stopId;
  final LatLng? oldCoordinates;
  final LatLng? newCoordinates;
  final List<LatLng>? routeSegment;
  final List<LatLng>? routeAllerSegment;
  final LatLng? primus;
  final LatLng? terminus;
  final String? primusName;
  final String? terminusName;

  const EditData({
    required this.action,
    this.stopName,
    this.stopId,
    this.oldCoordinates,
    this.newCoordinates,
    this.routeSegment,
    this.routeAllerSegment,
    this.primus,
    this.terminus,
    this.primusName,
    this.terminusName,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action.name,
      'stop_name': stopName,
      'stop_id': stopId,
      'old_coordinates': oldCoordinates != null
          ? {'lat': oldCoordinates!.latitude, 'lng': oldCoordinates!.longitude}
          : null,
      'new_coordinates': newCoordinates != null
          ? {'lat': newCoordinates!.latitude, 'lng': newCoordinates!.longitude}
          : null,
      'route_segment':
          routeSegment?.map((p) => [p.longitude, p.latitude]).toList(),
      'route_aller_segment':
          routeAllerSegment?.map((p) => [p.longitude, p.latitude]).toList(),
      'primus': primus != null
          ? {'lat': primus!.latitude, 'lng': primus!.longitude}
          : null,
      'terminus': terminus != null
          ? {'lat': terminus!.latitude, 'lng': terminus!.longitude}
          : null,
      'primus_name': primusName,
      'terminus_name': terminusName,
    };
  }

  factory EditData.fromJson(Map<String, dynamic> json) {
    return EditData(
      action: EditAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => EditAction.add_stop,
      ),
      stopName: json['stop_name'],
      stopId: json['stop_id'],
      oldCoordinates: json['old_coordinates'] != null
          ? LatLng(
              (json['old_coordinates']['lat'] as num).toDouble(),
              (json['old_coordinates']['lng'] as num).toDouble(),
            )
          : null,
      newCoordinates: json['new_coordinates'] != null
          ? LatLng(
              (json['new_coordinates']['lat'] as num).toDouble(),
              (json['new_coordinates']['lng'] as num).toDouble(),
            )
          : null,
      routeSegment: json['route_segment'] != null
          ? (json['route_segment'] as List)
              .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
              .toList()
          : null,
      routeAllerSegment: json['route_aller_segment'] != null
          ? (json['route_aller_segment'] as List)
              .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
              .toList()
          : null,
      primus: json['primus'] != null
          ? LatLng(
              (json['primus']['lat'] as num).toDouble(),
              (json['primus']['lng'] as num).toDouble(),
            )
          : null,
      terminus: json['terminus'] != null
          ? LatLng(
              (json['terminus']['lat'] as num).toDouble(),
              (json['terminus']['lng'] as num).toDouble(),
            )
          : null,
      primusName: json['primus_name'],
      terminusName: json['terminus_name'],
    );
  }
}

/// Représente une contribution utilisateur pour corriger/améliorer une ligne
class TransportContribution {
  final String id;
  final String userId;
  final String userName;
  final String lineNumber;
  final ContributionType contributionType;
  final String description;
  final LatLng location;
  final DateTime submittedAt;
  final ContributionStatus status;
  final List<String> attachments;
  final int votes;
  final String moderatorNotes;
  final EditData? editData;

  const TransportContribution({
    required this.id,
    required this.userId,
    required this.userName,
    required this.lineNumber,
    required this.contributionType,
    required this.description,
    required this.location,
    required this.submittedAt,
    required this.status,
    required this.attachments,
    required this.votes,
    required this.moderatorNotes,
    this.editData,
  });

  factory TransportContribution.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geoPoint = data['location'] as GeoPoint;

    return TransportContribution(
      id: doc.id,
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? 'Utilisateur',
      lineNumber: data['line_number'] ?? '',
      contributionType: ContributionType.values.firstWhere(
        (e) => e.name == data['contribution_type'],
        orElse: () => ContributionType.general_issue,
      ),
      description: data['description'] ?? '',
      location: LatLng(geoPoint.latitude, geoPoint.longitude),
      submittedAt:
          (data['submitted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ContributionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ContributionStatus.pending,
      ),
      attachments: List<String>.from(data['attachments'] ?? []),
      votes: data['votes'] ?? 0,
      moderatorNotes: data['moderator_notes'] ?? '',
      editData: data['edit_data'] != null
          ? EditData.fromJson(data['edit_data'] as Map<String, dynamic>)
          : null,
    );
  }
}
