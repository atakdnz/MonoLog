import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

class Notebook {
  final String id;
  final String title;
  final String color;
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;
  final String entryStyle;
  final int sortOrder;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Notebook({
    String? id,
    required this.title,
    required this.color,
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.entryStyle = NotebookEntryStyles.chat,
    this.sortOrder = 0,
    this.deletedAt,
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
    bool? isDeleted,
    String? entryStyle,
    int? sortOrder,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Notebook(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      entryStyle: entryStyle ?? this.entryStyle,
      sortOrder: sortOrder ?? this.sortOrder,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
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
      isPinned: (map['is_pinned'] as int?) == 1,
      isArchived: (map['is_archived'] as int?) == 1,
      isDeleted: (map['is_deleted'] as int?) == 1,
      entryStyle: map['entry_style'] as String? ?? NotebookEntryStyles.chat,
      sortOrder: map['sort_order'] as int? ?? 0,
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
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
      'is_deleted': isDeleted ? 1 : 0,
      'entry_style': entryStyle,
      'sort_order': sortOrder,
      'deleted_at': deletedAt?.toIso8601String(),
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
      isDeleted: json['is_deleted'] as bool? ?? false,
      entryStyle: json['entry_style'] as String? ?? NotebookEntryStyles.chat,
      sortOrder: json['sort_order'] as int? ?? 0,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
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
      'is_deleted': isDeleted,
      'entry_style': entryStyle,
      'sort_order': sortOrder,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Notebook{id: $id, title: $title, color: $color, entryStyle: $entryStyle, isPinned: $isPinned, isArchived: $isArchived, isDeleted: $isDeleted, sortOrder: $sortOrder}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Notebook && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
