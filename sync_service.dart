import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'file_service.dart';
import 'folder_service.dart';
import 'storage_service.dart';

class SyncService {
  final _client = Supabase.instance.client;
  final _folderService = FolderService();
  final _fileService = FileService();
  final _storageService = StorageService();

  /// 🔄 Đồng bộ toàn bộ Storage ↔ Database
  Future<void> syncAllRecursive() async {
    try {
      final folders = await _client.from('folders').select();
      final files = await _client.from('files').select();

      // 1️⃣ Đồng bộ DB → Storage
      for (final folder in folders) {
        final path = folder['path'];
        final exists = await _storageService.folderExists(path);
        if (!exists) await _storageService.createFolder(path);
      }

      for (final file in files) {
        final path = file['path'];
        final exists = await _storageService.exists(path);
        if (!exists && file['content'] != null) {
          final content = Uint8List.fromList(List<int>.from(file['content']));
          await _storageService.uploadBytes(content, path);
        }
      }

      // 2️⃣ (Tuỳ chọn) Storage → DB nếu có file mới trong bucket
      await _syncStorageToDatabase('<profile_id_cần_đồng_bộ>');
    } catch (e) {
      print('⚠️ syncAllRecursive error: $e');
    }
  }

  /// 🔹 Đồng bộ Storage → Database
  Future<void> _syncStorageToDatabase(String profileId,
      {String? parentPath, String? parentId}) async {
    final path = parentPath ?? profileId;
    final items = await _client.storage.from('files').list(path: path);

    for (final item in items) {
      final isFolder = item.metadata == null;
      final itemPath =
      parentPath == null ? "$profileId/${item.name}" : "$parentPath/${item.name}";

      if (isFolder) {
        // Query folder trong DB
        var query = _client.from('folders').select('id')
            .eq('name', item.name)
            .eq('profile_id', profileId);

        if (parentId == null) {
          query = query.filter('parent_id', 'is', null);
        } else {
          query = query.eq('parent_id', parentId);
        }

        final existingFolder = await _maybeFirst(query);

        String folderId;
        if (existingFolder == null) {
          final folder = await _folderService.createFolder(
            name: item.name,
            parentId: parentId,
            profileId: profileId,
            parentPath: parentPath,
          );

          if (folder == null) {
            print('❌ Lỗi tạo folder: ${item.name}');
            continue;
          }

          folderId = folder['id'] as String;
          print("✅ Thêm folder: ${item.name}");
        } else {
          folderId = existingFolder['id'] as String;
        }

        // Đệ quy folder con
        await _syncStorageToDatabase(profileId, parentPath: itemPath, parentId: folderId);
      } else {
        // File
        var fileQuery = _client.from('files').select('id')
            .eq('name', item.name)
            .eq('profile_id', profileId);

        if (parentId == null) {
          fileQuery = fileQuery.filter('folder_id', 'is', null);
        } else {
          fileQuery = fileQuery.eq('folder_id', parentId);
        }

        final existingFile = await _maybeFirst(fileQuery);

        if (existingFile == null) {
          await _fileService.createFile(
              name: item.name, folderId: parentId, path: itemPath, profileId: profileId);
          print("🗂️ Thêm file: ${item.name}");
        }
      }
    }
  }

  /// 🔹 Đồng bộ Database → Storage
  Future<void> _syncDatabaseToStorage(String profileId,
      {String? parentPath, String? parentId}) async {
    // Folder
    var folderQuery = _client.from('folders').select('id,name').eq('profile_id', profileId);
    if (parentId == null) {
      folderQuery = folderQuery.filter('parent_id', 'is', null);
    } else {
      folderQuery = folderQuery.eq('parent_id', parentId);
    }
    final folders = await folderQuery;

    for (final folder in folders as List<dynamic>) {
      final name = folder['name'] as String;
      final id = folder['id'] as String;
      final path = parentPath != null
          ? "$parentPath/$name"
          : "$profileId/$name";

      final exists = await _storageService.folderExists(path);
      if (!exists) {
        await _storageService.createFolder(path);
        print("🪄 Tạo folder Storage: $path");
      }

      // Đệ quy folder con
      await _syncDatabaseToStorage(profileId, parentPath: path, parentId: id);
    }

    // File
    var fileQuery = _client.from('files').select('id,name,path,content')
        .eq('profile_id', profileId);
    if (parentId == null) {
      fileQuery = fileQuery.filter('folder_id', 'is', null);
    } else {
      fileQuery = fileQuery.eq('folder_id', parentId);
    }

    final files = await fileQuery;

    for (final file in files as List<dynamic>) {
      final path = file['path'] as String;
      final exists = await _storageService.fileExists(path);
      if (!exists) {
        // Lấy bytes từ DB, bạn cần thêm cột content (bytea) hoặc lấy từ fileService
        final Uint8List bytes = await _fileService.getFileBytes(file['id'] as String);
        final ok = await _storageService.uploadBytes(bytes, path);
        if (ok) print("⬆️ Upload file lên Storage: $path");
      }
    }
  }

  /// 🔹 Helper: lấy 1 object hoặc null
  Future<Map<String, dynamic>?> _maybeFirst(PostgrestFilterBuilder query) async {
    final res = await query.maybeSingle();
    return res as Map<String, dynamic>?;
  }

}