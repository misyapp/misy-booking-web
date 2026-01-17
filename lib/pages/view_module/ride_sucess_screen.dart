// import 'package:flutter/material.dart';
// import 'package:rider_ride_hailing_app/contants/global_data.dart';
// import 'package:rider_ride_hailing_app/pages/view_module/report_screen.dart';
// import '../../contants/my_colors.dart';
// import '../../contants/my_image_url.dart';
// import '../../contants/sized_box.dart';
// import '../../functions/navigation_functions.dart';
// import '../../widget/custom_rich_text.dart';
// import '../../widget/custom_text.dart';
// import '../../widget/round_edged_button.dart';

// class RideSuccessScreen extends StatefulWidget {
//   const RideSuccessScreen({Key? key}) : super(key: key);

//   @override
//   State<RideSuccessScreen> createState() => _RideSuccessScreenState();
// }

// class _RideSuccessScreenState extends State<RideSuccessScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           Image.asset(
//             MyImagesUrl.bgImage,
//             fit: BoxFit.cover,
//             width: MediaQuery.of(context).size.width,
//             height: MediaQuery.of(context).size.height,
//           ),
//           Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: globalHorizontalPadding),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Image.asset(
//                   MyImagesUrl.success,
//                   width: MediaQuery.of(context).size.width / 1.9,
//                 ),
//                 vSizedBox4,
//                 const SubHeadingText(
//                   'Success Your Ride',
//                   fontSize: 20,
//                   color: MyColors.blackColor,
//                   fontWeight: FontWeight.w500,
//                 ),
//                 vSizedBox,
//                 const ParagraphText(
//                   'We hope you will enjoy your ride',
//                   fontSize: 14,
//                   color: MyColors.blackColor,
//                   textAlign: TextAlign.center,
//                   fontWeight: FontWeight.w400,
//                 ),
//                 vSizedBox2,
//                 const ParagraphText(
//                   'CASH PAYMENT',
//                   fontSize: 13,
//                   color: MyColors.blackColor,
//                   textAlign: TextAlign.center,
//                   fontWeight: FontWeight.w400,
//                 ),
//                 RichTextCustomWidget(
//                   firstText: '25.00',
//                   firstTextFontSize: 35,
//                   firstTextColor: MyColors.blackColor,
//                   firstTextFontweight: FontWeight.w400,
//                   secondText: 'Ar',
//                   secondTextFontSize: 20,
//                   secondTextFontweight: FontWeight.w400,
//                 ),
//                 vSizedBox2,
//                 Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                   decoration: BoxDecoration(
//                       color: MyColors.whiteThemeColor(),
//                       borderRadius: BorderRadius.circular(15)),
//                   child: Row(
//                     children: [
//                       Column(
//                         children: [
//                           CircleAvatar(
//                               radius: 9,
//                               backgroundColor:
//                                   MyColors.blackThemeColorWithOpacity(0.35),
//                               child: Icon(
//                                 Icons.circle,
//                                 size: 14,
//                                 color: MyColors.blackThemeColor(),
//                               )),
//                           Container(
//                             margin: const EdgeInsets.symmetric(vertical: 4),
//                             width: 3,
//                             height: 40,
//                             color: MyColors.blackThemeColor(),
//                           ),
//                           Image.asset(
//                             MyImagesUrl.location01,
//                             width: 24,
//                             color: MyColors.blackThemeColor(),
//                           )
//                         ],
//                       ),
//                       hSizedBox,
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const ParagraphText(
//                             '4min (1.6mi) away',
//                             fontSize: 15,
//                             textAlign: TextAlign.center,
//                             fontWeight: FontWeight.w400,
//                           ),
//                           ParagraphText(
//                             '70-A Braj Vihar Colony, Indore',
//                             fontSize: 13,
//                             color: MyColors.blackThemeColorWithOpacity(0.5),
//                             textAlign: TextAlign.center,
//                             fontWeight: FontWeight.w400,
//                           ),
//                           vSizedBox3,
//                           const ParagraphText(
//                             '4min (1.6mi) away',
//                             fontSize: 15,
//                             textAlign: TextAlign.center,
//                             fontWeight: FontWeight.w400,
//                           ),
//                           ParagraphText(
//                             '70-A Braj Vihar Colony, Indore',
//                             fontSize: 13,
//                             color: MyColors.blackThemeColorWithOpacity(0.5),
//                             textAlign: TextAlign.center,
//                             fontWeight: FontWeight.w400,
//                           ),
//                         ],
//                       )
//                     ],
//                   ),
//                 ),
//                 vSizedBox,
//                 RoundEdgedButton(
//                   onTap: () {
//                     // push(context: context, screen: const RateUsScreen());
//                   },
//                   verticalMargin: 20,
//                   text: "Rate Driver",
//                 ),
//                 RoundEdgedButton(
//                   color: MyColors.blackColor,
//                   onTap: () {
//                     push(context: context, screen: const ReportScreen());
//                   },
//                   verticalMargin: 0,
//                   text: "Report",
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
