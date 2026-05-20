import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/notebook.dart';
import '../models/entry.dart';
import '../models/folder.dart';
import 'backup_encryption_service.dart';

enum ImportDataResult {
  success,
  cancelled,
  failed,
  passwordRequired,
  invalidPassword,
}

class ImportService {
  final DatabaseHelper _db = DatabaseHelper();
  final BackupEncryptionService _encryptionService = BackupEncryptionService();

  /// Import data from a ZIP file
  /// [merge] - If true, merge with existing data. If false, replace all data.
  Future<ImportDataResult> importData({
    required bool merge,
    Future<String?> Function()? encryptedPasswordProvider,
  }) async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.isEmpty) {
        return ImportDataResult.cancelled;
      }

      final filePath = result.files.first.path;
      if (filePath == null) return ImportDataResult.cancelled;

      final bytes = await File(filePath).readAsBytes();
      final extension = p.extension(filePath).toLowerCase();
      final isEncrypted =
          BackupEncryptionService.isEncryptedBackup(bytes) ||
          extension == BackupEncryptionService.fileExtension;

      if (!isEncrypted && extension != '.zip') {
        return ImportDataResult.failed;
      }

      List<int> zipBytes = bytes;
      if (isEncrypted) {
        if (encryptedPasswordProvider == null) {
          return ImportDataResult.passwordRequired;
        }

        final password = await encryptedPasswordProvider();
        if (password == null) return ImportDataResult.cancelled;

        try {
          zipBytes = await _encryptionService.decryptZipBytes(
            bytes,
            password: password,
          );
        } on BackupEncryptionException {
          return ImportDataResult.invalidPassword;
        }
      }

      final archive = ZipDecoder().decodeBytes(zipBytes);
      await _importFullArchive(archive, merge: merge);

      return ImportDataResult.success;
    } catch (e) {
      debugPrint('Import failed: $e');
      return ImportDataResult.failed;
    }
  }

  Future<void> _importFullArchive(
    Archive archive, {
    required bool merge,
  }) async {
    final jsonData = _readArchiveJson(archive);
    final imageMap = await _extractImages(archive);
    final audioMap = await _extractAudio(archive);

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
          String? audioPath;
          final audioFilename = entryData['audio_filename'] as String?;
          if (audioFilename != null && audioMap.containsKey(audioFilename)) {
            audioPath = audioMap[audioFilename];
          }

          final entry = Entry(
            id: entryData['id'] as String,
            notebookId: notebook.id,
            content: entryData['content'] as String?,
            imagePath: imagePath,
            annotationBaseImagePath: annotationBaseImagePath,
            annotationStrokes: entryData['annotation_strokes'] as String?,
            audioPath: audioPath,
            audioDurationMs: entryData['audio_duration_ms'] as int?,
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
  }

  Map<String, dynamic> _readArchiveJson(Archive archive) {
    final dataFile = archive.files.firstWhere(
      (f) => f.name == 'data.json',
      orElse: () => throw Exception('Invalid backup: data.json not found'),
    );
    final jsonString = utf8.decode(dataFile.content as List<int>);
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  Future<Map<String, String>> _extractImages(Archive archive) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

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

    return imageMap;
  }

  Future<Map<String, String>> _extractAudio(Archive archive) async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(appDir.path, 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final audioMap = <String, String>{};
    for (final file in archive.files) {
      if (file.name.startsWith('audio/') && file.isFile) {
        final audioFilename = p.basename(file.name);
        final localFilename =
            '${DateTime.now().millisecondsSinceEpoch}_$audioFilename';
        final localPath = p.join(audioDir.path, localFilename);

        final audioFile = File(localPath);
        await audioFile.writeAsBytes(file.content as List<int>);
        audioMap[audioFilename] = localPath;
      }
    }

    return audioMap;
  }

  String _remapClassicMediaTokens(String content, Map<String, String> idMap) {
    final tokenPattern = RegExp(
      r'(?:!\[MonoLog Image\]\(monolog-entry:([^)]+)\)|\[MonoLog Voice\]\(monolog-entry:([^)]+)\))',
    );
    return content.replaceAllMapped(tokenPattern, (match) {
      final imageId = match.group(1);
      final audioId = match.group(2);
      if (imageId != null) {
        return '![MonoLog Image](monolog-entry:${idMap[imageId] ?? imageId})';
      }
      if (audioId != null) {
        return '[MonoLog Voice](monolog-entry:${idMap[audioId] ?? audioId})';
      }
      return match.group(0) ?? '';
    });
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

      final imageMap = await _extractImages(archive);
      final audioMap = await _extractAudio(archive);

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
        final idMap = <String, String>{};
        for (final entryJson in entriesJson) {
          final entryData = entryJson as Map<String, dynamic>;
          final oldId = entryData['id'] as String;
          idMap[oldId] = '${DateTime.now().millisecondsSinceEpoch}_$oldId';
        }

        for (final entryJson in entriesJson) {
          final entryData = entryJson as Map<String, dynamic>;
          final oldId = entryData['id'] as String;

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
          String? audioPath;
          final audioFilename = entryData['audio_filename'] as String?;
          if (audioFilename != null && audioMap.containsKey(audioFilename)) {
            audioPath = audioMap[audioFilename];
          }
          final content = entryData['content'] as String?;

          final entry = Entry(
            id: idMap[oldId],
            notebookId: newNotebook.id, // Use new notebook ID
            content: content == null
                ? null
                : _remapClassicMediaTokens(content, idMap),
            imagePath: imagePath,
            annotationBaseImagePath: annotationBaseImagePath,
            annotationStrokes: entryData['annotation_strokes'] as String?,
            audioPath: audioPath,
            audioDurationMs: entryData['audio_duration_ms'] as int?,
            displayTime: DateTime.parse(entryData['display_time'] as String),
            createdAt: DateTime.parse(entryData['created_at'] as String),
            isStarred: entryData['is_starred'] as bool? ?? false,
          );

          await _db.insertEntry(entry);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Import single notebook failed: $e');
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

      final imageMap = await _extractImages(archive);
      final audioMap = await _extractAudio(archive);

      final notebooksJson = jsonData['notebooks'] as List;
      if (notebooksJson.isEmpty) return false;

      // Merge entries from all notebooks in the ZIP into target notebook
      int importedCount = 0;
      for (final notebookJson in notebooksJson) {
        final notebookData = notebookJson as Map<String, dynamic>;
        final entriesJson = notebookData['entries'] as List?;

        if (entriesJson != null) {
          final idMap = <String, String>{};
          for (final entryJson in entriesJson) {
            final entryData = entryJson as Map<String, dynamic>;
            final oldId = entryData['id'] as String;
            idMap[oldId] =
                '${DateTime.now().millisecondsSinceEpoch}_${importedCount}_$oldId';
          }

          for (final entryJson in entriesJson) {
            final entryData = entryJson as Map<String, dynamic>;
            final oldId = entryData['id'] as String;

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
            String? audioPath;
            final audioFilename = entryData['audio_filename'] as String?;
            if (audioFilename != null && audioMap.containsKey(audioFilename)) {
              audioPath = audioMap[audioFilename];
            }
            final content = entryData['content'] as String?;

            // Create entry with new ID to avoid conflicts
            final entry = Entry(
              id: idMap[oldId],
              notebookId: targetNotebookId, // Use target notebook ID
              content: content == null
                  ? null
                  : _remapClassicMediaTokens(content, idMap),
              imagePath: imagePath,
              annotationBaseImagePath: annotationBaseImagePath,
              annotationStrokes: entryData['annotation_strokes'] as String?,
              audioPath: audioPath,
              audioDurationMs: entryData['audio_duration_ms'] as int?,
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
      debugPrint('Import merge failed: $e');
      return false;
    }
  }
}
