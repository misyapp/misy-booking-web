// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../contants/my_colors.dart';

class CustomLoader extends StatelessWidget {
  final Color? color;
  const CustomLoader({Key? key, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Animation TwistingDots selon le cahier des charges Misy V2
    return Center(
      child: LoadingAnimationWidget.twistingDots(
        leftDotColor: MyColors.coralPink,
        rightDotColor: MyColors.horizonBlue,
        size: 30.0,
      ),
    );
  }
}

void loadingHide(context) {
  // Navigator.pop(dialogContext,true);
  Navigator.of(context, rootNavigator: true).pop();
}

Future<dynamic> loadingShow(context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.all(10),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: WillPopScope(
            onWillPop: () async {
              return false;
            },
            child: loadingWidget(context),
          ));
    },
  ).then((exit) {
    if (exit == null) return;
  });
}

Widget loadingWidget(context) {
  return Stack(clipBehavior: Clip.none, children: [
    SizedBox(
        width: double.infinity,
        // height: 200,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Row(
                children: [
                  Container(
                    clipBehavior: Clip.none,
                    width: (MediaQuery.of(context).size.width - 70),
                    // padding:EdgeInsets.fromLTRB(0, 0, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LoadingAnimationWidget.twistingDots(
                          leftDotColor: MyColors.coralPink,
                          rightDotColor: MyColors.horizonBlue,
                          size: 50.0,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        )),
  ]);
}
