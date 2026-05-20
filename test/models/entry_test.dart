import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/models/entry.dart';

void main() {
  group('Entry', () {
    test('should create an entry with required fields', () {
      final entry = Entry(notebookId: 'notebook-1');

      expect(entry.id, isNotNull);
      expect(entry.notebookId, 'notebook-1');
      expect(entry.content, isNull);
      expect(entry.imagePath, isNull);
      expect(entry.isStarred, false);
      expect(entry.isDeleted, false);
      expect(entry.displayTime, isNotNull);
      expect(entry.createdAt, isNotNull);
      expect(entry.updatedAt, isNotNull);
    });

    test('should create an entry with all fields', () {
      final now = DateTime.now();
      final entry = Entry(
        id: 'entry-1',
        notebookId: 'notebook-1',
        content: 'Test content',
        imagePath: '/path/to/image.jpg',
        annotationBaseImagePath: '/path/to/base.jpg',
        annotationStrokes: '[{"points":[]}]',
        audioPath: '/path/to/audio.m4a',
        audioDurationMs: 12345,
        displayTime: now,
        createdAt: now,
        updatedAt: now,
        isStarred: true,
        isDeleted: false,
      );

      expect(entry.id, 'entry-1');
      expect(entry.notebookId, 'notebook-1');
      expect(entry.content, 'Test content');
      expect(entry.imagePath, '/path/to/image.jpg');
      expect(entry.annotationBaseImagePath, '/path/to/base.jpg');
      expect(entry.annotationStrokes, '[{"points":[]}]');
      expect(entry.audioPath, '/path/to/audio.m4a');
      expect(entry.audioDurationMs, 12345);
      expect(entry.displayTime, now);
      expect(entry.createdAt, now);
      expect(entry.updatedAt, now);
      expect(entry.isStarred, true);
      expect(entry.isDeleted, false);
    });

    test('should generate UUID when id is not provided', () {
      final entry1 = Entry(notebookId: 'notebook-1');
      final entry2 = Entry(notebookId: 'notebook-1');

      expect(entry1.id, isNotNull);
      expect(entry2.id, isNotNull);
      expect(entry1.id, isNot(entry2.id));
    });

    test('should set default DateTime when not provided', () {
      final entry = Entry(notebookId: 'notebook-1');

      expect(
        entry.displayTime.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
      expect(
        entry.createdAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
      expect(
        entry.updatedAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
    });

    group('copyWith', () {
      test('should return a copy with updated content', () {
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          content: 'Old content',
        );

        final updated = entry.copyWith(content: 'New content');

        expect(updated.id, entry.id);
        expect(updated.notebookId, entry.notebookId);
        expect(updated.content, 'New content');
      });

      test('should clear content when clearContent is true', () {
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          content: 'Test content',
        );

        final updated = entry.copyWith(clearContent: true);

        expect(updated.content, isNull);
      });

      test('should clear imagePath when clearImagePath is true', () {
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          imagePath: '/path/to/image.jpg',
        );

        final updated = entry.copyWith(clearImagePath: true);

        expect(updated.imagePath, isNull);
      });

      test('should clear audio fields when clear audio flags are true', () {
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          audioPath: '/path/to/audio.m4a',
          audioDurationMs: 12345,
        );

        final updated = entry.copyWith(
          clearAudioPath: true,
          clearAudioDuration: true,
        );

        expect(updated.audioPath, isNull);
        expect(updated.audioDurationMs, isNull);
      });

      test(
        'should clear annotationBaseImagePath when clearAnnotationBaseImagePath is true',
        () {
          final entry = Entry(
            id: 'entry-1',
            notebookId: 'notebook-1',
            annotationBaseImagePath: '/path/to/base.jpg',
          );

          final updated = entry.copyWith(clearAnnotationBaseImagePath: true);

          expect(updated.annotationBaseImagePath, isNull);
        },
      );

      test(
        'should clear annotationStrokes when clearAnnotationStrokes is true',
        () {
          final entry = Entry(
            id: 'entry-1',
            notebookId: 'notebook-1',
            annotationStrokes: '[{"points":[]}]',
          );

          final updated = entry.copyWith(clearAnnotationStrokes: true);

          expect(updated.annotationStrokes, isNull);
        },
      );

      test('should clear deletedAt when clearDeletedAt is true', () {
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          isDeleted: true,
          deletedAt: DateTime.now(),
        );

        final updated = entry.copyWith(clearDeletedAt: true);

        expect(updated.deletedAt, isNull);
      });

      test('should toggle isStarred', () {
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          isStarred: false,
        );

        final updated = entry.copyWith(isStarred: true);

        expect(updated.isStarred, true);
      });

      test('should toggle isDeleted', () {
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          isDeleted: false,
        );

        final updated = entry.copyWith(
          isDeleted: true,
          deletedAt: DateTime.now(),
        );

        expect(updated.isDeleted, true);
        expect(updated.deletedAt, isNotNull);
      });
    });

    group('fromMap', () {
      test('should create Entry from database map', () {
        final now = DateTime.now();
        final map = {
          'id': 'entry-1',
          'notebook_id': 'notebook-1',
          'content': 'Test content',
          'image_path': '/path/to/image.jpg',
          'annotation_base_image_path': '/path/to/base.jpg',
          'annotation_strokes': '[{"points":[]}]',
          'display_time': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'is_starred': 1,
          'is_deleted': 0,
          'deleted_at': null,
        };

        final entry = Entry.fromMap(map);

        expect(entry.id, 'entry-1');
        expect(entry.notebookId, 'notebook-1');
        expect(entry.content, 'Test content');
        expect(entry.imagePath, '/path/to/image.jpg');
        expect(entry.isStarred, true);
        expect(entry.isDeleted, false);
      });

      test('should handle null values in map', () {
        final now = DateTime.now();
        final map = {
          'id': 'entry-1',
          'notebook_id': 'notebook-1',
          'content': null,
          'image_path': null,
          'annotation_base_image_path': null,
          'annotation_strokes': null,
          'display_time': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'is_starred': 0,
          'is_deleted': 0,
          'deleted_at': null,
        };

        final entry = Entry.fromMap(map);

        expect(entry.content, isNull);
        expect(entry.imagePath, isNull);
        expect(entry.annotationBaseImagePath, isNull);
        expect(entry.annotationStrokes, isNull);
        expect(entry.isStarred, false);
        expect(entry.isDeleted, false);
        expect(entry.deletedAt, isNull);
      });

      test('should parse deletedAt when not null', () {
        final now = DateTime.now();
        final map = {
          'id': 'entry-1',
          'notebook_id': 'notebook-1',
          'content': null,
          'image_path': null,
          'annotation_base_image_path': null,
          'annotation_strokes': null,
          'display_time': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'is_starred': 0,
          'is_deleted': 1,
          'deleted_at': now.toIso8601String(),
        };

        final entry = Entry.fromMap(map);

        expect(entry.isDeleted, true);
        expect(entry.deletedAt, isNotNull);
      });
    });

    group('toMap', () {
      test('should convert Entry to database map', () {
        final now = DateTime.now();
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          content: 'Test content',
          imagePath: '/path/to/image.jpg',
          audioPath: '/path/to/audio.m4a',
          audioDurationMs: 12345,
          displayTime: now,
          createdAt: now,
          updatedAt: now,
          isStarred: true,
          isDeleted: false,
        );

        final map = entry.toMap();

        expect(map['id'], 'entry-1');
        expect(map['notebook_id'], 'notebook-1');
        expect(map['content'], 'Test content');
        expect(map['image_path'], '/path/to/image.jpg');
        expect(map['audio_path'], '/path/to/audio.m4a');
        expect(map['audio_duration_ms'], 12345);
        expect(map['is_starred'], 1);
        expect(map['is_deleted'], 0);
      });

      test('should handle null values in map', () {
        final now = DateTime.now();
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          content: null,
          imagePath: null,
          displayTime: now,
          createdAt: now,
          updatedAt: now,
          isStarred: false,
          isDeleted: true,
          deletedAt: now,
        );

        final map = entry.toMap();

        expect(map['content'], isNull);
        expect(map['image_path'], isNull);
        expect(map['is_starred'], 0);
        expect(map['is_deleted'], 1);
        expect(map['deleted_at'], isNotNull);
      });
    });

    group('fromJson', () {
      test('should create Entry from JSON', () {
        final now = DateTime.now();
        final json = {
          'id': 'entry-1',
          'content': 'Test content',
          'image_filename': 'image.jpg',
          'annotation_base_image_filename': 'base.jpg',
          'annotation_strokes': '[{"points":[]}]',
          'audio_filename': 'audio.m4a',
          'audio_duration_ms': 12345,
          'display_time': now.toIso8601String(),
          'is_starred': true,
          'created_at': now.toIso8601String(),
        };

        final entry = Entry.fromJson(json, 'notebook-1');

        expect(entry.id, 'entry-1');
        expect(entry.notebookId, 'notebook-1');
        expect(entry.content, 'Test content');
        expect(entry.imagePath, 'image.jpg');
        expect(entry.annotationBaseImagePath, 'base.jpg');
        expect(entry.audioPath, 'audio.m4a');
        expect(entry.audioDurationMs, 12345);
        expect(entry.isStarred, true);
        expect(entry.isDeleted, false);
      });

      test('should use created_at for updated_at when not provided', () {
        final now = DateTime.now();
        final json = {
          'id': 'entry-1',
          'content': 'Test content',
          'display_time': now.toIso8601String(),
          'is_starred': false,
          'created_at': now.toIso8601String(),
        };

        final entry = Entry.fromJson(json, 'notebook-1');

        expect(entry.updatedAt, entry.createdAt);
      });

      test('should handle missing optional fields', () {
        final now = DateTime.now();
        final json = {
          'id': 'entry-1',
          'content': null,
          'display_time': now.toIso8601String(),
          'is_starred': false,
          'created_at': now.toIso8601String(),
        };

        final entry = Entry.fromJson(json, 'notebook-1');

        expect(entry.imagePath, isNull);
        expect(entry.annotationBaseImagePath, isNull);
        expect(entry.annotationStrokes, isNull);
        expect(entry.audioPath, isNull);
        expect(entry.audioDurationMs, isNull);
      });
    });

    group('toJson', () {
      test('should convert Entry to JSON', () {
        final now = DateTime.now();
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          content: 'Test content',
          imagePath: '/path/to/image.jpg',
          audioPath: '/path/to/audio.m4a',
          audioDurationMs: 12345,
          displayTime: now,
          createdAt: now,
          isStarred: true,
        );

        final json = entry.toJson();

        expect(json['id'], 'entry-1');
        expect(json['content'], 'Test content');
        expect(json['image_filename'], 'image.jpg');
        expect(json['audio_filename'], 'audio.m4a');
        expect(json['audio_duration_ms'], 12345);
        expect(json['display_time'], now.toIso8601String());
        expect(json['is_starred'], true);
        expect(json['created_at'], now.toIso8601String());
      });

      test('should extract filename from full path', () {
        final now = DateTime.now();
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          imagePath: '/some/long/path/to/image.jpg',
          annotationBaseImagePath: '/some/long/path/to/base.png',
          displayTime: now,
          createdAt: now,
        );

        final json = entry.toJson();

        expect(json['image_filename'], 'image.jpg');
        expect(json['annotation_base_image_filename'], 'base.png');
      });

      test('should handle null image paths', () {
        final now = DateTime.now();
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          imagePath: null,
          annotationBaseImagePath: null,
          displayTime: now,
          createdAt: now,
        );

        final json = entry.toJson();

        expect(json['image_filename'], isNull);
        expect(json['annotation_base_image_filename'], isNull);
      });
    });

    group('getters', () {
      test('hasContent should return true when content is not empty', () {
        final entry = Entry(notebookId: 'notebook-1', content: 'Some content');

        expect(entry.hasContent, true);
      });

      test('hasContent should return false when content is null', () {
        final entry = Entry(notebookId: 'notebook-1', content: null);

        expect(entry.hasContent, false);
      });

      test('hasContent should return false when content is empty', () {
        final entry = Entry(notebookId: 'notebook-1', content: '');

        expect(entry.hasContent, false);
      });

      test('hasImage should return true when imagePath is not empty', () {
        final entry = Entry(
          notebookId: 'notebook-1',
          imagePath: '/path/to/image.jpg',
        );

        expect(entry.hasImage, true);
      });

      test('hasImage should return false when imagePath is null', () {
        final entry = Entry(notebookId: 'notebook-1', imagePath: null);

        expect(entry.hasImage, false);
      });

      test('hasImage should return false when imagePath is empty', () {
        final entry = Entry(notebookId: 'notebook-1', imagePath: '');

        expect(entry.hasImage, false);
      });

      test('hasAudio should return true when audioPath is not empty', () {
        final entry = Entry(
          notebookId: 'notebook-1',
          audioPath: '/path/to/audio.m4a',
        );

        expect(entry.hasAudio, true);
        expect(entry.hasMedia, true);
      });

      test('hasAudio should return false when audioPath is empty', () {
        final entry = Entry(notebookId: 'notebook-1', audioPath: '');

        expect(entry.hasAudio, false);
      });

      test(
        'hasEditableAnnotations should return true when both base image and strokes exist',
        () {
          final entry = Entry(
            notebookId: 'notebook-1',
            annotationBaseImagePath: '/path/to/base.jpg',
            annotationStrokes: '[{"points":[]}]',
          );

          expect(entry.hasEditableAnnotations, true);
        },
      );

      test(
        'hasEditableAnnotations should return false when base image is null',
        () {
          final entry = Entry(
            notebookId: 'notebook-1',
            annotationBaseImagePath: null,
            annotationStrokes: '[{"points":[]}]',
          );

          expect(entry.hasEditableAnnotations, false);
        },
      );

      test(
        'hasEditableAnnotations should return false when strokes is null',
        () {
          final entry = Entry(
            notebookId: 'notebook-1',
            annotationBaseImagePath: '/path/to/base.jpg',
            annotationStrokes: null,
          );

          expect(entry.hasEditableAnnotations, false);
        },
      );

      test('isEmpty should return true when no content and no image', () {
        final entry = Entry(
          notebookId: 'notebook-1',
          content: null,
          imagePath: null,
        );

        expect(entry.isEmpty, true);
      });

      test('isEmpty should return false when has content', () {
        final entry = Entry(
          notebookId: 'notebook-1',
          content: 'Some content',
          imagePath: null,
        );

        expect(entry.isEmpty, false);
      });

      test('isEmpty should return false when has image', () {
        final entry = Entry(
          notebookId: 'notebook-1',
          content: null,
          imagePath: '/path/to/image.jpg',
        );

        expect(entry.isEmpty, false);
      });

      test('isEmpty should return false when has audio', () {
        final entry = Entry(
          notebookId: 'notebook-1',
          content: null,
          audioPath: '/path/to/audio.m4a',
        );

        expect(entry.isEmpty, false);
      });
    });

    group('equality', () {
      test('should be equal when ids match', () {
        final entry1 = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          content: 'Content 1',
        );

        final entry2 = Entry(
          id: 'entry-1',
          notebookId: 'notebook-2',
          content: 'Content 2',
        );

        expect(entry1, entry2);
      });

      test('should not be equal when ids differ', () {
        final entry1 = Entry(id: 'entry-1', notebookId: 'notebook-1');

        final entry2 = Entry(id: 'entry-2', notebookId: 'notebook-1');

        expect(entry1, isNot(entry2));
      });

      test('should have same hashCode when ids match', () {
        final entry1 = Entry(id: 'entry-1', notebookId: 'notebook-1');

        final entry2 = Entry(id: 'entry-1', notebookId: 'notebook-2');

        expect(entry1.hashCode, entry2.hashCode);
      });
    });

    group('toString', () {
      test('should return string representation', () {
        final entry = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          content: 'This is a long content for testing',
          isStarred: true,
          isDeleted: false,
        );

        final str = entry.toString();

        expect(str, contains('entry-1'));
        expect(str, contains('notebook-1'));
        expect(str, contains('isStarred: true'));
        expect(str, contains('isDeleted: false'));
      });
    });
  });
}
