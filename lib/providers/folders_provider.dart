import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/folder.dart';
import '../models/notebook.dart';

class FoldersProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Folder> _folders = [];
  String? _selectedFolderId;
  bool _isLoading = false;

  List<Folder> get folders => _folders;
  String? get selectedFolderId => _selectedFolderId;
  bool get isLoading => _isLoading;
  bool get isShowingAll => _selectedFolderId == null;

  Future<void> loadFolders() async {
    _isLoading = true;
    notifyListeners();

    try {
      _folders = await _db.getFolders();
    } catch (e) {
      debugPrint('Error loading folders: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectFolder(String? folderId) {
    _selectedFolderId = folderId;
    notifyListeners();
  }

  Future<Folder> createFolder({required String name}) async {
    final folder = Folder(name: name, sortOrder: _folders.length);
    await _db.insertFolder(folder);
    await loadFolders();
    return folder;
  }

  Future<void> updateFolder(Folder folder) async {
    await _db.updateFolder(folder);
    await loadFolders();
  }

  Future<void> deleteFolder(String id) async {
    await _db.deleteFolder(id);
    if (_selectedFolderId == id) {
      _selectedFolderId = null;
    }
    await loadFolders();
  }

  Future<void> reorderFolders(List<Folder> list, int oldIndex, int newIndex) async {
    final Folder item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    notifyListeners();

    final futures = <Future>[];
    for (int i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) {
        list[i] = list[i].copyWith(sortOrder: i);
        futures.add(_db.updateFolderSortOrder(list[i].id, i));
      }
    }

    await Future.wait(futures);
    await loadFolders();
  }

  Future<void> moveNotebookToFolder(String notebookId, String? folderId) async {
    await _db.moveNotebookToFolder(notebookId, folderId);
    await loadFolders();
  }

  Future<List<Notebook>> getNotebooksInFolder(String folderId) async {
    return await _db.getNotebooksInFolder(folderId);
  }

  Future<List<Notebook>> getPinnedNotebooksInFolder(String folderId) async {
    return await _db.getPinnedNotebooksInFolder(folderId);
  }

  Future<List<Notebook>> getRegularNotebooksInFolder(String folderId) async {
    return await _db.getRegularNotebooksInFolder(folderId);
  }

  Future<List<Notebook>> getArchivedNotebooksInFolder(String folderId) async {
    return await _db.getArchivedNotebooksInFolder(folderId);
  }

  Future<int> getNotebookCountInFolder(String folderId) async {
    return await _db.getNotebookCountInFolder(folderId);
  }
}
