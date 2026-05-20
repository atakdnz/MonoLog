import 'package:uuid/uuid.dart';

class Entry {
  final String id;
  final String notebookId;
  final String? content;
  final String? imagePath;
  final String? annotationBaseImagePath;
  final String? annotationStrokes;
  final String? audioPath;
  final int? audioDurationMs;
  final DateTime displayTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isStarred;
  final bool isDeleted;
  final DateTime? deletedAt;

  Entry({
    String? id,
    required this.notebookId,
    this.content,
    this.imagePath,
    this.annotationBaseImagePath,
    this.annotationStrokes,
    this.audioPath,
    this.audioDurationMs,
    DateTime? displayTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isStarred = false,
    this.isDeleted = false,
    this.deletedAt,
  }) : id = id ?? const Uuid().v4(),
       displayTime = displayTime ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create a copy with updated fields
  Entry copyWith({
    String? id,
    String? notebookId,
    String? content,
    String? imagePath,
    String? annotationBaseImagePath,
    String? annotationStrokes,
    String? audioPath,
    int? audioDurationMs,
    DateTime? displayTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isStarred,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearContent = false,
    bool clearImagePath = false,
    bool clearAnnotationBaseImagePath = false,
    bool clearAnnotationStrokes = false,
    bool clearAudioPath = false,
    bool clearAudioDuration = false,
    bool clearDeletedAt = false,
  }) {
    return Entry(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      content: clearContent ? null : (content ?? this.content),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      annotationBaseImagePath: clearAnnotationBaseImagePath
          ? null
          : (annotationBaseImagePath ?? this.annotationBaseImagePath),
      annotationStrokes: clearAnnotationStrokes
          ? null
          : (annotationStrokes ?? this.annotationStrokes),
      audioPath: clearAudioPath ? null : (audioPath ?? this.audioPath),
      audioDurationMs: clearAudioDuration
          ? null
          : (audioDurationMs ?? this.audioDurationMs),
      displayTime: displayTime ?? this.displayTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isStarred: isStarred ?? this.isStarred,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  /// Factory constructor from database map
  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id: map['id'] as String,
      notebookId: map['notebook_id'] as String,
      content: map['content'] as String?,
      imagePath: map['image_path'] as String?,
      annotationBaseImagePath: map['annotation_base_image_path'] as String?,
      annotationStrokes: map['annotation_strokes'] as String?,
      audioPath: map['audio_path'] as String?,
      audioDurationMs: map['audio_duration_ms'] as int?,
      displayTime: DateTime.parse(map['display_time'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isStarred: (map['is_starred'] as int) == 1,
      isDeleted: (map['is_deleted'] as int) == 1,
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notebook_id': notebookId,
      'content': content,
      'image_path': imagePath,
      'annotation_base_image_path': annotationBaseImagePath,
      'annotation_strokes': annotationStrokes,
      'audio_path': audioPath,
      'audio_duration_ms': audioDurationMs,
      'display_time': displayTime.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_starred': isStarred ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  /// Factory constructor from JSON (for import/export)
  factory Entry.fromJson(Map<String, dynamic> json, String notebookId) {
    return Entry(
      id: json['id'] as String,
      notebookId: notebookId,
      content: json['content'] as String?,
      imagePath: json['image_filename'] as String?,
      annotationBaseImagePath:
          json['annotation_base_image_filename'] as String?,
      annotationStrokes: json['annotation_strokes'] as String?,
      audioPath: json['audio_filename'] as String?,
      audioDurationMs: json['audio_duration_ms'] as int?,
      displayTime: DateTime.parse(json['display_time'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String),
      isStarred: json['is_starred'] as bool? ?? false,
      isDeleted: false,
      deletedAt: null,
    );
  }

  /// Convert to JSON (for import/export)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'image_filename': imagePath?.split('/').last,
      'annotation_base_image_filename': annotationBaseImagePath
          ?.split('/')
          .last,
      'annotation_strokes': annotationStrokes,
      'audio_filename': audioPath?.split('/').last,
      'audio_duration_ms': audioDurationMs,
      'display_time': displayTime.toIso8601String(),
      'is_starred': isStarred,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if the entry has any content
  bool get hasContent => content != null && content!.isNotEmpty;

  /// Check if the entry has an image
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  /// Check if the entry has audio
  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;

  /// Check if the entry has image or audio media
  bool get hasMedia => hasImage || hasAudio;

  /// Check if the entry has editable annotation layer data
  bool get hasEditableAnnotations =>
      annotationBaseImagePath != null &&
      annotationBaseImagePath!.isNotEmpty &&
      annotationStrokes != null &&
      annotationStrokes!.isNotEmpty;

  /// Check if the entry is empty (no content and no media)
  bool get isEmpty => !hasContent && !hasMedia;

  @override
  String toString() {
    return 'Entry{id: $id, notebookId: $notebookId, content: ${content?.substring(0, content!.length > 20 ? 20 : content!.length)}..., isStarred: $isStarred, isDeleted: $isDeleted}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Entry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
