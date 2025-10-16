// lib/services/file_preview_service.dart
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class FilePreviewService {
  /// Tải PDF từ URL
  Future<Uint8List> fetchPdfBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception("Không tải được PDF");
    }
  }

  /// Lấy loại file từ tên file
  String getFileExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }

}