// lib/widgets/trash_widgets.dart
import 'package:flutter/material.dart';
import '../models/trash_model.dart';
import '../services/trash_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({Key? key}) : super(key: key);

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final TrashService _trashService = TrashService();
  List<Trash> _trashList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _loading = true);
    final data = await _trashService.fetchAllTrash();
    setState(() {
      _trashList = data;
      _loading = false;
    });
  }

  Future<void> _restoreTrash(Trash trash) async {
    final ok = await _trashService.restoreTrash(trash);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('♻️ Đã khôi phục ${trash.originalPath}')),
      );
      setState(() {
        _trashList.remove(trash);
      });
    }
  }

  Future<void> _deleteTrash(Trash trash) async {
    bool ok = true;
    if (trash.type == 'folder') {
      ok = await _trashService.deleteFolderRecursive(trash);
    } else {
      ok = await _trashService.deletePermanently(trash);
    }

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🚮 Đã xóa vĩnh viễn ${trash.originalPath}')),
      );
      setState(() {
        _trashList.remove(trash);
      });
    }
  }

  // 🔹 Xây dựng cây thùng rác
  List<Widget> _buildTree(String parentPath) {
    final nodes = _trashList.where((t) {
      final path = t.originalPath;
      if (!path.startsWith(parentPath)) return false;
      final relative = path.replaceFirst('$parentPath/', '');
      return relative.isNotEmpty && !relative.contains('/');
    }).toList();

    return nodes.map((t) {
      final isFolder = t.type == 'folder';
      final name = t.originalPath.split('/').last;

      if (isFolder) {
        return ExpansionTile(
          leading: const Icon(Icons.folder_open, color: Colors.amber),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'restore') await _restoreTrash(t);
                  else if (value == 'delete') await _deleteTrash(t);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'restore', child: Text('Khôi phục')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa vĩnh viễn')),
                ],
              ),
            ],
          ),
          children: _buildTree(t.originalPath),
        );
      } else {
        return ListTile(
          leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
          title: Text(name),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'restore') await _restoreTrash(t);
              else if (value == 'delete') await _deleteTrash(t);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'restore', child: Text('Khôi phục')),
              PopupMenuItem(value: 'delete', child: Text('Xóa vĩnh viễn')),
            ],
          ),
        );
      }
    }).toList();
  }

  // 🔹 Tìm tất cả root profileId
  List<String> _findRoots() {
    final roots = <String>{};
    for (var t in _trashList) {
      final profileId = t.originalPath.split('/').first;
      roots.add(profileId);
    }
    return roots.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗑️ Thùng rác'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trashList.isEmpty
          ? const Center(child: Text('Thùng rác trống'))
          : ListView(
        children: _findRoots()
            .map((root) => ExpansionTile(
          leading: const Icon(Icons.person, color: Colors.grey),
          title: Text(root),
          children: _buildTree(root),
        ))
            .toList(),
      ),
    );
  }
}
