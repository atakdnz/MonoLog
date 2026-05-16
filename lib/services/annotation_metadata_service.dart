import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/annotation_stroke.dart';

class AnnotationMetadataService {
  static String metadataPathForImage(String imagePath) {
    return '$imagePath.annotation.json';
  }

  static Future<void> writeMetadata({
    required String imagePath,
    required String? baseImagePath,
    required List<AnnotationStroke> strokes,
  }) async {
    final metadata = {
      'version': 1,
      'base_image_path': baseImagePath,
      'strokes': strokes.map(_strokeToJson).toList(),
    };

    final file = File(metadataPathForImage(imagePath));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata),
    );
  }

  static String encodeStrokes(List<AnnotationStroke> strokes) {
    return json.encode(strokes.map(_strokeToJson).toList());
  }

  static List<AnnotationStroke> decodeStrokes(String? strokesJson) {
    if (strokesJson == null || strokesJson.isEmpty) return const [];

    try {
      final decoded = json.decode(strokesJson);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_strokeFromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<ImageAnnotationMetadata?> readMetadata(String imagePath) async {
    final file = File(metadataPathForImage(imagePath));
    if (!await file.exists()) return null;

    try {
      final jsonData = json.decode(await file.readAsString());
      if (jsonData is! Map<String, dynamic>) return null;

      final strokesJson = jsonData['strokes'];
      if (strokesJson is! List) return null;

      return ImageAnnotationMetadata(
        baseImagePath: jsonData['base_image_path'] as String?,
        strokes: strokesJson
            .whereType<Map<String, dynamic>>()
            .map(_strokeFromJson)
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> copyMetadata({
    required String sourceImagePath,
    required String destinationImagePath,
  }) async {
    final sourceMetadata = File(metadataPathForImage(sourceImagePath));
    if (!await sourceMetadata.exists()) return;

    final metadata = await readMetadata(sourceImagePath);
    if (metadata == null) return;

    var baseImagePath = metadata.baseImagePath;
    if (baseImagePath != null && p.equals(baseImagePath, sourceImagePath)) {
      baseImagePath = destinationImagePath;
    }

    await writeMetadata(
      imagePath: destinationImagePath,
      baseImagePath: baseImagePath,
      strokes: metadata.strokes,
    );
  }

  static Map<String, dynamic> _strokeToJson(AnnotationStroke stroke) {
    return {
      'color': stroke.color.toARGB32(),
      'width': stroke.width,
      'points': stroke.points
          .map((point) => {'x': point.dx, 'y': point.dy})
          .toList(),
    };
  }

  static AnnotationStroke _strokeFromJson(Map<String, dynamic> json) {
    final pointsJson = json['points'];
    return AnnotationStroke(
      color: Color((json['color'] as num).toInt()),
      width: (json['width'] as num).toDouble(),
      points: pointsJson is List
          ? pointsJson.whereType<Map<String, dynamic>>().map((point) {
              return Offset(
                (point['x'] as num).toDouble(),
                (point['y'] as num).toDouble(),
              );
            }).toList()
          : const [],
    );
  }
}

class ImageAnnotationMetadata {
  final String? baseImagePath;
  final List<AnnotationStroke> strokes;

  const ImageAnnotationMetadata({
    required this.baseImagePath,
    required this.strokes,
  });
}
