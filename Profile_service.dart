import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Profile?> getCurrentProfile() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      print('Error getting current profile: $e');
      return null;
    }
  }


  Future<Profile?> getProfileById(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      print('Error getting profile by ID: $e');
      return null;
    }
  }


  Future<Profile?> getProfileByEmail(String email) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('email', email)
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      print('Error getting profile by email: $e');
      return null;
    }
  }


  Future<String?> updateProfile(Profile profile) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return 'Bạn chưa đăng nhập';
      }

      if (userId != profile.userId) {
        return 'Bạn không có quyền cập nhật profile này';
      }

      await _client.from('profiles').update({
        'full_name': profile.fullName,
        'avatar_url': profile.avatarUrl,
        'phone': profile.phone,
        'bio': profile.bio,
        'date_of_birth': profile.dateOfBirth?.toIso8601String(),
      }).eq('user_id', userId);

      return null; // Success
    } on PostgrestException catch (e) {
      return 'Lỗi database: ${e.message}';
    } catch (e) {
      return 'Lỗi: ${e.toString()}';
    }
  }


  Future<String?> uploadAvatar(String userId, File file) async {
    try {
      // Đọc file thành bytes
      final bytes = await file.readAsBytes();

      // Upload lên Supabase Storage
      await _client.storage
          .from('avatars')
          .uploadBinary('$userId.jpg', bytes);

      // Lấy public URL
      final publicUrl = _client.storage
          .from('avatars')
          .getPublicUrl('$userId.jpg');

      // Update avatar_url trong profile
      await _client.from('profiles').update({
        'avatar_url': publicUrl,
      }).eq('user_id', userId);

      return publicUrl;
    } catch (e) {
      print('Error uploading avatar: $e');
      return null;
    }
  }


  Future<String?> uploadAvatarFromPath(String userId, String filePath) async {
    try {
      final file = File(filePath);
      return await uploadAvatar(userId, file);
    } catch (e) {
      print('Error uploading avatar from path: $e');
      return null;
    }
  }


  Future<bool> deleteAvatar(String userId) async {
    try {
      await _client.storage.from('avatars').remove(['$userId.jpg']);

      // Remove avatar_url trong profile
      await _client.from('profiles').update({
        'avatar_url': null,
      }).eq('user_id', userId);

      return true;
    } catch (e) {
      print('Error deleting avatar: $e');
      return false;
    }
  }


  Stream<Profile?> watchProfile(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
      if (data.isEmpty) return null;
      return Profile.fromJson(data.first);
    });
  }


  Future<List<Profile>> searchProfiles(String query) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .ilike('full_name', '%$query%')
          .limit(20);

      return (response as List)
          .map((json) => Profile.fromJson(json))
          .toList();
    } catch (e) {
      print('Error searching profiles: $e');
      return [];
    }
  }


  Future<List<Profile>> getAllProfiles({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => Profile.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting all profiles: $e');
      return [];
    }
  }
}