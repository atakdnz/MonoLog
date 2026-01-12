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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Timestamp on the left (compact)
          if (showTimestamp)
            SizedBox(
              width: 44,
              child: Text(
                TimeUtils.getEntryTime(entry.displayTime),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(100),
                  fontSize: 10,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          if (showTimestamp) const SizedBox(width: 8),

          // Entry bubble
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? baseColor.withAlpha(25)
                      : baseColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: baseColor.withAlpha(isDark ? 50 : 30),
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Content row with star
                      if (entry.hasContent)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                entry.content!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (entry.isStarred) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber[600],
                              ),
                            ],
                          ],
                        ),

                      // Image
                      if (entry.hasImage) ...[
                        if (entry.hasContent) const SizedBox(height: 6),
                        GestureDetector(
                          onTap: onImageTap,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 180,
                                  ),
                                  child: Image.file(
                                    File(entry.imagePath!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 80,
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
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
                              // Star overlay for image-only entries
                              if (!entry.hasContent && entry.isStarred)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(100),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      size: 12,
                                      color: Colors.amber[400],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
