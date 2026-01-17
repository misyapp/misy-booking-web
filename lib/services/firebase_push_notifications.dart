// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:convert';
import 'dart:developer';
import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/my_booking_screen.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_chat_provider.dart';
import 'package:rider_ride_hailing_app/pages/view_module/trip_chat_screen.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/services/firebase_access_token.dart';
import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/services/firestore_services.dart';

// {receiver: 51, sender: 55, screen: chat_page}

String firebaseNotificationAppId =
    // "AAAAO12B4OE:APA91bEtm29N0Fm2EUUYBRwyFitppjfIbqJDYBgJhq1DIlvzumsZyncnHMKVHthwfflKI0WLMSJ7Nqil27xCuhbCWWwaZ8daWvqY9Da8iyypG0h7Ybhv3A_vcmiuoL4S3oQvpJcjRO3R";
    "AAAAO12B4OE:APA91bGeEVF5O1peZPu2mLvxlFmOh7XgwbPkOi-3J3qNeUIayn4Ro4CPZGQtVuheAFsmJfJYmwpC1DIxLjnBqcG0ZaBdvzBoOxCro5pTZqTrJRflSapHntPz9cRuA-Py94snF-6q8zlz";
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  importance: Importance.high,
  playSound: true,
);
String deviceId = "";
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
InitializationSettings initializationSettings = const InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: DarwinInitializationSettings(),
);

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  myCustomPrintStatement('A bg message just showed up :  ${message.messageId}');
  myCustomPrintStatement('${message.data}');
  // push(
  //     context: MyGlobalKeys.navigatorKey.currentContext!,
  //     screen: const MailBox());
}

class FirebasePushNotifications {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static const String webPushCertificateKey =
      'BBRD9BxyN3SPaNejDtDvdveIPGT6R5S27c4h1zOy3c4AdmG5cHwbuwjS293Wfh5X60XKfxw-sJdAXSGqMDh-Phc';

  /// this token is used to send notification // use the returned token to send messages to users from your custom server
  static String? token;

  static Future<NotificationSettings> getPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    myCustomPrintStatement(
        'User granted permission: ${settings.authorizationStatus}');
    return settings;
  }

  static Future<String?> getToken() async {
    try {
      // token = await messaging.getToken(vapidKey: webPushCertificateKey);
      token = await messaging.getToken();
      myCustomPrintStatement("Token Is That $token");
      return token;
    } catch (e) {
      // 🔧 FIX: Sur iOS, le token APNS peut ne pas être disponible immédiatement
      // après le login (erreur firebase_messaging/apns-token-not-set)
      // On retourne null et on réessaiera plus tard
      myCustomPrintStatement("⚠️ FCM Token non disponible: $e");
      return null;
    }
  }

  static Future<void> firebaseSetup() async {
    await getPermission();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (dd) {
      var jsonPayload = jsonDecode(dd.payload!);
      myCustomPrintStatement("my notification open when i tapped $jsonPayload");
      navigationScreen(jsonPayload);
    });
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      myCustomPrintStatement('firebase messaging is being listened');
      try {
        RemoteNotification? notification = message.notification;
        var data = message.data;

        // MIZAN: Handle booking status update from foreground notification
        final screen = data['screen'];
        if (screen == 'driver_reached' ||
            screen == 'ride_completed' ||
            screen == 'booking_accepted' ||
            screen == 'ride_started' ||
            screen == 'ride_cancelled') {
          try {
            final tripProvider = Provider.of<TripProvider>(
                MyGlobalKeys.navigatorKey.currentContext!,
                listen: false);
            tripProvider.applyBookingStatusFromPush(data);
            myCustomPrintStatement('Applied booking status from foreground push: $data');
          } catch (e) {
            myCustomPrintStatement('Error applying booking status from push: $e');
          }
        }


        // log('notidata+--'+data.toString());
        // AndroidNotification? android = message.notification?.android;
        log('this is notification bb bb ---  ');
        myCustomPrintStatement('___________${notification.toString()}');
        myCustomPrintStatement('________________');
        myCustomPrintStatement(message.data);
        myCustomPrintStatement('________________');

        // Afficher la notification locale (Android et iOS)
        if (notification != null) {
          await flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                  android: AndroidNotificationDetails(
                    channel.id,
                    channel.name,
                    playSound: channel.playSound,
                    sound: channel.sound,
                    icon: '@drawable/ic_launcher',
                    styleInformation: const BigTextStyleInformation(''),
                  ),
                  iOS: const DarwinNotificationDetails(
                    presentAlert: true,
                    presentBadge: true,
                    presentSound: true,
                  )),
              payload: convert.jsonEncode(data));
          myCustomPrintStatement('the payLoad is $data');
        }
      } catch (e) {
        myCustomPrintStatement('error in listening notifications $e');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      myCustomPrintStatement('A new onMessageOpenedApp event was published!');
      myCustomPrintStatement(message.data);
      RemoteNotification? notification = message.notification;
      log('this is notification aa aa ---  ');

      if (notification != null) {}
      if (notification != null) {
        log('this is notification ---  ');

        try {
          navigationScreen(message.data);
        } catch (e) {
          myCustomPrintStatement('Error in Inside catch block $e');
        }
      }
    });

    await FirebaseMessaging.instance.getToken().then(
      (value) async {
        if (value != null) {
          myCustomPrintStatement('the device token is $value');
          deviceId = value;
        }
      },
      onError: (err) {
        myCustomLogStatements("erro token $err");
      },
    );
  }

  static navigationScreen(payload) {
    if (payload['screen'] == 'driver_reached' ||
        payload['screen'] == 'ride_completed' ||
        payload['screen'] == 'booking_accepted' ||
        payload['screen'] == 'ride_started' ||
        payload['screen'] == 'ride_cancelled') {

      // For scheduled booking acceptance notifications, don't force navigation
      // This prevents unwanted screen transitions
      if (payload['screen'] == 'booking_accepted') {
        myCustomPrintStatement('📢 Booking accepted notification - NOT forcing navigation to avoid screen transitions');
        // Just update the state via the push handler, don't navigate
        return;
      }

      // 🔧 FIX: Utiliser pushAndRemoveUntil vers MainNavigationScreen
      // au lieu de push(HomeScreen) pour éviter le Duplicate GlobalKey
      pushAndRemoveUntil(
          context: MyGlobalKeys.navigatorKey.currentContext!,
          screen: const MainNavigationScreen());
    } else if (payload['screen'] == 'rating') {
      push(
          context: MyGlobalKeys.navigatorKey.currentContext!,
          screen: const MyBookingScreen());
    } else if (payload['screen'] == 'chat_message') {
      // Navigation vers le chat quand l'utilisateur tape sur la notification
      try {
        final tripProvider = Provider.of<TripProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);

        // Vérifier qu'il y a une course active avec un chauffeur
        final booking = tripProvider.booking;
        final driver = tripProvider.acceptedDriver;

        if (booking != null && driver != null && payload['bookingId'] != null) {
          push(
            context: MyGlobalKeys.navigatorKey.currentContext!,
            screen: TripChatScreen(
              bookingId: payload['bookingId'],
              driver: driver,
            ),
          );
        } else {
          // 🔧 FIX: Utiliser pushAndRemoveUntil vers MainNavigationScreen
          // au lieu de push(HomeScreen) pour éviter le Duplicate GlobalKey
          myCustomPrintStatement('💬 Chat notification - no active booking, navigating to home');
          pushAndRemoveUntil(
            context: MyGlobalKeys.navigatorKey.currentContext!,
            screen: const MainNavigationScreen(),
          );
        }
      } catch (e) {
        myCustomPrintStatement('❌ Error navigating to chat from notification: $e');
      }
    }
  }

  /// Affiche une notification locale sur l'appareil de l'utilisateur
  /// Utilisé notamment pour informer le passager quand un chauffeur accepte une course réservée
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            playSound: channel.playSound,
            sound: channel.sound,
            icon: '@drawable/ic_launcher',
            styleInformation: BigTextStyleInformation(body),
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload != null ? convert.jsonEncode(payload) : null,
      );
      myCustomPrintStatement('📢 Notification locale affichée: $title');
    } catch (e) {
      myCustomPrintStatement('❌ Erreur affichage notification locale: $e');
    }
  }

  static Future sendPushNotifications(
      {required List deviceIds,
      required Map data,
      required String body,
      required String title,
      String? acessToken,
      bool isOnline = true,
      String? userId}) async {
    // Vérifier que la liste de device IDs n'est pas vide
    if (deviceIds.isEmpty) {
      myCustomPrintStatement('⚠️ Aucun device ID fourni pour la notification push');
      return;
    }

    String apiToken = "";
    if (acessToken == null) {
      apiToken = await FirebaseAccessToken().getFirebaseAccessToken()??'';
      if(apiToken.isEmpty){
        return ;
      }
    }
    myCustomPrintStatement("📱 Device IDs pour notification: $deviceIds");
    myCustomPrintStatement("📱 Premier token: ${deviceIds.first}");
    var request = {
      "message": {
        "token": deviceIds.first,
        "notification": {
          "body": body,
          "title": title,
        },
        
        "data": data,
      }
    };

    Map<String, String> headers = {
      "Content-Type": "application/json",
      "authorization": "Bearer ${acessToken ?? apiToken}",
    };

    print("notification sending---------");

    var response = await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/misy-95336/messages:send'),
        headers: headers,
        body: convert.jsonEncode(request));
    print('the response is ${response.statusCode}.... ${response.body}');
    if (response.statusCode == 200) {
      print('notification sent to ${deviceIds.length} devices');
    }
    if (userId != null && !isOnline) {
      await FirestoreServices.users
          .doc(userId)
          .collection('notifications')
          .doc()
          .set({
        "to": userId,
        "by": userData.value!.id,
        "type": "customer_to_driver",
        "title": title,
        "message": body,
        "read": false,
        "createdAt": Timestamp.now(),
        "id": DateTime.now().second
      });
    }
  }
}
