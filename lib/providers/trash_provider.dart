import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/entry.dart';
import '../models/notebook.dart';

class TrashProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Entry> _trashEntries = [];
  List<Notebook> _trashNotebooks = [];
  bool _isLoading = false;

  List<Entry> get trashEntries => _trashEntries;
  List<Notebook> get trashNotebooks => _trashNotebooks;
  bool get isLoading => _isLoading;

  int get totalTrashCount => _trashEntries.length + _trashNotebooks.length;
  bool get isEmpty => totalTrashCount == 0;

  /// Load all trash items (entries and notebooks)
  Future<void> loadTrash() async {
    _isLoading = true;
    notifyListeners();

    try {
      // First, cleanup old items
      await _db.cleanupOldTrash();
      // Then load remaining trash
      _trashEntries = await _db.getTrashEntries();
      _trashNotebooks = await _db.getDeletedNotebooks();
    } catch (e) {
      debugPrint('Error loading trash: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Restore an entry from trash
  Future<void> restoreEntry(String id) async {
    await _db.restoreEntry(id);
    await loadTrash();
  }

  /// Restore a notebook from trash
  Future<void> restoreNotebook(String id) async {
    await _db.restoreNotebook(id);
    await loadTrash();
  }

  /// Permanently delete an entry
  Future<void> permanentlyDeleteEntry(String id) async {
    await _db.permanentlyDeleteEntry(id);
    await loadTrash();
  }

  /// Permanently delete a notebook and all its entries
  Future<void> permanentlyDeleteNotebook(String id) async {
    await _db.permanentlyDeleteNotebook(id);
    await loadTrash();
  }

  /// Empty all trash
  Future<void> emptyTrash() async {
    await _db.emptyTrash();
    await loadTrash();
  }
}
