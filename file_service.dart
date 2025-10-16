import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import 'trash_service.dart';
import 'package:uuid/uuid.dart';
import 'storage_service.dart';
import 'package:flutter/foundation.dart';
import '../views/trash.dart';

class FileService {
  final SupabaseClient _client = Supabase.instance.client;
  final String tableName = 'files';
  final String bucketName = 'files';
  final TrashService _trashService = TrashService();
  final StorageService _storageService = StorageService();
  final uuid = const Uuid();

  /// 📂 Lấy danh sách file (theo folder & profile)
  Future<List<FileModel>> fetchFiles({
    String? folderId,
    required String profileId,
  }) async {
    try {
      var query = _client
          .from('files')
          .select()
          .eq('is_deleted', false)
          .eq('profile_id', profileId);

      if (folderId != null) {
        query = query.eq('folder_id', folderId);
      } else {
        query = query.isFilter('folder_id', null);
      }

      final response = await query;
      final data = response as List<dynamic>;

      return data
          .map((e) {
        final file = FileModel.fromMap(e);
        return file.copyWith(type: getFileType(file.name));
      })
          .where((f) => f.isFolder == false)
          .toList();
    } catch (e) {
      print('❌ Lỗi fetchFiles: $e');
      return [];
    }
  }

  /// 📤 Upload file mới
  Future<bool> uploadFile({
    required File file,
    required String profileId,
    String? folderId,
  }) async {
    try {
      final fileName = file.uri.pathSegments.last;

      // Lấy folderPath từ folderId nếu có
      String folderPath = '';
      if (folderId != null) {
        folderPath = await _getFolderPathById(folderId);
      }

      // Storage path: nếu folderPath rỗng => root profile
      final storagePath = folderPath.isNotEmpty
          ? '$folderPath/$fileName'
          : '$profileId/$fileName';

      // Upload lên storage
      await _client.storage.from(bucketName).upload(storagePath, file);

      // Tạo record trong DB
      final fileModel = FileModel(
        id: uuid.v4(),
        folderId: folderId,
        profileId: profileId,
        name: fileName,
        type: getFileType(fileName),
        path: storagePath,
        size: await file.length().then((v) => v.toDouble()),
        isFolder: false,
        isDeleted: false,
      );

      await _client.from('files').insert(fileModel.toMap());
      return true;
    } catch (e) {
      print('❌ Lỗi uploadFile: $e');
      return false;
    }
  }

  /// ✏️ Đổi tên file
  Future<bool> renameFile({
    required String fileId,
    required String newName,
  }) async {
    try {
      final res = await _client.from('files').select('path, profile_id').eq('id', fileId).maybeSingle();
      if (res == null) return false;

      final oldPath = res['path'] as String;
      final profileId = res['profile_id'] as String;
      final newPath = oldPath.replaceAll(RegExp(r'[^/]+$'), newName);

      final ok = await _storageService.renameItem(oldPath, newPath);
      if (!ok) return false;

      await _client.from('files').update({
        'name': newName,
        'path': newPath,
      }).eq('id', fileId);
      return true;
    } catch (e) {
      print('❌ Lỗi renameFile: $e');
      return false;
    }
  }

  /// 🗑️ Xóa mềm (chuyển vào thùng rác)
  Future<bool> deleteFile(FileModel file) async {
    final trashManager = TrashManager();
    final profileId = file.profileId ?? '';
    final trashPath = '$profileId/Trash/${file.name}';
    return await trashManager.moveToTrashFile(file, trashPath);
  }

  /// ♻️ Di chuyển vào Trash
  Future<bool> moveToTrash(FileModel file) async {
    try {
      if (file.isDeleted) return false;
      if (file.path == null) throw Exception("File path null");

      final profileId = file.profileId ?? ''; // <-- Thêm dòng này

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final trashPath = '$profileId/Trash/${timestamp}_${file.name}';

      final ok = await _trashService.moveToTrash(
        type: 'file',
        originalId: file.id,
        originalPath: file.path!,
        trashPath: trashPath,
      );

      if (ok) print('✅ Đã chuyển ${file.name} vào Trash');
      return ok;
    } catch (e) {
      print('❌ Lỗi moveToTrash file: $e');
      return false;
    }
  }

  /// 📦 Di chuyển file sang folder khác
  Future<bool> moveFile({
    required String fileId,
    String? folderId,
  }) async {
    try {
      // Lấy file hiện tại
      final fileData = await _client.from(tableName).select().eq('id', fileId).maybeSingle();
      if (fileData == null) return false;
      final file = FileModel.fromMap(fileData);

      final profileId = file.profileId ?? '';

      // Lấy folder nếu có
      String newPath;
      if (folderId != null) {
        final folderData = await _client.from('folders').select().eq('id', folderId).maybeSingle();
        if (folderData == null) return false;
        final folder = FolderModel.fromMap(folderData);
        final folderPath = folder.path ?? '';

        newPath = '$folderPath/${file.name}';
      } else {
        newPath = '$profileId/${file.name}';
      }

      final oldPath = file.path ?? '';

      // ✅ move trong storage
      await _storageService.moveItem(oldPath, newPath);

      // Cập nhật DB
      await _client.from(tableName).update({
        'folder_id': folderId,
        'path': newPath,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', fileId);

      return true;
    } catch (e) {
      debugPrint('⚠️ moveFile error: $e');
      return false;
    }
  }

  /// 🌐 Lấy public URL file
  String getFileUrl(FileModel file) {
    if (file.path == null) return '';
    return _client.storage.from(bucketName).getPublicUrl(file.path!);
  }

  /// 🔍 Xác định loại file
  String getFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) return 'image';
    if (['mp4', 'mov', 'avi', 'mkv', 'wmv'].contains(ext)) return 'video';
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].contains(ext)) return 'document';
    return 'other';
  }

  /// 🧩 Tạo record file
  Future<void> createFile({
    required String name,
    required String profileId,
    String? folderId,
    required String path,
  }) async {
    await _client.from('files').insert({
      'name': name,
      'profile_id': profileId,
      'folder_id': folderId,
      'path': path,
    });
  }

  /// ⬇️ Tải file từ storage
  Future<bool> downloadFile({
    required FileModel file,
    required String localPath,
  }) async {
    try {
      if (file.path == null) throw Exception("File path null");
      final response = await _client.storage.from(bucketName).download(file.path!);
      if (response is List<int>) {
        final localFile = File(localPath);
        await localFile.writeAsBytes(response);
        print('✅ File đã được tải xuống: $localPath');
        return true;
      } else {
        print('❌ Download response không phải List<int>');
        return false;
      }
    } catch (e) {
      print('❌ Lỗi downloadFile: $e');
      return false;
    }
  }

  /// 🔹 Lấy nội dung file từ cột 'content' (Uint8List)
  Future<Uint8List> getFileBytes(String fileId) async {
    final res = await _client
        .from('files')
        .select('content')
        .eq('id', fileId)
        .maybeSingle();

    if (res == null || res['content'] == null) {
      throw Exception('File không tồn tại hoặc không có content');
    }

    return Uint8List.fromList(List<int>.from(res['content'] as List));
  }

  Future<String> _getFolderPathById(String folderId) async {
    final res = await _client.from('folders').select('path').eq('id', folderId).maybeSingle();
    return res?['path'] ?? '';
  }

}
