import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/utils/time_utils.dart';

void main() {
  group('TimeUtils', () {
    group('getRelativeTime', () {
      test('should return "Just now" for very recent time', () {
        final now = DateTime.now();
        final result = TimeUtils.getRelativeTime(now);

        expect(result, 'Just now');
      });

      test('should return minutes ago for recent time', () {
        final now = DateTime.now();
        final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
        final result = TimeUtils.getRelativeTime(fiveMinutesAgo);

        expect(result, '5m ago');
      });

      test('should return hours ago for same day time', () {
        final now = DateTime.now();
        final threeHoursAgo = now.subtract(const Duration(hours: 3));
        final result = TimeUtils.getRelativeTime(threeHoursAgo);

        expect(result, '3h ago');
      });

      test('should return "Yesterday" for one day ago', () {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final result = TimeUtils.getRelativeTime(yesterday);

        expect(result, 'Yesterday');
      });

      test('should return days ago for less than a week', () {
        final now = DateTime.now();
        final threeDaysAgo = now.subtract(const Duration(days: 3));
        final result = TimeUtils.getRelativeTime(threeDaysAgo);

        expect(result, '3d ago');
      });

      test('should return weeks ago for less than a month', () {
        final now = DateTime.now();
        final twoWeeksAgo = now.subtract(const Duration(days: 14));
        final result = TimeUtils.getRelativeTime(twoWeeksAgo);

        expect(result, '2w ago');
      });

      test('should return formatted date for older than a month', () {
        final now = DateTime.now();
        final twoMonthsAgo = now.subtract(const Duration(days: 60));
        final result = TimeUtils.getRelativeTime(twoMonthsAgo);

        expect(result.contains('ago'), false);
      });
    });

    group('getEntryTime', () {
      test('should format time with AM/PM', () {
        final dateTime = DateTime(2025, 1, 15, 9, 15);
        final result = TimeUtils.getEntryTime(dateTime);

        expect(result, '9:15 AM');
      });

      test('should format afternoon time correctly', () {
        final dateTime = DateTime(2025, 1, 15, 14, 30);
        final result = TimeUtils.getEntryTime(dateTime);

        expect(result, '2:30 PM');
      });

      test('should format midnight correctly', () {
        final dateTime = DateTime(2025, 1, 15, 0, 0);
        final result = TimeUtils.getEntryTime(dateTime);

        expect(result, '12:00 AM');
      });

      test('should format noon correctly', () {
        final dateTime = DateTime(2025, 1, 15, 12, 0);
        final result = TimeUtils.getEntryTime(dateTime);

        expect(result, '12:00 PM');
      });
    });

    group('getDateHeader', () {
      test('should return "Today" for today', () {
        final now = DateTime.now();
        final result = TimeUtils.getDateHeader(now);

        expect(result, 'Today');
      });

      test('should return "Yesterday" for yesterday', () {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final result = TimeUtils.getDateHeader(yesterday);

        expect(result, 'Yesterday');
      });

      test('should return formatted date for same year', () {
        final date = DateTime(DateTime.now().year, 1, 15);
        final result = TimeUtils.getDateHeader(date);

        expect(result, contains('Jan 15'));
        expect(result, isNot(contains('${date.year}')));
      });

      test('should include year for different year', () {
        final date = DateTime(DateTime.now().year - 1, 1, 15);
        final result = TimeUtils.getDateHeader(date);

        expect(result, contains('Jan 15, ${date.year}'));
      });
    });

    group('getShortDate', () {
      test('should format date as "MMM d"', () {
        final dateTime = DateTime(2025, 1, 15);
        final result = TimeUtils.getShortDate(dateTime);

        expect(result, 'Jan 15');
      });

      test('should handle different months', () {
        final dateTime = DateTime(2025, 12, 25);
        final result = TimeUtils.getShortDate(dateTime);

        expect(result, 'Dec 25');
      });
    });

    group('getTimeGapMinutes', () {
      test('should return difference in minutes', () {
        final earlier = DateTime(2025, 1, 15, 10, 0);
        final later = DateTime(2025, 1, 15, 10, 30);

        final result = TimeUtils.getTimeGapMinutes(earlier, later);

        expect(result, 30);
      });

      test('should handle hour difference', () {
        final earlier = DateTime(2025, 1, 15, 10, 0);
        final later = DateTime(2025, 1, 15, 12, 0);

        final result = TimeUtils.getTimeGapMinutes(earlier, later);

        expect(result, 120);
      });

      test('should handle day difference', () {
        final earlier = DateTime(2025, 1, 15, 10, 0);
        final later = DateTime(2025, 1, 16, 10, 0);

        final result = TimeUtils.getTimeGapMinutes(earlier, later);

        expect(result, 1440);
      });

      test('should return absolute value', () {
        final earlier = DateTime(2025, 1, 15, 10, 0);
        final later = DateTime(2025, 1, 15, 10, 30);

        final result1 = TimeUtils.getTimeGapMinutes(earlier, later);
        final result2 = TimeUtils.getTimeGapMinutes(later, earlier);

        expect(result1, result2);
        expect(result1, 30);
      });
    });

    group('isSameDay', () {
      test('should return true for same day', () {
        final a = DateTime(2025, 1, 15, 10, 0);
        final b = DateTime(2025, 1, 15, 15, 30);

        expect(TimeUtils.isSameDay(a, b), true);
      });

      test('should return false for different days', () {
        final a = DateTime(2025, 1, 15, 10, 0);
        final b = DateTime(2025, 1, 16, 10, 0);

        expect(TimeUtils.isSameDay(a, b), false);
      });

      test('should return false for different months', () {
        final a = DateTime(2025, 1, 15, 10, 0);
        final b = DateTime(2025, 2, 15, 10, 0);

        expect(TimeUtils.isSameDay(a, b), false);
      });

      test('should return false for different years', () {
        final a = DateTime(2025, 1, 15, 10, 0);
        final b = DateTime(2026, 1, 15, 10, 0);

        expect(TimeUtils.isSameDay(a, b), false);
      });
    });

    group('isToday', () {
      test('should return true for today', () {
        final now = DateTime.now();

        expect(TimeUtils.isToday(now), true);
      });

      test('should return false for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));

        expect(TimeUtils.isToday(yesterday), false);
      });

      test('should return false for tomorrow', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));

        expect(TimeUtils.isToday(tomorrow), false);
      });
    });

    group('formatTimeOfDay', () {
      test('should format time as HH:mm', () {
        final dateTime = DateTime(2025, 1, 15, 9, 15);
        final result = TimeUtils.formatTimeOfDay(dateTime);

        expect(result, '09:15');
      });

      test('should handle afternoon time', () {
        final dateTime = DateTime(2025, 1, 15, 14, 30);
        final result = TimeUtils.formatTimeOfDay(dateTime);

        expect(result, '14:30');
      });
    });

    group('formatDate', () {
      test('should format date as "MMM d, yyyy"', () {
        final dateTime = DateTime(2025, 1, 15);
        final result = TimeUtils.formatDate(dateTime);

        expect(result, 'Jan 15, 2025');
      });
    });

    group('combineDateAndTime', () {
      test('should combine date and time correctly', () {
        final date = DateTime(2025, 1, 15);
        final time = DateTime(2025, 1, 1, 14, 30, 45);

        final result = TimeUtils.combineDateAndTime(date, time);

        expect(result.year, 2025);
        expect(result.month, 1);
        expect(result.day, 15);
        expect(result.hour, 14);
        expect(result.minute, 30);
        expect(result.second, 45);
      });
    });

    group('parseIso8601', () {
      test('should parse valid ISO 8601 string', () {
        final dateString = '2025-01-15T10:30:00.000';
        final result = TimeUtils.parseIso8601(dateString);

        expect(result, isNotNull);
        expect(result!.year, 2025);
        expect(result.month, 1);
        expect(result.day, 15);
        expect(result.hour, 10);
        expect(result.minute, 30);
      });

      test('should return null for null input', () {
        final result = TimeUtils.parseIso8601(null);

        expect(result, isNull);
      });

      test('should return null for empty string', () {
        final result = TimeUtils.parseIso8601('');

        expect(result, isNull);
      });

      test('should return null for invalid string', () {
        final result = TimeUtils.parseIso8601('not-a-date');

        expect(result, isNull);
      });
    });

    group('toIso8601', () {
      test('should convert DateTime to ISO 8601 string', () {
        final dateTime = DateTime(2025, 1, 15, 10, 30, 0);
        final result = TimeUtils.toIso8601(dateTime);

        expect(result, dateTime.toIso8601String());
      });
    });
  });
}
