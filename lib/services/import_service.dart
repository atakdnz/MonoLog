import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/notebook.dart';
import '../models/entry.dart';
import '../models/folder.dart';

class ImportService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Import data from a ZIP file
  /// [merge] - If true, merge with existing data. If false, replace all data.
  Future<bool> importData({required bool merge}) async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return false;

      final filePath = result.files.first.path;
      if (filePath == null) return false;

      // Read ZIP file
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find data.json
      final dataFile = archive.files.firstWhere(
        (f) => f.name == 'data.json',
        orElse: () => throw Exception('Invalid backup: data.json not found'),
      );

      // Parse JSON
      final jsonString = utf8.decode(dataFile.content as List<int>);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Get images directory
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Extract images
      final imageMap = <String, String>{}; // archive filename -> local path
      for (final file in archive.files) {
        if (file.name.startsWith('images/') && !file.isFile) continue;
        if (file.name.startsWith('images/') && file.isFile) {
          final imageFilename = p.basename(file.name);
          final localFilename =
              '${DateTime.now().millisecondsSinceEpoch}_$imageFilename';
          final localPath = p.join(imagesDir.path, localFilename);

          final imageFile = File(localPath);
          await imageFile.writeAsBytes(file.content as List<int>);

          imageMap[imageFilename] = localPath;
        }
      }

      // Import notebooks and entries
      final notebooksJson = jsonData['notebooks'] as List;
      final foldersJson = jsonData['folders'] as List?;

      // Import folders first
      final folderIdMap = <String, String>{}; // old id -> new id
      if (foldersJson != null) {
        for (final folderJson in foldersJson) {
          final folderData = folderJson as Map<String, dynamic>;
          final folder = Folder.fromJson(folderData);

          final exists = await _db.getFolder(folder.id) != null;
          if (exists && merge) {
            folderIdMap[folder.id] = folder.id;
            continue;
          }

          await _db.insertFolder(folder);
          folderIdMap[folder.id] = folder.id;
        }
      }

      for (final notebookJson in notebooksJson) {
        final notebookData = notebookJson as Map<String, dynamic>;
        final notebook = Notebook.fromJson(notebookData);

        // Map folder_id if it exists
        String? mappedFolderId = notebook.folderId;
        if (mappedFolderId != null && folderIdMap.containsKey(mappedFolderId)) {
          mappedFolderId = folderIdMap[mappedFolderId];
        }

        // Check if notebook exists
        final exists = await _db.notebookExists(notebook.id);

        if (exists && merge) {
          // Skip existing notebook in merge mode
          continue;
        } else if (exists && !merge) {
          // Delete existing notebook in replace mode
          await _db.permanentlyDeleteNotebook(notebook.id);
        }

        // Insert notebook with mapped folder_id
        final notebookToInsert = mappedFolderId != null
            ? notebook.copyWith(folderId: mappedFolderId)
            : notebook;
        await _db.insertNotebook(notebookToInsert);

        // Import entries
        final entriesJson = notebookData['entries'] as List?;
        if (entriesJson != null) {
          for (final entryJson in entriesJson) {
            final entryData = entryJson as Map<String, dynamic>;

            // Handle image path
            String? imagePath;
            final imageFilename = entryData['image_filename'] as String?;
            if (imageFilename != null && imageMap.containsKey(imageFilename)) {
              imagePath = imageMap[imageFilename];
            }
            String? annotationBaseImagePath;
            final annotationBaseImageFilename =
                entryData['annotation_base_image_filename'] as String?;
            if (annotationBaseImageFilename != null &&
                imageMap.containsKey(annotationBaseImageFilename)) {
              annotationBaseImagePath = imageMap[annotationBaseImageFilename];
            }

            final entry = Entry(
              id: entryData['id'] as String,
              notebookId: notebook.id,
              content: entryData['content'] as String?,
              imagePath: imagePath,
              annotationBaseImagePath: annotationBaseImagePath,
              annotationStrokes: entryData['annotation_strokes'] as String?,
              displayTime: DateTime.parse(entryData['display_time'] as String),
              createdAt: DateTime.parse(entryData['created_at'] as String),
              isStarred: entryData['is_starred'] as bool? ?? false,
            );

            // Check if entry exists
            final entryExists = await _db.entryExists(entry.id);
            if (!entryExists) {
              await _db.insertEntry(entry);
            }
          }
        }
      }

      return true;
    } catch (e) {
      print('Import failed: $e');
      return false;
    }
  }

  /// Import a single notebook from ZIP as a new notebook
  /// Used from Settings - creates a new notebook from the imported data
  Future<bool> importSingleNotebookAsNew() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return false;

      final filePath = result.files.first.path;
      if (filePath == null) return false;

      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final dataFile = archive.files.firstWhere(
        (f) => f.name == 'data.json',
        orElse: () => throw Exception('Invalid backup: data.json not found'),
      );

      final jsonString = utf8.decode(dataFile.content as List<int>);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Extract images
      final imageMap = <String, String>{};
      for (final file in archive.files) {
        if (file.name.startsWith('images/') && file.isFile) {
          final imageFilename = p.basename(file.name);
          final localFilename =
              '${DateTime.now().millisecondsSinceEpoch}_$imageFilename';
          final localPath = p.join(imagesDir.path, localFilename);

          final imageFile = File(localPath);
          await imageFile.writeAsBytes(file.content as List<int>);
          imageMap[imageFilename] = localPath;
        }
      }

      final notebooksJson = jsonData['notebooks'] as List;
      if (notebooksJson.isEmpty) return false;

      // Import the first notebook (single notebook export only has one)
      final notebookData = notebooksJson.first as Map<String, dynamic>;
      final originalNotebook = Notebook.fromJson(notebookData);

      // Create a new notebook with new ID to avoid conflicts
      final newNotebook = Notebook(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${originalNotebook.title} (Imported)',
        color: originalNotebook.color,
        entryStyle: originalNotebook.entryStyle,
        isPinned: false,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.insertNotebook(newNotebook);

      // Import entries with new notebook ID
      final entriesJson = notebookData['entries'] as List?;
      if (entriesJson != null) {
        for (final entryJson in entriesJson) {
          final entryData = entryJson as Map<String, dynamic>;

          String? imagePath;
          final imageFilename = entryData['image_filename'] as String?;
          if (imageFilename != null && imageMap.containsKey(imageFilename)) {
            imagePath = imageMap[imageFilename];
          }
          String? annotationBaseImagePath;
          final annotationBaseImageFilename =
              entryData['annotation_base_image_filename'] as String?;
          if (annotationBaseImageFilename != null &&
              imageMap.containsKey(annotationBaseImageFilename)) {
            annotationBaseImagePath = imageMap[annotationBaseImageFilename];
          }

          final entry = Entry(
            id: '${DateTime.now().millisecondsSinceEpoch}_${entryData['id']}',
            notebookId: newNotebook.id, // Use new notebook ID
            content: entryData['content'] as String?,
            imagePath: imagePath,
            annotationBaseImagePath: annotationBaseImagePath,
            annotationStrokes: entryData['annotation_strokes'] as String?,
            displayTime: DateTime.parse(entryData['display_time'] as String),
            createdAt: DateTime.parse(entryData['created_at'] as String),
            isStarred: entryData['is_starred'] as bool? ?? false,
          );

          await _db.insertEntry(entry);
        }
      }

      return true;
    } catch (e) {
      print('Import single notebook failed: $e');
      return false;
    }
  }

  /// Import entries from ZIP and merge into an existing notebook
  /// Used from inside a notebook - merges entries into current notebook
  Future<bool> importMergeIntoNotebook(String targetNotebookId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return false;

      final filePath = result.files.first.path;
      if (filePath == null) return false;

      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final dataFile = archive.files.firstWhere(
        (f) => f.name == 'data.json',
        orElse: () => throw Exception('Invalid backup: data.json not found'),
      );

      final jsonString = utf8.decode(dataFile.content as List<int>);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Extract images
      final imageMap = <String, String>{};
      for (final file in archive.files) {
        if (file.name.startsWith('images/') && file.isFile) {
          final imageFilename = p.basename(file.name);
          final localFilename =
              '${DateTime.now().millisecondsSinceEpoch}_$imageFilename';
          final localPath = p.join(imagesDir.path, localFilename);

          final imageFile = File(localPath);
          await imageFile.writeAsBytes(file.content as List<int>);
          imageMap[imageFilename] = localPath;
        }
      }

      final notebooksJson = jsonData['notebooks'] as List;
      if (notebooksJson.isEmpty) return false;

      // Merge entries from all notebooks in the ZIP into target notebook
      int importedCount = 0;
      for (final notebookJson in notebooksJson) {
        final notebookData = notebookJson as Map<String, dynamic>;
        final entriesJson = notebookData['entries'] as List?;

        if (entriesJson != null) {
          for (final entryJson in entriesJson) {
            final entryData = entryJson as Map<String, dynamic>;

            String? imagePath;
            final imageFilename = entryData['image_filename'] as String?;
            if (imageFilename != null && imageMap.containsKey(imageFilename)) {
              imagePath = imageMap[imageFilename];
            }
            String? annotationBaseImagePath;
            final annotationBaseImageFilename =
                entryData['annotation_base_image_filename'] as String?;
            if (annotationBaseImageFilename != null &&
                imageMap.containsKey(annotationBaseImageFilename)) {
              annotationBaseImagePath = imageMap[annotationBaseImageFilename];
            }

            // Create entry with new ID to avoid conflicts
            final entry = Entry(
              id: '${DateTime.now().millisecondsSinceEpoch}_${importedCount}_${entryData['id']}',
              notebookId: targetNotebookId, // Use target notebook ID
              content: entryData['content'] as String?,
              imagePath: imagePath,
              annotationBaseImagePath: annotationBaseImagePath,
              annotationStrokes: entryData['annotation_strokes'] as String?,
              displayTime: DateTime.parse(entryData['display_time'] as String),
              createdAt: DateTime.parse(entryData['created_at'] as String),
              isStarred: entryData['is_starred'] as bool? ?? false,
            );

            await _db.insertEntry(entry);
            importedCount++;
          }
        }
      }

      return importedCount > 0;
    } catch (e) {
      print('Import merge failed: $e');
      return false;
    }
  }
}
