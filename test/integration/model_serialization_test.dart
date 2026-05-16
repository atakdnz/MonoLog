import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/models/entry.dart';
import 'package:monolog/models/notebook.dart';
import 'package:monolog/models/folder.dart';

void main() {
  group('Model Serialization Roundtrip Tests', () {
    group('Entry Roundtrip', () {
      test('Entry toMap -> fromMap should preserve all fields', () {
        final now = DateTime.now();
        final original = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          content: 'Test content',
          imagePath: '/path/to/image.jpg',
          annotationBaseImagePath: '/path/to/base.jpg',
          annotationStrokes: '[{"points":[]}]',
          displayTime: now,
          createdAt: now,
          updatedAt: now,
          isStarred: true,
          isDeleted: false,
        );

        final map = original.toMap();
        final restored = Entry.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.notebookId, original.notebookId);
        expect(restored.content, original.content);
        expect(restored.imagePath, original.imagePath);
        expect(restored.annotationBaseImagePath, original.annotationBaseImagePath);
        expect(restored.annotationStrokes, original.annotationStrokes);
        expect(restored.displayTime, original.displayTime);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
        expect(restored.isStarred, original.isStarred);
        expect(restored.isDeleted, original.isDeleted);
        expect(restored.deletedAt, original.deletedAt);
      });

      test('Entry toJson -> fromJson should preserve export fields', () {
        final now = DateTime.now();
        final original = Entry(
          id: 'entry-1',
          notebookId: 'notebook-1',
          content: 'Test content',
          imagePath: '/path/to/image.jpg',
          annotationBaseImagePath: '/path/to/base.jpg',
          annotationStrokes: '[{"points":[]}]',
          displayTime: now,
          createdAt: now,
          isStarred: true,
        );

        final json = original.toJson();
        final restored = Entry.fromJson(json, 'notebook-2');

        expect(restored.id, original.id);
        expect(restored.notebookId, 'notebook-2');
        expect(restored.content, original.content);
        expect(restored.imagePath, 'image.jpg');
        expect(restored.annotationBaseImagePath, 'base.jpg');
        expect(restored.annotationStrokes, original.annotationStrokes);
        expect(restored.displayTime, original.displayTime);
        expect(restored.createdAt, original.createdAt);
        expect(restored.isStarred, original.isStarred);
      });
    });

    group('Notebook Roundtrip', () {
      test('Notebook toMap -> fromMap should preserve all fields', () {
        final now = DateTime.now();
        final original = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isPinned: true,
          isArchived: false,
          isDeleted: false,
          entryStyle: 'classic',
          sortOrder: 5,
          folderId: 'folder-1',
          isLocked: true,
          createdAt: now,
          updatedAt: now,
        );

        final map = original.toMap();
        final restored = Notebook.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.color, original.color);
        expect(restored.isPinned, original.isPinned);
        expect(restored.isArchived, original.isArchived);
        expect(restored.isDeleted, original.isDeleted);
        expect(restored.entryStyle, original.entryStyle);
        expect(restored.sortOrder, original.sortOrder);
        expect(restored.folderId, original.folderId);
        expect(restored.isLocked, original.isLocked);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
      });

      test('Notebook toJson -> fromJson should preserve all fields', () {
        final now = DateTime.now();
        final original = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isPinned: true,
          isArchived: false,
          isDeleted: false,
          entryStyle: 'classic',
          sortOrder: 5,
          folderId: 'folder-1',
          isLocked: true,
          createdAt: now,
          updatedAt: now,
        );

        final json = original.toJson();
        final restored = Notebook.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.color, original.color);
        expect(restored.isPinned, original.isPinned);
        expect(restored.isArchived, original.isArchived);
        expect(restored.isDeleted, original.isDeleted);
        expect(restored.entryStyle, original.entryStyle);
        expect(restored.sortOrder, original.sortOrder);
        expect(restored.folderId, original.folderId);
        expect(restored.isLocked, original.isLocked);
        expect(restored.createdAt, original.createdAt);
      });
    });

    group('Folder Roundtrip', () {
      test('Folder toMap -> fromMap should preserve all fields', () {
        final now = DateTime.now();
        final original = Folder(
          id: 'folder-1',
          name: 'Test Folder',
          sortOrder: 5,
          createdAt: now,
          updatedAt: now,
        );

        final map = original.toMap();
        final restored = Folder.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.sortOrder, original.sortOrder);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
      });

      test('Folder toJson -> fromJson should preserve all fields', () {
        final now = DateTime.now();
        final original = Folder(
          id: 'folder-1',
          name: 'Test Folder',
          sortOrder: 5,
          createdAt: now,
          updatedAt: now,
        );

        final json = original.toJson();
        final restored = Folder.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.sortOrder, original.sortOrder);
        expect(restored.createdAt, original.createdAt);
      });
    });
  });

  group('Edge Cases', () {
    test('Entry with empty content should have hasContent false', () {
      final entry = Entry(
        notebookId: 'notebook-1',
        content: '',
      );

      expect(entry.hasContent, false);
      expect(entry.isEmpty, true);
    });

    test('Entry with only whitespace content should have hasContent true', () {
      final entry = Entry(
        notebookId: 'notebook-1',
        content: '   ',
      );

      expect(entry.hasContent, true);
      expect(entry.isEmpty, false);
    });

    test('Entry with content and image should not be empty', () {
      final entry = Entry(
        notebookId: 'notebook-1',
        content: 'Test content',
        imagePath: '/path/to/image.jpg',
      );

      expect(entry.hasContent, true);
      expect(entry.hasImage, true);
      expect(entry.isEmpty, false);
    });

    test('Notebook copyWith should preserve unchanged fields', () {
      final now = DateTime.now();
      final original = Notebook(
        id: 'notebook-1',
        title: 'Original Title',
        color: '#6366F1',
        isPinned: true,
        isArchived: false,
        entryStyle: 'classic',
        sortOrder: 5,
        folderId: 'folder-1',
        isLocked: true,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(title: 'New Title');

      expect(updated.title, 'New Title');
      expect(updated.id, original.id);
      expect(updated.color, original.color);
      expect(updated.isPinned, original.isPinned);
      expect(updated.isArchived, original.isArchived);
      expect(updated.entryStyle, original.entryStyle);
      expect(updated.sortOrder, original.sortOrder);
      expect(updated.folderId, original.folderId);
      expect(updated.isLocked, original.isLocked);
      expect(updated.createdAt, original.createdAt);
    });

    test('Entry copyWith should preserve unchanged fields', () {
      final now = DateTime.now();
      final original = Entry(
        id: 'entry-1',
        notebookId: 'notebook-1',
        content: 'Original content',
        imagePath: '/path/to/image.jpg',
        displayTime: now,
        createdAt: now,
        updatedAt: now,
        isStarred: true,
        isDeleted: false,
      );

      final updated = original.copyWith(content: 'New content');

      expect(updated.content, 'New content');
      expect(updated.id, original.id);
      expect(updated.notebookId, original.notebookId);
      expect(updated.imagePath, original.imagePath);
      expect(updated.displayTime, original.displayTime);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, original.updatedAt);
      expect(updated.isStarred, original.isStarred);
      expect(updated.isDeleted, original.isDeleted);
    });

    test('Folder copyWith should preserve unchanged fields', () {
      final now = DateTime.now();
      final original = Folder(
        id: 'folder-1',
        name: 'Original Name',
        sortOrder: 5,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(name: 'New Name');

      expect(updated.name, 'New Name');
      expect(updated.id, original.id);
      expect(updated.sortOrder, original.sortOrder);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, original.updatedAt);
    });
  });
}
