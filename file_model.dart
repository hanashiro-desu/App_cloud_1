import 'dart:typed_data';
import 'package:uuid/uuid.dart';

class FileModel {
  final String id;
  final String name;
  final String? folderId;
  final String? profileId;
  final String type;
  final String? path;
  final double? size;
  final bool isFolder;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final Uint8List? content; // ← thêm cột content

  FileModel({
    String? id,
    required this.name,
    this.folderId,
    this.profileId,
    required this.type,
    this.path,
    this.size,
    this.isFolder = false,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.content, // ← thêm
  }) : id = id ?? const Uuid().v4();

  /// ✅ Tạo object từ Map (từ Supabase)
  factory FileModel.fromMap(Map<String, dynamic> map) {
    return FileModel(
      id: map['id'] as String,
      name: map['name'] as String,
      folderId: map['folder_id'] as String?,
      profileId: map['profile_id'] as String?,
      type: map['type'] ?? 'other',
      path: map['path'] as String?,
      size: (map['size'] is int)
          ? (map['size'] as int).toDouble()
          : map['size']?.toDouble(),
      isFolder: map['is_folder'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
      createdAt:
      map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
      map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      deletedAt:
      map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      content: map['content'] != null
          ? Uint8List.fromList(List<int>.from(map['content']))
          : null, // ← thêm
    );
  }

  /// ✅ Chuyển object thành Map (để insert/update)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'folder_id': folderId,
      'profile_id': profileId,
      'type': type,
      'path': path,
      'size': size,
      'is_folder': isFolder,
      'is_deleted': isDeleted,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'content': content, // ← thêm
    };
  }

  /// ✅ Copy object có thể thay đổi một vài trường
  FileModel copyWith({
    String? id,
    String? name,
    String? folderId,
    String? profileId,
    String? type,
    String? path,
    double? size,
    bool? isFolder,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    Uint8List? content, // ← thêm
  }) {
    return FileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      profileId: profileId ?? this.profileId,
      type: type ?? this.type,
      path: path ?? this.path,
      size: size ?? this.size,
      isFolder: isFolder ?? this.isFolder,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      content: content ?? this.content, // ← thêm
    );
  }
}