import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';
import '../widgets/user_details_page.dart';

class SidebarMenu extends StatefulWidget {
  final void Function(String type, {String? query}) onSelect;
  final VoidCallback onTrash;

  const SidebarMenu({
    Key? key,
    required this.onSelect,
    required this.onTrash,
  }) : super(key: key);

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  final ProfileService _profileService = ProfileService();
  Profile? _profile;
  bool _isLoading = true;
  StreamSubscription<Profile?>? _profileSub;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final profile = await _profileService.getCurrentProfile();
    setState(() {
      _profile = profile;
      _isLoading = false;
    });

    _profileSub?.cancel();
    if (profile?.userId != null) {
      _profileSub = _profileService.watchProfile(profile!.userId!).listen((updatedProfile) {
        if (updatedProfile != null) setState(() => _profile = updatedProfile);
      });
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: GestureDetector(
              onTap: () async {
                if (_profile != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailsPage(profile: _profile!),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: _profile?.avatarUrl != null
                        ? NetworkImage(_profile!.avatarUrl!)
                        : null,
                    child: _profile?.avatarUrl == null
                        ? const Icon(Icons.person, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isLoading
                        ? const Text(
                      "Đang tải...",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    )
                        : Text(
                      _profile?.fullName ?? _profile?.email ?? "Người dùng ẩn danh",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(leading: const Icon(Icons.dashboard), title: const Text("Dashboard"), onTap: () => widget.onSelect("dashboard")),
          ListTile(leading: const Icon(Icons.search), title: const Text('Tìm kiếm'), onTap: () => widget.onSelect('search')),
          ListTile(leading: const Icon(Icons.folder), title: const Text("All Files"), onTap: () => widget.onSelect("all")),
          ListTile(leading: const Icon(Icons.image), title: const Text("Images"), onTap: () => widget.onSelect("images")),
          ListTile(leading: const Icon(Icons.video_library), title: const Text("Videos"), onTap: () => widget.onSelect("videos")),
          ListTile(leading: const Icon(Icons.description), title: const Text("Documents"), onTap: () => widget.onSelect("documents")),
          const Divider(),
          ListTile(leading: const Icon(Icons.delete), title: const Text("Trash"), onTap: widget.onTrash),
          ListTile(leading: const Icon(Icons.logout), title: const Text("Đăng xuất"), onTap: () => widget.onSelect('logout')),
        ],
      ),
    );
  }
}
