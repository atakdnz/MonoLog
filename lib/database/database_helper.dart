import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/notebook.dart';
import '../models/entry.dart';
import '../utils/constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'monolog.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notebooks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        color TEXT NOT NULL,
        is_pinned INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        entry_style TEXT DEFAULT 'chat',
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE entries (
        id TEXT PRIMARY KEY,
        notebook_id TEXT NOT NULL,
        content TEXT,
        image_path TEXT,
        annotation_base_image_path TEXT,
        annotation_strokes TEXT,
        display_time TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_starred INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        deleted_at TEXT,
        FOREIGN KEY (notebook_id) REFERENCES notebooks(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better query performance
    await db.execute(
      'CREATE INDEX idx_entries_notebook ON entries(notebook_id)',
    );
    await db.execute(
      'CREATE INDEX idx_entries_display_time ON entries(display_time)',
    );
    await db.execute(
      'CREATE INDEX idx_entries_is_deleted ON entries(is_deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_notebooks_is_deleted ON notebooks(is_deleted)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add is_deleted and deleted_at columns to notebooks table
      await db.execute(
        'ALTER TABLE notebooks ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE notebooks ADD COLUMN deleted_at TEXT');
      await db.execute(
        'CREATE INDEX idx_notebooks_is_deleted ON notebooks(is_deleted)',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE notebooks ADD COLUMN entry_style TEXT DEFAULT 'chat'",
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE entries ADD COLUMN annotation_base_image_path TEXT',
      );
      await db.execute(
        'ALTER TABLE entries ADD COLUMN annotation_strokes TEXT',
      );
    }
  }

  // =========== NOTEBOOK OPERATIONS ===========

  /// Insert a new notebook
  Future<void> insertNotebook(Notebook notebook) async {
    final db = await database;
    await db.insert('notebooks', notebook.toMap());
  }

  /// Update an existing notebook
  Future<void> updateNotebook(Notebook notebook) async {
    final db = await database;
    await db.update(
      'notebooks',
      notebook.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [notebook.id],
    );
  }

  /// Soft delete a notebook (move to trash)
  Future<void> softDeleteNotebook(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE notebooks 
      SET is_deleted = 1, deleted_at = ?, updated_at = ?, is_pinned = 0
      WHERE id = ?
    ''',
      [now, now, id],
    );
  }

  /// Restore a notebook from trash
  Future<void> restoreNotebook(String id) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE notebooks 
      SET is_deleted = 0, deleted_at = NULL, updated_at = ?
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  /// Delete a notebook and all its entries permanently
  Future<void> permanentlyDeleteNotebook(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete all entries in the notebook first
      await txn.delete('entries', where: 'notebook_id = ?', whereArgs: [id]);
      // Delete the notebook
      await txn.delete('notebooks', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Get a notebook by ID
  Future<Notebook?> getNotebook(String id) async {
    final db = await database;
    final maps = await db.query('notebooks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Notebook.fromMap(maps.first);
  }

  /// Get all notebooks (excluding archived and deleted)
  Future<List<Notebook>> getNotebooks({bool includeArchived = false}) async {
    final db = await database;
    final maps = await db.query(
      'notebooks',
      where: includeArchived
          ? 'is_deleted = 0'
          : 'is_archived = 0 AND is_deleted = 0',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return maps.map((map) => Notebook.fromMap(map)).toList();
  }

  /// Get pinned notebooks
  Future<List<Notebook>> getPinnedNotebooks() async {
    final db = await database;
    final maps = await db.query(
      'notebooks',
      where: 'is_pinned = 1 AND is_archived = 0 AND is_deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Notebook.fromMap(map)).toList();
  }

  /// Get regular (non-pinned, non-archived, non-deleted) notebooks
  Future<List<Notebook>> getRegularNotebooks() async {
    final db = await database;
    final maps = await db.query(
      'notebooks',
      where: 'is_pinned = 0 AND is_archived = 0 AND is_deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Notebook.fromMap(map)).toList();
  }

  /// Get archived notebooks
  Future<List<Notebook>> getArchivedNotebooks() async {
    final db = await database;
    final maps = await db.query(
      'notebooks',
      where: 'is_archived = 1 AND is_deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Notebook.fromMap(map)).toList();
  }

  /// Get deleted notebooks (trash)
  Future<List<Notebook>> getDeletedNotebooks() async {
    final db = await database;
    final maps = await db.query(
      'notebooks',
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC',
    );
    return maps.map((map) => Notebook.fromMap(map)).toList();
  }

  /// Toggle notebook pin status
  Future<void> toggleNotebookPin(String id) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE notebooks 
      SET is_pinned = CASE WHEN is_pinned = 1 THEN 0 ELSE 1 END,
          updated_at = ?
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  /// Toggle notebook archive status
  Future<void> toggleNotebookArchive(String id) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE notebooks 
      SET is_archived = CASE WHEN is_archived = 1 THEN 0 ELSE 1 END,
          is_pinned = 0,
          updated_at = ?
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  // =========== ENTRY OPERATIONS ===========

  /// Insert a new entry
  Future<void> insertEntry(Entry entry) async {
    final db = await database;
    await db.insert('entries', entry.toMap());
    // Update notebook's updated_at
    await db.rawUpdate(
      '''
      UPDATE notebooks SET updated_at = ? WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), entry.notebookId],
    );
  }

  /// Update an existing entry
  Future<void> updateEntry(Entry entry) async {
    final db = await database;
    await db.update(
      'entries',
      entry.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    // Update notebook's updated_at
    await db.rawUpdate(
      '''
      UPDATE notebooks SET updated_at = ? WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), entry.notebookId],
    );
  }

  /// Soft delete an entry (move to trash)
  Future<void> softDeleteEntry(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE entries 
      SET is_deleted = 1, deleted_at = ?, updated_at = ?
      WHERE id = ?
    ''',
      [now, now, id],
    );
  }

  /// Restore an entry from trash
  Future<void> restoreEntry(String id) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE entries 
      SET is_deleted = 0, deleted_at = NULL, updated_at = ?
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  /// Permanently delete an entry
  Future<void> permanentlyDeleteEntry(String id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Get an entry by ID
  Future<Entry?> getEntry(String id) async {
    final db = await database;
    final maps = await db.query('entries', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Entry.fromMap(maps.first);
  }

  /// Get all entries for a notebook (ordered by display_time DESC)
  Future<List<Entry>> getEntriesForNotebook(String notebookId) async {
    final db = await database;
    final maps = await db.query(
      'entries',
      where: 'notebook_id = ? AND is_deleted = 0',
      whereArgs: [notebookId],
      orderBy: 'display_time DESC',
    );
    return maps.map((map) => Entry.fromMap(map)).toList();
  }

  /// Get the most recent entry for a notebook (for preview)
  Future<Entry?> getMostRecentEntry(String notebookId) async {
    final db = await database;
    final maps = await db.query(
      'entries',
      where: 'notebook_id = ? AND is_deleted = 0',
      whereArgs: [notebookId],
      orderBy: 'display_time DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Entry.fromMap(maps.first);
  }

  /// Toggle entry star status
  Future<void> toggleEntryStar(String id) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE entries 
      SET is_starred = CASE WHEN is_starred = 1 THEN 0 ELSE 1 END,
          updated_at = ?
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  /// Set star status for multiple entries
  Future<void> setEntriesStarred(List<String> ids, bool isStarred) async {
    if (ids.isEmpty) return;

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.rawUpdate(
      '''
      UPDATE entries
      SET is_starred = ?,
          updated_at = ?
      WHERE id IN ($placeholders)
    ''',
      [isStarred ? 1 : 0, DateTime.now().toIso8601String(), ...ids],
    );
  }

  /// Move entry to a different notebook
  Future<void> moveEntry(String entryId, String newNotebookId) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE entries 
      SET notebook_id = ?, updated_at = ?
      WHERE id = ?
    ''',
      [newNotebookId, DateTime.now().toIso8601String(), entryId],
    );
  }

  // =========== TRASH OPERATIONS ===========

  /// Get all deleted entries (trash)
  Future<List<Entry>> getTrashEntries() async {
    final db = await database;
    final maps = await db.query(
      'entries',
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC',
    );
    return maps.map((map) => Entry.fromMap(map)).toList();
  }

  /// Empty trash (delete all trashed entries and notebooks permanently)
  Future<void> emptyTrash() async {
    final db = await database;
    await db.transaction((txn) async {
      // Get all deleted notebooks
      final deletedNotebooks = await txn.query(
        'notebooks',
        columns: ['id'],
        where: 'is_deleted = 1',
      );
      // Delete entries for deleted notebooks
      for (final notebook in deletedNotebooks) {
        await txn.delete(
          'entries',
          where: 'notebook_id = ?',
          whereArgs: [notebook['id']],
        );
      }
      // Delete notebooks
      await txn.delete('notebooks', where: 'is_deleted = 1');
      // Delete orphan entries
      await txn.delete('entries', where: 'is_deleted = 1');
    });
  }

  /// Auto-cleanup: delete entries and notebooks older than 30 days from trash
  Future<void> cleanupOldTrash() async {
    final db = await database;
    final cutoffDate = DateTime.now()
        .subtract(const Duration(days: trashRetentionDays))
        .toIso8601String();

    await db.transaction((txn) async {
      // Get old deleted notebooks
      final oldNotebooks = await txn.query(
        'notebooks',
        columns: ['id'],
        where: 'is_deleted = 1 AND deleted_at < ?',
        whereArgs: [cutoffDate],
      );
      // Delete entries for old notebooks
      for (final notebook in oldNotebooks) {
        await txn.delete(
          'entries',
          where: 'notebook_id = ?',
          whereArgs: [notebook['id']],
        );
      }
      // Delete old notebooks
      await txn.delete(
        'notebooks',
        where: 'is_deleted = 1 AND deleted_at < ?',
        whereArgs: [cutoffDate],
      );
      // Delete old entries
      await txn.delete(
        'entries',
        where: 'is_deleted = 1 AND deleted_at < ?',
        whereArgs: [cutoffDate],
      );
    });
  }

  // =========== SEARCH OPERATIONS ===========

  /// Global search across all notebooks
  Future<List<Map<String, dynamic>>> globalSearch(String query) async {
    final db = await database;
    final searchQuery = '%$query%';
    final results = await db.rawQuery(
      '''
      SELECT e.*, n.title as notebook_title, n.color as notebook_color
      FROM entries e
      JOIN notebooks n ON e.notebook_id = n.id
      WHERE e.is_deleted = 0 AND n.is_deleted = 0 AND e.content LIKE ?
      ORDER BY e.display_time DESC
      LIMIT 100
    ''',
      [searchQuery],
    );
    return results;
  }

  /// Local search within a notebook
  Future<List<Entry>> localSearch(String notebookId, String query) async {
    final db = await database;
    final searchQuery = '%$query%';
    final maps = await db.query(
      'entries',
      where: 'notebook_id = ? AND is_deleted = 0 AND content LIKE ?',
      whereArgs: [notebookId, searchQuery],
      orderBy: 'display_time DESC',
    );
    return maps.map((map) => Entry.fromMap(map)).toList();
  }

  // =========== IMPORT/EXPORT HELPERS ===========

  /// Get all notebooks with their entries for export
  Future<List<Map<String, dynamic>>> getAllDataForExport() async {
    final db = await database;
    final notebooks = await db.query(
      'notebooks',
      where: 'is_deleted = 0',
      orderBy: 'created_at ASC',
    );

    final result = <Map<String, dynamic>>[];
    for (final notebook in notebooks) {
      final entries = await db.query(
        'entries',
        where: 'notebook_id = ? AND is_deleted = 0',
        whereArgs: [notebook['id']],
        orderBy: 'display_time ASC',
      );
      result.add({...notebook, 'entries': entries});
    }
    return result;
  }

  /// Get a single notebook with all entries for export
  Future<Map<String, dynamic>?> getNotebookDataForExport(
    String notebookId,
  ) async {
    final db = await database;
    final notebooks = await db.query(
      'notebooks',
      where: 'id = ?',
      whereArgs: [notebookId],
    );
    if (notebooks.isEmpty) return null;

    final entries = await db.query(
      'entries',
      where: 'notebook_id = ? AND is_deleted = 0',
      whereArgs: [notebookId],
      orderBy: 'display_time ASC',
    );

    return {...notebooks.first, 'entries': entries};
  }

  /// Check if a notebook with the given ID exists
  Future<bool> notebookExists(String id) async {
    final db = await database;
    final result = await db.query(
      'notebooks',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty;
  }

  /// Check if an entry with the given ID exists
  Future<bool> entryExists(String id) async {
    final db = await database;
    final result = await db.query('entries', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty;
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
