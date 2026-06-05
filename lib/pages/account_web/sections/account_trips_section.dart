import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/pages/account_web/widgets/trip_card_web.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';

/// Section « Mes courses » de l'espace compte web : trois onglets
/// (À venir / Passées / Annulées) branchés sur les listes existantes de
/// [TripProvider] — aucune nouvelle requête Firestore.
class AccountTripsSection extends StatefulWidget {
  const AccountTripsSection({super.key});

  @override
  State<AccountTripsSection> createState() => _AccountTripsSectionState();
}

class _AccountTripsSectionState extends State<AccountTripsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Courses à venir : bookings actifs de `bookingRequest` non annulés et
  /// pas encore démarrés (les courses en cours de route se suivent sur la
  /// home, pas ici).
  List _upcoming(TripProvider trip) {
    return trip.myCurrentBookings.where((b) {
      final status = b['status'];
      return status is int &&
          status < BookingStatusType.RIDE_STARTED.value;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, trip, _) {
        final upcoming = _upcoming(trip);
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
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: kWebCoralDark,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: kWebCoral,
              dividerColor: Colors.grey.shade200,
              labelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'À venir (${upcoming.length})'),
                Tab(text: 'Passées (${trip.myPastBookings.length})'),
                Tab(text: 'Annulées (${trip.myCancelledBookings.length})'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _bookingList(
                    bookings: upcoming,
                    kind: TripCardKind.upcoming,
                    loading: trip.currentBookingLoading,
                    emptyMessage:
                        'Aucune course à venir. Planifiez votre prochain trajet depuis la page de réservation.',
                  ),
                  _bookingList(
                    bookings: trip.myPastBookings,
                    kind: TripCardKind.past,
                    loading: trip.bookingsLoading,
                    emptyMessage: 'Aucune course terminée pour le moment.',
                    hasMore: trip.hasMorePastBookings,
                    loadingMore: trip.isLoadingMorePastBookings,
                    onLoadMore: trip.loadMorePastBookings,
                  ),
                  _bookingList(
                    bookings: trip.myCancelledBookings,
                    kind: TripCardKind.cancelled,
                    loading: trip.bookingsLoading,
                    emptyMessage: 'Aucune course annulée.',
                    hasMore: trip.hasMoreCancelledBookings,
                    loadingMore: trip.isLoadingMoreCancelledBookings,
                    onLoadMore: trip.loadMoreCancelledBookings,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bookingList({
    required List bookings,
    required TripCardKind kind,
    required bool loading,
    required String emptyMessage,
    bool hasMore = false,
    bool loadingMore = false,
    Future<void> Function()? onLoadMore,
  }) {
    if (loading && bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: kWebCoral));
    }
    if (bookings.isEmpty) {
      return _emptyState(emptyMessage);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final booking in bookings)
          TripCardWeb(booking: booking, kind: kind),
        if (hasMore && onLoadMore != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: loadingMore
                  ? const CircularProgressIndicator(color: kWebCoral)
                  : OutlinedButton(
                      onPressed: onLoadMore,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kWebCoralDark,
                        side: BorderSide(color: kWebCoral.withOpacity(0.5)),
                      ),
                      child: const Text('Charger plus'),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Center(
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
    );
  }
}
