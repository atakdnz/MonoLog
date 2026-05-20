import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/annotation_stroke.dart';
import 'annotation_metadata_service.dart';

class SavedImage {
  final String imagePath;
  final String? annotationBaseImagePath;
  final String? annotationStrokes;

  const SavedImage({
    required this.imagePath,
    this.annotationBaseImagePath,
    this.annotationStrokes,
  });
}

class SavedAudio {
  final String audioPath;
  final int durationMs;

  const SavedAudio({required this.audioPath, required this.durationMs});
}

class MediaStorageService {
  Future<SavedImage?> saveImage(
    String sourcePath, {
    String? annotationBaseImagePath,
    String? annotationStrokes,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
      final destPath = p.join(imagesDir.path, fileName);
      await File(sourcePath).copy(destPath);

      var savedBaseImagePath = annotationBaseImagePath;
      var savedStrokes = annotationStrokes;

      final metadata = await AnnotationMetadataService.readMetadata(sourcePath);
      if (metadata != null && savedStrokes == null) {
        savedBaseImagePath = metadata.baseImagePath;
        savedStrokes = AnnotationMetadataService.encodeStrokes(
          metadata.strokes,
        );
      }

      if (savedStrokes != null) {
        String? baseImagePath = savedBaseImagePath;
        if (baseImagePath != null && await File(baseImagePath).exists()) {
          if (!p.isWithin(imagesDir.path, baseImagePath)) {
            final baseFileName =
                '${DateTime.now().millisecondsSinceEpoch}_base_${p.basename(baseImagePath)}';
            final baseDestPath = p.join(imagesDir.path, baseFileName);
            await File(baseImagePath).copy(baseDestPath);
            baseImagePath = baseDestPath;
          }
        }

        await AnnotationMetadataService.writeMetadata(
          imagePath: destPath,
          baseImagePath: baseImagePath,
          strokes: AnnotationMetadataService.decodeStrokes(savedStrokes),
        );
        savedBaseImagePath = baseImagePath;
      }

      return SavedImage(
        imagePath: destPath,
        annotationBaseImagePath: savedBaseImagePath,
        annotationStrokes: savedStrokes,
      );
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }

  Future<SavedImage?> saveDrawingResult({
    required String imagePath,
    String? annotationBaseImagePath,
    required List<AnnotationStroke> strokes,
  }) {
    return saveImage(
      imagePath,
      annotationBaseImagePath: annotationBaseImagePath,
      annotationStrokes: AnnotationMetadataService.encodeStrokes(strokes),
    );
  }

  Future<SavedAudio?> saveAudio(String sourcePath, Duration duration) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(p.join(appDir.path, 'audio'));
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final sourceExt = p.extension(sourcePath).isEmpty
          ? '.m4a'
          : p.extension(sourcePath);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(sourcePath)}$sourceExt';
      final destPath = p.join(audioDir.path, fileName);
      await File(sourcePath).copy(destPath);

      return SavedAudio(
        audioPath: destPath,
        durationMs: duration.inMilliseconds,
      );
    } catch (e) {
      debugPrint('Error saving audio: $e');
      return null;
    }
  }
}
