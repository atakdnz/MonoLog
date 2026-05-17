import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/notebook.dart';
import '../models/entry.dart';
import '../utils/constants.dart';

enum NotebookOrder {
  custom,
  lastEdited,
  newestCreated,
  oldestCreated,
  titleAsc,
  titleDesc,
}

extension NotebookOrderLabel on NotebookOrder {
  String get label {
    switch (this) {
      case NotebookOrder.custom:
        return 'Custom';
      case NotebookOrder.lastEdited:
        return 'Last edited';
      case NotebookOrder.newestCreated:
        return 'Newest';
      case NotebookOrder.oldestCreated:
        return 'Oldest';
      case NotebookOrder.titleAsc:
        return 'A to Z';
      case NotebookOrder.titleDesc:
        return 'Z to A';
    }
  }
}

class NotebooksProvider with ChangeNotifier {
  static const String _orderKey = 'notebook_order';
  final DatabaseHelper _db = DatabaseHelper();

  List<Notebook> _pinnedNotebooks = [];
  List<Notebook> _regularNotebooks = [];
  List<Notebook> _archivedNotebooks = [];
  final Map<String, DateTime> _activityTimes = {};
  NotebookOrder _order = NotebookOrder.custom;
  String? _folderId;
  bool _isLoading = false;
  bool _showArchived = false;

  List<Notebook> get pinnedNotebooks => _orderedNotebooks(_pinnedNotebooks);
  List<Notebook> get regularNotebooks => _orderedNotebooks(_regularNotebooks);
  List<Notebook> get archivedNotebooks => _orderedNotebooks(_archivedNotebooks);
  NotebookOrder get order => _order;
  bool get isCustomOrder => _order == NotebookOrder.custom;
  String? get folderId => _folderId;
  bool get isLoading => _isLoading;
  bool get showArchived => _showArchived;

  NotebooksProvider() {
    _loadOrder();
  }

  void setFolderId(String? folderId) {
    _folderId = folderId;
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_orderKey);
    if (index == null || index < 0 || index >= NotebookOrder.values.length) {
      return;
    }
    _order = NotebookOrder.values[index];
    notifyListeners();
  }

  Future<void> setOrder(NotebookOrder order) async {
    if (_order == order) return;
    _order = order;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_orderKey, order.index);
    notifyListeners();
  }

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
      _pinnedNotebooks = await _db.getPinnedNotebooks(folderId: _folderId);
      _regularNotebooks = await _db.getRegularNotebooks(folderId: _folderId);
      _archivedNotebooks = await _db.getArchivedNotebooks(folderId: _folderId);
      await _loadActivityTimes([
        ..._pinnedNotebooks,
        ..._regularNotebooks,
        ..._archivedNotebooks,
      ]);
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

  /// Toggle notebook lock status
  Future<void> toggleLock(String id) async {
    await _db.toggleNotebookLock(id);
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

  Future<DateTime?> getActivityTime(Notebook notebook) async {
    return await _db.getNotebookActivityTime(notebook);
  }

  /// Reorder notebooks
  Future<void> reorderNotebooks(
    List<Notebook> list,
    int oldIndex,
    int newIndex,
  ) async {
    if (!isCustomOrder) {
      return;
    }
    final Notebook item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Update state optimistically
    notifyListeners();

    final futures = <Future>[];
    // Save to database and update objects in memory
    for (int i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) {
        list[i] = list[i].copyWith(sortOrder: i);
        futures.add(_db.updateNotebookSortOrder(list[i].id, i));
      }
    }

    await Future.wait(futures);

    // Reload fully in background to sync
    _pinnedNotebooks = await _db.getPinnedNotebooks(folderId: _folderId);
    _regularNotebooks = await _db.getRegularNotebooks(folderId: _folderId);
    _archivedNotebooks = await _db.getArchivedNotebooks(folderId: _folderId);
    await _loadActivityTimes([
      ..._pinnedNotebooks,
      ..._regularNotebooks,
      ..._archivedNotebooks,
    ]);
    notifyListeners();
  }

  Future<void> _loadActivityTimes(List<Notebook> notebooks) async {
    _activityTimes.clear();
    final results = await Future.wait(
      notebooks.map((notebook) async {
        return MapEntry(
          notebook.id,
          await _db.getNotebookActivityTime(notebook),
        );
      }),
    );
    for (final result in results) {
      final activityTime = result.value;
      if (activityTime != null) {
        _activityTimes[result.key] = activityTime;
      }
    }
  }

  List<Notebook> _orderedNotebooks(List<Notebook> notebooks) {
    if (_order == NotebookOrder.custom) {
      return notebooks;
    }

    final sorted = [...notebooks];
    sorted.sort((a, b) {
      switch (_order) {
        case NotebookOrder.custom:
          return 0;
        case NotebookOrder.lastEdited:
          final aTime = _activityTimes[a.id] ?? a.createdAt;
          final bTime = _activityTimes[b.id] ?? b.createdAt;
          return bTime.compareTo(aTime);
        case NotebookOrder.newestCreated:
          return b.createdAt.compareTo(a.createdAt);
        case NotebookOrder.oldestCreated:
          return a.createdAt.compareTo(b.createdAt);
        case NotebookOrder.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case NotebookOrder.titleDesc:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
      }
    });
    return sorted;
  }
}
