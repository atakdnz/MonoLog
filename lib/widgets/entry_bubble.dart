import 'dart:io';
import 'package:flutter/material.dart';
import '../models/entry.dart';
import '../utils/time_utils.dart';

class EntryBubble extends StatelessWidget {
  final Entry entry;
  final bool showTimestamp;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onImageTap;
  final Color? notebookColor;

  const EntryBubble({
    super.key,
    required this.entry,
    this.showTimestamp = true,
    this.onTap,
    this.onLongPress,
    this.onImageTap,
    this.notebookColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = notebookColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          if (showTimestamp)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                TimeUtils.getEntryTime(entry.displayTime),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(128),
                ),
              ),
            ),

          // Entry bubble
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? baseColor.withAlpha(30)
                    : baseColor.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: baseColor.withAlpha(isDark ? 60 : 40),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Star indicator
                    if (entry.isStarred)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Starred',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.amber[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Text content
                    if (entry.hasContent)
                      Text(
                        entry.content!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),

                    // Image
                    if (entry.hasImage) ...[
                      if (entry.hasContent) const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onImageTap,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: Image.file(
                              File(entry.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: theme.colorScheme.onSurface
                                          .withAlpha(128),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
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
