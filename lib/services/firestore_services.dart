import 'package:rider_ride_hailing_app/utils/platform.dart';

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rider_ride_hailing_app/utils/file_upload.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rider_ride_hailing_app/modal/global_settings_modal.dart';
import 'package:rider_ride_hailing_app/modal/loyalty_config_modal.dart';
import 'package:rider_ride_hailing_app/modal/vehicle_modal.dart';
import 'package:rider_ride_hailing_app/models/pricing/pricing_config_v2.dart';
import 'package:rider_ride_hailing_app/services/firebase_access_token.dart';
import 'package:rider_ride_hailing_app/services/firebase_push_notifications.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import '../contants/global_data.dart';

class FirestoreServices {
  static final CollectionReference users =
      FirebaseFirestore.instance.collection('users');
  static final CollectionReference ratings =
      FirebaseFirestore.instance.collection('ratings');
  static final CollectionReference vehicleTypes =
      FirebaseFirestore.instance.collection('vehicleType');
  static final CollectionReference vehicleChangeRequest =
      FirebaseFirestore.instance.collection('vehicleChangeRequests');
  static final CollectionReference bookingRequest =
      FirebaseFirestore.instance.collection('bookingRequest');
  static final CollectionReference bookingHistory =
      FirebaseFirestore.instance.collection('bookingHistory');
  static final CollectionReference reasons =
      FirebaseFirestore.instance.collection('cancelledReasonDriver');
  static final CollectionReference notifications =
      users.doc(userData.value!.id).collection('notifications');
  static final CollectionReference savedPaymentMethods =
      users.doc(userData.value!.id).collection('savedPaymentMethods');
  static final CollectionReference bankDetails =
      users.doc(userData.value!.id).collection('banksDetailsLists');
  // static final CollectionReference withdrawal_request =   users.doc(currentUser!.uid).collection('withdrawal_request');
  static final CollectionReference walletHistory =
      users.doc(userData.value!.id).collection('wallet_history');
  static final CollectionReference support =
      FirebaseFirestore.instance.collection('driverSupport');
  static final CollectionReference settings =
      FirebaseFirestore.instance.collection('setting');
  static final CollectionReference content =
      FirebaseFirestore.instance.collection('content');
  static final CollectionReference cancelledBooking =
      FirebaseFirestore.instance.collection('cancelledBooking');
  static final CollectionReference promocodesCollection =
      FirebaseFirestore.instance.collection('promocodes');
  
  // Collections pour le portefeuille numérique
  static final CollectionReference wallets =
      FirebaseFirestore.instance.collection('wallets');
  static final CollectionReference walletTransactions =
      FirebaseFirestore.instance.collection('wallet_transactions');
  
  // Collections pour le système de fidélité
  static final CollectionReference loyaltyHistory =
      users.doc(userData.value!.id).collection('loyalty_history');

  static Future<bool> isPhoneAlreadyInUse(phone) async {
    var querySnapShot = await users
        .where('phone', isEqualTo: phone)
        .where('is_customer', isEqualTo: false)
        .get();
    if (querySnapShot.docs.isNotEmpty) {
      return true;
    } else {
      return false;
    }
  }

  static Future<void> getAndSetSettings() async {
    myCustomPrintStatement("getAndSetSettings called");
    try {
      var res = await settings.doc("BfnqY5zbKjRDEiUZbaCx").get()
          .timeout(const Duration(seconds: 5));
      if (res.exists) {
        Map s = res.data() as Map;
        DevFestPreferences()
            .setDefaultAppSettingRequest(res.data() as Map<String, dynamic>);
        globalSettings = GlobalSettingsModal.fromJson(s);
        myCustomPrintStatement("global settings-----------$s}-");
      }
    } catch (e) {
      myCustomPrintStatement("⚠️ Erreur chargement settings (timeout ou autre): $e");
      // Continuer avec les settings par défaut déjà définis
    }
  }

  static Future<void> getVehicleTypes() async {
    // Retry logic pour iOS où le chargement peut être lent
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final timeoutSeconds = attempt == 1 ? 8 : 15; // Plus de temps à la 2e tentative
        myCustomPrintStatement("🚗 Chargement types de véhicules (tentative $attempt/2, timeout ${timeoutSeconds}s)...");
        var res = await vehicleTypes.get()
            .timeout(Duration(seconds: timeoutSeconds));
        vehicleListMap = List.generate(
            res.docs.length, (index) => (res.docs[index].data() as Map)).toList();
        vehicleListMap.sort((a, b) => a['sequence']!.compareTo(b['sequence']!));
        vehicleListModal = List.generate(res.docs.length,
                (index) => (VehicleModal.fromJson(res.docs[index].data() as Map)))
            .toList();
        vehicleListModal.sort((a, b) => a.sequence.compareTo(b.sequence));

        for (int i = 0; i < vehicleListModal.length; i++) {
          vehicleMap[vehicleListModal[i].id] = vehicleListModal[i];
        }
        myCustomPrintStatement("✅ ${vehicleListModal.length} types de véhicules chargés");
        return; // Succès, sortir de la boucle
      } catch (e) {
        myCustomPrintStatement("⚠️ Tentative $attempt échouée: $e");
        if (attempt == 2) {
          myCustomPrintStatement("❌ Échec définitif chargement types de véhicules après 2 tentatives");
        }
      }
    }
  }

  /// Charge la configuration du système de tarification V2
  static Future<void> getPricingConfigV2() async {
    try {
      myCustomPrintStatement('FirestoreServices: Chargement de la configuration de tarification V2...');

      final docSnapshot = await FirebaseFirestore.instance
          .collection('setting')
          .doc('pricing_config_v2')
          .get()
          .timeout(const Duration(seconds: 5));
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        pricingConfigV2 = PricingConfigV2.fromJson(data);
        
        if (pricingConfigV2!.isValid()) {
          myCustomPrintStatement(
            'FirestoreServices: Configuration V2 chargée - System enabled: ${pricingConfigV2!.enableNewPricingSystem}',
            showPrint: true,
          );
        } else {
          myCustomPrintStatement(
            'FirestoreServices: Configuration V2 invalide, utilisation de la configuration par défaut',
            showPrint: true,
          );
          pricingConfigV2 = PricingConfigV2.defaultConfig();
        }
      } else {
        myCustomPrintStatement(
          'FirestoreServices: Configuration V2 non trouvée, utilisation de la configuration par défaut',
          showPrint: true,
        );
        pricingConfigV2 = PricingConfigV2.defaultConfig();
      }
    } catch (e) {
      myCustomPrintStatement(
        'FirestoreServices: Erreur chargement config V2 - $e. Utilisation configuration par défaut.',
        showPrint: true,
      );
      pricingConfigV2 = PricingConfigV2.defaultConfig();
    }
  }

  /// Charge la configuration du système de fidélité
  static Future<void> getLoyaltyConfig() async {
    try {
      myCustomPrintStatement('FirestoreServices: Chargement de la configuration de fidélité...');

      final docSnapshot = await FirebaseFirestore.instance
          .collection('setting')
          .doc('loyalty_config')
          .get()
          .timeout(const Duration(seconds: 5));
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        loyaltyConfig = LoyaltyConfigModal.fromJson(data);
        myCustomPrintStatement(
          'FirestoreServices: Configuration de fidélité chargée - Points per 1000 MGA: ${loyaltyConfig!.pointsPerThousandMGA}',
          showPrint: true,
        );
      } else {
        myCustomPrintStatement(
          'FirestoreServices: Configuration de fidélité non trouvée, utilisation de la configuration par défaut',
          showPrint: true,
        );
        loyaltyConfig = LoyaltyConfigModal.defaultConfig;
      }
    } catch (e) {
      myCustomPrintStatement(
        'FirestoreServices: Erreur chargement config fidélité - $e. Utilisation configuration par défaut.',
        showPrint: true,
      );
      loyaltyConfig = LoyaltyConfigModal.defaultConfig;
    }
  }

  static Future<List<String>> uploadMultipleImages(
      List<XFile> images, String path,
      {bool showloader = true}) async {
    List<String> imageURLs = [];
    // Animation désactivée selon demande du product owner
    // if (showloader == true) {
    //   await EasyLoading.show(status: null, maskType: EasyLoadingMaskType.black);
    // }
    for (XFile image in images) {
      File file = File(image.path);
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      try {
        final ref = FirebaseStorage.instance.ref('$path/$fileName');
        TaskSnapshot snapshot = await uploadFileToFirebase(file, ref);
        String downloadURL = await snapshot.ref.getDownloadURL();
        imageURLs.add(downloadURL);
      } catch (e) {
        myCustomPrintStatement('Error uploading image: $e');
      }
    }
    // Animation désactivée selon demande du product owner
    // if (showloader == true) {
    //   await EasyLoading.dismiss();
    // }
    return imageURLs;
  }

  /// Upload de bytes en mémoire vers Storage (web-safe : pas de `File` disque).
  /// Utilisé pour persister les factures PDF générées côté navigateur.
  static Future<String> uploadBytes(Uint8List bytes, String path,
      String fileName, {String contentType = 'application/pdf'}) async {
    try {
      final Reference storageReference =
          FirebaseStorage.instance.ref(path).child(fileName);
      final TaskSnapshot uploadTask = await storageReference.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (err) {
      myCustomPrintStatement('uploadBytes error: $err');
      return "";
    }
  }

  static Future<String> uploadFile(File file, String path,
      {bool showloader = true}) async {
    var a = file.path.toString().split('/');
    myCustomPrintStatement('ttkejekljkskf $a');
    String fileName = a[a.length - 1];
    // fileName=fileName.substring(0,fileName.length-1);
    myCustomPrintStatement("fileName____________$fileName");
    // Animation désactivée selon demande du product owner
    // if (showloader == true) {
    //   await EasyLoading.show(status: null, maskType: EasyLoadingMaskType.black);
    // }
    final Reference storageReference =
        FirebaseStorage.instance.ref(path).child(fileName);
    final TaskSnapshot uploadTask = await uploadFileToFirebase(file, storageReference);
    try {
      var downloadUrl = await uploadTask.ref.getDownloadURL();
      if (showloader == true) {
        await EasyLoading.dismiss();
      }
      myCustomPrintStatement("object=================$downloadUrl");
      return downloadUrl;
    } catch (err) {
      if (showloader == true) await EasyLoading.dismiss();
      return "";
    }
  }

  static Future<void> deleteUploadedImage(String imageUrl,
      {bool showLoader = true}) async {
    // Animation désactivée selon demande du product owner
    // if (showLoader) {
    //   await EasyLoading.show(status: null, maskType: EasyLoadingMaskType.black);
    // }
    if (imageUrl != dummyUserImage) {
      try {
        myCustomPrintStatement(imageUrl);
        // Parse the image URL to extract the path or filename
        // For example, if your image URL is gs://your-bucket-name/path/to/image.jpg
        // You need to extract "path/to/image.jpg"
        // You may need to customize this parsing based on your specific URL structure
        final Uri uri = Uri.parse(imageUrl);
        final String imagePath = uri.path;
        final decodedImagePath = Uri.decodeComponent(imagePath);
        myCustomPrintStatement(
            "image delete path is that ${decodedImagePath.split("misy-95336.appspot.com/o").last}");
        // Delete the image file from Firebase Storage
        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child(decodedImagePath.split("misy-95336.appspot.com/o").last);
        await storageRef.delete();

        // Image deletion successful
        myCustomPrintStatement('Image deleted successfully');
      } catch (error) {
        // Handle errors
        myCustomPrintStatement('Error deleting image: $error');
      }
    } else {
      myCustomPrintStatement("Request for detele static image");
    }
    // Animation désactivée selon demande du product owner
    // if (showLoader) {
    //   await EasyLoading.dismiss();
    // }
  }

  static Future<List<Map>> getReasons() async {
    var res = await reasons.get();
    return List.generate(
        res.docs.length, (index) => (res.docs[index].data() as Map)).toList();
  }

  // static Future<List<Map>> getBookings() async {
  //   var res = await bookingHistory.where('acceptedBy',isEqualTo: currentUser!.uid).orderBy('endTime',descending: true).get();
  //   return List.generate(
  //       res.docs.length,
  //           (index)  {
  //         Map d = res.docs[index].data() as Map;
  //         d['docId']=res.docs[index].id;
  //         return d;
  //       }).toList();
  // }

  static Future clearAllDataFromCollection(
      CollectionReference collectionRefrence,
      {bool showLoader = false}) async {
    // Animation désactivée selon demande du product owner
    // if (showLoader) {
    //   await EasyLoading.show(status: null, maskType: EasyLoadingMaskType.black);
    // }
    try {
      // Get all documents within the collection
      QuerySnapshot querySnapshot = await collectionRefrence.get();

      // Iterate over each document in the query snapshot
      // ignore: avoid_function_literals_in_foreach_calls
      querySnapshot.docs.forEach((doc) async {
        // Delete each document
        await doc.reference.delete();
      });

      myCustomPrintStatement('All documents deleted successfully');
    } catch (e) {
      // Handle any errors that may occur
      myCustomPrintStatement('Error deleting documents: $e');
    }
    // Animation désactivée selon demande du product owner
    // if (showLoader) {
    //   await EasyLoading.dismiss();
    // }
  }

  static Future<List<String>> sendNotificationToAllNearbyDriversDeviceIds(
      List<String> vehicleTypeId, double pickLat, double pickLng,
      {isScheduled = false, String? bookingId}) async {
    
    // Si feature flag activé ET bookingId fourni → Mode séquentiel
    if (globalSettings.enableSequentialNotification && bookingId != null) {
      return await sendSequentialNotifications(
        vehicleTypeId, pickLat, pickLng,
        isScheduled: isScheduled,
        bookingId: bookingId
      );
    }
    
    // Sinon → Mode legacy (code existant inchangé)
    try {
      myCustomPrintStatement('sendNotification ------------');
      var querySnapshot = await users
          .where('isCustomer', isEqualTo: false)
          .where('isBlocked', isEqualTo: false)
          .where('vehicleType', whereIn: vehicleTypeId)
          .where('isOnline', isEqualTo: true)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        List deviceIds = [];
        List driverIds = [];
        List<String> onlySendTo = [];
        List<String> filterDriverIds = [];
        // ignore: avoid_function_literals_in_foreach_calls
        querySnapshot.docs.forEach((element) {
          Map user =
              (element.data() as Map<String, dynamic>); //['deviceIdList']??[];
          if (getDistance(
                  user['currentLat'], user['currentLng'], pickLat, pickLng) <=
              ((isScheduled == false)
                  ? globalSettings.distanceLimitNow
                  : globalSettings.distanceLimitScheduled)) {
            user['near'] = getDistance(
                user['currentLat'], user['currentLng'], pickLat, pickLng);

            driverIds.add(user);
          }
        });

        driverIds.sort((a, b) {
          return a['near'].compareTo(b['near']);
        });

        filterDriverIds = List.generate(
          driverIds.length,
          (index) => driverIds[index]['id'],
        );
        List<List<dynamic>> chunks = chunkList(filterDriverIds, 29);

        myCustomLogStatements(
            "filterDriverIds --->>> ${filterDriverIds.length}");
        myCustomLogStatements("filterDriverIds --->>> ${chunks.length}");
        myCustomLogStatements("filterDriverIds --->>> ${chunks}");
        if (isScheduled == false && filterDriverIds.isNotEmpty) {
          // Query composite isSchedule+scheduleTime+acceptedBy → exige un index
          // Firestore composite. Si l'index manque, la query throw et le
          // try/catch global plus haut avalerait silencieusement l'exception
          // → return [] → course annulée à tort. On isole donc dans son
          // propre try/catch : un échec ici ne doit jamais bloquer le matching.
          try {
            final now = Timestamp.now();
            final oneHourLater =
                Timestamp.fromDate(now.toDate().add(const Duration(hours: 1)));
            for (var i = 0; i < chunks.length; i++) {
              var driverWhoHaveBooking = await bookingRequest
                  .where('scheduleTime', isGreaterThanOrEqualTo: now)
                  .where('scheduleTime', isLessThan: oneHourLater)
                  .where('isSchedule', isEqualTo: true)
                  .where('acceptedBy',
                      whereIn: chunks[i]) // Filter acceptedBy field
                  .get();
              if (driverWhoHaveBooking.docs.isNotEmpty) {
                for (var doc in driverWhoHaveBooking.docs) {
                  var removeDriverData = doc.data() as Map;
                  driverIds.removeWhere(
                    (element) =>
                        element['id'] == removeDriverData['acceptedBy'],
                  );
                }
              }
            }
          } catch (e) {
            myCustomLogStatements(
                "⚠ Scheduled-busy filter failed (index?) — continuing without filter: $e");
          }
        }
        int request = (isScheduled == false)
            ? globalSettings.receiveRideRequest
            : globalSettings.scheduleReceiveRideRequest;
        int brokeCondition =
            driverIds.length < request ? driverIds.length : request;
        for (var i = 0; i < brokeCondition; i++) {
          List ids = driverIds[i]['deviceId'] ?? [];
          deviceIds += ids;
          onlySendTo.add(driverIds[i]['id']);
          myCustomPrintStatement('sendNotification -----------1111-');
        
        }
        deviceIds.toSet().toList();
        onlySendTo.toSet().toList();
        sendnoti(
            brokeCondition: brokeCondition,
            driverIds: driverIds,
            isScheduled: isScheduled);
        return onlySendTo;
      } else {
        myCustomPrintStatement('No nearby drivers found');
        return [];
      }
    } catch (e) {
      myCustomLogStatements("Error while creating request ${e}");
      return [];
    }
  }

  static List<List<dynamic>> chunkList(List<dynamic> list, int chunkSize) {
    List<List<dynamic>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(
          i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  static sendnoti({
    required int brokeCondition,
    required List driverIds,
    required bool isScheduled,
  }) async {
    String accessToken =
        await FirebaseAccessToken().getFirebaseAccessToken() ?? '';
    if (accessToken.isEmpty) {
      return;
    }
    for (var i = 0; i < brokeCondition; i++) {
      List ids = driverIds[i]['deviceId'] ?? [];

      myCustomPrintStatement('sendNotification -----------1111-');
      FirebasePushNotifications.sendPushNotifications(
          deviceIds: ids,
          acessToken: accessToken,
          data: {
            'screen': (isScheduled == true)
                ? 'scheduled_ride_request'
                : 'ride_request'
          },
          body: (isScheduled == false)
              ? translateToSpecificLangaue(
                  key: "rideRequestMsg",
                  languageCode: driverIds[i]['preferedLanguage'],
                )
              : translateToSpecificLangaue(
                  key: "New Schedule ride incoming request",
                  languageCode: driverIds[i]['preferedLanguage'],
                ),
          userId: driverIds[i]['id'],
          isOnline:  driverIds[i]['isOnline'] ??false,
          title: translateToSpecificLangaue(
            key: "rideRequest",
            languageCode: driverIds[i]['preferedLanguage'],
          ));
      // }
    }
  }

  // === NOTIFICATION POUR CHAUFFEUR PRÉ-ASSIGNÉ (Central de réservation) ===

  /// Envoie une notification push à un chauffeur spécifique (pré-assigné par
  /// le super user). Utilisé par la centrale de réservation pour assigner
  /// directement un chauffeur sans passer par le matching séquentiel.
  static Future<void> sendNotificationToSpecificDriver(
    String driverId, {
    required String bookingId,
    bool isPreAssigned = false,
  }) async {
    try {
      myCustomPrintStatement(
          '👨‍✈️ Envoi notification au chauffeur pré-assigné: $driverId');

      final driverDoc = await users.doc(driverId).get();
      if (!driverDoc.exists) {
        myCustomPrintStatement('⚠️ Chauffeur $driverId non trouvé');
        return;
      }

      final driverData = driverDoc.data() as Map<String, dynamic>;
      final List deviceIds = driverData['deviceId'] ?? [];
      final String language = driverData['preferedLanguage'] ?? 'fr';
      final bool isOnline = driverData['isOnline'] ?? false;

      if (deviceIds.isEmpty) {
        myCustomPrintStatement('⚠️ Aucun deviceId pour le chauffeur $driverId');
        return;
      }

      String accessToken =
          await FirebaseAccessToken().getFirebaseAccessToken() ?? '';
      if (accessToken.isEmpty) {
        myCustomPrintStatement('⚠️ Impossible d\'obtenir le token Firebase');
        return;
      }

      await FirebasePushNotifications.sendPushNotifications(
        deviceIds: deviceIds,
        acessToken: accessToken,
        data: {
          'screen': 'scheduled_ride_request',
          'preAssigned': 'true',
          'bookingId': bookingId,
        },
        body: translateToSpecificLangaue(
          key: isPreAssigned ? "preAssignedRideMsg" : "rideRequestMsg",
          languageCode: language,
        ),
        userId: driverId,
        isOnline: isOnline,
        title: translateToSpecificLangaue(
          key: isPreAssigned ? "preAssignedRide" : "rideRequest",
          languageCode: language,
        ),
      );

      myCustomPrintStatement('✅ Notification envoyée au chauffeur $driverId');
    } catch (e) {
      myCustomPrintStatement('❌ Erreur envoi notification au chauffeur: $e');
    }
  }

  // === MÉTHODES POUR LA NOTIFICATION SÉQUENTIELLE ===

  /// Nouvelle méthode séquentielle pour notifier les chauffeurs un par un
  static Future<List<String>> sendSequentialNotifications(
      List<String> vehicleTypeId, double pickLat, double pickLng,
      {required bool isScheduled, required String bookingId}) async {
    
    try {
      myCustomPrintStatement('Starting sequential notifications for booking: $bookingId');
      
      // 1. Récupérer et trier les chauffeurs (même logique que legacy)
      List<String> sortedDriverIds = await _getSortedNearbyDrivers(
        vehicleTypeId, pickLat, pickLng, isScheduled: isScheduled
      );
      
      if (sortedDriverIds.isEmpty) {
        myCustomPrintStatement(
            '🚨 No drivers found for sequential notification — cleaning placeholder');
        // CRITIQUE : nettoyer le placeholder showOnly et poser noDriverFound
        // pour ne pas laisser le booking en limbo. Sans ce cleanup, le doc
        // reste avec showOnly=[] et noDriverFound absent → course fantôme
        // côté admin jusqu'à checkAndReset.
        try {
          await bookingRequest.doc(bookingId).update({
            'showOnly': FieldValue.delete(),
            'sequentialMode': false,
            'noDriverFound': true,
            'noDriverFoundAt': Timestamp.now(),
          });
        } catch (e) {
          myCustomLogStatements('⚠ Cleanup placeholder failed: $e');
        }
        return [];
      }
      
      myCustomPrintStatement('Found ${sortedDriverIds.length} drivers for sequential notification');

      // 2. Notifier le premier BATCH de chauffeurs (ex: 3 les plus proches)
      // Le batch size est configurable via sequentialBatchSize (dashboard settings).
      // Défaut 3 pour éviter que chaque séquence ne notifie qu'un seul driver
      // (goulot latence Firestore/FCM rend le single trop lent en pratique).
      final int batchSize = globalSettings.sequentialBatchSize.clamp(1, 10);
      final int firstBatchEnd = batchSize.clamp(1, sortedDriverIds.length);
      final List<String> firstBatch = sortedDriverIds.sublist(0, firstBatchEnd);

      await bookingRequest.doc(bookingId).update({
        'sequentialMode': true,
        'currentNotifiedDriverIndex': firstBatchEnd - 1,
        'notificationStartTime': Timestamp.now(),
        'sequentialDriversList': sortedDriverIds,
        'showOnly': firstBatch, // Tous les drivers du 1er batch sont visibles
        'lastNotificationTime': Timestamp.now(),
      });

      // 3. Notifier tous les chauffeurs du batch en parallèle
      await Future.wait(
        List.generate(firstBatch.length,
            (i) => _notifyDriverAtIndex(sortedDriverIds, i, isScheduled)),
      );

      myCustomPrintStatement(
          'Sequential notification: Notified first batch of ${firstBatch.length} driver(s): ${firstBatch.join(", ")}');
      return firstBatch;
      
    } catch (e) {
      myCustomLogStatements("Error in sequential notifications: $e");
      
      // Fallback au système legacy si configuré
      if (globalSettings.sequentialFallbackToLegacy) {
        myCustomPrintStatement('Falling back to legacy notification system');
        return await _sendLegacyNotifications(vehicleTypeId, pickLat, pickLng, isScheduled: isScheduled);
      }
      
      return [];
    }
  }

  /// Wrapper public pour _getSortedNearbyDrivers — utilisé par TripProvider
  /// pour rafraîchir périodiquement la liste pendant que la course est PENDING
  /// (Fix #1 — drivers qui passent online après T=0 sont intégrés au fil du temps).
  static Future<List<String>> refreshSortedNearbyDrivers(
      List<String> vehicleTypeId, double pickLat, double pickLng,
      {required bool isScheduled}) async {
    return _getSortedNearbyDrivers(vehicleTypeId, pickLat, pickLng,
        isScheduled: isScheduled);
  }

  /// Récupère et trie les chauffeurs proches (extrait de la logique legacy)
  static Future<List<String>> _getSortedNearbyDrivers(
      List<String> vehicleTypeId, double pickLat, double pickLng,
      {required bool isScheduled}) async {
    
    try {
      var querySnapshot = await users
          .where('isCustomer', isEqualTo: false)
          .where('isBlocked', isEqualTo: false)
          .where('vehicleType', whereIn: vehicleTypeId)
          .where('isOnline', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        myCustomPrintStatement(
            '🚨 _getSortedNearbyDrivers: 0 driver matching query (vehicleTypes=$vehicleTypeId)');
        return [];
      }

      List driverIds = [];
      int skippedNoGps = 0;
      int skippedOutOfRange = 0;

      final double distanceLimit = (isScheduled == false)
          ? globalSettings.distanceLimitNow
          : globalSettings.distanceLimitScheduled;

      // Filtrer par distance.
      // 🔥 Garde défensive : un chauffeur dont currentLat/currentLng est null
      // ne doit JAMAIS faire échouer la requête entière (ex: chauffeur online
      // mais qui n'a jamais push sa position). getDistance() retourne
      // double.infinity dans ce cas → naturellement filtré par le test.
      for (var element in querySnapshot.docs) {
        Map user = (element.data() as Map<String, dynamic>);
        final lat = user['currentLat'];
        final lng = user['currentLng'];

        if (lat is! num || lng is! num) {
          skippedNoGps++;
          continue;
        }

        double distance = getDistance(lat, lng, pickLat, pickLng);

        if (distance <= distanceLimit) {
          user['near'] = distance;
          user['id'] = element.id;
          driverIds.add(user);
        } else {
          skippedOutOfRange++;
        }
      }

      myCustomPrintStatement(
          '🎯 _getSortedNearbyDrivers: ${driverIds.length} candidats (skip GPS-null=$skippedNoGps, out-of-range=$skippedOutOfRange)');

      // Trier par proximité
      driverIds.sort((a, b) {
        return a['near'].compareTo(b['near']);
      });

      List<String> sortedDriverIds = List.generate(
        driverIds.length,
        (index) => driverIds[index]['id'],
      );

      return sortedDriverIds;

    } catch (e, st) {
      myCustomLogStatements("Error getting sorted drivers: $e\n$st");
      return [];
    }
  }

  /// Notifie un chauffeur spécifique à un index donné
  static Future<void> _notifyDriverAtIndex(
      List<String> driverIds, int index, bool isScheduled) async {
    
    if (index >= driverIds.length) {
      myCustomPrintStatement('Index $index out of bounds for driver list');
      return;
    }
    
    String driverId = driverIds[index];
    
    try {
      var driverDoc = await users.doc(driverId).get();
      
      if (!driverDoc.exists) {
        myCustomPrintStatement('Driver document not found: $driverId');
        return;
      }
      
      Map driverData = driverDoc.data() as Map;
      List deviceIds = driverData['deviceId'] ?? [];
      
      if (deviceIds.isEmpty) {
        myCustomPrintStatement('No device IDs for driver: $driverId');
        return;
      }
      
      String accessToken = await FirebaseAccessToken().getFirebaseAccessToken() ?? '';
      if (accessToken.isEmpty) {
        myCustomPrintStatement('No Firebase access token available');
        return;
      }
      
      myCustomPrintStatement('Sending notification to driver: $driverId');
      
      FirebasePushNotifications.sendPushNotifications(
        deviceIds: deviceIds,
        acessToken: accessToken,
        data: {'screen': isScheduled ? 'scheduled_ride_request' : 'ride_request'},
        body: translateToSpecificLangaue(
          key: isScheduled ? "New Schedule ride incoming request" : "rideRequestMsg",
          languageCode: driverData['preferedLanguage'],
        ),
        userId: driverId,
        isOnline: driverData['isOnline'] ?? false,
        title: translateToSpecificLangaue(
          key: "rideRequest",
          languageCode: driverData['preferedLanguage'],
        )
      );
      
    } catch (e) {
      myCustomLogStatements("Error notifying driver at index $index: $e");
    }
  }

  /// Passe au chauffeur suivant dans la séquence
  static Future<void> notifyNextDriverInSequence(String bookingId) async {
    try {
      var bookingDoc = await bookingRequest.doc(bookingId).get();
      
      if (!bookingDoc.exists) {
        myCustomPrintStatement('Booking not found: $bookingId');
        return;
      }
      
      Map bookingData = bookingDoc.data() as Map;
      
      if (!(bookingData['sequentialMode'] ?? false)) {
        myCustomPrintStatement('Booking not in sequential mode: $bookingId');
        return;
      }
      
      List<String> allDriverIds = List<String>.from(bookingData['sequentialDriversList'] ?? []);
      int currentIndex = bookingData['currentNotifiedDriverIndex'] ?? 0;
      int nextIndex = currentIndex + 1;
      
      if (nextIndex >= allDriverIds.length) {
        myCustomPrintStatement('Sequential notification: No more drivers available for booking $bookingId');
        return;
      }

      // Batch : notifier les N prochains drivers d'un coup (configurable via sequentialBatchSize)
      final int batchSize = globalSettings.sequentialBatchSize.clamp(1, 10);
      final int batchEnd =
          (nextIndex + batchSize).clamp(nextIndex + 1, allDriverIds.length);
      final List<String> nextBatch = allDriverIds.sublist(nextIndex, batchEnd);
      final int lastNotifiedIndex = batchEnd - 1;

      myCustomPrintStatement(
          'Sequential notification: Moving to next batch (indices $nextIndex → ${batchEnd - 1}) for booking $bookingId');

      // Ajouter le batch entier à showOnly et mettre à jour l'index
      List<String> currentShowOnly =
          List<String>.from(bookingData['showOnly'] ?? []);
      currentShowOnly.addAll(nextBatch);

      await bookingRequest.doc(bookingId).update({
        'currentNotifiedDriverIndex': lastNotifiedIndex,
        'showOnly': currentShowOnly,
        'lastNotificationTime': Timestamp.now(),
      });

      final bool isScheduled = bookingData['isSchedule'] ?? false;
      await Future.wait(
        List.generate(nextBatch.length,
            (i) => _notifyDriverAtIndex(allDriverIds, nextIndex + i, isScheduled)),
      );
      
    } catch (e) {
      myCustomLogStatements("Error in notifyNextDriverInSequence: $e");
    }
  }

  /// Fallback vers le système legacy
  static Future<List<String>> _sendLegacyNotifications(
      List<String> vehicleTypeId, double pickLat, double pickLng,
      {required bool isScheduled}) async {
    
    // Appeler la méthode legacy sans bookingId pour éviter la récursion
    return await sendNotificationToAllNearbyDriversDeviceIds(
      vehicleTypeId, pickLat, pickLng, isScheduled: isScheduled
    );
  }
}
