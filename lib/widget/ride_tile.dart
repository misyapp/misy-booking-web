
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/modal/vehicle_modal.dart';
import 'package:rider_ride_hailing_app/pages/view_module/booking_detail_screen.dart';

class RideTile extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isPast;

  const RideTile({
    Key? key,
    required this.booking,
    this.isPast = false,
  }) : super(key: key);

  /// Vérifie si la course est annulée (plusieurs façons de le détecter)
  bool _isCancelled() {
    // Vérifier le statut numérique (6 = CANCELLED)
    if (booking['status'] == 6) return true;

    // Vérifier le flag _cancelled
    if (booking['_cancelled'] == true) return true;

    // Vérifier si cancelledAt existe (courses de la collection cancelledBooking)
    if (booking['cancelledAt'] != null) return true;

    // Vérifier cancelledBy
    if (booking['cancelledBy'] != null) return true;

    // Vérifier le statut textuel
    final status = booking['status']?.toString().toLowerCase() ?? '';
    if (status.contains('cancel')) return true;

    return false;
  }

  /// Récupère l'URL de l'image du véhicule depuis Firestore (via vehicleMap)
  String? _getVehicleImageUrl() {
    // 1. Essayer selectedVehicle (si présent dans le booking)
    if (booking['selectedVehicle'] != null) {
      if (booking['selectedVehicle'] is Map) {
        return booking['selectedVehicle']['image'] as String?;
      } else if (booking['selectedVehicle'] is VehicleModal) {
        return (booking['selectedVehicle'] as VehicleModal).image;
      }
    }

    // 2. Utiliser l'ID du véhicule pour chercher dans vehicleMap global
    final vehicleId = booking['vehicle'] as String?;
    if (vehicleId != null && vehicleMap.containsKey(vehicleId)) {
      return vehicleMap[vehicleId]!.image;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer l'URL de l'image du véhicule depuis Firestore
    final String? vehicleImageUrl = _getVehicleImageUrl();

    // Helper to format date and time
    String formatDateTime(Timestamp timestamp) {
      final dateTime = timestamp.toDate();
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    }

    return InkWell(
      onTap: () {
        push(context: context, screen: BookingDetails(booking: booking));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: MyColors.bottomSheetBackgroundColor(),
          border: Border(
            bottom: BorderSide(color: MyColors.colorD9D9D9Theme(), width: 1.0),
          ),
        ),
        child: Row(
          children: [
            // Left side: Vehicle Image from Firestore
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: vehicleImageUrl != null && vehicleImageUrl.isNotEmpty
                  ? Image.network(
                      vehicleImageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[300],
                          child: const Icon(Icons.directions_car, color: Colors.white),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[200],
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[300],
                      child: const Icon(Icons.directions_car, color: Colors.white),
                    ),
            ),
            const SizedBox(width: 16),

            // Right side: Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking['pickAddress'] ?? 'N/A',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: MyColors.blackThemeColor(),
                    ),
                  ),
                  // Masquer le 2ème itinéraire (destination) uniquement pour les courses terminées
                  if (!isPast) ...[
                    const SizedBox(height: 4),
                    Text(
                      booking['dropAddress'] ?? 'N/A',
                      style: TextStyle(fontSize: 14, color: MyColors.blackThemeColorWithOpacity(0.7)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (!isPast && booking['scheduleTime'] != null)
                        ? const Color(0xFFFF5357).withOpacity(0.1)
                        : MyColors.colorD9D9D9Theme().withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (!isPast && booking['scheduleTime'] != null)
                          ? const Color(0xFFFF5357).withOpacity(0.3)
                          : MyColors.colorD9D9D9Theme(),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (!isPast && booking['scheduleTime'] != null)
                            ? Icons.schedule
                            : Icons.history,
                          size: 14,
                          color: (!isPast && booking['scheduleTime'] != null)
                            ? const Color(0xFFFF5357)
                            : MyColors.blackThemeColorWithOpacity(0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          // Pour les courses programmées (à venir), afficher la date/heure de réservation
                          // Pour les courses terminées, afficher la date/heure de demande
                          formatDateTime(
                            (!isPast && booking['scheduleTime'] != null)
                              ? booking['scheduleTime']
                              : booking['requestTime']
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: (!isPast && booking['scheduleTime'] != null)
                              ? const Color(0xFFFF5357)
                              : MyColors.blackThemeColorWithOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Show cancelled status if booking is cancelled
                  if (_isCancelled()) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red, width: 1),
                      ),
                      child: Text(
                        'ANNULÉE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
