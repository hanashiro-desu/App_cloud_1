// lib/models/folder_model.dart
import 'package:uuid/uuid.dart';

class FolderModel {
  final String id;
  final String name;
  final String? parentId;
  final String? path; // ✅ thêm path
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? profileId;

  FolderModel({
    String? id,
    required this.name,
    this.parentId,
    this.path,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.profileId,
  }) : id = id ?? const Uuid().v4();

  /// ✅ Chuyển Map từ Supabase thành FolderModel
  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      parentId: map['parent_id'],
      path: map['path'] as String?,
      createdAt:
      map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
      map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isDeleted: map['is_deleted'] ?? false,
      deletedAt:
      map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      profileId: map['profile_id'],
    );
  }

  factory FolderModel.fromJson(Map<String, dynamic> json) => FolderModel.fromMap(json);

  /// ✅ Chuyển FolderModel thành Map để lưu lên Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'path': path,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'profile_id': profileId,
    };
  }

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentId,
    String? path,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? profileId,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      profileId: profileId ?? this.profileId,
    );
  }

  String getFullPath() {
    if (path == null || path!.isEmpty) return name;
    return '$path/$name';
  }

}