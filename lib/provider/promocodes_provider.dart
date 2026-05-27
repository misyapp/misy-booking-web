import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/promocodes_modal.dart';
import 'package:rider_ride_hailing_app/modal/vehicle_modal.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

class PromocodesProvider with ChangeNotifier {
  List<PromoCodeModal> promocodes = [];
  List<PromoCodeModal> filteredPromocodes = [];

  getPromoCodes() async {
    final userId = userData.value!.id;
    var result = await FirestoreServices.promocodesCollection
        .where("availableForUsers", arrayContains: userId)
        .where("status", isEqualTo: 1)
        .get();

    myCustomLogStatements(
        "promocode query returned ${result.docs.length} docs for user $userId");
    for (var doc in result.docs) {
      final data = doc.data() as Map<String, dynamic>;
      myCustomLogStatements(
          "  → code: ${data['code']}, status: ${data['status']}, usedBy: ${data['usedByUsers'] ?? data['usedBy']}, minRideAmount: ${data['minRideAmount']}, vehicleCategory: ${data['vehicleCategory']}");
    }

    // Filtrer côté client : exclure les codes déjà utilisés par l'user
    // (Firestore ne supporte pas arrayNotContains)
    promocodes = result.docs
        .map((doc) => PromoCodeModal.fromFirestore(doc))
        .where((promo) => !promo.usedBy.contains(userId))
        .toList();

    myCustomLogStatements(
        "promocode after usedBy filter: ${promocodes.length}");
    notifyListeners();
  }

  filterPromocodes(VehicleModal vehicleDetails, double rideAmount) {
    myCustomLogStatements(
        "filterPromocodes: vehicleId=${vehicleDetails.id}, rideAmount=$rideAmount, total promos=${promocodes.length}");
    filteredPromocodes = [];
    for (var i = 0; i < promocodes.length; i++) {
      myCustomLogStatements(
          "  → promo ${promocodes[i].code}: vehicleCategory=${promocodes[i].vehicleCategory}, minRideAmount=${promocodes[i].minRideAmount}, match=${(promocodes[i].vehicleCategory.isEmpty || promocodes[i].vehicleCategory.contains(vehicleDetails.id)) && rideAmount >= promocodes[i].minRideAmount}");
      if ((promocodes[i].vehicleCategory.isEmpty ||
              promocodes[i].vehicleCategory.contains(vehicleDetails.id)) &&
          rideAmount >= promocodes[i].minRideAmount) {
        filteredPromocodes.add(promocodes[i]);
      }
    }

    notifyListeners();
  }

  removePromocode(String promoCodeId) async {
    showLoading();
    try {
      // Retirer le code promo de la liste locale
      promocodes.removeWhere(
        (element) => element.id == promoCodeId,
      );

      // Retirer l'utilisateur de availableForUsers dans Firebase
      await FirestoreServices.promocodesCollection.doc(promoCodeId).update({
        "availableForUsers": FieldValue.arrayRemove([userData.value!.id]),
      });

      hideLoading();
      showSnackbar(translate("promoCodeDeleted"));
      notifyListeners();
    } catch (e) {
      hideLoading();
      showSnackbar(translate("promoCodeDeleteError"));
      // Recharger les codes promos en cas d'erreur
      getPromoCodes();
    }
  }

  applyForPromocode({required String code}) async {
    showLoading();

    // 1. Chercher le code promo par son code
    var promoQuery = await FirestoreServices.promocodesCollection
        .where("code", isEqualTo: code)
        .limit(1)
        .get();

    if (promoQuery.docs.isEmpty) {
      hideLoading();
      showSnackbar(translate("invalidCode"));
      return;
    }

    final promoDoc = promoQuery.docs.first;
    final promoData = promoDoc.data() as Map<String, dynamic>;
    final promoId = promoDoc.id;
    final userId = userData.value!.id;

    // 2. Vérifier si le code est actif
    if (promoData['status'] != 1) {
      hideLoading();
      showSnackbar(translate("codeExpiredOrDisabled"));
      return;
    }

    // 3. Vérifier si l'utilisateur a déjà utilisé ce code
    final List usedByUsers =
        promoData['usedBy'] ?? promoData['usedByUsers'] ?? [];
    if (usedByUsers.contains(userId)) {
      hideLoading();
      showSnackbar(translate("codeAlreadyUsed"));
      return;
    }

    // 4. Vérifier si le code est déjà dans la liste disponible
    final List availableForUsers = promoData['availableForUsers'] ?? [];
    if (availableForUsers.contains(userId)) {
      hideLoading();
      showSnackbar(translate("codeAlreadyActive"));
      // Recharger la liste au cas où elle n'est pas à jour
      getPromoCodes();
      return;
    }

    // 5. Ajouter le code à l'utilisateur
    await FirestoreServices.promocodesCollection.doc(promoId).update({
      "availableForUsers": FieldValue.arrayUnion([userId]),
    });

    hideLoading();
    showSnackbar(translate("promoCodeActivated"));
    getPromoCodes();
  }
}
