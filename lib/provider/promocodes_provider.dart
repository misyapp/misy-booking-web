import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
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
    var result = await FirestoreServices.promocodesCollection
        .where("availableForUsers", arrayContains: userData.value!.id)
        .where("usedByUsers", whereNotIn: [userData.value!.id]).get();

    myCustomLogStatements("promocode ===== ${result.docs.length}");
    promocodes = List.generate(
      result.docs.length,
      (index) => PromoCodeModal.fromFirestore(result.docs[index]),
    );
    notifyListeners();
  }

  filterPromocodes(VehicleModal vehicleDetails,double rideAmount ) {
    filteredPromocodes = [];
    for (var i = 0; i < promocodes.length; i++) {
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
      await FirestoreServices.promocodesCollection
          .doc(promoCodeId)
          .update({
        "availableForUsers": FieldValue.arrayRemove([userData.value!.id]),
      });
      
      hideLoading();
      showSnackbar("Code promo supprimé avec succès");
      notifyListeners();
    } catch (e) {
      hideLoading();
      showSnackbar("Erreur lors de la suppression du code promo");
      // Recharger les codes promos en cas d'erreur
      getPromoCodes();
    }
  }

  applyForPromocode({required String code}) async {
    showLoading();
    var checlAlreadyredemed = await FirestoreServices.promocodesCollection
        .where("code", isEqualTo: code)
        .where("status", isEqualTo: 1)
        .where("availableForUsers", arrayContains: userData.value!.id)
        .limit(1)
        .get();
    if (checlAlreadyredemed.docs.isEmpty) {
      var idThat = await FirestoreServices.promocodesCollection
          .where("code", isEqualTo: code)
          .limit(1)
          .get();
      if (idThat.docs.isNotEmpty) {
        await FirestoreServices.promocodesCollection
            .doc(idThat.docs.first.id)
            .update({
          "availableForUsers": FieldValue.arrayUnion([userData.value!.id]),
          "usedByUsers": FieldValue.arrayUnion([])
        });
        hideLoading();
        getPromoCodes();
      } else {
        hideLoading();
        showSnackbar("Code invalide");
      }
    } else {
      hideLoading();
      var data = checlAlreadyredemed.docs.first.data() as Map;
      if (data['availableForUsers'] != null &&
          data['availableForUsers'].contains(userData.value!.id)) {
        showSnackbar("Vous avez déjà utilisé ce code");
      } else {
        showSnackbar("Code expiré ou désactivé par l'administrateur");
      }
    }
  }
}
