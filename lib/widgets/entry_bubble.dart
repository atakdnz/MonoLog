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
  final VoidCallback? onImageLongPress;
  final Color? notebookColor;
  final bool isSelected;

  const EntryBubble({
    super.key,
    required this.entry,
    this.showTimestamp = true,
    this.onTap,
    this.onLongPress,
    this.onImageTap,
    this.onImageLongPress,
    this.notebookColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use notebook color or fallback to primary
    final bubbleColor = notebookColor ?? const Color(0xFF3b19e6);
    // Create a lighter version for light mode
    final bubbleColorLight = Color.lerp(bubbleColor, Colors.white, 0.85)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.80,
            ),
            decoration: BoxDecoration(
              color: isDark ? bubbleColor : bubbleColorLight,
              // Chat-style corners: rounded except bottom-right
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: bubbleColor.withValues(
                          alpha: isSelected ? 0.30 : 0.15,
                        ),
                        blurRadius: isSelected ? 14 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
              border: isSelected
                  ? Border.all(
                      color: isDark ? Colors.white : bubbleColor,
                      width: 2,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                              height: 1.5,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1F1B2E),
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
                              color: isDark
                                  ? Colors.amber[300]
                                  : Colors.amber[600],
                            ),
                          ),
                        ],
                      ],
                    ),

                  // Image
                  if (entry.hasImage) ...[
                    if (entry.hasContent) const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onImageTap,
                      onLongPress: onImageLongPress,
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
                                      color: isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.5)
                                            : Colors.black.withOpacity(0.3),
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
                                  color: Colors.black.withOpacity(0.5),
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

                  // Timestamp
                  if (showTimestamp) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: isDark ? Colors.white : bubbleColor,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          TimeUtils.getEntryTime(entry.displayTime),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? Colors.white.withOpacity(0.6)
                                : const Color(0xFF3b19e6).withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
