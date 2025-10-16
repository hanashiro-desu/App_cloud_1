// lib/services/move_logic.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/folder_model.dart';
import '../services/folder_service.dart';
import '../services/file_service.dart';

class MoveLogic {
  static final FolderService _folderService = FolderService();
  static final FileService _fileService = FileService();

  /// Lấy danh sách folder có thể di chuyển (loại trừ folder excludeId)
  static Future<List<FolderModel>> fetchMovableFolders({String? excludeId}) async {
    final folders = await _folderService.fetchAllFolders();
    return folders.where((f) => f.id != excludeId).toList();
  }

  /// Di chuyển file hoặc folder
  static Future<bool> moveItem({
    required bool isFile,
    required String itemId,
    FolderModel? destinationFolder,
  }) async {
    if (isFile) {
      // Move file trong cùng user, folderId = null nếu move ra root
      return await _fileService.moveFile(
        fileId: itemId,
        folderId: destinationFolder?.id, // null = root
      );
    } else {
      // Move folder trong cùng user, newParentId = null nếu move ra root
      return await _folderService.moveFolder(
        folderId: itemId,
        newParentId: destinationFolder?.id, // null = root
      );
    }
  }
}
