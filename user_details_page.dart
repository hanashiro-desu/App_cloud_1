import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';

class UserDetailsPage extends StatefulWidget {
  final Profile profile;
  const UserDetailsPage({Key? key, required this.profile}) : super(key: key);

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  late TextEditingController fullNameController;
  late TextEditingController phoneController;
  late TextEditingController bioController;
  DateTime? dateOfBirth;
  File? _newAvatar;
  final _profileService = ProfileService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    fullNameController = TextEditingController(text: widget.profile.fullName ?? '');
    phoneController = TextEditingController(text: widget.profile.phone ?? '');
    bioController = TextEditingController(text: widget.profile.bio ?? '');
    dateOfBirth = widget.profile.dateOfBirth;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _newAvatar = File(picked.path));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => dateOfBirth = picked);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    String? avatarUrl = widget.profile.avatarUrl;
    if (_newAvatar != null) {
      avatarUrl = await _profileService.uploadAvatar(widget.profile.userId!, _newAvatar!);
    }

    final updatedProfile = widget.profile.copyWith(
      fullName: fullNameController.text.trim(),
      phone: phoneController.text.trim(),
      bio: bioController.text.trim(),
      dateOfBirth: dateOfBirth,
      avatarUrl: avatarUrl,
    );

    final result = await _profileService.updateProfile(updatedProfile);
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result ?? 'Cập nhật thành công!'),
        backgroundColor: result == null ? Colors.green : Colors.red,
      ),
    );

    if (result == null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thông tin cá nhân")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _newAvatar != null
                    ? FileImage(_newAvatar!)
                    : (widget.profile.avatarUrl != null
                    ? NetworkImage(widget.profile.avatarUrl!) as ImageProvider
                    : const AssetImage('assets/icons/user_placeholder.png')),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: fullNameController, decoration: const InputDecoration(labelText: "Họ và tên")),
            const SizedBox(height: 10),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Số điện thoại")),
            const SizedBox(height: 10),
            TextField(controller: bioController, decoration: const InputDecoration(labelText: "Giới thiệu ngắn"), maxLines: 3),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.cake),
              title: Text(dateOfBirth != null
                  ? "${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}"
                  : "Chọn ngày sinh"),
              onTap: _pickDate,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text("Lưu thay đổi"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
