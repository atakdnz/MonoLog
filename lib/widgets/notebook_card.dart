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
    final notebookColor = NotebookColors.fromHex(widget.notebook.color);
    final isLight =
        ThemeData.estimateBrightnessForColor(notebookColor) == Brightness.light;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: notebookColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                notebookColor.withOpacity(0.15),
                notebookColor.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and pin icon
                Row(
                  children: [
                    if (widget.notebook.isPinned) ...[
                      Icon(Icons.push_pin, size: 16, color: notebookColor),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        widget.notebook.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isLight
                              ? notebookColor.withOpacity(0.9)
                              : notebookColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          _previewEntry!.content ?? '📷 Image',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),

                // Timestamp
                if (_previewEntry != null)
                  Text(
                    TimeUtils.getRelativeTime(_previewEntry!.displayTime),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
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
