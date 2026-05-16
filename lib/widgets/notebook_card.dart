import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/notebook.dart';
import '../models/entry.dart';
import '../models/folder.dart';
import '../providers/notebooks_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';

class NotebookCard extends StatefulWidget {
  final Notebook notebook;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final bool isSelected;

  const NotebookCard({
    super.key,
    required this.notebook,
    required this.onTap,
    required this.onSelect,
    this.isSelected = false,
  });

  @override
  State<NotebookCard> createState() => _NotebookCardState();
}

class _NotebookCardState extends State<NotebookCard> {
  Entry? _previewEntry;
  bool _isLoadingPreview = true;
  Timer? _selectionTimer;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _selectionTimer?.cancel();
    super.dispose();
  }

  void _cancelTimer() {
    _selectionTimer?.cancel();
    _selectionTimer = null;
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

    return Listener(
      onPointerDown: (_) {
        _cancelTimer();
        _selectionTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted && !widget.isSelected) {
            HapticFeedback.selectionClick();
            widget.onSelect();
          }
        });
      },
      onPointerUp: (_) => _cancelTimer(),
      onPointerCancel: (_) => _cancelTimer(),
      child: Container(
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
            splashColor: textColor.withOpacity(0.1),
            highlightColor: textColor.withOpacity(0.05),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title, pin, and type indicator
                      Row(
                        children: [
                          if (widget.notebook.isPinned) ...[
                            Icon(
                              Icons.push_pin,
                              size: 14,
                              color: textColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 3),
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isClassic
                                      ? Icons.notes_outlined
                                      : Icons.chat_bubble_outline,
                                  size: 10,
                                  color: textColor.withOpacity(0.8),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isClassic ? 'Classic' : 'Chat',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: textColor.withOpacity(0.85),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Preview content
                      Expanded(
                        child: widget.notebook.isLocked
                            ? Center(
                                child: Icon(
                                  Icons.lock,
                                  size: 32,
                                  color: textColor.withOpacity(0.5),
                                ),
                              )
                            : _isLoadingPreview
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

                      // Footer: time (left) + folder badge (right)
                      if (!widget.notebook.isLocked &&
                          (_previewEntry != null ||
                              widget.notebook.folderId != null))
                        Row(
                          children: [
                            // Time badge (left, always visible)
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
                                  TimeUtils.getRelativeTime(
                                    _previewEntry!.displayTime,
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: textColor.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            if (_previewEntry != null) const SizedBox(width: 4),
                            // Spacer pushes folder to the right
                            if (widget.notebook.folderId != null)
                              const Spacer(),
                            // Folder badge (right, constrained)
                            if (widget.notebook.folderId != null)
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 80),
                                child: FutureBuilder<Folder?>(
                                  future: DatabaseHelper().getFolder(
                                    widget.notebook.folderId!,
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    final folder = snapshot.data!;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: textColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.folder,
                                            size: 10,
                                            color: textColor.withOpacity(0.8),
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              folder.name,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: textColor
                                                        .withOpacity(0.85),
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 9,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (widget.isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.15),
                        border: Border.all(
                          color: isDark ? Colors.white : notebookColor,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                if (widget.isSelected)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Icon(
                      Icons.check_circle,
                      color: isDark ? Colors.white : notebookColor,
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
