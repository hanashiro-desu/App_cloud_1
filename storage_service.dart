// lib/services/storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;
  final String bucket = 'files';

  SupabaseClient get supabase => _client;

  /// Lấy danh sách file và folder trong bucket Supabase
  Future<List<Map<String, dynamic>>> listFiles({String path = ''}) async {
    try {
      final List response = await _client.storage.from(bucket).list(path: path);
      final List<Map<String, dynamic>> items = [];

      print('📁 [Debug] Storage list("$path") trả về: ${response.map((e) => e.name).toList()}');

      for (var f in response) {
        final name = (f as dynamic).name ?? '';
        final fullPath = path.isEmpty ? name : '$path/$name';

        // Kiểm tra xem đây có phải là folder không bằng cách thử list bên trong nó
        final subItems = await _client.storage.from(bucket).list(path: fullPath);
        final isFolder = subItems.isNotEmpty || name == '.keep';

        items.add({
          'name': name,
          'path': fullPath,
          'isFolder': isFolder,
          'url': isFolder ? null : getPublicUrl(fullPath),
        });
      }

      return items;
    } catch (e) {
      print('listFiles error: $e');
      return [];
    }
  }

  /// Upload file lên bucket (mặc định lưu ở gốc nếu destPath null)
  Future<bool> uploadFile(File file, {String? destPath}) async {
    try {
      final path = destPath ?? p.basename(file.path);
      await _client.storage.from(bucket).upload(path, file);
      return true;
    } catch (e) {
      print('uploadFile error: $e');
      return false;
    }
  }

  /// Tạo folder bằng cách tạo file .keep (lưu mặc định ở gốc)
  Future<bool> createFolder(String folderName) async {
    try {
      final marker = File('${Directory.systemTemp.path}/.keep_${DateTime.now().millisecondsSinceEpoch}');
      await marker.writeAsBytes(Uint8List(0));
      final ok = await uploadFile(marker, destPath: '$folderName/.keep');
      try { await marker.delete(); } catch (_) {}
      return ok;
    } catch (e) {
      print('createFolder error: $e');
      return false;
    }
  }

  /// Xóa file hoặc folder (folder đệ quy)
  Future<bool> deleteItem(String path) async {
    try {
      final List listed = await _client.storage.from(bucket).list(path: path);
      if (listed.isEmpty) {
        await _client.storage.from(bucket).remove([path]);
      } else {
        for (var f in listed) {
          final name = (f as dynamic).name ?? '';
          final childPath = '$path/$name';
          await deleteItem(childPath);
        }
        try {
          await _client.storage.from(bucket).remove(['$path/.keep']);
        } catch (_) {}
      }
      return true;
    } catch (e) {
      print('deleteItem error: $e');
      return false;
    }
  }

  /// Đổi tên file hoặc folder
  Future<bool> renameItem(String oldPath, String newPath) async {
    try {
      final bytes = await _client.storage.from(bucket).download(oldPath);
      final tmp = File('${Directory.systemTemp.path}/${p.basename(newPath)}');
      await tmp.writeAsBytes(bytes);
      final ok = await uploadFile(tmp, destPath: newPath);
      try { await tmp.delete(); } catch (_) {}
      if (!ok) return false;
      await _client.storage.from(bucket).remove([oldPath]);
      return true;
    } catch (e) {
      print('renameItem error: $e');
      return false;
    }
  }

  /// 🔄 Di chuyển hoặc đổi tên file/folder trong Storage
  Future<void> moveItem(String oldPath, String newPath) async {
    try {
      // Không move giữa 2 người dùng
      final oldRoot = oldPath.split('/').first;
      final newRoot = newPath.split('/').first;
      if (oldRoot != newRoot) {
        throw Exception('❌ moveItem: cannot move between different profile owners');
      }

      final oldItems = await _client.storage.from(bucket).list(path: oldPath);

      if (oldItems.isEmpty) {
        // File đơn
        final file = await _client.storage.from(bucket).download(oldPath);
        await _client.storage.from(bucket).uploadBinary(newPath, file);
        await _client.storage.from(bucket).remove([oldPath]);
      } else {
        // Folder có nội dung → di chuyển đệ quy
        for (final item in oldItems) {
          final oldSubPath = '$oldPath/${item.name}';
          final newSubPath = '$newPath/${item.name}';
          await moveItem(oldSubPath, newSubPath);
        }

        // ⚠️ Chỉ xoá nếu không phải folder gốc profileId
        if (oldPath.split('/').length > 1) {
          try {
            await _client.storage.from(bucket).remove(['$oldPath/.keep']);
          } catch (_) {}
        }
      }
    } catch (e) {
      print('⚠️ moveItem error: $e');
    }
  }

  /// Tải file về máy
  Future<File?> downloadFile(String path) async {
    try {
      final bytes = await _client.storage.from(bucket).download(path);
      final file = File('${Directory.systemTemp.path}/${p.basename(path)}');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      print('downloadFile error: $e');
      return null;
    }
  }

  Future<bool> folderExists(String path) async {
    final list = await Supabase.instance.client.storage.from('files').list(path: path);
    return list.isNotEmpty;
  }

  /// Lấy URL public
  String getPublicUrl(String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Tải file về dạng bytes (nếu cần)
  Future<Uint8List> downloadBytes(String path) async {
    return await _client.storage.from(bucket).download(path);
  }

  Future<bool> fileExists(String path) async {
    try {
      final list = await _client.storage.from(bucket).list(path: path);
      // Nếu path là file thì list trả về rỗng => thử download để check
      if (list.isEmpty) {
        try {
          await _client.storage.from(bucket).download(path);
          return true;
        } catch (_) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadBytes(Uint8List bytes, String destPath) async {
    try {
      await _client.storage.from(bucket).uploadBinary(destPath, bytes);
      return true;
    } catch (e) {
      print('uploadBytes error: $e');
      return false;
    }
  }

  /// ✅ Kiểm tra tồn tại (file hoặc folder)
  Future<bool> exists(String path) async {
    try {
      // Kiểm tra nếu là folder
      final folderItems = await _client.storage.from(bucket).list(path: path);
      if (folderItems.isNotEmpty) return true;

      // Nếu không phải folder, thử tải file
      await _client.storage.from(bucket).download(path);
      return true;
    } catch (_) {
      return false;
    }
  }

}
