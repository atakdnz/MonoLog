import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/models/annotation_stroke.dart';

void main() {
  group('AnnotationStroke', () {
    test('should create a stroke with required fields', () {
      final points = [
        const Offset(0, 0),
        const Offset(10, 10),
        const Offset(20, 20),
      ];
      const color = Colors.red;
      const width = 5.0;

      final stroke = AnnotationStroke(
        points: points,
        color: color,
        width: width,
      );

      expect(stroke.points, points);
      expect(stroke.color, color);
      expect(stroke.width, width);
    });

    test('should create a stroke with empty points', () {
      final stroke = const AnnotationStroke(
        points: [],
        color: Colors.blue,
        width: 3.0,
      );

      expect(stroke.points, isEmpty);
      expect(stroke.color, Colors.blue);
      expect(stroke.width, 3.0);
    });

    group('hitTest', () {
      test('should return false when points are empty', () {
        final stroke = const AnnotationStroke(
          points: [],
          color: Colors.red,
          width: 5.0,
        );

        expect(stroke.hitTest(const Offset(0, 0), 10.0), false);
      });

      test('should return true when point matches a stroke point', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(10, 10),
            const Offset(20, 20),
          ],
          color: Colors.red,
          width: 5.0,
        );

        expect(stroke.hitTest(const Offset(10, 10), 0.0), true);
      });

      test('should return true when point is within radius of a stroke point', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(10, 10),
          ],
          color: Colors.red,
          width: 5.0,
        );

        expect(stroke.hitTest(const Offset(12, 12), 5.0), true);
      });

      test('should return false when point is far from all stroke points', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(10, 10),
          ],
          color: Colors.red,
          width: 5.0,
        );

        expect(stroke.hitTest(const Offset(100, 100), 5.0), false);
      });

      test('should return true when point is on line segment between points', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(100, 0),
          ],
          color: Colors.red,
          width: 5.0,
        );

        expect(stroke.hitTest(const Offset(50, 0), 2.0), true);
      });

      test('should return false when point is near but not on line segment', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(100, 0),
          ],
          color: Colors.red,
          width: 2.0,
        );

        expect(stroke.hitTest(const Offset(50, 50), 2.0), false);
      });
    });

    group('eraseAt', () {
      test('should return empty list when points are empty', () {
        final stroke = const AnnotationStroke(
          points: [],
          color: Colors.red,
          width: 5.0,
        );

        final result = stroke.eraseAt(const Offset(0, 0), 10.0);

        expect(result, isEmpty);
      });

      test('should return original stroke when no points are erased', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(10, 10),
            const Offset(20, 20),
          ],
          color: Colors.red,
          width: 5.0,
        );

        final result = stroke.eraseAt(const Offset(100, 100), 5.0);

        expect(result.length, 1);
        expect(result[0].points.length, 3);
        expect(result[0].color, Colors.red);
        expect(result[0].width, 5.0);
      });

      test('should split stroke when erasing middle point', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(10, 10),
            const Offset(20, 20),
            const Offset(30, 30),
            const Offset(40, 40),
          ],
          color: Colors.red,
          width: 5.0,
        );

        final result = stroke.eraseAt(const Offset(20, 20), 5.0);

        expect(result.length, 2);
        expect(result[0].points.length, 2);
        expect(result[1].points.length, 2);
        expect(result[0].color, Colors.red);
        expect(result[1].color, Colors.red);
      });

      test('should remove all points when erasing covers entire stroke', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(10, 10),
            const Offset(20, 20),
          ],
          color: Colors.red,
          width: 5.0,
        );

        final result = stroke.eraseAt(const Offset(10, 10), 20.0);

        expect(result, isEmpty);
      });

      test('should erase multiple points in a row', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(10, 10),
            const Offset(20, 20),
            const Offset(30, 30),
            const Offset(40, 40),
            const Offset(50, 50),
          ],
          color: Colors.red,
          width: 5.0,
        );

        final result = stroke.eraseAt(const Offset(25, 25), 20.0);

        expect(result.length, 2);
        expect(result[0].points, [const Offset(0, 0), const Offset(10, 10)]);
        expect(result[1].points, [const Offset(40, 40), const Offset(50, 50)]);
      });

      test('should preserve color and width in split strokes', () {
        final stroke = AnnotationStroke(
          points: [
            const Offset(0, 0),
            const Offset(10, 10),
            const Offset(20, 20),
            const Offset(30, 30),
            const Offset(40, 40),
          ],
          color: Colors.blue,
          width: 10.0,
        );

        final result = stroke.eraseAt(const Offset(20, 20), 5.0);

        expect(result.length, 2);
        expect(result[0].color, Colors.blue);
        expect(result[0].width, 10.0);
        expect(result[1].color, Colors.blue);
        expect(result[1].width, 10.0);
      });
    });
  });
}
