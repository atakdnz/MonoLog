import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/entry.dart';

class TrashProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Entry> _trashEntries = [];
  bool _isLoading = false;

  List<Entry> get trashEntries => _trashEntries;
  bool get isLoading => _isLoading;

  /// Load all trash entries
  Future<void> loadTrash() async {
    _isLoading = true;
    notifyListeners();

    try {
      // First, cleanup old entries
      await _db.cleanupOldTrash();
      // Then load remaining trash
      _trashEntries = await _db.getTrashEntries();
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

  /// Permanently delete an entry
  Future<void> permanentlyDeleteEntry(String id) async {
    await _db.permanentlyDeleteEntry(id);
    await loadTrash();
  }

  /// Empty all trash
  Future<void> emptyTrash() async {
    await _db.emptyTrash();
    await loadTrash();
  }
}
