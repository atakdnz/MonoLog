import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/notebook.dart';
import '../models/entry.dart';
import '../utils/constants.dart';

class ExportService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Export all data to a ZIP file
  Future<String?> exportAllData() async {
    try {
      final data = await _db.getAllDataForExport();
      return await _createExportZip(data);
    } catch (e) {
      print('Export failed: $e');
      return null;
    }
  }

  /// Export a single notebook to a ZIP file
  Future<String?> exportNotebook(String notebookId) async {
    try {
      final data = await _db.getNotebookDataForExport(notebookId);
      if (data == null) return null;
      return await _createExportZip([data]);
    } catch (e) {
      print('Export failed: $e');
      return null;
    }
  }

  Future<String?> _createExportZip(
    List<Map<String, dynamic>> notebooksData,
  ) async {
    try {
      final archive = Archive();
      final imagesToInclude =
          <String, String>{}; // original path -> archive filename

      // Build notebooks JSON
      final notebooks = <Map<String, dynamic>>[];

      for (final notebookData in notebooksData) {
        final notebook = Notebook.fromMap(notebookData);
        final entriesData = notebookData['entries'] as List;

        final entries = <Map<String, dynamic>>[];
        for (final entryData in entriesData) {
          final entry = Entry.fromMap(entryData as Map<String, dynamic>);
          final entryJson = entry.toJson();

          // Handle image
          if (entry.hasImage) {
            final imageFile = File(entry.imagePath!);
            if (await imageFile.exists()) {
              final imageFilename =
                  'image_${imagesToInclude.length + 1}${p.extension(entry.imagePath!)}';
              imagesToInclude[entry.imagePath!] = imageFilename;
              entryJson['image_filename'] = imageFilename;
            }
          }

          entries.add(entryJson);
        }

        final notebookJson = notebook.toJson();
        notebookJson['entries'] = entries;
        notebooks.add(notebookJson);
      }

      // Create JSON data
      final jsonData = {
        'app_version': appVersion,
        'export_date': DateTime.now().toIso8601String(),
        'notebooks': notebooks,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      final jsonBytes = utf8.encode(jsonString);

      // Add JSON to archive
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

      // Add images to archive
      for (final entry in imagesToInclude.entries) {
        final imageFile = File(entry.key);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          archive.addFile(
            ArchiveFile('images/${entry.value}', imageBytes.length, imageBytes),
          );
        }
      }

      // Encode archive
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return null;

      // Save to file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final zipPath = p.join(tempDir.path, 'monolog_backup_$timestamp.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      return zipPath;
    } catch (e) {
      print('Error creating ZIP: $e');
      return null;
    }
  }

  /// Share the exported file
  Future<void> shareExport(String filePath) async {
    await Share.shareXFiles([XFile(filePath)], subject: 'MonoLog Backup');
  }
}
