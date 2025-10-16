import 'package:flutter/material.dart';
import '../models/folder_model.dart';

class FolderTile extends StatelessWidget {
  final FolderModel folder;
  final VoidCallback onOpen;
  final void Function(String action)? onAction;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onOpen,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 48, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    folder.name,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                onSelected: onAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                  PopupMenuItem(value: 'move', child: Text('Di chuyển')),
                  PopupMenuItem(value: 'delete', child: Text('Chuyển vào thùng rác')),
                ],
                icon: const Icon(Icons.more_vert, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
