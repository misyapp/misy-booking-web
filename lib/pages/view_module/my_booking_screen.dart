
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/widget/ride_tile.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/custom_text.dart';

class MyBookingScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const MyBookingScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<MyBookingScreen> createState() => _MyBookingScreenState();
}

class _MyBookingScreenState extends State<MyBookingScreen> {
  ValueNotifier<int> defaultController = ValueNotifier(0);
  TripProvider? _tripProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var tripProvider = Provider.of<TripProvider>(context, listen: false);
      tripProvider.scheduledBookingListener();
      tripProvider.getMyBookingList(); // Charge les trajets terminés
      tripProvider.getMyCurrentList(); // Charge les trajets actuels
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tripProvider = Provider.of<TripProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _tripProvider?.disposeScheduledBookingListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    return WillPopScope(
      onWillPop: () async {
        if (widget.onBack != null) {
          widget.onBack!();
          return false;
        }
        return true;
      },
      child: ValueListenableBuilder(
        valueListenable: defaultController,
        builder: (context, value, child) => DefaultTabController(
          length: 2,
          initialIndex: value,
          child: Scaffold(
                appBar: CustomAppBar(
                  toolbarHeight: 100,
                  title: translate('MyBookings'),
                  isBackIcon: true,
                  onPressed: () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(50.0),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            indicatorColor: MyColors.blackThemeColor(),
                            indicatorSize: TabBarIndicatorSize.label,
                            labelColor: MyColors.blackThemeColor(),
                            dividerColor: Colors.transparent,
                            labelStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            unselectedLabelColor: MyColors.blackThemeColorWithOpacity(0.6),
                            unselectedLabelStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            tabs: [
                              Tab(text: translate('CurrentBooking')),
                              Tab(text: translate('PastBooking')),
                            ],
                          ),
                        ),
                        Container(
                          height: 2,
                          color: const Color(0xFF333333).withOpacity(0.2),
                        )
                      ],
                    ),
                  ),
                ),
                body: Consumer<TripProvider>(
                  builder: (context, bookingProvider, child) {
                    return TabBarView(
                      children: [
                        currentBooking(bookingProvider),
                        pastBooking(bookingProvider),
                      ],
                    );
                  },
                ),
              ),
            ),
        ),
    );
  }

  currentBooking(TripProvider bookingProvider) {
    final allowedStatuses = ['pending', 'accepted', 'started', 'arrived', 'pickedUp'];
    
    // Combinez les réservations actuelles et planifiées
    final currentBookings = bookingProvider.myCurrentBookings
        .where((booking) => allowedStatuses.contains(booking['status']))
        .toList();
    final scheduledBookings = bookingProvider.scheduledBookingsList;

    final allBookings = [...currentBookings, ...scheduledBookings];

    // Triez les réservations par date (les plus proches en premier)
    allBookings.sort((a, b) {
      DateTime timeA = (a['scheduleTime'] as Timestamp).toDate();
      DateTime timeB = (b['scheduleTime'] as Timestamp).toDate();
      return timeA.compareTo(timeB);
    });

    // Afficher le contenu avec le bouton toujours visible
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Liste des courses ou message si vide
          Expanded(
            child: allBookings.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 80,
                          color: MyColors.blackThemeColorWithOpacity(0.5),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Aucun trajet à venir",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: MyColors.blackThemeColor(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            "Peur de rater un rendez-vous à cause des bouchons ? Planifiez votre trajet à l'avance et arrivez à l'heure, en toute sérénité.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: MyColors.blackThemeColorWithOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: allBookings.length,
                    padding: const EdgeInsets.symmetric(
                        horizontal: globalHorizontalPadding, vertical: 20),
                    itemBuilder: (context, index) {
                      var booking = allBookings[index];
                      return RideTile(booking: booking, isPast: false);
                    },
                  ),
          ),
          // Bouton "Planifier un trajet" toujours visible en bas
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () async {
                // Log Analytics event pour clic bouton course planifiée
                final userDetails = await DevFestPreferences().getUserDetails();
                final userId = userDetails?.id;

                await AnalyticsService.logScheduledRideButtonClicked(
                  userId: userId,
                );

                // Utiliser le même flow que le bouton "Trajets planifiés" depuis l'accueil
                // 1. Naviguer vers le menu principal (index 0 = Home)
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.of(context).pop();
                }

                // 2. Attendre que la navigation soit terminée, puis déclencher le flow
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Provider.of<TripProvider>(context, listen: false)
                      .setScreen(CustomTripType.selectScheduleTime);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5357),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Planifier un trajet",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pastBooking(TripProvider bookingProvider) {
    // Combiner les courses terminées et annulées
    final List allPastBookings = [
      ...bookingProvider.myPastBookings,
      ...bookingProvider.myCancelledBookings,
    ];

    // Trier par date (les plus récentes en premier)
    allPastBookings.sort((a, b) {
      // Utiliser endTime pour les terminées, cancelledAt pour les annulées
      DateTime? timeA;
      DateTime? timeB;

      if (a['endTime'] != null) {
        timeA = (a['endTime'] as Timestamp).toDate();
      } else if (a['cancelledAt'] != null) {
        timeA = (a['cancelledAt'] as Timestamp).toDate();
      } else if (a['scheduleTime'] != null) {
        timeA = (a['scheduleTime'] as Timestamp).toDate();
      }

      if (b['endTime'] != null) {
        timeB = (b['endTime'] as Timestamp).toDate();
      } else if (b['cancelledAt'] != null) {
        timeB = (b['cancelledAt'] as Timestamp).toDate();
      } else if (b['scheduleTime'] != null) {
        timeB = (b['scheduleTime'] as Timestamp).toDate();
      }

      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;

      return timeB.compareTo(timeA); // Plus récentes en premier
    });

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        allPastBookings.isEmpty
            ? Center(
                child: SubHeadingText(
                  translate('noDataFound'),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              )
            : Expanded(
                child: ListView.builder(
                    itemCount: allPastBookings.length,
                    padding: const EdgeInsets.symmetric(
                        horizontal: globalHorizontalPadding, vertical: 20),
                    itemBuilder: (context, index) {
                      var booking = allPastBookings[index];
                      return RideTile(booking: booking, isPast: true);
                    }),
              )
      ],
    );
  }
}
