import 'package:flutter/material.dart';
import '../models/file_model.dart';

class FileTile extends StatelessWidget {
  final FileModel file;
  final void Function(String action)? onAction;
  final VoidCallback? onTap;

  const FileTile({
    super.key,
    required this.file,
    this.onAction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFolder = file.isFolder;
    final iconData = isFolder
        ? Icons.folder
        : (file.type == 'image'
        ? Icons.image
        : file.type == 'video'
        ? Icons.videocam
        : Icons.insert_drive_file);

    final iconColor = isFolder
        ? Colors.amber.shade700
        : (file.type == 'image'
        ? Colors.green.shade400
        : file.type == 'video'
        ? Colors.purple.shade400
        : Colors.grey.shade600);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(iconData, size: 48, color: iconColor),
                  const SizedBox(height: 8),
                  Text(
                    file.name,
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
                  PopupMenuItem(value: 'download', child: Text('Tải xuống')),
                  PopupMenuItem(value: 'move', child: Text('Di chuyển')),
                  PopupMenuItem(value: 'delete', child: Text('Chuyển vào thùng rác')),
                  PopupMenuItem(value: 'preview', child: Text('Xem trước')),
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
