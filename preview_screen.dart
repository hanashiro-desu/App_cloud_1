import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/pdf_preview.dart';
import '../widgets/image_preview.dart';
import '../widgets/web_preview.dart';

class PreviewScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;

  const PreviewScreen({super.key, required this.fileUrl, required this.fileName});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late Future<Uint8List> _pdfBytes;

  Future<Uint8List> _loadPdfBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception("Không tải được PDF");
  }

  @override
  void initState() {
    super.initState();
    if (widget.fileName.toLowerCase().endsWith(".pdf")) {
      _pdfBytes = _loadPdfBytes(widget.fileUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.fileName.split('.').last.toLowerCase();

    Widget body;
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
      body = ImagePreview(imageUrl: widget.fileUrl);
    } else if (ext == 'pdf') {
      body = FutureBuilder<Uint8List>(
        future: _pdfBytes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi mở PDF: ${snapshot.error}"));
          }
          return PdfPreview(pdfBytes: snapshot.data!);
        },
      );
    } else {
      final docsUrl =
          "https://docs.google.com/viewer?url=${widget.fileUrl}&embedded=true";
      body = WebPreview(url: docsUrl);
    }

    return Scaffold(
      appBar: AppBar(title: Text("Xem trước: ${widget.fileName}")),
      body: body,
    );
  }
}
