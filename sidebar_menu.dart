import 'package:flutter/material.dart';

/// SidebarMenu — chỉ chứa UI các danh mục chính, không chứa hành động (upload, tạo folder,...)
class SidebarMenu extends StatelessWidget {
  final void Function(String type, {String? query}) onSelect;
  final VoidCallback onTrash;

  const SidebarMenu({
    Key? key,
    required this.onSelect,
    required this.onTrash,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person, size: 32),
                ),
                SizedBox(width: 12),
                Text(
                  "Tên người dùng",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),

          // Dashboard
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text("Dashboard"),
            onTap: () => onSelect("dashboard"),
          ),

          // Search
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Tìm kiếm'),
            onTap: () => onSelect('search'),
          ),

          // All Files
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text("All Files"),
            onTap: () => onSelect("all"),
          ),

          // Images
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text("Images"),
            onTap: () => onSelect("images"),
          ),

          // Videos
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text("Videos"),
            onTap: () => onSelect("videos"),
          ),

          // Documents
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("Documents"),
            onTap: () => onSelect("documents"),
          ),

          const Divider(),

          // Trash
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text("Trash"),
            onTap: onTrash,
          ),

          // Sign Out
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Đăng xuất"),
            onTap: () => onSelect('logout'),
          ),

        ],
      ),
    );
  }
}