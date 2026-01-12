import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/notebook.dart';
import '../models/entry.dart';
import '../providers/entries_provider.dart';
import '../providers/notebooks_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import '../widgets/entry_bubble.dart';
import '../widgets/date_header.dart';
import '../widgets/input_bar.dart';
import '../services/export_service.dart';
import 'entry_edit_screen.dart';

class NotebookScreen extends StatefulWidget {
  final Notebook notebook;

  const NotebookScreen({super.key, required this.notebook});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  final _scrollController = ScrollController();
  late Notebook _notebook;
  bool _isSearching = false;
  bool _showStarredOnly = false;
  final _searchController = TextEditingController();
  List<Entry> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _notebook = widget.notebook;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EntriesProvider>().setNotebook(_notebook.id);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _saveImage(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
      final destPath = p.join(imagesDir.path, fileName);
      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }

  Future<void> _handleSend(
    String content,
    String? imagePath,
    DateTime? customTime,
  ) async {
    String? savedImagePath;
    if (imagePath != null) {
      savedImagePath = await _saveImage(imagePath);
    }

    await context.read<EntriesProvider>().addEntry(
      content: content,
      imagePath: savedImagePath,
      displayTime: customTime,
    );

    // Scroll to top (newest entries)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: normalAnimation,
        curve: Curves.easeOut,
      );
    }
  }

  void _showEntryOptions(Entry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  entry.isStarred ? Icons.star : Icons.star_outline,
                  color: entry.isStarred ? Colors.amber[600] : null,
                ),
                title: Text(entry.isStarred ? 'Remove Star' : 'Add Star'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<EntriesProvider>().toggleStar(entry.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToEdit(entry);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to...'),
                onTap: () {
                  Navigator.pop(context);
                  _showMoveDialog(entry);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.read<EntriesProvider>().deleteEntry(entry.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entry moved to trash')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToEdit(Entry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditScreen(entry: entry, notebookId: _notebook.id),
      ),
    ).then((_) {
      context.read<EntriesProvider>().loadEntries();
    });
  }

  void _showMoveDialog(Entry entry) async {
    final notebooks = await context.read<NotebooksProvider>().loadNotebooks();
    final provider = context.read<NotebooksProvider>();
    final allNotebooks = [
      ...provider.pinnedNotebooks,
      ...provider.regularNotebooks,
    ].where((n) => n.id != _notebook.id).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Move to...',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (allNotebooks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No other notebooks available',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              )
            else
              ...allNotebooks.map(
                (notebook) => ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: NotebookColors.fromHex(notebook.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(notebook.title),
                  onTap: () async {
                    Navigator.pop(context);
                    await context.read<EntriesProvider>().moveEntry(
                      entry.id,
                      notebook.id,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Moved to ${notebook.title}')),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showJumpToDatePicker() async {
    final entries = context.read<EntriesProvider>().entries;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to navigate to')),
      );
      return;
    }

    final oldestDate = entries.last.displayTime;
    final newestDate = entries.first.displayTime;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: newestDate,
      firstDate: oldestDate,
      lastDate: newestDate,
    );

    if (selectedDate == null || !mounted) return;

    // Find the index of the first entry on that date
    int targetIndex = entries.indexWhere(
      (e) => TimeUtils.isSameDay(e.displayTime, selectedDate),
    );

    if (targetIndex == -1) {
      // Find nearest date
      int nearestIndex = 0;
      int minDiff = 999999;
      for (int i = 0; i < entries.length; i++) {
        final diff = entries[i].displayTime
            .difference(selectedDate)
            .inDays
            .abs();
        if (diff < minDiff) {
          minDiff = diff;
          nearestIndex = i;
        }
      }
      targetIndex = nearestIndex;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No entries on selected date. Jumping to ${TimeUtils.getShortDate(entries[targetIndex].displayTime)}',
          ),
        ),
      );
    }

    // Calculate approximate scroll position
    // This is a rough estimate since items have variable height
    final scrollOffset = targetIndex * 100.0;
    _scrollController.animateTo(
      scrollOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: normalAnimation,
      curve: Curves.easeOut,
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults = [];
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final results = await context.read<EntriesProvider>().searchEntries(query);
    setState(() => _searchResults = results);
  }

  void _showFullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(child: Image.file(File(imagePath))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notebookColor = NotebookColors.fromHex(_notebook.color);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search in notebook...',
                  border: InputBorder.none,
                ),
                onChanged: _performSearch,
              )
            : Text(
                _notebook.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          if (!_isSearching) ...[
            IconButton(
              icon: Icon(
                _showStarredOnly ? Icons.star : Icons.star_border,
                color: _showStarredOnly ? Colors.amber[600] : null,
              ),
              onPressed: () =>
                  setState(() => _showStarredOnly = !_showStarredOnly),
              tooltip: _showStarredOnly ? 'Show all' : 'Show starred only',
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _showJumpToDatePicker,
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    _showEditNotebookDialog();
                    break;
                  case 'export':
                    _exportNotebook();
                    break;
                  case 'archive':
                    await context.read<NotebooksProvider>().toggleArchive(
                      _notebook.id,
                    );
                    if (mounted) Navigator.pop(context);
                    break;
                  case 'delete':
                    _showDeleteConfirmation();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit Notebook'),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Text('Export Notebook'),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(_notebook.isArchived ? 'Unarchive' : 'Archive'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<EntriesProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                var entries = _isSearching && _searchController.text.isNotEmpty
                    ? _searchResults
                    : provider.entries;

                // Apply starred filter
                if (_showStarredOnly) {
                  entries = entries.where((e) => e.isStarred).toList();
                }

                if (entries.isEmpty) {
                  return _buildEmptyState();
                }

                // Entries from provider are DESC (newest first)
                // With reverse:true ListView, we iterate normally so newest shows at bottom
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final previousEntry = index < entries.length - 1
                        ? entries[index + 1]
                        : null;

                    return _buildEntryItem(entry, previousEntry);
                  },
                );
              },
            ),
          ),
          InputBar(
            onSend: _handleSend,
            enabled: !_isSearching,
            notebookColor: notebookColor,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'No results found' : 'No entries yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (!_isSearching) ...[
            const SizedBox(height: 8),
            Text(
              'Start typing below to add your first entry',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryItem(Entry entry, Entry? nextEntryInTime) {
    final widgets = <Widget>[];

    // Date header: show when this entry is the first of a new day
    // nextEntryInTime is actually the next older entry (displayTime-wise)
    final needsDateHeader =
        nextEntryInTime == null ||
        !TimeUtils.isSameDay(entry.displayTime, nextEntryInTime.displayTime);

    // Calculate time-based spacing
    double topSpacing = 0;
    if (nextEntryInTime != null &&
        TimeUtils.isSameDay(entry.displayTime, nextEntryInTime.displayTime)) {
      final gapMinutes = TimeUtils.getTimeGapMinutes(
        nextEntryInTime.displayTime,
        entry.displayTime,
      );
      // Dynamic spacing based on time gap
      if (gapMinutes >= TimeGaps.medium) {
        topSpacing = 20; // 2+ hours gap
      } else if (gapMinutes >= TimeGaps.small) {
        topSpacing = 12; // 30min - 2hr gap
      } else if (gapMinutes >= TimeGaps.minimal) {
        topSpacing = 6; // 5-30min gap
      }
    }

    // Add spacing before entry (appears after in visual order due to reverse)
    if (topSpacing > 0) {
      widgets.add(SizedBox(height: topSpacing));
    }

    // Add entry bubble
    widgets.add(
      EntryBubble(
        entry: entry,
        showTimestamp: true,
        notebookColor: NotebookColors.fromHex(_notebook.color),
        onTap: () {
          if (_showStarredOnly) {
            // When in starred filter, tapping navigates to original location
            setState(() => _showStarredOnly = false);
            // Find index in full list and scroll to it
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final provider = context.read<EntriesProvider>();
              final index = provider.entries.indexWhere(
                (e) => e.id == entry.id,
              );
              if (index >= 0 && _scrollController.hasClients) {
                // Estimate scroll position (rough calculation)
                final estimatedOffset = index * 70.0;
                _scrollController.animateTo(
                  estimatedOffset.clamp(
                    0,
                    _scrollController.position.maxScrollExtent,
                  ),
                  duration: normalAnimation,
                  curve: Curves.easeOut,
                );
              }
            });
          } else {
            _navigateToEdit(entry);
          }
        },
        onLongPress: () => _showEntryOptions(entry),
        onImageTap: entry.hasImage
            ? () => _showFullScreenImage(entry.imagePath!)
            : null,
      ),
    );

    // Add date header above entries (appears below in visual order due to reverse)
    if (needsDateHeader) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(DateHeader(date: TimeUtils.getDateHeader(entry.displayTime)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets.reversed.toList(), // Reverse so header appears on top
    );
  }

  Future<void> _exportNotebook() async {
    final exportService = ExportService();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Exporting notebook...')));

    final filePath = await exportService.exportNotebook(_notebook.id);

    if (filePath != null && mounted) {
      await exportService.shareExport(filePath);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export failed')));
    }
  }

  void _showEditNotebookDialog() {
    final titleController = TextEditingController(text: _notebook.title);
    String selectedColor = _notebook.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Notebook',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Notebook Name',
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Choose Color',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: NotebookColors.colors.map((color) {
                      final hex = NotebookColors.toHex(color);
                      final isSelected = hex == selectedColor;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = hex),
                        child: AnimatedContainer(
                          duration: quickAnimation,
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;

                        final updatedNotebook = _notebook.copyWith(
                          title: title,
                          color: selectedColor,
                          updatedAt: DateTime.now(),
                        );

                        await context.read<NotebooksProvider>().updateNotebook(
                          updatedNotebook,
                        );

                        setState(() => _notebook = updatedNotebook);

                        if (mounted) Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notebook?'),
        content: Text(
          'This will permanently delete "${_notebook.title}" and all its entries. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<NotebooksProvider>().deleteNotebook(
                _notebook.id,
              );
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
