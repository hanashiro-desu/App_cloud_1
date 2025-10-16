// lib/services/search.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/file_model.dart';

class SearchManager {
  final SupabaseClient _client = Supabase.instance.client;
  final String _tableName = 'files'; // hoặc 'trash_file' nếu muốn tìm trong Trash

  /// Tìm kiếm file với các điều kiện: tên, ngày tạo, loại file, và lọc theo user hiện tại
  Future<List<FileModel>> searchFiles({
    required String profileId, // ✅ đổi từ userId
    String? nameQuery,
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? fileTypes,
    bool includeDeleted = false,
  }) async {
    try {
      var query = _client
          .from(_tableName)
          .select()
          .eq('profile_id', profileId) // ✅ filter theo profile_id
          .maybeFilter('is_deleted', includeDeleted ? null : false);

      if (nameQuery != null && nameQuery.isNotEmpty) {
        query = query.ilike('name', '%$nameQuery%');
      }
      if (fromDate != null) query = query.gte('created_at', fromDate.toIso8601String());
      if (toDate != null) query = query.lte('created_at', toDate.toIso8601String());

      final response = await query;
      final data = response as List<dynamic>;
      var files = data.map((e) => FileModel.fromMap(e)).toList();

      if (fileTypes != null && fileTypes.isNotEmpty) {
        final lowerTypes = fileTypes.map((e) => e.toLowerCase()).toList();
        files = files.where((f) {
          final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
          return lowerTypes.contains(ext);
        }).toList();
      }

      return files;
    } catch (e) {
      print('❌ Lỗi searchFiles: $e');
      return [];
    }
  }
}

/// Extension xử lý filter nullable
extension on PostgrestFilterBuilder {
  PostgrestFilterBuilder maybeFilter(String column, dynamic value) {
    if (value == null) return this;
    return eq(column, value);
  }
}
