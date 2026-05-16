import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../models/notebook.dart';
import '../providers/entries_provider.dart';
import '../providers/notebooks_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';

class NotebookDetailsScreen extends StatefulWidget {
  final Notebook notebook;

  const NotebookDetailsScreen({super.key, required this.notebook});

  @override
  State<NotebookDetailsScreen> createState() => _NotebookDetailsScreenState();
}

class _NotebookDetailsScreenState extends State<NotebookDetailsScreen> {
  late Notebook _notebook;

  @override
  void initState() {
    super.initState();
    _notebook = widget.notebook;
  }

  @override
  Widget build(BuildContext context) {
    final notebookColor = NotebookColors.fromHex(_notebook.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintedBackground = Color.lerp(
      Theme.of(context).scaffoldBackgroundColor,
      notebookColor,
      isDark ? 0.13 : 0.16,
    )!;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: tintedBackground,
        appBar: AppBar(
          title: Text(
            _notebook.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(
              children: [
                Divider(height: 1, thickness: 2, color: notebookColor),
                TabBar(
                  indicatorColor: notebookColor,
                  labelColor: notebookColor,
                  tabs: [
                    Tab(text: 'Gallery'),
                    Tab(text: 'Info'),
                    Tab(text: 'Actions'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: ColoredBox(
          color: tintedBackground,
          child: TabBarView(
            children: [
              const _GalleryTab(),
              _InfoTab(notebook: _notebook),
              _ActionsTab(
                notebook: _notebook,
                onNotebookChanged: (notebook) =>
                    setState(() => _notebook = notebook),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final Notebook notebook;

  const _InfoTab({required this.notebook});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<EntriesProvider>().entries;
    final isChat = notebook.entryStyle == NotebookEntryStyles.chat;
    final stats = _NotebookStats.fromEntries(entries);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: NotebookColors.fromHex(
                notebook.color,
              ).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isChat ? Icons.chat_bubble_outline : Icons.notes_outlined,
                  size: 18,
                  color: NotebookColors.fromHex(notebook.color),
                ),
                const SizedBox(width: 8),
                Text(isChat ? 'Chat Notebook' : 'Classic Notebook'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _InfoRow(
          icon: Icons.format_list_bulleted,
          label: isChat ? 'Messages' : 'Entries',
          value: '${entries.length}',
        ),
        _InfoRow(
          icon: Icons.text_fields,
          label: 'Characters',
          value: stats.characterCount.toString(),
        ),
        _InfoRow(
          icon: Icons.text_snippet_outlined,
          label: 'Words',
          value: stats.wordCount.toString(),
        ),
        if (stats.imageCount > 0)
          _InfoRow(
            icon: Icons.image_outlined,
            label: 'Images',
            value: stats.imageCount.toString(),
          ),
        if (stats.starredCount > 0)
          _InfoRow(
            icon: Icons.star_outline,
            label: 'Starred',
            value: stats.starredCount.toString(),
          ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.event_note_outlined,
            label: 'First entry',
            value: TimeUtils.getShortDate(entries.last.displayTime),
          ),
          _InfoRow(
            icon: Icons.event_outlined,
            label: 'Last entry',
            value: TimeUtils.getShortDate(entries.first.displayTime),
          ),
        ],
      ],
    );
  }
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab();

  @override
  Widget build(BuildContext context) {
    final imageEntries = context
        .watch<EntriesProvider>()
        .entries
        .where((entry) => entry.hasImage)
        .toList();

    if (imageEntries.isEmpty) {
      return Center(
        child: Text(
          'No images yet',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: imageEntries.length,
      itemBuilder: (context, index) {
        final entry = imageEntries[index];
        return GestureDetector(
          onTap: () => Navigator.pop(context, entry.id),
          child: Image.file(
            File(entry.imagePath!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        );
      },
    );
  }
}

class _ActionsTab extends StatelessWidget {
  final Notebook notebook;
  final ValueChanged<Notebook> onNotebookChanged;

  const _ActionsTab({required this.notebook, required this.onNotebookChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.ios_share_outlined),
          title: const Text('Export Notebook'),
          onTap: () => _exportNotebook(context),
        ),
        if (notebook.entryStyle == NotebookEntryStyles.chat)
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Import & Merge'),
            onTap: () => _importIntoNotebook(context),
          ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit Notebook'),
          onTap: () => _showEditNotebookDialog(context),
        ),
        ListTile(
          leading: Icon(
            notebook.isLocked ? Icons.lock_open : Icons.lock_outline,
          ),
          title: Text(notebook.isLocked ? 'Remove Lock' : 'Add Lock'),
          onTap: () => _toggleLock(context),
        ),
        const Divider(),
        ListTile(
          leading: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Delete Notebook',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () => _showDeleteConfirmation(context),
        ),
      ],
    );
  }

  Future<void> _exportNotebook(BuildContext context) async {
    final exportService = ExportService();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Exporting notebook...')));

    final filePath = await exportService.exportNotebook(notebook.id);

    if (!context.mounted) return;
    if (filePath != null) {
      await exportService.shareExport(filePath);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export failed')));
    }
  }

  Future<void> _importIntoNotebook(BuildContext context) async {
    final importService = ImportService();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Importing entries...')));

    final success = await importService.importMergeIntoNotebook(notebook.id);

    if (!context.mounted) return;
    if (success) {
      await context.read<EntriesProvider>().loadEntries();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entries imported successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed or cancelled')),
      );
    }
  }

  Future<void> _toggleLock(BuildContext context) async {
    await context.read<NotebooksProvider>().toggleLock(notebook.id);
    if (!context.mounted) return;
    final updated = await context.read<NotebooksProvider>().getNotebook(
      notebook.id,
    );
    if (updated != null && context.mounted) {
      onNotebookChanged(updated);
    }
  }

  void _showEditNotebookDialog(BuildContext parentContext) {
    final titleController = TextEditingController(text: notebook.title);
    String selectedColor = notebook.color;

    showModalBottomSheet(
      context: parentContext,
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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
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

                        final updatedNotebook = notebook.copyWith(
                          title: title,
                          color: selectedColor,
                          updatedAt: DateTime.now(),
                        );

                        await parentContext
                            .read<NotebooksProvider>()
                            .updateNotebook(updatedNotebook);

                        if (!parentContext.mounted) return;
                        onNotebookChanged(updatedNotebook);
                        Navigator.pop(context);
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
    ).whenComplete(titleController.dispose);
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Notebook?'),
        content: Text(
          'This will move "${notebook.title}" and all its entries to trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context.read<NotebooksProvider>().deleteNotebook(
                notebook.id,
              );
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
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

class _NotebookStats {
  final int characterCount;
  final int wordCount;
  final int imageCount;
  final int starredCount;

  const _NotebookStats({
    required this.characterCount,
    required this.wordCount,
    required this.imageCount,
    required this.starredCount,
  });

  factory _NotebookStats.fromEntries(List<Entry> entries) {
    var characterCount = 0;
    var wordCount = 0;
    var imageCount = 0;
    var starredCount = 0;

    for (final entry in entries) {
      if (entry.hasContent) {
        characterCount += entry.content!.length;
        wordCount += entry.content!
            .trim()
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .length;
      }
      if (entry.hasImage) imageCount++;
      if (entry.isStarred) starredCount++;
    }

    return _NotebookStats(
      characterCount: characterCount,
      wordCount: wordCount,
      imageCount: imageCount,
      starredCount: starredCount,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
