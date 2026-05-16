import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/models/notebook.dart';
import 'package:monolog/utils/constants.dart';

void main() {
  group('Notebook', () {
    test('should create a notebook with required fields', () {
      final notebook = Notebook(
        title: 'Test Notebook',
        color: '#6366F1',
      );

      expect(notebook.id, isNotNull);
      expect(notebook.title, 'Test Notebook');
      expect(notebook.color, '#6366F1');
      expect(notebook.isPinned, false);
      expect(notebook.isArchived, false);
      expect(notebook.isDeleted, false);
      expect(notebook.entryStyle, NotebookEntryStyles.chat);
      expect(notebook.sortOrder, 0);
      expect(notebook.folderId, isNull);
      expect(notebook.isLocked, false);
      expect(notebook.createdAt, isNotNull);
      expect(notebook.updatedAt, isNotNull);
    });

    test('should create a notebook with all fields', () {
      final now = DateTime.now();
      final notebook = Notebook(
        id: 'notebook-1',
        title: 'Test Notebook',
        color: '#6366F1',
        isPinned: true,
        isArchived: false,
        isDeleted: false,
        entryStyle: NotebookEntryStyles.classic,
        sortOrder: 5,
        folderId: 'folder-1',
        isLocked: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(notebook.id, 'notebook-1');
      expect(notebook.title, 'Test Notebook');
      expect(notebook.color, '#6366F1');
      expect(notebook.isPinned, true);
      expect(notebook.isArchived, false);
      expect(notebook.entryStyle, NotebookEntryStyles.classic);
      expect(notebook.sortOrder, 5);
      expect(notebook.folderId, 'folder-1');
      expect(notebook.isLocked, true);
    });

    test('should generate UUID when id is not provided', () {
      final notebook1 = Notebook(title: 'Notebook 1', color: '#6366F1');
      final notebook2 = Notebook(title: 'Notebook 2', color: '#6366F1');

      expect(notebook1.id, isNotNull);
      expect(notebook2.id, isNotNull);
      expect(notebook1.id, isNot(notebook2.id));
    });

    test('should set default DateTime when not provided', () {
      final notebook = Notebook(title: 'Test Notebook', color: '#6366F1');

      expect(notebook.createdAt.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
      expect(notebook.updatedAt.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
    });

    group('copyWith', () {
      test('should return a copy with updated title', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Old Title',
          color: '#6366F1',
        );

        final updated = notebook.copyWith(title: 'New Title');

        expect(updated.id, notebook.id);
        expect(updated.title, 'New Title');
        expect(updated.color, notebook.color);
      });

      test('should return a copy with updated color', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
        );

        final updated = notebook.copyWith(color: '#EF4444');

        expect(updated.color, '#EF4444');
      });

      test('should toggle isPinned', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isPinned: false,
        );

        final updated = notebook.copyWith(isPinned: true);

        expect(updated.isPinned, true);
      });

      test('should toggle isArchived', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isArchived: false,
        );

        final updated = notebook.copyWith(isArchived: true);

        expect(updated.isArchived, true);
      });

      test('should toggle isDeleted', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isDeleted: false,
        );

        final updated = notebook.copyWith(isDeleted: true, deletedAt: DateTime.now());

        expect(updated.isDeleted, true);
        expect(updated.deletedAt, isNotNull);
      });

      test('should update entryStyle', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          entryStyle: NotebookEntryStyles.chat,
        );

        final updated = notebook.copyWith(entryStyle: NotebookEntryStyles.classic);

        expect(updated.entryStyle, NotebookEntryStyles.classic);
      });

      test('should update sortOrder', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          sortOrder: 0,
        );

        final updated = notebook.copyWith(sortOrder: 10);

        expect(updated.sortOrder, 10);
      });

      test('should update folderId', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          folderId: null,
        );

        final updated = notebook.copyWith(folderId: 'folder-1');

        expect(updated.folderId, 'folder-1');
      });

      test('should clear folderId when clearFolderId is true', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          folderId: 'folder-1',
        );

        final updated = notebook.copyWith(clearFolderId: true);

        expect(updated.folderId, isNull);
      });

      test('should toggle isLocked', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isLocked: false,
        );

        final updated = notebook.copyWith(isLocked: true);

        expect(updated.isLocked, true);
      });

      test('should clear deletedAt when clearDeletedAt is true', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isDeleted: true,
          deletedAt: DateTime.now(),
        );

        final updated = notebook.copyWith(clearDeletedAt: true);

        expect(updated.deletedAt, isNull);
      });
    });

    group('fromMap', () {
      test('should create Notebook from database map', () {
        final now = DateTime.now();
        final map = {
          'id': 'notebook-1',
          'title': 'Test Notebook',
          'color': '#6366F1',
          'is_pinned': 1,
          'is_archived': 0,
          'is_deleted': 0,
          'entry_style': NotebookEntryStyles.classic,
          'sort_order': 5,
          'folder_id': 'folder-1',
          'is_locked': 1,
          'deleted_at': null,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final notebook = Notebook.fromMap(map);

        expect(notebook.id, 'notebook-1');
        expect(notebook.title, 'Test Notebook');
        expect(notebook.color, '#6366F1');
        expect(notebook.isPinned, true);
        expect(notebook.isArchived, false);
        expect(notebook.isDeleted, false);
        expect(notebook.entryStyle, NotebookEntryStyles.classic);
        expect(notebook.sortOrder, 5);
        expect(notebook.folderId, 'folder-1');
        expect(notebook.isLocked, true);
      });

      test('should handle null values in map', () {
        final now = DateTime.now();
        final map = {
          'id': 'notebook-1',
          'title': 'Test Notebook',
          'color': '#6366F1',
          'is_pinned': null,
          'is_archived': null,
          'is_deleted': null,
          'entry_style': null,
          'sort_order': null,
          'folder_id': null,
          'is_locked': null,
          'deleted_at': null,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final notebook = Notebook.fromMap(map);

        expect(notebook.isPinned, false);
        expect(notebook.isArchived, false);
        expect(notebook.isDeleted, false);
        expect(notebook.entryStyle, NotebookEntryStyles.chat);
        expect(notebook.sortOrder, 0);
        expect(notebook.folderId, isNull);
        expect(notebook.isLocked, false);
      });

      test('should parse deletedAt when not null', () {
        final now = DateTime.now();
        final map = {
          'id': 'notebook-1',
          'title': 'Test Notebook',
          'color': '#6366F1',
          'is_pinned': 0,
          'is_archived': 0,
          'is_deleted': 1,
          'entry_style': NotebookEntryStyles.chat,
          'sort_order': 0,
          'folder_id': null,
          'is_locked': 0,
          'deleted_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final notebook = Notebook.fromMap(map);

        expect(notebook.isDeleted, true);
        expect(notebook.deletedAt, isNotNull);
      });
    });

    group('toMap', () {
      test('should convert Notebook to database map', () {
        final now = DateTime.now();
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isPinned: true,
          isArchived: false,
          isDeleted: false,
          entryStyle: NotebookEntryStyles.classic,
          sortOrder: 5,
          folderId: 'folder-1',
          isLocked: true,
          createdAt: now,
          updatedAt: now,
        );

        final map = notebook.toMap();

        expect(map['id'], 'notebook-1');
        expect(map['title'], 'Test Notebook');
        expect(map['color'], '#6366F1');
        expect(map['is_pinned'], 1);
        expect(map['is_archived'], 0);
        expect(map['is_deleted'], 0);
        expect(map['entry_style'], NotebookEntryStyles.classic);
        expect(map['sort_order'], 5);
        expect(map['folder_id'], 'folder-1');
        expect(map['is_locked'], 1);
      });

      test('should handle null deletedAt', () {
        final now = DateTime.now();
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          createdAt: now,
          updatedAt: now,
        );

        final map = notebook.toMap();

        expect(map['deleted_at'], isNull);
      });

      test('should handle non-null deletedAt', () {
        final now = DateTime.now();
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isDeleted: true,
          deletedAt: now,
          createdAt: now,
          updatedAt: now,
        );

        final map = notebook.toMap();

        expect(map['deleted_at'], isNotNull);
      });
    });

    group('fromJson', () {
      test('should create Notebook from JSON', () {
        final now = DateTime.now();
        final json = {
          'id': 'notebook-1',
          'title': 'Test Notebook',
          'color': '#6366F1',
          'is_pinned': true,
          'is_archived': false,
          'is_deleted': false,
          'entry_style': NotebookEntryStyles.classic,
          'sort_order': 5,
          'folder_id': 'folder-1',
          'is_locked': true,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final notebook = Notebook.fromJson(json);

        expect(notebook.id, 'notebook-1');
        expect(notebook.title, 'Test Notebook');
        expect(notebook.color, '#6366F1');
        expect(notebook.isPinned, true);
        expect(notebook.isArchived, false);
        expect(notebook.entryStyle, NotebookEntryStyles.classic);
        expect(notebook.sortOrder, 5);
        expect(notebook.folderId, 'folder-1');
        expect(notebook.isLocked, true);
      });

      test('should use created_at for updated_at when not provided', () {
        final now = DateTime.now();
        final json = {
          'id': 'notebook-1',
          'title': 'Test Notebook',
          'color': '#6366F1',
          'created_at': now.toIso8601String(),
        };

        final notebook = Notebook.fromJson(json);

        expect(notebook.updatedAt, notebook.createdAt);
      });

      test('should handle missing optional fields', () {
        final now = DateTime.now();
        final json = {
          'id': 'notebook-1',
          'title': 'Test Notebook',
          'color': '#6366F1',
          'created_at': now.toIso8601String(),
        };

        final notebook = Notebook.fromJson(json);

        expect(notebook.isPinned, false);
        expect(notebook.isArchived, false);
        expect(notebook.isDeleted, false);
        expect(notebook.entryStyle, NotebookEntryStyles.chat);
        expect(notebook.sortOrder, 0);
        expect(notebook.folderId, isNull);
        expect(notebook.isLocked, false);
        expect(notebook.deletedAt, isNull);
      });
    });

    group('toJson', () {
      test('should convert Notebook to JSON', () {
        final now = DateTime.now();
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isPinned: true,
          isArchived: false,
          isDeleted: false,
          entryStyle: NotebookEntryStyles.classic,
          sortOrder: 5,
          folderId: 'folder-1',
          isLocked: true,
          createdAt: now,
          updatedAt: now,
        );

        final json = notebook.toJson();

        expect(json['id'], 'notebook-1');
        expect(json['title'], 'Test Notebook');
        expect(json['color'], '#6366F1');
        expect(json['is_pinned'], true);
        expect(json['is_archived'], false);
        expect(json['is_deleted'], false);
        expect(json['entry_style'], NotebookEntryStyles.classic);
        expect(json['sort_order'], 5);
        expect(json['folder_id'], 'folder-1');
        expect(json['is_locked'], true);
      });

      test('should handle null deletedAt', () {
        final now = DateTime.now();
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          createdAt: now,
          updatedAt: now,
        );

        final json = notebook.toJson();

        expect(json['deleted_at'], isNull);
      });

      test('should handle non-null deletedAt', () {
        final now = DateTime.now();
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          isDeleted: true,
          deletedAt: now,
          createdAt: now,
          updatedAt: now,
        );

        final json = notebook.toJson();

        expect(json['deleted_at'], isNotNull);
      });
    });

    group('equality', () {
      test('should be equal when ids match', () {
        final notebook1 = Notebook(
          id: 'notebook-1',
          title: 'Title 1',
          color: '#6366F1',
        );

        final notebook2 = Notebook(
          id: 'notebook-1',
          title: 'Title 2',
          color: '#EF4444',
        );

        expect(notebook1, notebook2);
      });

      test('should not be equal when ids differ', () {
        final notebook1 = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
        );

        final notebook2 = Notebook(
          id: 'notebook-2',
          title: 'Test Notebook',
          color: '#6366F1',
        );

        expect(notebook1, isNot(notebook2));
      });

      test('should have same hashCode when ids match', () {
        final notebook1 = Notebook(
          id: 'notebook-1',
          title: 'Title 1',
          color: '#6366F1',
        );

        final notebook2 = Notebook(
          id: 'notebook-1',
          title: 'Title 2',
          color: '#EF4444',
        );

        expect(notebook1.hashCode, notebook2.hashCode);
      });
    });

    group('toString', () {
      test('should return string representation', () {
        final notebook = Notebook(
          id: 'notebook-1',
          title: 'Test Notebook',
          color: '#6366F1',
          entryStyle: NotebookEntryStyles.chat,
          isPinned: true,
          isArchived: false,
          isDeleted: false,
          isLocked: false,
          sortOrder: 0,
        );

        final str = notebook.toString();

        expect(str, contains('notebook-1'));
        expect(str, contains('Test Notebook'));
        expect(str, contains('#6366F1'));
        expect(str, contains('isPinned: true'));
        expect(str, contains('isArchived: false'));
        expect(str, contains('isDeleted: false'));
        expect(str, contains('isLocked: false'));
      });
    });
  });
}
