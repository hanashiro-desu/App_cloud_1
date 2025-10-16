// lib/views/trash.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trash_model.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import '../services/trash_service.dart';

class TrashManager {
  final TrashService _trashService = TrashService();
  final _client = Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  // ---------------- FILE ----------------

  Future<bool> moveToTrashFile(FileModel file, String trashPath) async {
    final profileId = _currentUserId;
    if (profileId == null) return false;

    final finalTrashPath = trashPath.startsWith('$profileId/')
        ? trashPath
        : '$profileId/Trash/${file.name}';

    final ok = await _trashService.moveToTrash(
      type: 'file',
      originalId: file.id,
      originalPath: file.path!,
      trashPath: finalTrashPath,
    );

    if (ok) print('🗑️ [TrashManager] Đã chuyển file "${file.name}" vào thùng rác.');
    return ok;
  }

  Future<bool> restoreFile(Trash trash) async {
    final profileId = _currentUserId;
    if (profileId == null) return false;

    final ok = await _trashService.restoreTrash(trash);
    if (ok) print('♻️ [TrashManager] Đã phục hồi file "${trash.originalPath}"');
    return ok;
  }

  Future<bool> deleteFilePermanently(Trash trash) async {
    final profileId = _currentUserId;
    if (profileId == null) return false;

    final ok = await _trashService.deletePermanently(trash);
    if (ok) print('🚮 [TrashManager] Đã xóa vĩnh viễn file "${trash.originalPath}"');
    return ok;
  }

  // ---------------- FOLDER ----------------

  Future<bool> moveToTrashFolder(FolderModel folder, String trashPath) async {
    final profileId = _currentUserId;
    if (profileId == null) return false;

    final ok = await _trashService.moveToTrash(
      type: 'folder',
      originalId: folder.id!,
      originalPath: folder.path!,
      trashPath: trashPath,
    );

    if (ok) print('📁 [TrashManager] Đã chuyển folder "${folder.name}" vào thùng rác.');
    return ok;
  }

  /// 🔹 Move folder + tất cả folder/file con theo đệ quy
  Future<bool> moveToTrashFolderRecursive(FolderModel folder, {String? parentTrashPath}) async {
    final profileId = _currentUserId;
    if (profileId == null) return false;

    final currentTrashPath = parentTrashPath != null
        ? '$parentTrashPath/${folder.name}'
        : '$profileId/Trash/${folder.name}';

    // 1️⃣ Lấy folder con
    final subfoldersRes = await _client
        .from('folders')
        .select()
        .eq('parent_id', folder.id)
        .eq('is_deleted', false);

    final subfolders = (subfoldersRes as List<dynamic>)
        .map((e) => FolderModel.fromMap(e))
        .toList();

    for (var sub in subfolders) {
      await moveToTrashFolderRecursive(sub, parentTrashPath: currentTrashPath);
    }

    // 2️⃣ Lấy file trong folder
    final filesRes = await _client
        .from('files')
        .select()
        .eq('folder_id', folder.id)
        .eq('is_deleted', false);

    final files = (filesRes as List<dynamic>)
        .map((e) => FileModel.fromMap(e))
        .toList();

    for (var file in files) {
      final trashPath = '$currentTrashPath/${file.name}';
      await moveToTrashFile(file, trashPath);
    }

    // 3️⃣ Move folder cha
    return await moveToTrashFolder(folder, currentTrashPath);
  }

  /// 🔹 Restore folder + tất cả file/folder con
  Future<bool> restoreFolderRecursive(Trash folderTrash) async {
    final profileId = _currentUserId;
    if (profileId == null) return false;

    final trashList = await _trashService.fetchAllTrash();

    final folderItems = trashList.where((t) =>
    t.originalPath.startsWith(folderTrash.originalPath) &&
        t.profileId == profileId
    ).toList();

    for (var t in folderItems) {
      await _trashService.restoreTrash(t);
    }

    print('♻️ [TrashManager] Đã phục hồi folder "${folderTrash.originalPath}" cùng các con.');
    return true;
  }

  /// 🔹 Xóa vĩnh viễn folder + tất cả file/folder con
  Future<bool> deleteFolderPermanentlyRecursive(Trash folderTrash) async {
    final profileId = _currentUserId;
    if (profileId == null) return false;

    final trashList = await _trashService.fetchAllTrash();

    final folderItems = trashList.where((t) =>
    t.originalPath.startsWith(folderTrash.originalPath) &&
        t.profileId == profileId
    ).toList();

    for (var t in folderItems) {
      await _trashService.deletePermanently(t);
    }

    print('🚮 [TrashManager] Đã xóa vĩnh viễn folder "${folderTrash.originalPath}" cùng các con.');
    return true;
  }

  // ---------------- FETCH ----------------

  Future<Map<String, dynamic>> fetchAllTrash() async {
    final profileId = _currentUserId;
    if (profileId == null) return {'files': [], 'folders': []};

    final trashList = await _trashService.fetchAllTrash();

    final files = trashList.where((t) => t.type == 'file').toList();
    final folders = trashList.where((t) => t.type == 'folder').toList();

    return {'files': files, 'folders': folders};
  }
}
