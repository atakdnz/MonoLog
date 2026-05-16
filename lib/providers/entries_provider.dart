import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/entry.dart';

class EntriesProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  String? _currentNotebookId;
  List<Entry> _entries = [];
  bool _isLoading = false;

  String? get currentNotebookId => _currentNotebookId;
  List<Entry> get entries => _entries;
  bool get isLoading => _isLoading;

  /// Set current notebook and load its entries
  Future<void> setNotebook(String notebookId) async {
    _currentNotebookId = notebookId;
    await loadEntries();
  }

  /// Load entries for current notebook
  Future<void> loadEntries() async {
    if (_currentNotebookId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _entries = await _db.getEntriesForNotebook(_currentNotebookId!);
    } catch (e) {
      debugPrint('Error loading entries: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new entry
  Future<Entry> addEntry({
    required String content,
    String? imagePath,
    String? annotationBaseImagePath,
    String? annotationStrokes,
    DateTime? displayTime,
  }) async {
    if (_currentNotebookId == null) {
      throw Exception('No notebook selected');
    }

    final entry = Entry(
      notebookId: _currentNotebookId!,
      content: content.isEmpty ? null : content,
      imagePath: imagePath,
      annotationBaseImagePath: annotationBaseImagePath,
      annotationStrokes: annotationStrokes,
      displayTime: displayTime,
    );

    await _db.insertEntry(entry);
    await loadEntries();
    return entry;
  }

  /// Update an entry
  Future<void> updateEntry(Entry entry) async {
    await _db.updateEntry(entry);
    await loadEntries();
  }

  /// Soft delete an entry (move to trash)
  Future<void> deleteEntry(String id) async {
    await _db.softDeleteEntry(id);
    await loadEntries();
  }

  /// Toggle entry star status
  Future<void> toggleStar(String id) async {
    await _db.toggleEntryStar(id);
    await loadEntries();
  }

  /// Set star status for multiple entries
  Future<void> setEntriesStarred(List<String> ids, bool isStarred) async {
    await _db.setEntriesStarred(ids, isStarred);
    await loadEntries();
  }

  /// Move entry to a different notebook
  Future<void> moveEntry(String entryId, String newNotebookId) async {
    await _db.moveEntry(entryId, newNotebookId);
    await loadEntries();
  }

  /// Get entry by ID
  Future<Entry?> getEntry(String id) async {
    return await _db.getEntry(id);
  }

  /// Clear current notebook selection
  void clearNotebook() {
    _currentNotebookId = null;
    _entries = [];
    notifyListeners();
  }

  /// Local search within current notebook
  Future<List<Entry>> searchEntries(String query) async {
    if (_currentNotebookId == null || query.isEmpty) {
      return [];
    }
    return await _db.localSearch(_currentNotebookId!, query);
  }
}
