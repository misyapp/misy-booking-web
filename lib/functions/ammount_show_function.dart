// String formatAriary(double amount) {
//   List<String> parts = amount.toStringAsFixed(2).split('.');
//   String integerPart = parts[0];
//   String fractionalPart = parts.length > 1 ? parts[1] : '';

//   String formattedInteger = '';
//   String formattedFractional = '';

//   // Format integer part
//   while (integerPart.length > 3) {
//     formattedInteger =
//         '.${integerPart.substring(integerPart.length - 3)}$formattedInteger';
//     integerPart = integerPart.substring(0, integerPart.length - 3);
//   }
//   formattedInteger = integerPart + formattedInteger;

//   // Format fractional part
//   if (fractionalPart.isNotEmpty) {
//     formattedFractional = '.$fractionalPart';
//   }

//   return formattedInteger + formattedFractional;
// }
String formatAriary(double euroAmount) {
  // Round the Euro amount to the nearest thousand0
  int roundedEuroAmount = (euroAmount / 100).round() * 100;
  String formattedAriary = roundedEuroAmount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
  return formattedAriary;
}

String formatNearest(double euroAmount) {
  // Round the Euro amount to the nearest thousand
  int roundedEuroAmount = (euroAmount / 100).round() * 100;
  return roundedEuroAmount.toString();
}
