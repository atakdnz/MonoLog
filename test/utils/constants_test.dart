import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/utils/constants.dart';

void main() {
  group('NotebookColors', () {
    test('should have 12 predefined colors', () {
      expect(NotebookColors.colors.length, 12);
    });

    test('all colors should be valid Color objects', () {
      for (final color in NotebookColors.colors) {
        expect(color, isA<Color>());
      }
    });

    group('fromHex', () {
      test('should parse hex color string to Color', () {
        final color = NotebookColors.fromHex('#6366F1');

        expect(color, isA<Color>());
      });

      test('should parse hex without hash', () {
        final color = NotebookColors.fromHex('6366F1');

        expect(color, isA<Color>());
      });

      test('should create correct color value', () {
        final color = NotebookColors.fromHex('#FF0000');

        expect(color.value, 0xFFFF0000);
      });

      test('should handle lowercase hex', () {
        final color1 = NotebookColors.fromHex('#6366f1');
        final color2 = NotebookColors.fromHex('#6366F1');

        expect(color1.value, color2.value);
      });
    });

    group('toHex', () {
      test('should convert Color to hex string', () {
        const color = Color(0xFF6366F1);
        final hex = NotebookColors.toHex(color);

        expect(hex, '#6366F1');
      });

      test('should return uppercase hex', () {
        const color = Color(0xFFabcdef);
        final hex = NotebookColors.toHex(color);

        expect(hex, '#ABCDEF');
      });

      test('should roundtrip correctly', () {
        const originalColor = Color(0xFF6366F1);
        final hex = NotebookColors.toHex(originalColor);
        final parsedColor = NotebookColors.fromHex(hex);

        expect(parsedColor.value, originalColor.value);
      });
    });

    group('getDefault', () {
      test('should return first color in list', () {
        final defaultColor = NotebookColors.getDefault();

        expect(defaultColor, NotebookColors.colors[0]);
      });
    });
  });

  group('NotebookEntryStyles', () {
    test('should have chat style', () {
      expect(NotebookEntryStyles.chat, 'chat');
    });

    test('should have classic style', () {
      expect(NotebookEntryStyles.classic, 'classic');
    });

    test('styles should be different', () {
      expect(
        NotebookEntryStyles.chat,
        isNot(equals(NotebookEntryStyles.classic)),
      );
    });
  });

  group('TimeGaps', () {
    test('minimal should be 5 minutes', () {
      expect(TimeGaps.minimal, 5);
    });

    test('small should be 30 minutes', () {
      expect(TimeGaps.small, 30);
    });

    test('medium should be 120 minutes', () {
      expect(TimeGaps.medium, 120);
    });

    test('thresholds should be in ascending order', () {
      expect(TimeGaps.minimal < TimeGaps.small, true);
      expect(TimeGaps.small < TimeGaps.medium, true);
    });
  });

  group('Constants', () {
    test('trash retention days should be 30', () {
      expect(trashRetentionDays, 30);
    });

    test('app name should be MonoLog', () {
      expect(appName, 'MonoLog');
    });

    test('app version should be 1.7.0', () {
      expect(appVersion, '1.7.0');
    });

    test('quick animation should be 200ms', () {
      expect(quickAnimation, const Duration(milliseconds: 200));
    });

    test('normal animation should be 300ms', () {
      expect(normalAnimation, const Duration(milliseconds: 300));
    });
  });

  group('Input bar constants', () {
    test('max lines should be 6', () {
      expect(inputBarMaxLines, 6);
    });

    test('min height should be 48.0', () {
      expect(inputBarMinHeight, 48.0);
    });
  });
}
