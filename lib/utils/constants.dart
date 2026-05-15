import 'package:flutter/material.dart';

/// Predefined notebook colors
class NotebookColors {
  static const List<Color> colors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFFBBF24), // Amber
    Color(0xFF22C55E), // Green
    Color(0xFF14B8A6), // Teal
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF64748B), // Slate
    Color(0xFF78716C), // Stone
  ];

  static Color fromHex(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  static String toHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  static Color getDefault() => colors[0];
}

class NotebookEntryStyles {
  static const String chat = 'chat';
  static const String classic = 'classic';
}

/// Time gap thresholds for visual grouping (in minutes)
class TimeGaps {
  static const int minimal = 5; // < 5 min: minimal spacing
  static const int small = 30; // 5-30 min: small gap
  static const int medium = 120; // 30-120 min: medium gap
  // > 120 min: large gap
}

/// Trash retention period
const int trashRetentionDays = 30;

/// App info
const String appName = 'MonoLog';
const String appVersion = '1.0.0';

/// Animation durations
const Duration quickAnimation = Duration(milliseconds: 200);
const Duration normalAnimation = Duration(milliseconds: 300);

/// Input bar
const int inputBarMaxLines = 6;
const double inputBarMinHeight = 48.0;
