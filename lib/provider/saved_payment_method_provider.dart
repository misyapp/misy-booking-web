import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/modal/saved_payment_method_modal.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/widget/common_alert_dailog.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

class SavedPaymentMethodProvider with ChangeNotifier {
  List<SavedPaymentMethodModal> savedPaymentMethod = [];
  int addPaymentMethodCount = 0;
  List addPaymentGateways = [
    {
      'image': MyImagesUrl.orangeMoneyIcon,
      'name': 'Orange Money',
      'paymentGatewayType': PaymentMethodType.orangeMoney,
      'onTap': () {
        showSnackbar("this is new payment");
      },
      'show': true,
      'selected': true,
    },
    {
      'image': MyImagesUrl.bankCardIcon,
      'name': 'Credit Card',
      'paymentGatewayType': PaymentMethodType.creditCard,
      'onTap': () {
        showSnackbar("this is new payment");
      },
      'show': true,
      'selected': true,
    },
    {
      'image': MyImagesUrl.airtelMoneyIcon,
      'name': 'Airtel Money',
      'onTap': () {
        showSnackbar("this is new payment");
      },
      'show': true,
      'selected': true,
      'paymentGatewayType': PaymentMethodType.airtelMoney,
    },
    {
      'image': MyImagesUrl.telmaMvolaIcon,
      'name': 'MVola',
      'onTap': () {
        showSnackbar("this is new payment");
      },
      'show': true,
      'selected': true,
      'paymentGatewayType': PaymentMethodType.telmaMvola,
    },
  ];
  List allPaymentMethods = [
    {
      'image': MyImagesUrl.cashIcon,
      'name': PaymentMethodType.cash.value,
      'paymentGatewayType': PaymentMethodType.cash,
      'disabled': false,
    },
    {
      'image': MyImagesUrl.wallet,
      'name': PaymentMethodType.wallet.value,
      'paymentGatewayType': PaymentMethodType.wallet,
      'disabled': false,
    },
    {
      'image': MyImagesUrl.airtelMoneyIcon,
      'name': PaymentMethodType.airtelMoney.value,
      'paymentGatewayType': PaymentMethodType.airtelMoney,
      'disabled': false,
    },
    {
      'image': MyImagesUrl.orangeMoneyIcon,
      'name': PaymentMethodType.orangeMoney.value,
      'paymentGatewayType': PaymentMethodType.orangeMoney,
      'disabled': false,
    },
    {
      'image': MyImagesUrl.telmaMvolaIcon,
      'name': PaymentMethodType.telmaMvola.value,
      'paymentGatewayType': PaymentMethodType.telmaMvola,
      'disabled': false,
    },
    {
      'image': MyImagesUrl.bankCardIcon,
      'name': PaymentMethodType.creditCard.value,
      'paymentGatewayType': PaymentMethodType.creditCard,
      'disabled': false,
    },
  ];
  
  /// Getter qui filtre les moyens de paiement selon les flags de fonctionnalités
  List get filteredAddPaymentGateways {
    return addPaymentGateways.where((method) {
      final paymentType = method['paymentGatewayType'] as PaymentMethodType?;
      
      // Masquer le portefeuille si la fonctionnalité est désactivée
      if (paymentType == PaymentMethodType.wallet && 
          !FeatureToggleService.instance.isDigitalWalletEnabled()) {
        return false;
      }
      
      // Masquer les cartes bancaires si la fonctionnalité est désactivée
      if (paymentType == PaymentMethodType.creditCard && 
          !FeatureToggleService.instance.isCreditCardPaymentEnabled()) {
        return false;
      }
      
      return true;
    }).toList();
  }
  
  // List allScheduleFeePaymentMethods = [
  //   {
  //     'image': MyImagesUrl.airtelMoneyIcon,
  //     'name': PaymentMethodType.airtelMoney.value,
  //     'paymentGatewayType': PaymentMethodType.airtelMoney,
  //     'disabled': false,
  //   },
  //   {
  //     'image': MyImagesUrl.orangeMoneyIcon,
  //     'name': PaymentMethodType.orangeMoney.value,
  //     'paymentGatewayType': PaymentMethodType.orangeMoney,
  //     'disabled': false,
  //   },
  //   {
  //     'image': MyImagesUrl.telmaMvolaIcon,
  //     'name': PaymentMethodType.telmaMvola.value,
  //     'paymentGatewayType': PaymentMethodType.telmaMvola,
  //     'disabled': false,
  //   },
  //   {
  //     'image': MyImagesUrl.bankCardIcon,
  //     'name': PaymentMethodType.creditCard.value,
  //     'paymentGatewayType': PaymentMethodType.creditCard,
  //     'disabled': true,
  //   },
  // ];
  getMySavedPaymentMethod() async {
    for (var i = 0; i < addPaymentGateways.length; i++) {
      addPaymentGateways[i]['show'] = true;
    }
    final snapshot = await FirestoreServices.savedPaymentMethods.get();
    if (snapshot.docs.isNotEmpty) {
      addPaymentMethodCount = 0;
      savedPaymentMethod = List.generate(snapshot.docs.length, (index) {
        var data = snapshot.docs[index].data() as Map;
        // Ne plus cacher les méthodes déjà ajoutées pour permettre les doublons
        // Garder seulement le comptage pour la logique existante
        addPaymentMethodCount++;

        return SavedPaymentMethodModal(
          icons: data['image'],
          mobileNumber: data['mobileNumber'],
          isSelected: data['isSelected'],
          id: data['id'],
          name: data['name'],
          onDeleteTap: () {
            deletePaymentMethod(docId: data['id']);
          },
          onEditTap: () {
            showSnackbar("Edit is pressed $index");
          },
          onTap: () async {
            showLoading();
            int findIndex =
                savedPaymentMethod.indexWhere((element) => element.isSelected);
            if (findIndex != -1) {
              await FirestoreServices.savedPaymentMethods
                  .doc(savedPaymentMethod[findIndex].id)
                  .update({
                'isSelected': false,
              });
              savedPaymentMethod[findIndex].isSelected = false;
            }
            await FirestoreServices.savedPaymentMethods
                .doc(savedPaymentMethod[index].id)
                .update({
              'isSelected': true,
            });
            DevFestPreferences()
                .setLastPaymentMethodSelected(savedPaymentMethod[index].name);
            savedPaymentMethod[index].isSelected = true;
            notifyListeners();
            hideLoading();
          },
          showCheckBox: true,
          showDeleteIcon: data['name'] == "Cash" ? false : true,
          showDivider: true,
          showEditIcon: data['name'] == "Cash" ? false : true,
        );
      });
    } else {
      var add = {
        'image': MyImagesUrl.cashIcon,
        'name': PaymentMethodType.cash.value,
        'mobileNumber': '',
        'isSelected': true,
      };
      final docId = FirestoreServices.savedPaymentMethods.doc();
      add['id'] = docId.id;
      await FirestoreServices.savedPaymentMethods.doc(docId.id).set(add);
      getMySavedPaymentMethod();
    }
    notifyListeners();
  }

  savePaymentMethod(Map<String, dynamic> request, int index) async {
    showLoading();
    if (request['id'] == null) {
      final docId = FirestoreServices.savedPaymentMethods.doc();
      request['id'] = docId.id;
      await FirestoreServices.savedPaymentMethods.doc(docId.id).set(Map<String, dynamic>.from(request));
    } else {
      await FirestoreServices.savedPaymentMethods
          .doc(request['id'])
          .update(request);
    }

    notifyListeners();
    popPage(context: MyGlobalKeys.navigatorKey.currentContext!);
    getMySavedPaymentMethod();
    hideLoading();
  }

  deletePaymentMethod({required String docId}) async {
    var res = await showCommonAlertDailog(
        MyGlobalKeys.navigatorKey.currentContext,
        headingText: translate("areYouSure"),
        successIcon: false,
        confirmButtonText: translate("yes"),
        cancelButtonText: translate("no"),
        buttonAlignMent: MainAxisAlignment.spaceAround,
        message: translate("removePaymentMethod"));
    if (res) {
      await FirestoreServices.savedPaymentMethods.doc(docId).delete();
      getMySavedPaymentMethod();
    }
  }
}
