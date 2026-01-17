import 'package:flutter/material.dart';
Future push({required  BuildContext context, required Widget screen,})async{
  return Navigator.push(context, MaterialPageRoute(builder: (context){
    return screen;
  }));
}

Future pushReplacement({required  BuildContext context, required Widget screen,})async{
  return Navigator.pushReplacement(context, MaterialPageRoute(builder: (context){
    return screen;
  }));
}
Future pushAndRemoveUntil({required  BuildContext context, required Widget screen,})async{
  return   Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => screen,), (route) => false);
}
Future popPage({required  BuildContext context})async{
return Navigator.pop(context);
}