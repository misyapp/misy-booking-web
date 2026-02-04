import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/modal/notification_modal.dart';
import 'package:rider_ride_hailing_app/modal/user_modal.dart';

Future<Uint8List> generateCustomerInvoice(
    {required bookingDetails,
    required UserModal customerDetails,
    required DriverModal driverData}) async {
  try {
    print('🔶 PDF_DEBUG: generateCustomerInvoice started');
    print('🔶 PDF_DEBUG: bookingId: ${bookingDetails['id']}, ride_price_to_pay: ${bookingDetails['ride_price_to_pay']}');
    
    final pw.Document doc = pw.Document();
    print('🔶 PDF_DEBUG: PDF document created');
    
    // Table data
    print('🔶 PDF_DEBUG: Calculating prices...');
    double totalRidePrice;
    try {
      totalRidePrice = double.parse(
          formatNearest(double.parse(bookingDetails['ride_price_to_pay'])));
      print('🔶 PDF_DEBUG: totalRidePrice calculated: $totalRidePrice');
    } catch (e) {
      print('🔶 PDF_DEBUG: ERROR parsing ride_price_to_pay: $e');
      throw Exception('Failed to parse ride price: $e');
    }
    
    double total18PercentTva = 0.20 * totalRidePrice;
    double totalHt = totalRidePrice - total18PercentTva;
    print('🔶 PDF_DEBUG: TVA and HT calculated - TVA: $total18PercentTva, HT: $totalHt');

    // Obtenir le taux de commission depuis les données de réservation (fallback 15%)
    double commissionRate = ((bookingDetails['admin_commission_in_per'] ?? 15.0) as num).toDouble() / 100;
    double driverShareRate = 1 - commissionRate;
    print('🔶 PDF_DEBUG: Commission rate: ${commissionRate * 100}%, Driver share: ${driverShareRate * 100}%');

  print('🔶 PDF_DEBUG: Creating table data...');
  print('🔶 PDF_DEBUG: bookingDetails endTime: ${bookingDetails['endTime']}, type: ${bookingDetails['endTime'].runtimeType}');
  
  String formattedDate;
  try {
    formattedDate = formatTimestamp(bookingDetails['endTime'], formateString: "dd/MM/yyyy");
    print('🔶 PDF_DEBUG: Date formatted successfully: $formattedDate');
  } catch (e) {
    print('🔶 PDF_DEBUG: ERROR formatting timestamp: $e');
    formattedDate = 'Date non disponible';
  }
  
  List<List<String>> data = [
    ['Date de la transaction', 'Description', 'Qté', 'Prix total'],
    ['', 'Prix du service de transport:', '', ''],
    [
      formattedDate,
      'Prix de la course',
      '1',
      "${(driverShareRate * totalHt).toStringAsFixed(2)} ${globalSettings.currency}"
    ],

    [
      formattedDate,
      'Frais de reservation (${(commissionRate * 100).toStringAsFixed(0)}%)',
      '1',
      "${(commissionRate * totalHt).toStringAsFixed(2)} ${globalSettings.currency}"
    ],

    // Add more rows as needed
  ];
  print('🔶 PDF_DEBUG: Table data created successfully');
  // Table headers
  List<String> headers = data.removeAt(0);

  doc.addPage(pw.MultiPage(
      footer: (context) => pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Paragraph(
                    text:
                        "Facture établie au nom et pour le compte de ${driverData.fullName} par:\nSARLU Misy Technology / Ambohimamory AB 739/III, ANTANETY, BEMASOANDRO, ANTANANARIVO ATSIMONDRANO / RCS Antananarivo 2024 B 00089 / NIF : 3 018 428 139 / STAT : 49292-11-2024-0-10090",
                    style: pw.Theme.of(context).defaultTextStyle.copyWith(
                        color: PdfColors.black,
                        fontSize: 8,
                        lineSpacing: 0,
                        fontWeight: pw.FontWeight.normal),
                    textAlign: pw.TextAlign.center),
              ]),
      pageFormat: PdfPageFormat.a4,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      header: (pw.Context context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
          padding: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
          decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey, width: 0.5))),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Paragraph(
                  text: "Facture émise par Misy Technology pour:",
                  style: pw.Theme.of(context).defaultTextStyle.copyWith(
                      color: PdfColors.black,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.normal),
                ),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          driverData.fullName,
                          style: pw.Theme.of(context).defaultTextStyle.copyWith(
                              fontSize: 18, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.start,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            'Facture',
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(
                                    color: PdfColors.black,
                                    fontSize: 25,
                                    fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      )
                    ]),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      driverData.companyAddress,
                      style: pw.Theme.of(context).defaultTextStyle.copyWith(
                          fontSize: 14, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.end,
                    ),
                    pw.Text(
                      driverData.nifNumber,
                      style: pw.Theme.of(context).defaultTextStyle.copyWith(
                          fontSize: 14, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.end,
                    ),
                    pw.Text(
                      driverData.statisticNumber,
                      style: pw.Theme.of(context).defaultTextStyle.copyWith(
                          fontSize: 14, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.end,
                    ),
                    pw.Text(
                      driverData.email,
                      style: pw.Theme.of(context).defaultTextStyle.copyWith(
                          fontSize: 14, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.end,
                    ),
                    pw.Text(
                      "${driverData.countryCode}${driverData.phone.startsWith("0", 0) ? driverData.phone.substring(1) : driverData.phone}",
                      style: pw.Theme.of(context).defaultTextStyle.copyWith(
                          fontSize: 14, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.end,
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                          pw.Text(
                            "Client:",
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            customerDetails.fullName,
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.normal),
                          ),
                          pw.Text(
                            "${customerDetails.countryCode}${customerDetails.phone.startsWith("0", 0) ? customerDetails.phone.substring(1) : customerDetails.phone} ",
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.normal),
                          ),
                        ])),
                    pw.Expanded(
                        child: pw.Column(
                      children: [
                        pw.Row(children: [
                          pw.Text(
                            'N° de facture: ',
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(
                                    color: PdfColors.black,
                                    fontSize: 15,
                                    lineSpacing: 0,
                                    fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            "MISY/${Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().year}/${Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().month < 10 ? "0${Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().month}" : Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().month}/${Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().day}${generateInvoiceNumber()}",
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(
                                    color: PdfColors.black,
                                    lineSpacing: 0,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.normal),
                          ),
                        ]),
                        pw.Row(children: [
                          pw.Text(
                            'Date de facturation: ',
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(
                                    color: PdfColors.black,
                                    fontSize: 15,
                                    fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            formatTimestamp(
                                Timestamp.fromDate(
                                    (bookingDetails['endTime'] as Timestamp)
                                        .toDate()
                                        .toUtc()
                                        .add(const Duration(hours: 3))),
                                formateString: 'dd-MM-yyyy'),
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(
                                    color: PdfColors.black,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.normal),
                          ),
                        ]),
                      ],
                    )),
                  ],
                ),
                pw.SizedBox(height: 20),
              ]),
        );
      },
      build: (pw.Context context) => <pw.Widget>[
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              cellAlignment: pw.Alignment.center,
              headerAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(width: 1),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
              },
            ),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              pw.Expanded(
                flex: 8,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      style: const pw.TextStyle(lineSpacing: 0), "Total HT : "),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      style: const pw.TextStyle(lineSpacing: 0),
                      "${(totalHt).toStringAsFixed(2)} ${globalSettings.currency}"),
                ),
              ),
            ]),
            pw.Row(children: [
              pw.Expanded(
                flex: 8,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      style: const pw.TextStyle(lineSpacing: 0),
                      "Total TVA 20% : "),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      style: const pw.TextStyle(lineSpacing: 0),
                      "${(total18PercentTva).toStringAsFixed(2)} ${globalSettings.currency}"),
                ),
              ),
            ]),
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 8,
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                        style: const pw.TextStyle(lineSpacing: 0),
                        "Montant total à payer : "),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                        style: const pw.TextStyle(lineSpacing: 0),
                        "${totalRidePrice.toStringAsFixed(2)} ${globalSettings.currency}"),
                  ),
                ),
              ],
            ),
          ]));

  print('🔶 PDF_DEBUG: PDF page created, generating final document...');
  Uint8List result = await doc.save();
  print('🔶 PDF_DEBUG: PDF document saved successfully, size: ${result.length} bytes');
  return result;
  } catch (e) {
    print('🔶 PDF_DEBUG: FATAL ERROR in generateCustomerInvoice: $e');
    print('🔶 PDF_DEBUG: Stack trace: ${StackTrace.current}');
    rethrow;
  }
}

Future<Uint8List> generateDriverInvoice(
    {required bookingDetails, required DriverModal driverData}) async {
  final pw.Document doc = pw.Document();
  final Uint8List splashImage = await getImageBytes(MyImagesUrl.splashLogo);
  double totalCommision = double.parse(
      formatNearest(double.parse(bookingDetails['ride_price_commission'])));
  double totalTVA = 0;  // Entreprise non assujettie à la TVA (impôt synthétique)
  double totalHT = totalCommision;  // HT = TTC car pas de TVA

  // Obtenir le taux de commission pour affichage (fallback 15%)
  double commissionPercent = ((bookingDetails['admin_commission_in_per'] ?? 15.0) as num).toDouble();

// Table data
  List<List<String>> data = [
    ['Date de la transaction', 'Description', 'Qté', 'Prix total'],
    [
      formatTimestamp(bookingDetails['endTime'], formateString: "dd/MM/yyyy"),
      'Frais de service (${commissionPercent.toStringAsFixed(0)}%)',
      '1',
      "${totalHT.toStringAsFixed(2)} ${globalSettings.currency}"
    ],
    // Add more rows as needed
  ];
  // Table headers
  List<String> headers = data.removeAt(0);

  doc.addPage(pw.MultiPage(
      footer: (context) => pw.Paragraph(
            text:
                "Exonéré de TVA - Régime de l'impôt synthétique\nSARLU Misy Technology / Ambohimamory AB 739/III, ANTANETY, BEMASOANDRO, ANTANANARIVO ATSIMONDRANO / RCS Antananarivo 2024 B 00089 / NIF : 3 018 428 139 / STAT : 49292-11-2024-0-10090",
            style: pw.Theme.of(context).defaultTextStyle.copyWith(
                color: PdfColors.black,
                fontSize: 8,
                fontWeight: pw.FontWeight.normal),
          ),
      pageFormat: PdfPageFormat.a4,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      header: (pw.Context context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
          padding: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
          decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey, width: 0.5))),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.ClipRRect(
                        horizontalRadius: 2,
                        verticalRadius: 2,
                        child: pw.Image(pw.MemoryImage(splashImage),
                            height: 55, width: 65),
                      ),
                      pw.Expanded(
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            'Facture',
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(
                                    color: PdfColors.black,
                                    fontSize: 25,
                                    fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      )
                    ]),
                pw.SizedBox(height: 20),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'SARLU Misy Technology',
                        style: pw.Theme.of(context).defaultTextStyle.copyWith(
                            color: PdfColors.black,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Client:',
                        style: pw.Theme.of(context).defaultTextStyle.copyWith(
                            color: PdfColors.black,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold),
                      )
                    ]),
                pw.SizedBox(
                  height: 10,
                ),
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Ambohimamory AB 739/III, ANTANETY, BEMASOANDRO, ANTANANARIVO ATSIMONDRANO',
                                style: pw.Theme.of(context)
                                    .defaultTextStyle
                                    .copyWith(
                                        color: PdfColors.black,
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.normal),
                              ),
                              pw.Text(
                                'RCS Antananarivo 2024 B 00089',
                                style: pw.Theme.of(context)
                                    .defaultTextStyle
                                    .copyWith(
                                        color: PdfColors.black,
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.normal),
                              ),
                              pw.Text(
                                'NIF : 3 018 428 139',
                                style: pw.Theme.of(context)
                                    .defaultTextStyle
                                    .copyWith(
                                        color: PdfColors.black,
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.normal),
                              ),
                              pw.Text(
                                'STAT : 49292-11-2024-0-10090',
                                style: pw.Theme.of(context)
                                    .defaultTextStyle
                                    .copyWith(
                                        color: PdfColors.black,
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.normal),
                              )
                            ]),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            children: [
                              pw.Text(driverData.fullName,
                                  style: pw.Theme.of(context)
                                      .defaultTextStyle
                                      .copyWith(
                                          fontSize: 14,
                                          fontWeight: pw.FontWeight.normal),
                                  textAlign: pw.TextAlign.end),
                              pw.Text(
                                driverData.companyAddress,
                                style: pw.Theme.of(context)
                                    .defaultTextStyle
                                    .copyWith(
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.normal),
                                textAlign: pw.TextAlign.end,
                              ),
                              pw.Text(
                                driverData.nifNumber,
                                style: pw.Theme.of(context)
                                    .defaultTextStyle
                                    .copyWith(
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.normal),
                                textAlign: pw.TextAlign.end,
                              ),
                              pw.Text(
                                driverData.statisticNumber,
                                style: pw.Theme.of(context)
                                    .defaultTextStyle
                                    .copyWith(
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.normal),
                                textAlign: pw.TextAlign.end,
                              ),
                              pw.Text(
                                driverData.email,
                                style: pw.Theme.of(context)
                                    .defaultTextStyle
                                    .copyWith(
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.normal),
                                textAlign: pw.TextAlign.end,
                              ),
                              pw.Text(
                                "${driverData.countryCode}${driverData.phone.startsWith("0", 0) ? driverData.phone.substring(1) : driverData.phone}",
                                style: pw.Theme.of(context)
                                    .defaultTextStyle
                                    .copyWith(
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.normal),
                                textAlign: pw.TextAlign.end,
                              ),
                            ]),
                      )
                    ]),
                pw.SizedBox(height: 10),
                pw.Row(children: [
                  pw.Text(
                    'N° de facture: ',
                    style: pw.Theme.of(context).defaultTextStyle.copyWith(
                        color: PdfColors.black,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    "MISY/${Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().year}/${Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().month < 10 ? "0${Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().month}" : Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().month}/${Timestamp.fromDate((bookingDetails['endTime'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3))).toDate().day}${generateInvoiceNumber()}",
                    style: pw.Theme.of(context).defaultTextStyle.copyWith(
                        color: PdfColors.black,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.normal),
                  ),
                ]),
                pw.SizedBox(height: 5),
                pw.Row(children: [
                  pw.Text(
                    'Date de facturation: ',
                    style: pw.Theme.of(context).defaultTextStyle.copyWith(
                        color: PdfColors.black,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    formatTimestamp(
                        Timestamp.fromDate(
                            (bookingDetails['endTime'] as Timestamp)
                                .toDate()
                                .toUtc()
                                .add(const Duration(hours: 3))),
                        formateString: 'dd-MM-yyyy'),
                    style: pw.Theme.of(context).defaultTextStyle.copyWith(
                        color: PdfColors.black,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.normal),
                  ),
                ]),
                pw.SizedBox(height: 20),
              ]),
        );
      },
      build: (pw.Context context) => <pw.Widget>[
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              cellAlignment: pw.Alignment.center,
              headerAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(width: 1),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
              },
            ),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              pw.Expanded(
                flex: 8,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      style: const pw.TextStyle(lineSpacing: 0), "Total HT : "),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      style: const pw.TextStyle(lineSpacing: 0),
                      "${totalHT.toStringAsFixed(2)} ${globalSettings.currency}"),
                ),
              ),
            ]),
            pw.Row(children: [
              pw.Expanded(
                flex: 8,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      style: const pw.TextStyle(lineSpacing: 0),
                      "Total TVA 0% : "),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    "${totalTVA.toStringAsFixed(2)} ${globalSettings.currency}",
                    style: const pw.TextStyle(lineSpacing: 0),
                  ),
                ),
              ),
            ]),
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 8,
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                        style: const pw.TextStyle(lineSpacing: 0),
                        "Montant total à payer : "),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        style: const pw.TextStyle(lineSpacing: 0),
                        "${totalCommision.toStringAsFixed(2)} ${globalSettings.currency}",
                      )),
                ),
              ],
            ),
          ]));

  return await doc.save();
}

Future<Uint8List> getImageBytes(String imagePath) async {
  final ByteData data = await rootBundle.load(imagePath);
  return data.buffer.asUint8List();
}

String generateInvoiceNumber() {
  Random random = Random();
  // Generate a random number between 100000 and 999999
  int randomNumber = 100000 + random.nextInt(900000);
  return randomNumber.toString();
}
