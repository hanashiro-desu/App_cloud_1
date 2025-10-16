// lib/widgets/move_widgets.dart
import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../views/move.dart';

class MoveFolderList extends StatefulWidget {
  final String itemId;
  final bool isFile;
  final String? excludeId;

  const MoveFolderList({
    super.key,
    required this.itemId,
    required this.isFile,
    this.excludeId,
  });

  @override
  State<MoveFolderList> createState() => _MoveFolderListState();
}

class _MoveFolderListState extends State<MoveFolderList> {
  List<FolderModel> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    final folders = await MoveLogic.fetchMovableFolders(excludeId: widget.excludeId);
    setState(() {
      _folders = folders;
      _isLoading = false;
    });
  }

  Future<void> _onFolderTap(FolderModel? folder) async {
    setState(() => _isLoading = true);
    final success = await MoveLogic.moveItem(
      isFile: widget.isFile,
      itemId: widget.itemId,
      destinationFolder: folder,
    );
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Di chuyển thành công')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Di chuyển thất bại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn thư mục đích')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Thư mục gốc của tôi'),
            onTap: () => _onFolderTap(null),
          ),
          ..._folders.map((f) => ListTile(
            leading: const Icon(Icons.folder),
            title: Text(f.name),
            subtitle: Text('👤 ${f.profileId ?? "Không rõ"}'),
            onTap: () => _onFolderTap(f),
          )),
        ],
      ),
    );
  }
}
