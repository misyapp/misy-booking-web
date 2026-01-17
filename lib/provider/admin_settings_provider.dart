import 'package:rider_ride_hailing_app/utils/platform.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/default_app_settings_modal.dart';
import 'package:rider_ride_hailing_app/modal/payment_gateway_secret_keys_modal.dart';
import 'package:rider_ride_hailing_app/models/payment_promo_model.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_custom_dialog.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminSettingsProvider extends ChangeNotifier {
  /// run it only once to initialize settings
  // await AdminSettingsProvider.updateDefaultAppSettingsToFirebase();
  /// add this in main function
  // var adminSettingsProvider= Provider.of<AdminSettingsProvider>(context, listen: false);
  // await adminSettingsProvider.getDefaultAppSettings();
  DefaultAppSettingModal defaultAppSettingModal = DefaultAppSettingModal(
    appVersionIos: 1,
    appVersionAndroid: 1,
    hardUpdateVersionIos: 1,
    hardUpdateVersionAndroid: 1,
    updatePopup: true,
    googleApiKey: 'AIzaSyBCV_9MoubJ8OG3DNtmfUAtFC9EPGRbPyQ',
    updateUrlAndroid: '',
    hideAndroidSocialLogin: false,
    hideIOSSocialLogin: false,
    digitalWalletEnabled: false,
    creditCardPaymentEnabled: false,
    loyaltySystemEnabled: false,
    updateUrlIos: '',
    updateMessage:
        'New Version is available, Please download latest version from store',
  );

  PaymentPromoModel? paymentPromo;

  static final adminSettingCollection =
      FirebaseFirestore.instance.collection('adminSettings');
  static final defaultAppSettingsDocument =
      adminSettingCollection.doc('riderDefaultAppSettings');
  static final paymentGateWaysSecretDocument =
      adminSettingCollection.doc('paymentGatewaySecretKeys');
  static final settingsCollection =
      FirebaseFirestore.instance.collection('setting');
  static final settingsDocument =
      settingsCollection.doc('BfnqY5zbKjRDEiUZbaCx');

  static const appVersionAndroid = 31;
  static const appVersionIos = 22;

  Future<void> getDefaultAppSettings() async {
    try {
      // 🚀 Charger les deux documents en parallèle avec timeout
      final results = await Future.wait([
        defaultAppSettingsDocument.get().timeout(const Duration(seconds: 5)),
        paymentGateWaysSecretDocument.get().timeout(const Duration(seconds: 5)),
      ], eagerError: false);

      final snapshot = results[0];
      final paymentSnapshot = results[1];

      if (paymentSnapshot.exists) {
        myCustomPrintStatement('the app settings snapshot is $paymentSnapshot');
        paymentGateWaySecretKeys =
            PaymentGatewaySecretKeyModal.fromJson(paymentSnapshot.data() as Map);
      }
      myCustomPrintStatement('the app settings snapshot is $snapshot');
      if (snapshot.exists) {
        bool showPopup = false;
        try {
          defaultAppSettingModal =
              DefaultAppSettingModal.fromJson(snapshot.data() as Map);
          googleMapApiKey = defaultAppSettingModal.googleApiKey ?? '';
          myCustomPrintStatement('the snapshot is ${snapshot.data()}');
          if (defaultAppSettingModal.appVersionAndroid > appVersionAndroid &&
              Platform.isAndroid) {
            myCustomPrintStatement('the snapshot true sd');
            showPopup = true;
          }
          if (defaultAppSettingModal.appVersionIos > appVersionIos &&
              Platform.isIOS) {
            myCustomPrintStatement('the snapshot true sdsdf');
            showPopup = true;
          }

          if (showPopup) {
            await showUpdateDialog();
          }
          notifyListeners();
        } catch (e) {
          myCustomPrintStatement('Error in catch block in admin settings $e');
        }
      }

      await _loadPaymentPromoFromSettings();
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur chargement admin settings (timeout ou autre): $e');
      // Continuer avec les settings par défaut
    }
  }

  showUpdateDialog() async {
    return showCustomDialog(
        height: 250,
        child: PopScope(
          // onPopInvoked: (value)async{
          //
          // },
          canPop: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ParagraphText(
                defaultAppSettingModal.updateMessage,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              vSizedBox2,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if ((defaultAppSettingModal.hardUpdateVersionAndroid <=
                              appVersionAndroid &&
                          Platform.isAndroid) ||
                      (defaultAppSettingModal.hardUpdateVersionIos <=
                              appVersionIos &&
                          Platform.isIOS))
                    TextButton(
                        onPressed: () {
                          Navigator.pop(
                              MyGlobalKeys.navigatorKey.currentContext!);
                        },
                        child: const SubHeadingText(
                          'Remind me later',
                          fontSize: 16,
                        ))
                  else
                    vSizedBox,
                  RoundEdgedButton(
                    text: 'Update',
                    width: 100,
                    height: 40,
                    onTap: () {
                      try {
                        if (Platform.isIOS) {
                          launchUrl(
                              Uri.parse(defaultAppSettingModal.updateUrlIos));
                        } else {
                          launchUrl(Uri.parse(
                              defaultAppSettingModal.updateUrlAndroid));
                        }
                      } catch (e) {
                        showSnackbar('Some Error, please update from store');
                      }
                    },
                  ),
                ],
              )
            ],
          ),
        ));
  }

  static updateDefaultAppSettingsToFirebase() async {
    var request = {
      'appVersionIos': 1,
      'appVersionAndroid': 1,
      'hardUpdateVersionAndroid': 1,
      'hardUpdateVersionIos': 1,
      'updatePopup': true,
      'updateUrlAndroid': 'https://www.instagram.com/manish.talreja.50',
      'updateUrlIos': 'https://www.instagram.com/manish.talreja.50',
      // 'googleApiKey': GoogleMapServices.googleMapApiKey,
      'updateMessage':
          'New Version is available, Please download latest version from store',
      'googleApiKey': 'AIzaSyBCV_9MoubJ8OG3DNtmfUAtFC9EPGRbPyQ',
      'digitalWalletEnabled': false,
      'creditCardPaymentEnabled': false,
      'loyaltySystemEnabled': false,
    };
    var snapshot = await defaultAppSettingsDocument.get();
    if (snapshot.exists) {
      defaultAppSettingsDocument.update(request);
    } else {
      defaultAppSettingsDocument.set(Map<String, dynamic>.from(request));
    }
  }

  Future<void> _loadPaymentPromoFromSettings() async {
    try {
      myCustomPrintStatement('🔍 Loading payment promo from setting/BfnqY5zbKjRDEiUZbaCx...');
      var settingsSnapshot = await settingsDocument.get();
      
      if (settingsSnapshot.exists) {
        var data = settingsSnapshot.data() as Map<String, dynamic>;
        myCustomPrintStatement('📄 Settings document data: $data');
        
        paymentPromo = PaymentPromoModel.fromJson(data);
        myCustomPrintStatement('✅ Payment promo loaded: $paymentPromo');
        myCustomPrintStatement('🎯 Promo enabled: ${paymentPromo?.isEnabled}');
        myCustomPrintStatement('💰 Discounts available: ${paymentPromo?.paymentMethodDiscounts}');
        
        notifyListeners();
      } else {
        paymentPromo = PaymentPromoModel();
        myCustomPrintStatement('❌ Settings document not found, using default payment promo');
        myCustomPrintStatement('📋 Document path: setting/BfnqY5zbKjRDEiUZbaCx');
      }
    } catch (e) {
      paymentPromo = PaymentPromoModel();
      myCustomPrintStatement('🚨 Error loading payment promo from settings: $e');
    }
  }

  double getPaymentPromoDiscount(PaymentMethodType method) {
    return paymentPromo?.getDiscountForMethod(method) ?? 0.0;
  }

  bool isPaymentPromoActive() {
    return paymentPromo?.isEnabled ?? false;
  }

  bool hasPaymentPromoForMethod(PaymentMethodType method) {
    return paymentPromo?.hasDiscountForMethod(method) ?? false;
  }

  PaymentMethodType? getBestPaymentPromoMethod() {
    return paymentPromo?.getBestDiscountMethod();
  }

  List<PaymentMethodType> getMethodsWithPaymentPromo() {
    return paymentPromo?.getMethodsWithDiscount() ?? [];
  }
}
