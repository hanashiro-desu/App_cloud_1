import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trash_model.dart';

class TrashService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _trashTable = 'trash';

  /// 🗑️ Di chuyển file hoặc folder vào Trash
  Future<bool> moveToTrash({
    required String type, // 'file' hoặc 'folder'
    required String originalId,
    required String originalPath,
    required String trashPath,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        print('⚠️ Không tìm thấy người dùng đăng nhập!');
        return false;
      }

      // 🔹 Lấy profile_id từ bảng profiles dựa trên user.id
      final profileRes = await _client
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      final profileId = profileRes?['id'];
      if (profileId == null) {
        print('⚠️ Không tìm thấy profile_id hợp lệ cho user ${user.id}');
        return false;
      }

      print('🗑️ [moveToTrash] Chuẩn bị insert vào trash: $originalId - $originalPath');

      await _client.from(_trashTable).insert({
        'type': type,
        'original_id': originalId,
        'original_path': originalPath,
        'trash_path': trashPath,
        'deleted_at': DateTime.now().toIso8601String(),
        'restored': false,
        'profile_id': profileId, // 🔹 Dùng profile_id đúng
      });

      // Nếu là file, di chuyển trong storage
      if (type == 'file') {
        await _client.storage.from('files').move(originalPath, trashPath);
      }

      // Cập nhật cờ xóa trong bảng gốc
      final table = (type == 'file') ? 'files' : 'folders';
      await _client.from(table).update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', originalId);

      print('✅ Move $type ($originalId) to trash for profile $profileId');
      return true;
    } catch (e) {
      print('❌ [moveToTrash] Lỗi: $e');
      if (e is PostgrestException) print('🔍 Chi tiết: ${e.message}');
      return false;
    }
  }

  /// 📋 Lấy tất cả file/folder trong Trash (theo người dùng hiện tại)
  Future<List<Trash>> fetchAllTrash() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        print('⚠️ Chưa đăng nhập!');
        return [];
      }

      // 🔹 Lấy profile_id từ bảng profiles
      final profileRes = await _client
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      final profileId = profileRes?['id'];
      if (profileId == null) {
        print('⚠️ Không tìm thấy profile_id cho user ${user.id}');
        return [];
      }

      // 🔹 Lấy tất cả trash cho profile_id
      final response = await _client
          .from(_trashTable)
          .select('*')
          .eq('restored', false)
          .eq('profile_id', profileId)
          .order('deleted_at', ascending: false);

      final List<dynamic> data = response;
      print('🧭 [TrashService] Có ${data.length} bản ghi trong trash của profile $profileId');

      return data.map((row) => Trash.fromMap(row as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ [fetchAllTrash] Lỗi: $e');
      return [];
    }
  }

  /// ♻️ Phục hồi file/folder từ Trash
  Future<bool> restoreTrash(Trash trash) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        print('⚠️ Chưa đăng nhập!');
        return false;
      }

      // Nếu là file thì restore bình thường
      if (trash.type == 'file') {
        await _client.storage
            .from('files')
            .move(trash.trashPath, trash.originalPath);

        // Cập nhật DB files
        await _client.from('files').update({
          'is_deleted': false,
          'deleted_at': null,
        }).eq('id', trash.originalId);

        // Xóa record trong trash
        await _client.from(_trashTable).delete().eq('id', trash.id);

        print('♻️ File restored: ${trash.originalPath}');
        return true;
      }

      // Nếu là folder thì restore đệ quy
      if (trash.type == 'folder') {
        final originalPath = trash.originalPath;

        // 1️⃣ Lấy tất cả file con trong folder đó (bao gồm các file trong folder con)
        final filesToRestore = await _client
            .from('files')
            .select()
            .ilike('path', '$originalPath%')
            .eq('is_deleted', true);

        for (final f in filesToRestore) {
          final fileTrashPath = f['path'] as String;
          final fileOriginalPath = fileTrashPath.replaceFirst(
            '${user.id}/Trash/',
            '${user.id}/',
          );

          // Move file trong storage
          await _client.storage.from('files').move(fileTrashPath, fileOriginalPath);

          // Cập nhật DB
          await _client.from('files').update({
            'path': fileOriginalPath,
            'is_deleted': false,
            'deleted_at': null,
          }).eq('id', f['id']);

          // Xóa record trong trash
          await _client.from(_trashTable).delete().eq('original_id', f['id']);
        }

        // 2️⃣ Lấy tất cả folder con trong folder đó (bao gồm folder con sâu)
        final foldersToRestore = await _client
            .from('folders')
            .select()
            .ilike('path', '$originalPath%')
            .eq('is_deleted', true);

        for (final f in foldersToRestore) {
          final folderOriginalPath = f['path'] as String;
          final restoredPath = folderOriginalPath.replaceFirst(
            '${user.id}/Trash/',
            '${user.id}/',
          );

          await _client.from('folders').update({
            'path': restoredPath,
            'is_deleted': false,
            'deleted_at': null,
          }).eq('id', f['id']);

          await _client.from(_trashTable).delete().eq('original_id', f['id']);
        }

        // 3️⃣ Restore chính folder
        await _client.storage.from('files').move(trash.trashPath, trash.originalPath);
        await _client.from('folders').update({
          'path': trash.originalPath,
          'is_deleted': false,
          'deleted_at': null,
        }).eq('id', trash.originalId);
        await _client.from(_trashTable).delete().eq('id', trash.id);

        print('♻️ Folder restored: ${trash.originalPath}');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ [restoreTrash] Lỗi: $e');
      return false;
    }
  }

  /// ❌ Xóa vĩnh viễn khỏi Trash
  Future<bool> deletePermanently(Trash trash) async {
    try {
      if (trash.type == 'file') {
        await _client.storage.from('files').remove([trash.trashPath]);
      }

      await _client.from(_trashTable).delete().eq('id', trash.id);

      print('🗑️ Đã xóa vĩnh viễn: ${trash.originalPath}');
      return true;
    } catch (e) {
      print('❌ [deletePermanently] Lỗi: $e');
      return false;
    }
  }

  /// ❌ Xóa folder cùng tất cả file/folder con trong Trash
  Future<bool> deleteFolderRecursive(Trash folderTrash) async {
    try {
      final folderId = folderTrash.originalId;

      // 1️⃣ Lấy tất cả folder con
      final subfoldersRes = await _client
          .from('folders')
          .select('*')
          .eq('parent_id', folderId)
          .eq('is_deleted', true); // chỉ folder đã move to trash

      final List<dynamic> subfolders = subfoldersRes;

      // 2️⃣ Đệ quy xóa folder con
      for (var sub in subfolders) {
        final subTrash = Trash(
          id: sub['id'],
          type: 'folder',
          originalId: sub['id'],
          originalPath: sub['path'],
          trashPath: '${folderTrash.trashPath}/${sub['name']}',
          deletedAt: DateTime.parse(sub['deleted_at']),
          restored: false,
        );
        await deleteFolderRecursive(subTrash);
      }

      // 3️⃣ Lấy tất cả file trong folder
      final filesRes = await _client
          .from('files')
          .select('*')
          .eq('folder_id', folderId)
          .eq('is_deleted', true);

      final List<dynamic> files = filesRes;

      // 4️⃣ Xóa từng file vĩnh viễn
      for (var file in files) {
        final fileTrash = Trash(
          id: file['id'],
          type: 'file',
          originalId: file['id'],
          originalPath: file['path'],
          trashPath: '${folderTrash.trashPath}/${file['name']}',
          deletedAt: DateTime.parse(file['deleted_at']),
          restored: false,
        );
        await deletePermanently(fileTrash);
      }

      // 5️⃣ Xóa folder chính trong storage + trash
      await _client.storage.from('files').remove([folderTrash.trashPath]);
      await _client.from(_trashTable).delete().eq('id', folderTrash.id);
      await _client.from('folders').delete().eq('id', folderId);

      print('🗑️ Đã xóa vĩnh viễn folder: ${folderTrash.originalPath}');
      return true;
    } catch (e) {
      print('❌ [deleteFolderRecursive] Lỗi: $e');
      return false;
    }
  }
}
