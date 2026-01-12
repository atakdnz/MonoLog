import 'package:uuid/uuid.dart';

class Notebook {
  final String id;
  final String title;
  final String color;
  final bool isPinned;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Notebook({
    String? id,
    required this.title,
    required this.color,
    this.isPinned = false,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create a copy with updated fields
  Notebook copyWith({
    String? id,
    String? title,
    String? color,
    bool? isPinned,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Notebook(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Factory constructor from database map
  factory Notebook.fromMap(Map<String, dynamic> map) {
    return Notebook(
      id: map['id'] as String,
      title: map['title'] as String,
      color: map['color'] as String,
      isPinned: (map['is_pinned'] as int) == 1,
      isArchived: (map['is_archived'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'color': color,
      'is_pinned': isPinned ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Factory constructor from JSON (for import/export)
  factory Notebook.fromJson(Map<String, dynamic> json) {
    return Notebook(
      id: json['id'] as String,
      title: json['title'] as String,
      color: json['color'] as String,
      isPinned: json['is_pinned'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON (for import/export)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'color': color,
      'is_pinned': isPinned,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Notebook{id: $id, title: $title, color: $color, isPinned: $isPinned, isArchived: $isArchived}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Notebook && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
