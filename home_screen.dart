import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/file_tile.dart';
import '../widgets/folder_tile.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import '../services/file_service.dart';
import '../services/folder_service.dart';
import 'move.dart';
import 'preview_screen.dart';
import 'search.dart';
import 'trash.dart';
import '../services/sync_service.dart';
import '../widgets/search_widgets.dart';
import '../widgets/trash_widgets.dart';
import '../widgets/move_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FileService _fileService = FileService();
  final FolderService _folderService = FolderService();
  final TrashManager _trashService = TrashManager();

  bool _isLoading = false;
  List<FolderModel> _folders = [];
  List<FileModel> _files = [];
  String? _currentFolderId;
  String _currentFolderPath = '';

  @override
  void initState() {
    super.initState();
    final syncService = SyncService();
    syncService.syncAllRecursive();
    _loadData();
  }

  Future<List<FileModel>> _fetchAllFilesRecursive({
    required String profileId,
    String? folderId,
  }) async {
    List<FileModel> allFiles = [];

    // Lấy file trực tiếp trong folder hiện tại
    final files = await _fileService.fetchFiles(
      folderId: folderId,
      profileId: profileId,
    );
    allFiles.addAll(files.where((f) => f.name != '.keep'));

    // Lấy các folder con
    final folders = await _folderService.fetchFolders(
      parentId: folderId,
      profileId: profileId,
    );

    // Đệ quy lấy file trong folder con
    for (var folder in folders) {
      final childFiles = await _fetchAllFilesRecursive(
        profileId: profileId,
        folderId: folder.id,
      );
      allFiles.addAll(childFiles);
    }

    return allFiles;
  }

  Future<void> _loadData({
    String? folderId,
    String? folderPath,
    String? filterType,
  }) async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (profile == null) return;
      final profileId = profile['id'] as String;

      List<FolderModel> folders = [];
      List<FileModel> files = [];

      if (filterType == null || filterType == 'dashboard') {
        // Dashboard: folder + file trực tiếp
        folders = await _folderService.fetchFolders(
          parentId: folderId,
          profileId: profileId,
        );
        files = await _fileService.fetchFiles(
          folderId: folderId,
          profileId: profileId,
        );
        files = files.where((f) => f.name != '.keep').toList();
      } else {
        // All Files hoặc filter Documents/Images/Videos
        files = await _fetchAllFilesRecursive(
          profileId: profileId,
          folderId: folderId,
        );

        // Lọc theo type nếu cần
        switch (filterType) {
          case 'all':
            folders = [];
            break;
          case 'documents':
            files = files.where((f) => f.type == 'document').toList();
            folders = [];
            break;
          case 'images':
            files = files.where((f) => f.type == 'image').toList();
            folders = [];
            break;
          case 'videos':
            files = files.where((f) => f.type == 'video').toList();
            folders = [];
            break;
        }
      }

      setState(() {
        _folders = folders;
        _files = files;
        _currentFolderId = folderId;
        if (folderPath != null) _currentFolderPath = folderPath;
      });
    } catch (e) {
      print('❌ Lỗi loadData: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    // Lấy profile_id từ bảng profiles
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('user_id', currentUser.id)
        .maybeSingle(); // trả về Map<String, dynamic>? hoặc null

    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Lỗi lấy profile: Không tìm thấy profile')),
      );
      return;
    }

    final profileId = profile['id'] as String;

    final file = File(result.files.single.path!);

    try {
      final ok = await _fileService.uploadFile(
        file: file,
        folderId: _currentFolderId,
        profileId: profileId, // dùng profileId vừa lấy
      );

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Upload thành công')),
        );
        _loadData(folderId: _currentFolderId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi uploadFile: $e')),
      );
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tạo thư mục mới'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tên thư mục'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final folderName = controller.text.trim();
    if (folderName.isEmpty) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    // ✅ Lấy profileId từ bảng profiles
    final profileData = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('user_id', currentUser.id)
        .maybeSingle() as Map<String, dynamic>?; // Trả về trực tiếp Map

    if (profileData == null || !profileData.containsKey('id')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Lỗi: Không tìm thấy profile')),
      );
      return;
    }

    final profileId = profileData['id'] as String;

    final success = await _folderService.createFolder(
      name: folderName,
      profileId: profileId,
      parentId: _currentFolderId,
    );

    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Tạo thư mục "$folderName" thành công')),
      );
      _loadData(folderId: _currentFolderId);
    }
  }

  Future<void> _renameFolder(FolderModel folder) async {
    final controller = TextEditingController(text: folder.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đổi tên thư mục'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Tên mới')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đổi tên')),
        ],
      ),
    );

    if (ok != true) return;
    final newName = controller.text.trim();
    if (newName.isEmpty) return;
    final success = await _folderService.renameFolder(folder.id!, newName);
    if (success) _loadData(folderId: _currentFolderId);
  }

  Future<void> _renameFile(FileModel file) async {
    final controller = TextEditingController(text: file.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đổi tên file'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Tên mới')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đổi tên')),
        ],
      ),
    );

    if (ok != true) return;
    final newName = controller.text.trim();
    if (newName.isEmpty) return;
    final success = await _fileService.renameFile(fileId: file.id, newName: newName);
    if (success) _loadData(folderId: _currentFolderId);
  }

  Future<void> _downloadFile(FileModel file) async {
    final tempDir = '/storage/emulated/0/Download'; // trên máy thật Android
    final localPath = '$tempDir/${file.name}';
    final ok = await _fileService.downloadFile(file: file, localPath: localPath);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ File "${file.name}" đã tải xuống $localPath')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Không tải được file "${file.name}"')),
      );
    }
  }

  Future<void> _moveFolderOrFile({required bool isFile, required String id}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoveFolderList(
          itemId: id,
          isFile: isFile,
          excludeId: id,
        ),
      ),
    );

    _loadData(folderId: _currentFolderId);
  }

  void _previewFile(FileModel file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(fileUrl: _fileService.getFileUrl(file), fileName: file.name),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đăng xuất: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  void _onSidebarSelect(String type, {String? query}) {
    Navigator.pop(context); // đóng Drawer nếu đang mở

    if (type == 'search') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
    } else if (type == 'trash') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TrashScreen()));
    } else if (type == 'logout') {
      _confirmSignOut(); // gọi hàm xác nhận logout đã có
    } else {
      _loadData(folderId: _currentFolderId, filterType: type);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📁 Quản lý File'),
        actions: [
          if (_currentFolderId != null)
            IconButton(icon: const Icon(Icons.home), onPressed: () => _loadData(folderId: null)),
          IconButton(icon: const Icon(Icons.create_new_folder), onPressed: _createFolder),
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _uploadFile),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadData(folderId: _currentFolderId)),
        ],
      ),
      drawer: SidebarMenu(
        onSelect: (type, {query}) => _onSidebarSelect(type, query: query),
        onTrash: () => _onSidebarSelect('trash'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_folders.isEmpty && _files.isEmpty)
          ? const Center(child: Text('Không có dữ liệu'))
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 3, // 3 cột cố định
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            // Folder tiles
            ..._folders.map((folder) => FolderTile(
              folder: folder,
              onOpen: () => _loadData(
                folderId: folder.id,
                folderPath: folder.name,
              ),
              onAction: (action) async {
                switch (action) {
                  case 'rename':
                    await _renameFolder(folder);
                    break;
                  case 'move':
                    await _moveFolderOrFile(
                        isFile: false, id: folder.id!);
                    break;
                  case 'delete':
                    await _folderService.moveToTrash(folder);
                    _loadData(folderId: _currentFolderId);
                    break;
                }
              },
            )),
            // File tiles
            ..._files.map((file) => FileTile(
              file: file,
              onTap: () => _previewFile(file),
              onAction: (action) async {
                switch (action) {
                  case 'rename':
                    await _renameFile(file);
                    break;
                  case 'download':
                    await _downloadFile(file);
                    break;
                  case 'delete':
                    await _fileService.moveToTrash(file);
                    _loadData(folderId: _currentFolderId);
                    break;
                  case 'preview':
                    _previewFile(file);
                    break;
                  case 'move':
                    await _moveFolderOrFile(isFile: true, id: file.id);
                    break;
                }
              },
            )),
          ],
        ),
      ),
    );
  }
}
