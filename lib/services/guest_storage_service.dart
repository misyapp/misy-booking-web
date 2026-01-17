// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rider_ride_hailing_app/models/guest_session.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

/// Service de stockage pour les sessions invité
/// Gère la persistance des données temporaires pour les utilisateurs non connectés
class GuestStorageService {
  // Clés de stockage
  static const String GUEST_SESSION = "GUEST_SESSION";
  static const String IS_GUEST_MODE = "IS_GUEST_MODE";
  static const String GUEST_ONBOARDING_SHOWN = "GUEST_ONBOARDING_SHOWN";

  /// Singleton
  static final GuestStorageService _instance = GuestStorageService._internal();
  factory GuestStorageService() => _instance;
  GuestStorageService._internal();

  /// Sauvegarde la session invité
  Future<void> saveGuestSession(GuestSession session) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(GUEST_SESSION, jsonEncode(session.toJson()));
      myCustomPrintStatement("💾 Session invité sauvegardée: ${session.sessionId}");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur sauvegarde session invité: $e");
    }
  }

  /// Récupère la session invité
  Future<GuestSession?> getGuestSession() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? sessionJson = prefs.getString(GUEST_SESSION);

      if (sessionJson != null && sessionJson.isNotEmpty) {
        var sessionData = jsonDecode(sessionJson);
        GuestSession session = GuestSession.fromJson(sessionData);

        // Vérifier si la session est expirée
        if (session.isExpired) {
          myCustomPrintStatement("⏰ Session invité expirée, suppression...");
          await clearGuestSession();
          return null;
        }

        myCustomPrintStatement("📱 Session invité restaurée: ${session.sessionId}");
        return session;
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lecture session invité: $e");
    }
    return null;
  }

  /// Supprime la session invité
  Future<void> clearGuestSession() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(GUEST_SESSION);
      myCustomPrintStatement("🗑️ Session invité supprimée");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur suppression session invité: $e");
    }
  }

  /// Définit le mode invité
  Future<void> setGuestMode(bool isGuest) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(IS_GUEST_MODE, isGuest);
      myCustomPrintStatement("🔄 Mode invité: ${isGuest ? 'Activé' : 'Désactivé'}");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur définition mode invité: $e");
    }
  }

  /// Vérifie si l'utilisateur est en mode invité
  Future<bool> isGuestMode() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(IS_GUEST_MODE) ?? false;
    } catch (e) {
      myCustomPrintStatement("❌ Erreur vérification mode invité: $e");
      return false;
    }
  }

  /// Définit si l'onboarding invité a été montré
  Future<void> setGuestOnboardingShown(bool shown) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(GUEST_ONBOARDING_SHOWN, shown);
    } catch (e) {
      myCustomPrintStatement("❌ Erreur sauvegarde onboarding shown: $e");
    }
  }

  /// Vérifie si l'onboarding invité a été montré
  Future<bool> hasShownGuestOnboarding() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(GUEST_ONBOARDING_SHOWN) ?? false;
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lecture onboarding shown: $e");
      return false;
    }
  }

  /// Nettoie toutes les données invité (appelé lors de la connexion)
  Future<void> clearAllGuestData() async {
    try {
      await clearGuestSession();
      await setGuestMode(false);
      await setGuestOnboardingShown(false);
      myCustomPrintStatement("🧹 Toutes les données invité supprimées");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur nettoyage données invité: $e");
    }
  }

  /// Met à jour les données de réservation dans la session
  Future<void> updateBookingData({
    required GuestSession currentSession,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      GuestSession updatedSession = currentSession.copyWith(
        pickupLocation: bookingData['pickupLocation'],
        pickupAddress: bookingData['pickupAddress'],
        destinationLocation: bookingData['destinationLocation'],
        destinationAddress: bookingData['destinationAddress'],
        selectedVehicleType: bookingData['selectedVehicleType'],
        estimatedPrice: bookingData['estimatedPrice'],
        hasActiveBooking: bookingData['hasActiveBooking'] ?? false,
        additionalData: bookingData['additionalData'],
      );

      await saveGuestSession(updatedSession);
      myCustomPrintStatement("✅ Données de réservation invité mises à jour");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur mise à jour données réservation: $e");
    }
  }

  /// Récupère uniquement les données de réservation
  Future<Map<String, dynamic>?> getBookingData() async {
    try {
      GuestSession? session = await getGuestSession();
      if (session != null && session.hasBookingData) {
        return {
          'pickupLocation': session.pickupLocation,
          'pickupAddress': session.pickupAddress,
          'destinationLocation': session.destinationLocation,
          'destinationAddress': session.destinationAddress,
          'selectedVehicleType': session.selectedVehicleType,
          'estimatedPrice': session.estimatedPrice,
          'additionalData': session.additionalData,
        };
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lecture données réservation: $e");
    }
    return null;
  }

  /// Efface les données de réservation tout en gardant la session
  Future<void> clearBookingData() async {
    try {
      GuestSession? session = await getGuestSession();
      if (session != null) {
        await saveGuestSession(session.clearBookingData());
        myCustomPrintStatement("🗑️ Données de réservation invité effacées");
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur effacement données réservation: $e");
    }
  }
}
