import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Modèle pour gérer la session d'un utilisateur invité (non connecté)
/// Stocke temporairement les informations de réservation avant l'authentification
class GuestSession {
  final String sessionId;
  final DateTime createdAt;
  final DateTime? expiresAt;

  // Données de réservation temporaires
  final LatLng? pickupLocation;
  final String? pickupAddress;
  final LatLng? destinationLocation;
  final String? destinationAddress;
  final String? selectedVehicleType;
  final double? estimatedPrice;

  // Métadonnées
  final bool hasActiveBooking;
  final Map<String, dynamic>? additionalData;

  const GuestSession({
    required this.sessionId,
    required this.createdAt,
    this.expiresAt,
    this.pickupLocation,
    this.pickupAddress,
    this.destinationLocation,
    this.destinationAddress,
    this.selectedVehicleType,
    this.estimatedPrice,
    this.hasActiveBooking = false,
    this.additionalData,
  });

  /// Crée une nouvelle session invité vide
  factory GuestSession.create() {
    final now = DateTime.now();
    return GuestSession(
      sessionId: 'guest_${now.millisecondsSinceEpoch}',
      createdAt: now,
      expiresAt: null, // Pas d'expiration pour l'instant
    );
  }

  /// Crée une instance depuis JSON (pour SharedPreferences)
  factory GuestSession.fromJson(Map<String, dynamic> json) {
    return GuestSession(
      sessionId: json['sessionId'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      pickupLocation: json['pickupLocation'] != null
          ? LatLng(
              json['pickupLocation']['latitude'],
              json['pickupLocation']['longitude'],
            )
          : null,
      pickupAddress: json['pickupAddress'],
      destinationLocation: json['destinationLocation'] != null
          ? LatLng(
              json['destinationLocation']['latitude'],
              json['destinationLocation']['longitude'],
            )
          : null,
      destinationAddress: json['destinationAddress'],
      selectedVehicleType: json['selectedVehicleType'],
      estimatedPrice: json['estimatedPrice']?.toDouble(),
      hasActiveBooking: json['hasActiveBooking'] ?? false,
      additionalData: json['additionalData'] != null
          ? Map<String, dynamic>.from(json['additionalData'])
          : null,
    );
  }

  /// Convertit l'instance en JSON (pour SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'pickupLocation': pickupLocation != null
          ? {
              'latitude': pickupLocation!.latitude,
              'longitude': pickupLocation!.longitude,
            }
          : null,
      'pickupAddress': pickupAddress,
      'destinationLocation': destinationLocation != null
          ? {
              'latitude': destinationLocation!.latitude,
              'longitude': destinationLocation!.longitude,
            }
          : null,
      'destinationAddress': destinationAddress,
      'selectedVehicleType': selectedVehicleType,
      'estimatedPrice': estimatedPrice,
      'hasActiveBooking': hasActiveBooking,
      'additionalData': additionalData,
    };
  }

  /// Crée une copie avec des modifications
  GuestSession copyWith({
    String? sessionId,
    DateTime? createdAt,
    DateTime? expiresAt,
    LatLng? pickupLocation,
    String? pickupAddress,
    LatLng? destinationLocation,
    String? destinationAddress,
    String? selectedVehicleType,
    double? estimatedPrice,
    bool? hasActiveBooking,
    Map<String, dynamic>? additionalData,
  }) {
    return GuestSession(
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      selectedVehicleType: selectedVehicleType ?? this.selectedVehicleType,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      hasActiveBooking: hasActiveBooking ?? this.hasActiveBooking,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  /// Vérifie si la session a expiré
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Vérifie si la session a des données de réservation
  bool get hasBookingData {
    return pickupLocation != null && destinationLocation != null;
  }

  /// Réinitialise les données de réservation
  GuestSession clearBookingData() {
    return copyWith(
      pickupLocation: null,
      pickupAddress: null,
      destinationLocation: null,
      destinationAddress: null,
      selectedVehicleType: null,
      estimatedPrice: null,
      hasActiveBooking: false,
      additionalData: null,
    );
  }

  @override
  String toString() {
    return 'GuestSession(sessionId: $sessionId, hasBookingData: $hasBookingData, hasActiveBooking: $hasActiveBooking)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GuestSession &&
      other.sessionId == sessionId &&
      other.createdAt == createdAt;
  }

  @override
  int get hashCode => sessionId.hashCode ^ createdAt.hashCode;
}
