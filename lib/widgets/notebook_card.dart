import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notebook.dart';
import '../models/entry.dart';
import '../providers/notebooks_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';

class NotebookCard extends StatefulWidget {
  final Notebook notebook;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const NotebookCard({
    super.key,
    required this.notebook,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<NotebookCard> createState() => _NotebookCardState();
}

class _NotebookCardState extends State<NotebookCard> {
  Entry? _previewEntry;
  bool _isLoadingPreview = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(NotebookCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notebook.id != widget.notebook.id) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoadingPreview = true);
    final provider = context.read<NotebooksProvider>();
    final entry = await provider.getPreviewEntry(widget.notebook.id);
    if (mounted) {
      setState(() {
        _previewEntry = entry;
        _isLoadingPreview = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notebookColor = NotebookColors.fromHex(widget.notebook.color);
    final textColor =
        ThemeData.estimateBrightnessForColor(notebookColor) == Brightness.light
        ? Colors.black87
        : Colors.white;
    final isClassic = widget.notebook.entryStyle == NotebookEntryStyles.classic;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: notebookColor.withOpacity(isDark ? 0.2 : 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: notebookColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          splashColor: textColor.withOpacity(0.1),
          highlightColor: textColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and pin icon
                Row(
                  children: [
                    if (widget.notebook.isPinned) ...[
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: textColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        widget.notebook.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: isClassic ? 'Classic note' : 'Chat notebook',
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isClassic
                              ? Icons.notes_outlined
                              : Icons.chat_bubble_outline,
                          size: 14,
                          color: textColor.withOpacity(0.82),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Preview content
                Expanded(
                  child: _isLoadingPreview
                      ? const SizedBox.shrink()
                      : _previewEntry == null
                      ? Text(
                          'No entries yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          _previewEntry!.content ?? '📷 Image',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withOpacity(0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),

                if (_previewEntry != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      TimeUtils.getRelativeTime(_previewEntry!.displayTime),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textColor.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
