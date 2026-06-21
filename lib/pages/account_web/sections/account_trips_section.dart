import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/pages/account_web/widgets/trip_card_web.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';

/// Section « Mes courses » de l'espace compte web, façon Uber : une seule
/// liste qui s'ouvre directement (plus d'onglets). Les courses « En cours »
/// (actives) sont épinglées en haut ; en dessous, « Passées » regroupe les
/// terminées ET les annulées, triées par date décroissante.
///
/// On n'affiche que les [_pageSize] dernières ; « Plus » dévoile le lot suivant
/// et déclenche le chargement Firestore quand on atteint le bout du local.
class AccountTripsSection extends StatefulWidget {
  const AccountTripsSection({super.key});

  @override
  State<AccountTripsSection> createState() => _AccountTripsSectionState();
}

class _AccountTripsSectionState extends State<AccountTripsSection> {
  /// Nombre de courses passées affichées (incrémenté par « Plus »).
  static const int _pageSize = 4;
  int _visibleCount = _pageSize;

  /// Courses actives (en route ou planifiées) : tout ce qui n'est ni terminé
  /// ni annulé. Épinglées sous « En cours ».
  List _current(TripProvider trip) {
    return trip.myCurrentBookings.where((b) {
      final s = b['status'];
      return s is int && s < BookingStatusType.RIDE_COMPLETE.value;
    }).toList();
  }

  /// Passées = terminées + annulées, triées du plus récent au plus ancien.
  ///
  /// ⚠️ `myPastBookings` lit `bookingHistory` SANS filtre de statut : il
  /// contient déjà les annulées-avec-chauffeur (le flux d'annulation les y
  /// copie). `myCancelledBookings` vient de la collection `cancelledBooking`.
  /// On fusionne puis on dédoublonne par `id` pour éviter les doublons.
  List _past(TripProvider trip) {
    final seen = <String>{};
    final merged = <Map>[];
    for (final b in [...trip.myPastBookings, ...trip.myCancelledBookings]) {
      if (b is! Map) continue;
      final id = (b['id'] ?? '').toString();
      if (id.isNotEmpty && !seen.add(id)) continue; // doublon déjà vu
      merged.add(b);
    }
    merged.sort((a, b) {
      final ta = _timeOf(a);
      final tb = _timeOf(b);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return merged;
  }

  DateTime? _timeOf(Map b) {
    return _toDate(b['endTime']) ??
        _toDate(b['cancelledAt']) ??
        _toDate(b['scheduleTime']) ??
        _toDate(b['requestTime']);
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  bool _isCancelled(Map b) {
    final s = b['status'];
    if (s == BookingStatusType.CANCELLED.value ||
        s == BookingStatusType.CANCELLED_BY_RIDER.value) {
      return true;
    }
    return b['cancelledAt'] != null || b['cancelledBy'] != null;
  }

  void _loadMore(TripProvider trip, int loadedLength) {
    setState(() => _visibleCount += _pageSize);
    // On approche du bout des données déjà chargées → on en demande plus à
    // Firestore (pagination des deux listes).
    if (_visibleCount >= loadedLength) {
      if (trip.hasMorePastBookings) trip.loadMorePastBookings();
      if (trip.hasMoreCancelledBookings) trip.loadMoreCancelledBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, trip, _) {
        final current = _current(trip);
        final past = _past(trip);
        final visiblePast = past.take(_visibleCount).toList();
        final hasMoreDb =
            trip.hasMorePastBookings || trip.hasMoreCancelledBookings;
        final showMore = _visibleCount < past.length || hasMoreDb;
        final loadingMore = trip.isLoadingMorePastBookings ||
            trip.isLoadingMoreCancelledBookings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mes courses',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // ─── En cours (épinglé) ───
                  if (current.isNotEmpty) ...[
                    _sectionLabel('En cours'),
                    const SizedBox(height: 12),
                    for (final booking in current)
                      TripCardWeb(
                          booking: booking, kind: TripCardKind.upcoming),
                    const SizedBox(height: 28),
                  ],

                  // ─── Passées (terminées + annulées) ───
                  _sectionLabel('Passées'),
                  const SizedBox(height: 12),
                  if (trip.bookingsLoading && past.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: kWebCoral),
                      ),
                    )
                  else if (past.isEmpty)
                    _emptyState('Aucune course pour le moment.')
                  else ...[
                    for (final booking in visiblePast)
                      TripCardWeb(
                        booking: booking,
                        kind: _isCancelled(booking)
                            ? TripCardKind.cancelled
                            : TripCardKind.past,
                      ),
                    if (showMore)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, right: 4),
                          child: loadingMore
                              ? const SizedBox(
                                  height: 36,
                                  width: 36,
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: kWebCoral),
                                  ),
                                )
                              : TextButton(
                                  onPressed: () =>
                                      _loadMore(trip, past.length),
                                  style: TextButton.styleFrom(
                                    foregroundColor: kWebCoralDark,
                                    backgroundColor: kWebCoral.withOpacity(0.08),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                  ),
                                  child: const Text('Plus',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      );

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
