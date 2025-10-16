import 'package:uuid/uuid.dart';

class Trash {
  final String id;
  final String type; // 'file' hoặc 'folder'
  final String originalId; // id từ bảng files hoặc folders
  final String originalPath;
  final String trashPath;
  final DateTime? deletedAt;
  final bool restored;
  final DateTime? restoredAt;
  final String? profileId; // 🔥 Thêm để đồng bộ với DB

  Trash({
    String? id,
    required this.type,
    required this.originalId,
    required this.originalPath,
    required this.trashPath,
    this.deletedAt,
    this.restored = false,
    this.restoredAt,
    this.profileId,
  }) : id = id ?? const Uuid().v4();

  factory Trash.fromMap(Map<String, dynamic> map) {
    return Trash(
      id: map['id']?.toString() ?? '',
      type: map['type'] ?? '',
      originalId: map['original_id']?.toString() ?? '',
      originalPath: map['original_path'] ?? '',
      trashPath: map['trash_path'] ?? '',
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'])
          : null,
      restored: map['restored'] ?? false,
      restoredAt: map['restored_at'] != null
          ? DateTime.tryParse(map['restored_at'])
          : null,
      profileId: map['profile_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'original_id': originalId,
      'original_path': originalPath,
      'trash_path': trashPath,
      'deleted_at': deletedAt?.toIso8601String(),
      'restored': restored,
      'restored_at': restoredAt?.toIso8601String(),
      'profile_id': profileId, // 🔥 thêm để insert chính xác
    };
  }

  Trash copyWith({
    String? id,
    String? type,
    String? originalId,
    String? originalPath,
    String? trashPath,
    DateTime? deletedAt,
    bool? restored,
    DateTime? restoredAt,
    String? profileId,
  }) {
    return Trash(
      id: id ?? this.id,
      type: type ?? this.type,
      originalId: originalId ?? this.originalId,
      originalPath: originalPath ?? this.originalPath,
      trashPath: trashPath ?? this.trashPath,
      deletedAt: deletedAt ?? this.deletedAt,
      restored: restored ?? this.restored,
      restoredAt: restoredAt ?? this.restoredAt,
      profileId: profileId ?? this.profileId,
    );
  }
}
