import 'package:flutter/material.dart';

class AnnotationStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  const AnnotationStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  bool hitTest(Offset point, double eraserWidth) {
    if (points.isEmpty) return false;
    final radius = width + eraserWidth;

    for (var i = 0; i < points.length; i++) {
      if ((points[i] - point).distance <= radius) return true;
      if (i > 0 &&
          _distanceToSegment(point, points[i - 1], points[i]) <= radius) {
        return true;
      }
    }

    return false;
  }

  List<AnnotationStroke> eraseAt(Offset point, double eraserWidth) {
    if (points.isEmpty) return const [];

    final segments = <AnnotationStroke>[];
    var current = <Offset>[];

    for (final strokePoint in points) {
      final shouldErase = (strokePoint - point).distance <= eraserWidth;
      if (shouldErase) {
        if (current.length > 1) {
          segments.add(
            AnnotationStroke(points: current, color: color, width: width),
          );
        }
        current = [];
      } else {
        current.add(strokePoint);
      }
    }

    if (current.length > 1) {
      segments.add(
        AnnotationStroke(points: current, color: color, width: width),
      );
    }

    return segments;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) return (point - start).distance;

    final t =
        (((point.dx - start.dx) * segment.dx) +
            ((point.dy - start.dy) * segment.dy)) /
        lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(
      start.dx + segment.dx * clamped,
      start.dy + segment.dy * clamped,
    );
    return (point - projection).distance;
  }
}
