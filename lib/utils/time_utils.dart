import 'package:intl/intl.dart';

class TimeUtils {
  /// Returns relative time string like "2h ago", "Yesterday", "Jan 15"
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  /// Returns formatted time for entry bubbles (e.g., "9:15 AM")
  static String getEntryTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Returns full date header (e.g., "Monday, Jan 15, 2025")
  static String getDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (dateTime.year == now.year) {
      return DateFormat('EEEE, MMM d').format(dateTime);
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(dateTime);
    }
  }

  /// Returns short date for headers (e.g., "Jan 15")
  static String getShortDate(DateTime dateTime) {
    return DateFormat('MMM d').format(dateTime);
  }

  /// Calculates time gap in minutes between two DateTimes
  static int getTimeGapMinutes(DateTime earlier, DateTime later) {
    return later.difference(earlier).inMinutes.abs();
  }

  /// Checks if two DateTimes are on the same day
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Checks if a DateTime is today
  static bool isToday(DateTime dateTime) {
    final now = DateTime.now();
    return isSameDay(dateTime, now);
  }

  /// Returns formatted time for time picker display
  static String formatTimeOfDay(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Returns formatted date for date picker display
  static String formatDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  /// Combines a date and time into a single DateTime
  static DateTime combineDateAndTime(DateTime date, DateTime time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
    );
  }

  /// Parse ISO 8601 string to DateTime
  static DateTime? parseIso8601(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    return DateTime.tryParse(dateString);
  }

  /// Format DateTime to ISO 8601 string
  static String toIso8601(DateTime dateTime) {
    return dateTime.toIso8601String();
  }
}
