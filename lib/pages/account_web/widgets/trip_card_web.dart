import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/pages/account_web/widgets/invoice_button.dart';
import 'package:rider_ride_hailing_app/pages/view_module/booking_detail_screen.dart';

/// Nature de la liste dans laquelle la carte est affichée — pilote la date
/// mise en avant et les actions disponibles.
enum TripCardKind { upcoming, past, cancelled }

/// Carte course de l'espace compte web : trajet, date, prix, statut et
/// actions (détail/annulation via [BookingDetails], facture pour les
/// courses terminées). Présentation desktop — la version mobile reste
/// [RideTile] dans MyBookingScreen.
class TripCardWeb extends StatelessWidget {
  final Map booking;
  final TripCardKind kind;

  const TripCardWeb({super.key, required this.booking, required this.kind});

  String? _vehicleImageUrl() {
    if (booking['selectedVehicle'] is Map) {
      return booking['selectedVehicle']['image'] as String?;
    }
    final vehicleId = booking['vehicle'] as String?;
    if (vehicleId != null && vehicleMap.containsKey(vehicleId)) {
      return vehicleMap[vehicleId]!.image;
    }
    return null;
  }

  /// Timestamp le plus pertinent selon la liste : départ planifié pour les
  /// courses à venir, fin de course pour les passées, annulation pour les
  /// annulées — avec repli sur la date de demande.
  Timestamp? _relevantTime() {
    final candidates = switch (kind) {
      TripCardKind.upcoming => [booking['scheduleTime'], booking['requestTime']],
      TripCardKind.past => [booking['endTime'], booking['requestTime']],
      TripCardKind.cancelled => [booking['cancelledAt'], booking['requestTime']],
    };
    for (final c in candidates) {
      if (c is Timestamp) return c;
    }
    return null;
  }

  String _formattedTime() {
    final ts = _relevantTime();
    if (ts == null) return '—';
    return DateFormat('dd MMM yyyy, HH:mm').format(ts.toDate());
  }

  String _formattedPrice() {
    final raw = booking['ride_price_to_pay'] ?? booking['total_ride_price'];
    if (raw == null) return '';
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (value == null) return '';
    return '${formatAriary(value)} Ar';
  }

  bool get _isScheduled => booking['isSchedule'] == true;

  /// Parité avec `BookingDetails.canBeCancelled`.
  bool get _canBeCancelled {
    final status = booking['status'] ?? BookingStatusType.PENDING_REQUEST.value;
    if (status is! int || status >= BookingStatusType.RIDE_STARTED.value) {
      return false;
    }
    return _isScheduled || booking['acceptedBy'] != null;
  }

  (String, Color) _statusBadge() {
    switch (kind) {
      case TripCardKind.cancelled:
        return ('Annulée', Colors.red.shade700);
      case TripCardKind.past:
        return ('Terminée', Colors.green.shade700);
      case TripCardKind.upcoming:
        final status =
            booking['status'] ?? BookingStatusType.PENDING_REQUEST.value;
        if (status == BookingStatusType.PENDING_REQUEST.value) {
          return _isScheduled
              ? ('Planifiée', kWebCoralDark)
              : ('Recherche de chauffeur', Colors.orange.shade800);
        }
        return ('Chauffeur confirmé', Colors.blue.shade700);
    }
  }

  void _openDetails(BuildContext context) {
    push(context: context, screen: BookingDetails(booking: booking));
  }

  @override
  Widget build(BuildContext context) {
    final (badgeLabel, badgeColor) = _statusBadge();
    final vehicleImage = _vehicleImageUrl();
    final price = _formattedPrice();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vignette véhicule
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: kWebPageBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: vehicleImage != null && vehicleImage.isNotEmpty
                    ? Image.network(
                        vehicleImage,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.directions_car,
                            color: Colors.grey.shade400),
                      )
                    : Icon(Icons.directions_car, color: Colors.grey.shade400),
              ),
              const SizedBox(width: 16),
              // Trajet + méta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _addressLine(
                        Icons.trip_origin, booking['pickAddress'] ?? '—'),
                    const SizedBox(height: 4),
                    _addressLine(
                        Icons.place_outlined, booking['dropAddress'] ?? '—'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip(
                          icon: _isScheduled && kind == TripCardKind.upcoming
                              ? Icons.schedule
                              : Icons.history,
                          label: _formattedTime(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: badgeColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Prix + actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (price.isNotEmpty)
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (kind == TripCardKind.past)
                    InvoiceButton(booking: booking),
                  if (kind == TripCardKind.upcoming && _canBeCancelled)
                    TextButton.icon(
                      // L'annulation vit dans BookingDetails (_cancelBooking :
                      // migration bookingRequest → bookingHistory + nettoyage
                      // provider/cache). On ouvre le détail plutôt que de
                      // dupliquer cette logique ici.
                      onPressed: () => _openDetails(context),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Annuler'),
                      style: TextButton.styleFrom(
                        foregroundColor: kWebCoralDark,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
