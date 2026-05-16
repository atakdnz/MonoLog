import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/models/folder.dart';

void main() {
  group('Folder', () {
    test('should create a folder with required fields', () {
      final folder = Folder(name: 'Test Folder');

      expect(folder.id, isNotNull);
      expect(folder.name, 'Test Folder');
      expect(folder.sortOrder, 0);
      expect(folder.createdAt, isNotNull);
      expect(folder.updatedAt, isNotNull);
    });

    test('should create a folder with all fields', () {
      final now = DateTime.now();
      final folder = Folder(
        id: 'folder-1',
        name: 'Test Folder',
        sortOrder: 5,
        createdAt: now,
        updatedAt: now,
      );

      expect(folder.id, 'folder-1');
      expect(folder.name, 'Test Folder');
      expect(folder.sortOrder, 5);
      expect(folder.createdAt, now);
      expect(folder.updatedAt, now);
    });

    test('should generate UUID when id is not provided', () {
      final folder1 = Folder(name: 'Folder 1');
      final folder2 = Folder(name: 'Folder 2');

      expect(folder1.id, isNotNull);
      expect(folder2.id, isNotNull);
      expect(folder1.id, isNot(folder2.id));
    });

    test('should set default DateTime when not provided', () {
      final folder = Folder(name: 'Test Folder');

      expect(folder.createdAt.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
      expect(folder.updatedAt.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
    });

    group('copyWith', () {
      test('should return a copy with updated name', () {
        final folder = Folder(
          id: 'folder-1',
          name: 'Old Name',
        );

        final updated = folder.copyWith(name: 'New Name');

        expect(updated.id, folder.id);
        expect(updated.name, 'New Name');
      });

      test('should return a copy with updated sortOrder', () {
        final folder = Folder(
          id: 'folder-1',
          name: 'Test Folder',
          sortOrder: 0,
        );

        final updated = folder.copyWith(sortOrder: 10);

        expect(updated.sortOrder, 10);
      });

      test('should return a copy with updated createdAt', () {
        final now = DateTime.now();
        final earlier = now.subtract(const Duration(days: 1));
        final folder = Folder(
          id: 'folder-1',
          name: 'Test Folder',
          createdAt: earlier,
        );

        final updated = folder.copyWith(createdAt: now);

        expect(updated.createdAt, now);
      });

      test('should return a copy with updated updatedAt', () {
        final now = DateTime.now();
        final earlier = now.subtract(const Duration(days: 1));
        final folder = Folder(
          id: 'folder-1',
          name: 'Test Folder',
          updatedAt: earlier,
        );

        final updated = folder.copyWith(updatedAt: now);

        expect(updated.updatedAt, now);
      });
    });

    group('fromMap', () {
      test('should create Folder from database map', () {
        final now = DateTime.now();
        final map = {
          'id': 'folder-1',
          'name': 'Test Folder',
          'sort_order': 5,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final folder = Folder.fromMap(map);

        expect(folder.id, 'folder-1');
        expect(folder.name, 'Test Folder');
        expect(folder.sortOrder, 5);
        expect(folder.createdAt, now);
        expect(folder.updatedAt, now);
      });

      test('should handle null sortOrder', () {
        final now = DateTime.now();
        final map = {
          'id': 'folder-1',
          'name': 'Test Folder',
          'sort_order': null,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final folder = Folder.fromMap(map);

        expect(folder.sortOrder, 0);
      });
    });

    group('toMap', () {
      test('should convert Folder to database map', () {
        final now = DateTime.now();
        final folder = Folder(
          id: 'folder-1',
          name: 'Test Folder',
          sortOrder: 5,
          createdAt: now,
          updatedAt: now,
        );

        final map = folder.toMap();

        expect(map['id'], 'folder-1');
        expect(map['name'], 'Test Folder');
        expect(map['sort_order'], 5);
        expect(map['created_at'], now.toIso8601String());
        expect(map['updated_at'], now.toIso8601String());
      });
    });

    group('fromJson', () {
      test('should create Folder from JSON', () {
        final now = DateTime.now();
        final json = {
          'id': 'folder-1',
          'name': 'Test Folder',
          'sort_order': 5,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final folder = Folder.fromJson(json);

        expect(folder.id, 'folder-1');
        expect(folder.name, 'Test Folder');
        expect(folder.sortOrder, 5);
        expect(folder.createdAt, now);
        expect(folder.updatedAt, now);
      });

      test('should handle null sortOrder', () {
        final now = DateTime.now();
        final json = {
          'id': 'folder-1',
          'name': 'Test Folder',
          'sort_order': null,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final folder = Folder.fromJson(json);

        expect(folder.sortOrder, 0);
      });

      test('should use DateTime.now() for updatedAt when not provided', () {
        final now = DateTime.now();
        final json = {
          'id': 'folder-1',
          'name': 'Test Folder',
          'created_at': now.toIso8601String(),
        };

        final folder = Folder.fromJson(json);

        expect(folder.updatedAt.difference(now).inSeconds.abs(), lessThan(5));
      });
    });

    group('toJson', () {
      test('should convert Folder to JSON', () {
        final now = DateTime.now();
        final folder = Folder(
          id: 'folder-1',
          name: 'Test Folder',
          sortOrder: 5,
          createdAt: now,
          updatedAt: now,
        );

        final json = folder.toJson();

        expect(json['id'], 'folder-1');
        expect(json['name'], 'Test Folder');
        expect(json['sort_order'], 5);
        expect(json['created_at'], now.toIso8601String());
        expect(json['updated_at'], now.toIso8601String());
      });
    });

    group('equality', () {
      test('should be equal when ids match', () {
        final folder1 = Folder(
          id: 'folder-1',
          name: 'Name 1',
        );

        final folder2 = Folder(
          id: 'folder-1',
          name: 'Name 2',
        );

        expect(folder1, folder2);
      });

      test('should not be equal when ids differ', () {
        final folder1 = Folder(
          id: 'folder-1',
          name: 'Test Folder',
        );

        final folder2 = Folder(
          id: 'folder-2',
          name: 'Test Folder',
        );

        expect(folder1, isNot(folder2));
      });

      test('should have same hashCode when ids match', () {
        final folder1 = Folder(
          id: 'folder-1',
          name: 'Name 1',
        );

        final folder2 = Folder(
          id: 'folder-1',
          name: 'Name 2',
        );

        expect(folder1.hashCode, folder2.hashCode);
      });
    });

    group('toString', () {
      test('should return string representation', () {
        final folder = Folder(
          id: 'folder-1',
          name: 'Test Folder',
          sortOrder: 5,
        );

        final str = folder.toString();

        expect(str, contains('folder-1'));
        expect(str, contains('Test Folder'));
        expect(str, contains('sortOrder: 5'));
      });
    });
  });
}
