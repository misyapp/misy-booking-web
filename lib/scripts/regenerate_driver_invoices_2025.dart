import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/services/generate_invoice_pdf_service.dart';

/// Script de régénération des factures driver 2025 avec TVA 0%
///
/// Ce script régénère toutes les factures driver de 2025 pour corriger
/// l'erreur de TVA (passage de 20% à 0% - régime de l'impôt synthétique).
class RegenerateDriverInvoices2025 {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Compteurs pour le suivi
  static int _totalProcessed = 0;
  static int _successCount = 0;
  static int _errorCount = 0;
  static List<String> _errorBookings = [];

  /// Lance la régénération de toutes les factures driver 2025
  static Future<Map<String, dynamic>> regenerateAll({
    bool dryRun = false,
    int? limit,
    Function(String)? onProgress,
  }) async {
    _totalProcessed = 0;
    _successCount = 0;
    _errorCount = 0;
    _errorBookings = [];

    try {
      onProgress?.call('🚀 Démarrage de la régénération des factures driver 2025...');

      // Récupérer tous les bookings complétés (status = 5)
      // On filtre par date côté client pour éviter les problèmes d'index Firestore
      onProgress?.call('📥 Chargement des réservations complétées...');

      Query query = _firestore
          .collection('bookingHistory')
          .where('status', isEqualTo: 5);

      if (limit != null) {
        query = query.limit(limit);
      }

      final bookingsSnapshot = await query.get();
      onProgress?.call('📥 ${bookingsSnapshot.docs.length} réservations complétées trouvées au total');

      // Filtrer côté client pour 2025
      final start2025 = DateTime(2025, 1, 1);
      final end2025 = DateTime(2026, 1, 1);

      final bookings2025 = bookingsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final endTime = data['endTime'] as Timestamp?;
        if (endTime == null) return false;
        final date = endTime.toDate();
        return date.isAfter(start2025) && date.isBefore(end2025);
      }).toList();

      onProgress?.call('📊 ${bookings2025.length} réservations de 2025 à traiter');

      // Remplacer bookingsSnapshot.docs par bookings2025 pour le reste
      final docsToProcess = bookings2025;
      final totalBookings = docsToProcess.length;

      if (dryRun) {
        onProgress?.call('🔍 Mode DRY RUN - Aucune modification ne sera effectuée');
      }

      // Traiter chaque booking
      for (int i = 0; i < docsToProcess.length; i++) {
        final bookingDoc = docsToProcess[i];
        final bookingData = bookingDoc.data() as Map<String, dynamic>;
        final bookingId = bookingDoc.id;

        _totalProcessed++;
        onProgress?.call('📄 [$_totalProcessed/$totalBookings] Traitement de $bookingId...');

        try {
          await _regenerateInvoice(
            bookingId: bookingId,
            bookingData: bookingData,
            dryRun: dryRun,
            onProgress: onProgress,
          );
          _successCount++;
        } catch (e) {
          _errorCount++;
          _errorBookings.add(bookingId);
          onProgress?.call('❌ Erreur pour $bookingId: $e');
        }
      }

      // Résumé final
      final summary = {
        'totalProcessed': _totalProcessed,
        'successCount': _successCount,
        'errorCount': _errorCount,
        'errorBookings': _errorBookings,
        'dryRun': dryRun,
      };

      onProgress?.call('\n${'=' * 50}');
      onProgress?.call('✅ RÉGÉNÉRATION TERMINÉE');
      onProgress?.call('   Total traité: $_totalProcessed');
      onProgress?.call('   Succès: $_successCount');
      onProgress?.call('   Erreurs: $_errorCount');
      if (_errorBookings.isNotEmpty) {
        onProgress?.call('   IDs en erreur: ${_errorBookings.join(', ')}');
      }
      onProgress?.call('${'=' * 50}');

      return summary;

    } catch (e) {
      onProgress?.call('❌ ERREUR FATALE: $e');
      rethrow;
    }
  }

  /// Régénère une seule facture driver
  static Future<void> _regenerateInvoice({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required bool dryRun,
    Function(String)? onProgress,
  }) async {
    // Vérifier que le booking a un driver
    final driverId = bookingData['acceptedBy'];
    if (driverId == null || driverId.isEmpty) {
      throw Exception('Pas de driver assigné');
    }

    // Vérifier que le booking a une commission
    if (bookingData['ride_price_commission'] == null) {
      throw Exception('Pas de commission définie');
    }

    // Récupérer les données du driver
    final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
    if (!driverDoc.exists) {
      throw Exception('Driver $driverId non trouvé');
    }

    final driverData = driverDoc.data()!;
    driverData['id'] = driverId;
    final driver = DriverModal.fromJson(driverData);

    if (dryRun) {
      onProgress?.call('   [DRY RUN] Facture serait régénérée pour driver: ${driver.fullName}');
      onProgress?.call('   [DRY RUN] Commission: ${bookingData['ride_price_commission']} → TVA 0%');
      return;
    }

    // Générer le nouveau PDF avec TVA 0%
    final Uint8List pdfBytes = await generateDriverInvoice(
      bookingDetails: bookingData,
      driverData: driver,
    );

    // Supprimer l'ancienne facture si elle existe
    final oldInvoiceUrl = bookingData['driver_invoice'];
    if (oldInvoiceUrl != null &&
        oldInvoiceUrl.toString().isNotEmpty &&
        !oldInvoiceUrl.toString().startsWith('pending_')) {
      try {
        final oldRef = _storage.refFromURL(oldInvoiceUrl);
        await oldRef.delete();
        onProgress?.call('   🗑️ Ancienne facture supprimée');
      } catch (e) {
        // Ignorer les erreurs de suppression (fichier peut ne plus exister)
        onProgress?.call('   ⚠️ Impossible de supprimer l\'ancienne facture: $e');
      }
    }

    // Uploader la nouvelle facture
    final fileName = 'driver_invoice_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final storageRef = _storage.ref('invoice/$fileName');

    final uploadTask = await storageRef.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    final newInvoiceUrl = await uploadTask.ref.getDownloadURL();

    // Mettre à jour Firestore
    await _firestore.collection('bookingHistory').doc(bookingId).update({
      'driver_invoice': newInvoiceUrl,
      'driver_invoice_regenerated_at': FieldValue.serverTimestamp(),
      'driver_invoice_tva_corrected': true,
    });

    onProgress?.call('   ✅ Facture régénérée avec succès');
  }

  /// Régénère une seule facture par son ID de booking
  static Future<void> regenerateSingle(
    String bookingId, {
    bool dryRun = false,
    Function(String)? onProgress,
  }) async {
    onProgress?.call('🔄 Régénération de la facture pour $bookingId...');

    final bookingDoc = await _firestore.collection('bookingHistory').doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw Exception('Booking $bookingId non trouvé');
    }

    await _regenerateInvoice(
      bookingId: bookingId,
      bookingData: bookingDoc.data()!,
      dryRun: dryRun,
      onProgress: onProgress,
    );

    onProgress?.call('✅ Terminé');
  }

  /// Liste les bookings 2025 qui seront affectés (sans modification)
  static Future<List<Map<String, dynamic>>> listAffectedBookings({int? limit}) async {
    final start2025 = DateTime(2025, 1, 1);
    final end2025 = DateTime(2026, 1, 1);

    // Récupérer tous les bookings complétés puis filtrer par date côté client
    Query query = _firestore
        .collection('bookingHistory')
        .where('status', isEqualTo: 5);

    final snapshot = await query.get();

    // Filtrer pour 2025
    var filtered = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final endTime = data['endTime'] as Timestamp?;
      if (endTime == null) return false;
      final date = endTime.toDate();
      return date.isAfter(start2025) && date.isBefore(end2025);
    }).map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'endTime': data['endTime'],
        'driverId': data['acceptedBy'],
        'commission': data['ride_price_commission'],
        'currentInvoice': data['driver_invoice'],
      };
    }).toList();

    if (limit != null && filtered.length > limit) {
      return filtered.sublist(0, limit);
    }
    return filtered;
  }
}
