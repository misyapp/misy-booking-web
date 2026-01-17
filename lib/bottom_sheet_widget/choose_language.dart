// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../contants/my_colors.dart';
// import '../contants/sized_box.dart';
// import '../provider/trip_provider.dart';
// import '../widget/custom_text.dart';

// class ChooseLanguage extends StatelessWidget {
//   const ChooseLanguage({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     var tripProvider = Provider.of<TripProvider>(context, listen: false);
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       child: ValueListenableBuilder(
//         valueListenable: tripProvider.selectPayMethod,
//         builder: (context, value, child) => Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             vSizedBox,
//             Center(
//               child: Container(
//                 height: 4,
//                 width: 60,
//                 color: MyColors.colorD9D9D9Theme(),
//               ),
//             ),
//             vSizedBox3,
//             const SubHeadingText(
//               'Change Language',
//               fontWeight: FontWeight.w600,
//               fontSize: 14,
//             ),
//             vSizedBox3,
//             GestureDetector(
//               onTap: () {
//                 tripProvider.selectPayMethod.value = 1;
//                 Future.delayed(const Duration(microseconds: 500), () {
//                   tripProvider.setScreen(null);
//                 });
//               },
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                 decoration: BoxDecoration(
//                   color: value == 1
//                       ? MyColors.primaryColor.withOpacity(0.3)
//                       : MyColors.transparent,
//                   borderRadius: BorderRadius.circular(13),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const SubHeadingText(
//                       'English',
//                       fontWeight: FontWeight.w500,
//                       fontSize: 15,
//                     ),
//                     if (value == 1)
//                       const Icon(
//                         Icons.done,
//                         size: 19,
//                       )
//                   ],
//                 ),
//               ),
//             ),
//             vSizedBox2,
//             GestureDetector(
//               onTap: () {
//                 tripProvider.selectPayMethod.value = 2;
//                 Future.delayed(const Duration(microseconds: 500), () {
//                   tripProvider.setScreen(null);
//                 });
//               },
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                 decoration: BoxDecoration(
//                   color: value == 2
//                       ? MyColors.primaryColor.withOpacity(0.3)
//                       : MyColors.transparent,
//                   borderRadius: BorderRadius.circular(13),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const SubHeadingText(
//                       'French',
//                       fontWeight: FontWeight.w500,
//                       fontSize: 15,
//                     ),
//                     if (value == 2)
//                       const Icon(
//                         Icons.done,
//                         size: 19,
//                       )
//                   ],
//                 ),
//               ),
//             ),
//             vSizedBox2,
//             GestureDetector(
//               onTap: () {
//                 tripProvider.selectPayMethod.value = 3;
//                 Future.delayed(const Duration(microseconds: 500), () {
//                   tripProvider.setScreen(null);
//                 });
//               },
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                 decoration: BoxDecoration(
//                   color: value == 3
//                       ? MyColors.primaryColor.withOpacity(0.3)
//                       : MyColors.transparent,
//                   borderRadius: BorderRadius.circular(13),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const SubHeadingText(
//                       'Malagasy',
//                       fontWeight: FontWeight.w500,
//                       fontSize: 15,
//                     ),
//                     if (value == 3)
//                       const Icon(
//                         Icons.done,
//                         size: 19,
//                       )
//                   ],
//                 ),
//               ),
//             ),

//             vSizedBox2,
//             // RoundEdgedButton(
//             //   verticalMargin: 20,
//             //   text: "Next",
//             //   onTap: () {
//             //     tripProvider.setScreen(null);
//             //   },
//             // )
//           ],
//         ),
//       ),
//     );
//   }
// }
