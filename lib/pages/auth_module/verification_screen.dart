// import 'package:flutter/material.dart';
// import 'package:rider_ride_hailing_app/contants/language_strings.dart';
// import 'package:rider_ride_hailing_app/contants/my_colors.dart';
// import '../../contants/my_image_url.dart';
// import '../../contants/sized_box.dart';
// import '../../functions/navigation_functions.dart';
// import '../../widget/custom_text.dart';
// import '../../widget/round_edged_button.dart';
// import 'login_screen.dart';

// class VerificationScreen extends StatefulWidget {
//   const VerificationScreen({Key? key}) : super(key: key);

//   @override
//   State<VerificationScreen> createState() => _VerificationScreenState();
// }

// class _VerificationScreenState extends State<VerificationScreen> {
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
//             padding: const EdgeInsets.symmetric(horizontal: 30),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Image.asset(
//                   MyImagesUrl.success,
//                   width: MediaQuery.of(context).size.width / 1.9,
//                 ),
//                 vSizedBox4,
//                 SubHeadingText(
//                   translate("registrationSuccess"),
//                   fontSize: 20,
//                   color: MyColors.blackColor,
//                   fontWeight: FontWeight.w500,
//                 ),
//                 vSizedBox,
//                 ParagraphText(
//                   translate("registrationSucessMsg"),
//                   fontSize: 14,
//                   color: MyColors.blackColor,
//                   textAlign: TextAlign.center,
//                   fontWeight: FontWeight.w400,
//                 ),
//                 RoundEdgedButton(
//                   width: 70,
//                   onTap: () {
//                     pushAndRemoveUntil(
//                         context: context, screen: const LoginPage());
//                   },
//                   verticalMargin: 30,
//                   text: translate("ok"),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
