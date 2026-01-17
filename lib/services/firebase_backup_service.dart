// import 'dart:io';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:csv/csv.dart';
// import 'package:path_provider/path_provider.dart';

// class FirebaseBackupService {
//   static Future<void> backupCollectionToCSV(String collectionName) async {
//     try {
//       // Get Firestore collection
//       CollectionReference collection =
//           FirebaseFirestore.instance.collection(collectionName);
//       QuerySnapshot querySnapshot = await collection
//           .where(
//               // 'id', isEqualTo: '024TwgmMd5PfrqzJbaZpAZBwW9p1'
//               'isCustomer',
//               isEqualTo: false)
//           // .where(
//           //     // 'id', isEqualTo: '024TwgmMd5PfrqzJbaZpAZBwW9p1'
//           //     'formPage',
//           //     isLessThan: 8)
//           .limit(1)
//           .get();

//       // Prepare CSV data
//       List<List<dynamic>> rows = [];
//       List<String> headers = [
//         // 'name',
//         // 'countryCode',
//         // 'phoneNo',
//         // 'countryName',
//         // 'accountDeleted',
//         // 'email'
//       ];

//       if (querySnapshot.docs.isNotEmpty) {
//         // Extract headers
//         var headersResult = querySnapshot.docs.first.data() as Map;
//         headers = headersResult.keys.map((key) => key.toString()).toList();
//         rows.add(headers);

//         // Add document data to rows

//         for (var i = 0; i < querySnapshot.docs.length; i++) {
//           var dd = querySnapshot.docs[i].data() as Map;
//           List<dynamic> row = [];
//           for (var header in headers) {
//             row.add(dd[header] ?? '');
//           }
//           rows.add(row);
//         }
//       }

//       // Convert to CSV format
//       String csv = const ListToCsvConverter().convert(rows);

//       // Get temporary directory
//       final directory = await getDownloadsDirectory();
//       final localFile = File('${directory!.path}/$collectionName.xlsx');

//       // Write CSV data to local file
//       await localFile.writeAsString(csv);

//       print(
//           "Backup of collection '$collectionName' saved to :- ${localFile.path}.");
//     } catch (e) {
//       print("Error backing up collection: $e");
//     }
//   }
// }
