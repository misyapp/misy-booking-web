// import 'package:flutter/material.dart';

// import '../../contants/global_data.dart';
// import '../../contants/my_colors.dart';
// import '../../contants/my_image_url.dart';
// import '../../contants/sized_box.dart';
// import '../../functions/navigation_functions.dart';
// import '../../widget/custom_appbar.dart';
// import '../../widget/custom_text.dart';
// import '../../widget/input_text_field_widget.dart';
// import '../../widget/round_edged_button.dart';
// import 'home_screen.dart';

// class ReportScreen extends StatefulWidget {
//   const ReportScreen({Key? key}) : super(key: key);

//   @override
//   State<ReportScreen> createState() => _ReportScreenState();
// }

// class _ReportScreenState extends State<ReportScreen> {
//   TextEditingController rateUsController=TextEditingController();
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Image.asset(MyImagesUrl.bgImage,
//           fit: BoxFit.cover,
//           width: MediaQuery.of(context).size.width,
//           height: MediaQuery.of(context).size.height,
//         ),
//         Scaffold(
//           appBar:    CustomAppBar(
//             isBackIcon: false,
//             titleWidget:Row(
//               children: [
//                 IconButton(
//                   onPressed: () {Navigator.pop(context);},
//                   icon: const Icon(Icons.arrow_back_ios_new,size: 20,color: MyColors.blackColor,),),
//                 const SubHeadingText('Report',
//                   fontSize: 18,
//                   color: MyColors.blackColor,
//                   fontWeight: FontWeight.w600,),
//               ],
//             ) ,
//         title: 'Report',
//             titleColor: Colors.black,
//         ),
//           backgroundColor: MyColors.transparent,
//           body: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: globalHorizontalPadding,
//             vertical: 40),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               // mainAxisAlignment: MainAxisAlignment.s,
//               children: [
//                 const SubHeadingText('Complaint against Driver',
//                   fontSize: 22,
//                   color: MyColors.blackColor,
//                   fontWeight: FontWeight.w500,),
//                 vSizedBox,
//                 const ParagraphText('Enter your complaint below in the given box ',
//                   fontSize: 14,
//                   color: MyColors.blackColor,
//                   textAlign: TextAlign.center,
//                   fontWeight: FontWeight.w400,),
//                 vSizedBox3,
//                 InputTextFieldWidget(
//                   hintcolor: const Color(0xFF575757).withOpacity(0.6),
//                   maxLines:4,
//                   borderColor: Colors.transparent,
//                   fillColor: MyColors.whiteColor,
//                   controller: rateUsController,
//                   hintText: "Type here...",
//                 ),
//                 vSizedBox,
//                 RoundEdgedButton(
//                   onTap: (){
//                     pushAndRemoveUntil(context: context, screen: const HomeScreen());
//                   },
//                   verticalMargin: 20,
//                   text: "Submit",

//                 ),
//                 Align(
//                   alignment: Alignment.center,
//                   child: TextButton(onPressed: (){
//                     popPage(context: context);
//                   },
//                     child:    const ParagraphText('Skip',
//                       fontSize: 15,
//                       color: MyColors.blackColor,
//                       textAlign: TextAlign.center,
//                       fontWeight: FontWeight.w600,),),
//                 )

//               ],
//             ),
//           ),

//         ),
//       ],
//     );
//   }
// }
