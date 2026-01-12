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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark ? baseColor.withAlpha(35) : baseColor.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text content with star
                  if (entry.hasContent)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.content!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (entry.isStarred) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber[500],
                            ),
                          ),
                        ],
                      ],
                    ),

                  // Image
                  if (entry.hasImage) ...[
                    if (entry.hasContent) const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onImageTap,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: Image.file(
                                File(entry.imagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(120),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Colors.amber[400],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Timestamp inside bubble (bottom right)
                  if (showTimestamp) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        TimeUtils.getEntryTime(entry.displayTime),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(90),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
