// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:rider_ride_hailing_app/contants/global_data.dart';
// import 'package:rider_ride_hailing_app/contants/global_keys.dart';
// import 'package:rider_ride_hailing_app/contants/language_strings.dart';
// import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
// import 'package:rider_ride_hailing_app/pages/view_module/my_wallet_management.dart';
// import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
// import '../contants/my_colors.dart';
// import '../contants/sized_box.dart';
// import '../widget/custom_text.dart';
// import '../widget/round_edged_button.dart';

// class ScheduledFeePaymentMethod extends StatelessWidget {
//   final Function(PaymentMethodType selectedPaymentMethod) onTap;
//   const ScheduledFeePaymentMethod({Key? key, required this.onTap})
//       : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       child: ValueListenableBuilder(
//         valueListenable: sheetShowNoti,
//         builder: (context, sheetValue, child) => Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             vSizedBox,
//             Center(
//               child: GestureDetector(
//                 onTap: () {
//                   sheetShowNoti.value = !sheetValue;
//                   MyGlobalKeys.homePageKey.currentState!
//                       .updateBottomSheetHeight(milliseconds: 20);
//                 },
//                 child: Container(
//                   height: 6,
//                   width: 60,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(10),
//                     color: MyColors.colorD9D9D9Theme(),
//                   ),
//                 ),
//               ),
//             ),
//             vSizedBox,
//             if (sheetValue)
//               ValueListenableBuilder(
//                 valueListenable: selectPayMethod,
//                 builder: (context, value, child) => Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     vSizedBox,
//                     SubHeadingText(
//                       translate("SelectPaymentMethod"),
//                       fontWeight: FontWeight.w600,
//                       fontSize: 16,
//                     ),
//                     vSizedBox2,
//                     Consumer<SavedPaymentMethodProvider>(
//                       builder: (context, savedPayment, child) =>
//                           ListView.builder(
//                         shrinkWrap: true,
//                         itemCount:
//                             savedPayment.allScheduleFeePaymentMethods.length,
//                         itemBuilder: (context, index) => CardWithCheckBox(
//                           name: savedPayment.allScheduleFeePaymentMethods[index]
//                               ['name'],
//                           isSelected: value ==
//                               savedPayment.allScheduleFeePaymentMethods[index]
//                                   ['paymentGatewayType'],
//                           icons: savedPayment
//                               .allScheduleFeePaymentMethods[index]['image'],
//                           disabled: savedPayment
//                               .allScheduleFeePaymentMethods[index]['disabled'],
//                           subtitle:
//                               savedPayment.allScheduleFeePaymentMethods[index]
//                                       ['disabled']
//                                   ? "Temporarily unavailable"
//                                   : '',
//                           onTap: () {
//                             selectPayMethod.value =
//                                 savedPayment.allScheduleFeePaymentMethods[index]
//                                     ['paymentGatewayType'];
//                           },
//                           showDeleteIcon: false,
//                           showEditIcon: false,
//                         ),
//                       ),
//                     ),
//                     RoundEdgedButton(
//                       verticalMargin: 20,
//                       text: translate("next"),
//                       width: double.infinity,
//                       onTap: () async {},
//                     ),
//                     vSizedBox3,
//                   ],
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
