import 'dart:convert';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';

createDummyUser() {
  List<String> driverCollectionId = [
    "oZG1weTAjDd2kunaUIXMoxyaZLS2",
    "lrdIuRgUKUZz8CKNmYG4L405ZZm2",
    "ca19cXHfoBbYm5g3MmImkuU4yiJ3",
    "1BK9PcsvkQbWdEDllGYtkLKurgm1",
    "DDOH1TTPRFbaqX3HlSYfE0iJXgm1",
  ];
  Map<String, dynamic> userDummyDataStructure = {
    "lastName": "sharma",
    "isBlocked": false,
    "total_review": 0,
    "verified": true,
    "average_rating": 0.0,
    "profileImage":
        "https://firebasestorage.googleapis.com/v0/b/ride-hailing-83d70.appspot.com/o/dummy_user_image.png?alt=media&token=89f53564-3260-42bf-a4e4-6eb1ec0af42d",
    "deviceId": [
      "dhI7En9jSdKY7yOi1tMUSJ:APA91bEsccdzwWbvdKfvMhg_Bi164XkS4JDVOLkEdKBb5E8PRt79HZEiWRBoBJqQ-C0i4RrfhdDtkcx4kRJMFjSk1Vs4pNqUmpz8GzcuzrY1acAhhwS8Y3LaUSdPk7h80P5XNOjEhWpQ"
    ],
    "phoneNo": "06263624487",
    "isCustomer": true,
    "firstName": "rider",
    "currentLat": 22.7004267,
    "password": "123456",
    "countryCode": "+255",
    "name": "manish sharma",
    "currentLng": 75.8758677,
    "id": "ihoHH90N7FaMYBPrsW7XwffUK903",
    "countryName": "Madagasikara",
    "email": "manish.1webwiders@gmail.com"
  };
  for (var i = 0; i < driverCollectionId.length; i++) {
    userDummyDataStructure['id'] = driverCollectionId[i];
    userDummyDataStructure['firstName'] = "rider ${i + 1}";
    userDummyDataStructure['email'] = "rider${i + 1}@gmail.com";
    userDummyDataStructure['name'] =
        "rider ${i + 1} ${userDummyDataStructure['lastName']}";

    FirestoreServices.users
        .doc(driverCollectionId[i])
        .set(userDummyDataStructure);
  }
  print("Dummy user test = ${jsonEncode(userDummyDataStructure)}");
}
