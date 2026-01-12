import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/entry.dart';

class SearchProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  String _query = '';
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  String get query => _query;
  List<Map<String, dynamic>> get results => _results;
  bool get isSearching => _isSearching;

  /// Global search across all notebooks
  Future<void> search(String searchQuery) async {
    _query = searchQuery;

    if (searchQuery.isEmpty) {
      _results = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _results = await _db.globalSearch(searchQuery);
    } catch (e) {
      debugPrint('Error searching: $e');
      _results = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Clear search
  void clearSearch() {
    _query = '';
    _results = [];
    notifyListeners();
  }

  /// Get Entry from search result
  Entry getEntryFromResult(Map<String, dynamic> result) {
    return Entry.fromMap(result);
  }

  /// Get notebook title from search result
  String getNotebookTitle(Map<String, dynamic> result) {
    return result['notebook_title'] as String? ?? 'Unknown';
  }

  /// Get notebook color from search result
  String getNotebookColor(Map<String, dynamic> result) {
    return result['notebook_color'] as String? ?? '#6366F1';
  }
}
