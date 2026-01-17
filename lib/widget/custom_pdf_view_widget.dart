import 'package:rider_ride_hailing_app/utils/platform.dart';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class CustomPdfViewWidget extends StatefulWidget {
  final File file;
  const CustomPdfViewWidget({super.key, required this.file});

  @override
  State<CustomPdfViewWidget> createState() => _CustomPdfViewWidgetState();
}

class _CustomPdfViewWidgetState extends State<CustomPdfViewWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("View Pdf File"),
      ),
      body: Center(
          child: PDFView(
        filePath: widget.file.path,
        autoSpacing: false,
        pageFling: false,
      )),
    );
  }
}
