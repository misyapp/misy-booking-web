import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/models/guest_session.dart';
import 'package:rider_ride_hailing_app/services/guest_storage_service.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

/// Provider pour gérer l'état de la session invité
/// Coordonne les interactions entre l'UI et le service de stockage
class GuestSessionProvider with ChangeNotifier {
  final GuestStorageService _storageService = GuestStorageService();

  GuestSession? _currentSession;
  bool _isGuestMode = false;
  bool _isLoading = false;

  // Getters
  GuestSession? get currentSession => _currentSession;
  bool get isGuestMode => _isGuestMode;
  bool get isLoading => _isLoading;
  bool get hasBookingData => _currentSession?.hasBookingData ?? false;

  /// Initialise le provider (à appeler au démarrage de l'app)
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Vérifier si l'utilisateur était en mode invité
      _isGuestMode = await _storageService.isGuestMode();

      if (_isGuestMode) {
        // Restaurer la session si elle existe
        _currentSession = await _storageService.getGuestSession();
        myCustomPrintStatement(
            "🔄 Provider invité initialisé: ${_currentSession?.sessionId ?? 'Aucune session'}");
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur initialisation provider invité: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Active le mode invité et crée une nouvelle session
  Future<void> startGuestMode() async {
    try {
      _isGuestMode = true;
      _currentSession = GuestSession.create();

      await _storageService.setGuestMode(true);
      await _storageService.saveGuestSession(_currentSession!);

      myCustomPrintStatement("✅ Mode invité activé: ${_currentSession!.sessionId}");
      notifyListeners();
    } catch (e) {
      myCustomPrintStatement("❌ Erreur activation mode invité: $e");
    }
  }

  /// Désactive le mode invité (lors de la connexion)
  Future<void> exitGuestMode() async {
    try {
      await _storageService.clearAllGuestData();
      _isGuestMode = false;
      _currentSession = null;

      myCustomPrintStatement("🚪 Mode invité désactivé");
      notifyListeners();
    } catch (e) {
      myCustomPrintStatement("❌ Erreur désactivation mode invité: $e");
    }
  }

  /// Met à jour les données de réservation
  Future<void> updateBookingData({
    LatLng? pickupLocation,
    String? pickupAddress,
    LatLng? destinationLocation,
    String? destinationAddress,
    String? selectedVehicleType,
    double? estimatedPrice,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_currentSession == null) {
      myCustomPrintStatement("⚠️ Aucune session invité active");
      return;
    }

    try {
      _currentSession = _currentSession!.copyWith(
        pickupLocation: pickupLocation ?? _currentSession!.pickupLocation,
        pickupAddress: pickupAddress ?? _currentSession!.pickupAddress,
        destinationLocation:
            destinationLocation ?? _currentSession!.destinationLocation,
        destinationAddress:
            destinationAddress ?? _currentSession!.destinationAddress,
        selectedVehicleType:
            selectedVehicleType ?? _currentSession!.selectedVehicleType,
        estimatedPrice: estimatedPrice ?? _currentSession!.estimatedPrice,
        additionalData: additionalData ?? _currentSession!.additionalData,
      );

      await _storageService.saveGuestSession(_currentSession!);
      myCustomPrintStatement("✅ Données de réservation mises à jour");
      notifyListeners();
    } catch (e) {
      myCustomPrintStatement("❌ Erreur mise à jour données réservation: $e");
    }
  }

  /// Marque qu'une réservation est en cours
  Future<void> setHasActiveBooking(bool hasBooking) async {
    if (_currentSession == null) return;

    try {
      _currentSession = _currentSession!.copyWith(
        hasActiveBooking: hasBooking,
      );

      await _storageService.saveGuestSession(_currentSession!);
      myCustomPrintStatement(
          "✅ Statut réservation active: ${hasBooking ? 'Oui' : 'Non'}");
      notifyListeners();
    } catch (e) {
      myCustomPrintStatement("❌ Erreur mise à jour statut réservation: $e");
    }
  }

  /// Efface les données de réservation
  Future<void> clearBookingData() async {
    if (_currentSession == null) return;

    try {
      _currentSession = _currentSession!.clearBookingData();
      await _storageService.saveGuestSession(_currentSession!);

      myCustomPrintStatement("🗑️ Données de réservation effacées");
      notifyListeners();
    } catch (e) {
      myCustomPrintStatement("❌ Erreur effacement données réservation: $e");
    }
  }

  /// Récupère les données de réservation pour les transférer après connexion
  Map<String, dynamic>? getBookingDataForTransfer() {
    if (_currentSession == null || !_currentSession!.hasBookingData) {
      return null;
    }

    return {
      'pickupLocation': _currentSession!.pickupLocation,
      'pickupAddress': _currentSession!.pickupAddress,
      'destinationLocation': _currentSession!.destinationLocation,
      'destinationAddress': _currentSession!.destinationAddress,
      'selectedVehicleType': _currentSession!.selectedVehicleType,
      'estimatedPrice': _currentSession!.estimatedPrice,
      'additionalData': _currentSession!.additionalData,
    };
  }

  /// Vérifie si l'onboarding a été montré
  Future<bool> hasShownOnboarding() async {
    return await _storageService.hasShownGuestOnboarding();
  }

  /// Marque l'onboarding comme montré
  Future<void> setOnboardingShown() async {
    await _storageService.setGuestOnboardingShown(true);
  }

  /// Réinitialise complètement le provider
  void reset() {
    _currentSession = null;
    _isGuestMode = false;
    _isLoading = false;
    notifyListeners();
  }
}
