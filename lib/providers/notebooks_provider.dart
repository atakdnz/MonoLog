import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/notebook.dart';
import '../models/entry.dart';
import '../utils/constants.dart';

class NotebooksProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Notebook> _pinnedNotebooks = [];
  List<Notebook> _regularNotebooks = [];
  List<Notebook> _archivedNotebooks = [];
  bool _isLoading = false;
  bool _showArchived = false;

  List<Notebook> get pinnedNotebooks => _pinnedNotebooks;
  List<Notebook> get regularNotebooks => _regularNotebooks;
  List<Notebook> get archivedNotebooks => _archivedNotebooks;
  bool get isLoading => _isLoading;
  bool get showArchived => _showArchived;

  /// Toggle archived section visibility
  void toggleShowArchived() {
    _showArchived = !_showArchived;
    notifyListeners();
  }

  /// Load all notebooks from database
  Future<void> loadNotebooks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pinnedNotebooks = await _db.getPinnedNotebooks();
      _regularNotebooks = await _db.getRegularNotebooks();
      _archivedNotebooks = await _db.getArchivedNotebooks();
    } catch (e) {
      debugPrint('Error loading notebooks: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new notebook
  Future<Notebook> createNotebook({
    required String title,
    required String color,
    String entryStyle = NotebookEntryStyles.chat,
  }) async {
    final notebook = Notebook(
      title: title,
      color: color,
      entryStyle: entryStyle,
    );
    await _db.insertNotebook(notebook);
    await loadNotebooks();
    return notebook;
  }

  /// Update a notebook
  Future<void> updateNotebook(Notebook notebook) async {
    await _db.updateNotebook(notebook);
    await loadNotebooks();
  }

  /// Delete a notebook (move to trash)
  Future<void> deleteNotebook(String id) async {
    await _db.softDeleteNotebook(id);
    await loadNotebooks();
  }

  /// Toggle notebook pin status
  Future<void> togglePin(String id) async {
    await _db.toggleNotebookPin(id);
    await loadNotebooks();
  }

  /// Toggle notebook archive status
  Future<void> toggleArchive(String id) async {
    await _db.toggleNotebookArchive(id);
    await loadNotebooks();
  }

  /// Get notebook by ID
  Future<Notebook?> getNotebook(String id) async {
    return await _db.getNotebook(id);
  }

  /// Get preview entry for a notebook
  Future<Entry?> getPreviewEntry(String notebookId) async {
    return await _db.getMostRecentEntry(notebookId);
  }
}
