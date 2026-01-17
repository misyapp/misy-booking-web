import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/provider/navigation_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/firebase_push_notifications.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';

import '../../contants/global_data.dart';
import '../../contants/my_colors.dart';
import '../../contants/my_image_url.dart';
import '../../contants/sized_box.dart';
import '../../functions/navigation_functions.dart';
import '../../widget/custom_text.dart';
import '../../widget/input_text_field_widget.dart';
import '../../widget/round_edged_button.dart';
import '../../widget/circular_back_button.dart';
import '../../widget/store_review_dialog.dart';
import '../view_module/main_navigation_screen.dart';

// ignore: must_be_immutable
class RateUsScreen extends StatelessWidget {
  final Map booking;
  RateUsScreen({Key? key, required this.booking}) : super(key: key);

  double rating1 = 5.0;

  TextEditingController rateUsController = TextEditingController();

  final rateDriverFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            MyImagesUrl.bgImage,
            fit: BoxFit.cover,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
          ),
          
          // Bouton retour
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: CircularBackButton(
              onTap: () {
                // Retourner au menu principal et rétablir la navigation
                final navProvider = Provider.of<NavigationProvider>(context, listen: false);
                navProvider.setNavigationBarVisibility(true);

                // Réinitialiser l'état du trip avant de retourner au menu principal
                final tripProvider = Provider.of<TripProvider>(context, listen: false);
                tripProvider.resetAll();

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                  (route) => false,
                );
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: globalHorizontalPadding),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    MyImagesUrl.rateUs,
                    width: MediaQuery.of(context).size.width / 1.9,
                  ),
                  vSizedBox4,
                  SubHeadingText(
                    translate('RateDriver'),
                    fontSize: 20,
                    color: MyColors.blackThemeColor(),
                    fontWeight: FontWeight.w500,
                  ),
                  vSizedBox,
                  ParagraphText(
                    translate("Yourratingismostvaluableforotherusers"),
                    fontSize: 14,
                    color: MyColors.blackThemeColor(),
                    textAlign: TextAlign.center,
                    fontWeight: FontWeight.w400,
                  ),
                  vSizedBox3,
                  RatingBar(
                    initialRating: 5.0,
                    minRating: 1,
                    ignoreGestures: false,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemSize: 42,
                    ratingWidget: RatingWidget(
                      full: Image.asset(
                        MyImagesUrl.star,
                        color: const Color(0xFFFBBC04),
                      ),
                      half: Image.asset(MyImagesUrl.star),
                      empty: Image.asset(
                        MyImagesUrl.star,
                        color: MyColors.blackThemeColorWithOpacity(0.4),
                      ),
                    ),
                    onRatingUpdate: (rating) {
                      rating1 = rating;
                    },
                  ),
                  vSizedBox3,
                  Form(
                    key: rateDriverFormKey,
                    child: InputTextFieldWidget(
                      maxLines: 4,
                      borderColor: Colors.transparent,
                      fillColor: MyColors.whiteThemeColor(),
                      hintcolor: MyColors.blackThemeColorWithOpacity(0.3),
                      textColor: MyColors.blackThemeColor(),
                      controller: rateUsController,
                      hintText: translate("typeHere"),
                    ),
                  ),
                  vSizedBox,
                  RoundEdgedButton(
                    width: double.infinity,
                    onTap: () async {
                      if (rateDriverFormKey.currentState!.validate()) {
                        await showLoading();
                        await FirestoreServices.bookingHistory
                            .doc(booking['booking_id'])
                            .update({
                          "rating_by_customer": {
                            "rated_by": userData.value!.id,
                            "rated_to": booking['userId'],
                            "review": rateUsController.text,
                            "rating": rating1
                          }
                        });

                        var allRatings = await FirestoreServices.bookingHistory
                            .where('acceptedBy', isEqualTo: booking['userId'])
                            .get();
                        myCustomPrintStatement(
                            'rating-------a-----------------${allRatings.docs.length}------');
                        if (allRatings.docs.isNotEmpty) {
                          double sum = 0;
                          int count = 0;
                          for (int i = 0; i < allRatings.docs.length; i++) {
                            Map m = allRatings.docs[i].data() as Map;
                            if (m["rating_by_customer"] != null) {
                              sum = sum + m["rating_by_customer"]['rating'];
                              count = count + 1;
                            }
                          }
                          myCustomPrintStatement(
                              'rating------------------------$sum------$count');
                          double avg =
                              double.parse((sum / count).toStringAsFixed(1));
                          await FirestoreServices.users
                              .doc(booking['userId'])
                              .update({
                            "average_rating": avg,
                            "total_review": count,
                          });

                          if (booking['deviceId'].length > 0) {
                            FirebasePushNotifications.sendPushNotifications(
                              deviceIds: booking['deviceId'],
                              data: {
                                'screen': 'rating',
                              },
                              body:
                                  "${translateToSpecificLangaue(key: 'customerRatedYou', languageCode: booking['preferedLanguage'])} $rating1",
                              userId: booking['userId'],
                              title: translateToSpecificLangaue(
                                  key: 'Rating',
                                  languageCode: booking['preferedLanguage']),
                            );
                          }

                          // Cacher le loader AVANT d'afficher le dialog et de naviguer
                          await hideLoading();

                          // Afficher la demande d'avis store après la notation
                          // ignore: use_build_context_synchronously
                          await StoreReviewDialog.showIfFirstTrip(context);

                          // Réactiver la barre de navigation après la notation du chauffeur
                          // ignore: use_build_context_synchronously
                          final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
                          navigationProvider.setNavigationBarVisibility(true);

                          // Réinitialiser l'état du trip avant de retourner au menu principal
                          // ignore: use_build_context_synchronously
                          final tripProvider = Provider.of<TripProvider>(context, listen: false);
                          tripProvider.resetAll();

                          // Retourner au menu principal après la notation
                          // ignore: use_build_context_synchronously
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                            (route) => false,
                          );
                        } else {
                          await hideLoading();
                        }
                      }
                    },
                    verticalMargin: 20,
                    text: translate("submit"),
                  ),
                  TextButton(
                    onPressed: () {
                      // Réactiver la barre de navigation même si l'utilisateur skip la notation
                      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
                      navigationProvider.setNavigationBarVisibility(true);

                      // Réinitialiser l'état du trip avant de retourner au menu principal
                      final tripProvider = Provider.of<TripProvider>(context, listen: false);
                      tripProvider.resetAll();

                      // Retourner au menu principal après skip
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                        (route) => false,
                      );
                    },
                    child: ParagraphText(
                      translate('Skip'),
                      fontSize: 15,
                      color: MyColors.blackThemeColor(),
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
