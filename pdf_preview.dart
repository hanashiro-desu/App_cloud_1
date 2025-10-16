import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfPreview extends StatelessWidget {
  final Uint8List pdfBytes;

  const PdfPreview({super.key, required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    final controller = PdfController(document: PdfDocument.openData(pdfBytes));
    return PdfView(controller: controller);
  }
}
