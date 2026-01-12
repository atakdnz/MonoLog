import 'package:flutter/material.dart';

class DateHeader extends StatelessWidget {
  final String date;

  const DateHeader({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.outline.withOpacity(0),
                    theme.colorScheme.outline.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              date,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.outline.withOpacity(0.3),
                    theme.colorScheme.outline.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
