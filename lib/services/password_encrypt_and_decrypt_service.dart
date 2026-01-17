import 'package:bcrypt/bcrypt.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

class PasswordEncryptAndDecryptService {
  String stringToHashedPassword({required String password}) {
    String hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    myCustomLogStatements("Hashed Password: $hashedPassword");
    return hashedPassword;
  }

  bool checkStringPasswordWithHashed(
      {required String password, required String hashedPassword}) {
    bool isCorrect = BCrypt.checkpw(password, hashedPassword);
    myCustomLogStatements("Password Match: $isCorrect");
    return isCorrect;
  }

}
