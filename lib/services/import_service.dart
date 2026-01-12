import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/notebook.dart';
import '../models/entry.dart';

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

      for (final notebookJson in notebooksJson) {
        final notebookData = notebookJson as Map<String, dynamic>;
        final notebook = Notebook.fromJson(notebookData);

        // Check if notebook exists
        final exists = await _db.notebookExists(notebook.id);

        if (exists && merge) {
          // Skip existing notebook in merge mode
          continue;
        } else if (exists && !merge) {
          // Delete existing notebook in replace mode
          await _db.permanentlyDeleteNotebook(notebook.id);
        }

        // Insert notebook
        await _db.insertNotebook(notebook);

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

            final entry = Entry(
              id: entryData['id'] as String,
              notebookId: notebook.id,
              content: entryData['content'] as String?,
              imagePath: imagePath,
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
}
