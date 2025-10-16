import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/folder_model.dart';
import '../models/file_model.dart';
import 'file_service.dart';
import 'trash_service.dart';
import 'package:uuid/uuid.dart';
import 'storage_service.dart';
import 'package:flutter/foundation.dart';
import '../views/trash.dart';


class FolderService {
  final SupabaseClient client = Supabase.instance.client;
  final String tableName = 'folders';

  final FileService _fileService = FileService();
  final TrashService _trashService = TrashService();
  final StorageService _storageService = StorageService();


  /// 📂 Lấy danh sách folder theo parentId & profileId
  Future<List<FolderModel>> fetchFolders({
    String? parentId,
    required String profileId,
  }) async {
    try {
      var query = client
          .from(tableName)
          .select()
          .eq('is_deleted', false)
          .eq('profile_id', profileId);

      if (parentId != null) {
        query = query.eq('parent_id', parentId);
      } else {
        query = query.isFilter('parent_id', null);
      }

      final data = await query;
      if (data == null) return [];

      return (data as List<dynamic>)
          .map((e) => FolderModel.fromMap(e))
          .toList();
    } catch (e) {
      print('❌ Lỗi fetchFolders: $e');
      return [];
    }
  }

  // ✅ Hàm mới: Lấy tất cả thư mục của mọi người dùng
  Future<List<FolderModel>> fetchAllFolders() async {
    try {
      final response = await client
          .from(tableName)
          .select()
          .order('created_at', ascending: true);

      final data = response as List<dynamic>;
      return data.map((item) => FolderModel.fromJson(item)).toList();
    } catch (e) {
      print('❌ Lỗi fetchAllFolders: $e');
      return [];
    }
  }

  /// 📁 Tạo folder mới
  Future<Map<String, dynamic>?> createFolder({
    required String name,
    required String profileId,
    String? parentId,
    String? parentPath,
  }) async {
    try {
      final id = const Uuid().v4();
      final folderPath = parentPath != null
          ? '$parentPath/$name'
          : '$profileId/$name';

      final res = await client.from(tableName).insert({
        'id': id,
        'name': name,
        'parent_id': parentId,
        'profile_id': profileId,
        'path': folderPath,
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().maybeSingle(); // ✅ lấy folder vừa tạo

      if (res != null) {
        await StorageService().createFolder(folderPath);
      }

      return res; // Map<String,dynamic> của folder
    } catch (e) {
      print('❌ Lỗi createFolder: $e');
      return null;
    }
  }

  /// ✏️ Đổi tên folder
  Future<bool> renameFolder(String folderId, String newName) async {
    try {
      // 1️⃣ Lấy folder hiện tại
      final folderData = await client.from(tableName).select().eq('id', folderId).single();
      final folder = FolderModel.fromJson(folderData);

      final oldPath = folder.path ?? ''; // ✅ tránh null
      final pathParts = oldPath.split('/');
      pathParts[pathParts.length - 1] = newName;
      final newPath = pathParts.join('/');

      // 2️⃣ Di chuyển trên Storage
      await _storageService.moveItem(oldPath, newPath);

      // 3️⃣ Cập nhật tên + path mới của folder này
      await client
          .from(tableName)
          .update({'name': newName, 'path': newPath, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', folderId);

      // 4️⃣ Cập nhật đệ quy path con
      await _updatePathsRecursively(folderId, oldPath, newPath);

      return true;
    } catch (e) {
      debugPrint('⚠️ renameFolder error: $e');
      return false;
    }
  }

  /// 🔁 Cập nhật path đệ quy cho toàn bộ file/folder con
  Future<void> _updatePathsRecursively(String parentId, String oldBase, String newBase) async {
    // normalize bases: đảm bảo chúng không null và là full paths
    final oldBaseNormalized = oldBase ?? '';
    final newBaseNormalized = newBase ?? '';

    // Folder con
    final subFolders = await client.from(tableName).select().eq('parent_id', parentId);
    for (final f in subFolders) {
      final oldPath = f['path'] ?? '';
      // use Pattern explicitly to avoid type error
      var newPath = oldPath.replaceFirst(oldBaseNormalized as Pattern, newBaseNormalized);

      // ensure profileId prefix exists
      final folderProfileId = f['profile_id'] ?? '';

      await client.from(tableName).update({'path': newPath}).eq('id', f['id']);
      await _updatePathsRecursively(f['id'], oldBase, newPath);
    }

    // File con
    final files = await client.from('files').select().eq('folder_id', parentId);
    for (final fl in files) {
      final oldPath = fl['path'] ?? '';
      var newPath = oldPath.replaceFirst(oldBaseNormalized as Pattern, newBaseNormalized);

      final fileProfileId = fl['profile_id'] ?? '';
      if (fileProfileId.isNotEmpty && !newPath.startsWith('$fileProfileId/')) {
        newPath = '$fileProfileId/$newPath';
      }

      await client.from('files').update({'path': newPath}).eq('id', fl['id']);
    }
  }

  /// 🗑️ Xóa mềm folder
  Future<bool> deleteFolder(FolderModel folder) async {
    final trashManager = TrashManager();
    return await trashManager.moveToTrashFolderRecursive(folder);
  }

  /// ♻️ Di chuyển folder và tất cả file con vào Trash
  Future<bool> moveToTrash(FolderModel folder) async {
    try {
      if (folder.isDeleted) return false;

      final profileId = folder.profileId ?? '';
      final trashPath = '$profileId/Trash/${folder.path}';

      // 1️⃣ Move file con trong Storage
      final files = await client
          .from('files')
          .select()
          .eq('folder_id', folder.id)
          .eq('is_deleted', false);

      for (final f in files) {
        final file = FileModel.fromMap(f);
        final fileTrashPath = '$profileId/Trash/${file.path}';
        await _storageService.moveItem(file.path!, fileTrashPath);

        // Move file vào trash DB
        await _trashService.moveToTrash(
          type: 'file',
          originalId: file.id!,
          originalPath: file.path!,
          trashPath: fileTrashPath,
        );

        // Cập nhật DB
        await client.from('files').update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
        }).eq('id', file.id);
      }

      // 2️⃣ Move folder con đệ quy (tương tự)
      final subFolders = await client
          .from('folders')
          .select()
          .eq('parent_id', folder.id)
          .eq('is_deleted', false);

      for (final sf in subFolders) {
        final subFolder = FolderModel.fromMap(sf);
        await moveToTrash(subFolder);
      }

      // 3️⃣ Move chính folder
      await _storageService.moveItem(folder.path!, trashPath);
      await _trashService.moveToTrash(
        type: 'folder',
        originalId: folder.id!,
        originalPath: folder.path!,
        trashPath: trashPath,
      );

      await client.from('folders').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', folder.id);

      return true;
    } catch (e) {
      print('❌ [moveToTrash] Lỗi: $e');
      return false;
    }
  }

  /// 📦 Di chuyển folder sang folder khác
  Future<bool> moveFolder({
    required String folderId,
    String? newParentId,
  }) async {
    try {
      final folderData = await client.from(tableName).select().eq('id', folderId).single();
      final folder = FolderModel.fromJson(folderData);

      // old path from DB: ensure it is full (starts with profileId)
      final oldPath = folder.path ?? '';
      final profileId = folder.profileId ?? '';

      String newPath;
      if (newParentId != null) {
        final parentData = await client.from(tableName).select().eq('id', newParentId).single();
        final parent = FolderModel.fromJson(parentData);

        // parent.path may be stored relative or full; normalize
        final rawParentPath = parent.path ?? '';
        // parent.path trong DB đã luôn bắt đầu bằng profileId nên KHÔNG cần thêm lại
        final parentPath = rawParentPath;


        newPath = '$parentPath/${folder.name}';
      } else {
        // move to root under profile
        newPath = '$profileId/${folder.name}';
      }
      print('🧭 MoveFolder old=$oldPath → new=$newPath');

      // 3️⃣ Move in storage (both paths are now full)
      await _storageService.moveItem(oldPath, newPath);

      // 4️⃣ Update DB for this folder
      await client
          .from(tableName)
          .update({
        'parent_id': newParentId,
        'path': newPath,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', folderId);

      // 5️⃣ Recursively update children paths in DB
      await _updatePathsRecursively(folderId, oldPath, newPath);

      return true;
    } catch (e) {
      debugPrint('⚠️ moveFolder error: $e');
      return false;
    }
  }

  /// 🔍 Lấy ID folder theo tên
  Future<String?> getFolderIdByName(String name) async {
    try {
      final res = await client
          .from(tableName)
          .select('id')
          .eq('name', name)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;
      return res['id'] as String?;
    } catch (e) {
      print('❌ Lỗi getFolderIdByName: $e');
      return null;
    }
  }
}
