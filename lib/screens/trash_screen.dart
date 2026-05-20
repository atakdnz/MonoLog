import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../models/notebook.dart';
import '../providers/trash_provider.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final _db = DatabaseHelper();
  Map<String, String> _notebookNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrashProvider>().loadTrash();
      _loadNotebookNames();
    });
  }

  Future<void> _loadNotebookNames() async {
    final notebooks = await _db.getNotebooks(includeArchived: true);
    setState(() {
      _notebookNames = {for (final n in notebooks) n.id: n.title};
    });
  }

  void _showEmptyTrashConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text(
          'All items in trash will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TrashProvider>().emptyTrash();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Trash emptied')));
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          Consumer<TrashProvider>(
            builder: (context, provider, _) {
              if (provider.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_forever),
                onPressed: _showEmptyTrashConfirmation,
                tooltip: 'Empty Trash',
              );
            },
          ),
        ],
      ),
      body: Consumer<TrashProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: provider.loadTrash,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Deleted notebooks section
                if (provider.trashNotebooks.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Notebooks',
                    provider.trashNotebooks.length,
                  ),
                  ...provider.trashNotebooks.map(_buildNotebookItem),
                ],
                // Deleted entries section
                if (provider.trashEntries.isNotEmpty) ...[
                  _buildSectionHeader('Entries', provider.trashEntries.length),
                  ...provider.trashEntries.map(_buildEntryItem),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
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
            Icons.delete_outline,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 16),
          Text(
            'Trash is empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deleted items will appear here for 30 days',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotebookItem(Notebook notebook) {
    return Dismissible(
      key: Key('notebook_${notebook.id}'),
      background: Container(
        color: Theme.of(context).colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.restore, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_forever, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          context.read<TrashProvider>().restoreNotebook(notebook.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notebook "${notebook.title}" restored')),
          );
          return false;
        } else {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Permanently?'),
              content: const Text(
                'This notebook and all its entries will be permanently deleted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (result == true) {
            context.read<TrashProvider>().permanentlyDeleteNotebook(
              notebook.id,
            );
          }
          return false;
        }
      },
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: NotebookColors.fromHex(notebook.color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.book, color: Colors.white, size: 20),
        ),
        title: Text(
          notebook.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Deleted ${TimeUtils.getRelativeTime(notebook.deletedAt ?? notebook.updatedAt)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: () {
                context.read<TrashProvider>().restoreNotebook(notebook.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Notebook "${notebook.title}" restored'),
                  ),
                );
              },
              tooltip: 'Restore',
            ),
            IconButton(
              icon: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _showNotebookDeleteConfirmation(notebook),
              tooltip: 'Delete permanently',
            ),
          ],
        ),
      ),
    );
  }

  void _showNotebookDeleteConfirmation(Notebook notebook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text(
          'The notebook "${notebook.title}" and all its entries will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TrashProvider>().permanentlyDeleteNotebook(
                notebook.id,
              );
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

  Widget _buildEntryItem(Entry entry) {
    final notebookName = _notebookNames[entry.notebookId] ?? 'Unknown Notebook';

    return Dismissible(
      key: Key('entry_${entry.id}'),
      background: Container(
        color: Theme.of(context).colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.restore, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_forever, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          context.read<TrashProvider>().restoreEntry(entry.id);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Entry restored')));
          return false;
        } else {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Permanently?'),
              content: const Text('This cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (result == true) {
            context.read<TrashProvider>().permanentlyDeleteEntry(entry.id);
          }
          return false;
        }
      },
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            entry.hasAudio
                ? Icons.mic_none
                : (entry.hasImage ? Icons.image : Icons.note),
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
          ),
        ),
        title: Text(
          entry.content ?? (entry.hasAudio ? 'Voice note' : 'Image'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(notebookName, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(width: 8),
            Text(
              '• Deleted ${TimeUtils.getRelativeTime(entry.deletedAt ?? entry.updatedAt)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: () {
                context.read<TrashProvider>().restoreEntry(entry.id);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Entry restored')));
              },
              tooltip: 'Restore',
            ),
            IconButton(
              icon: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _showEntryDeleteConfirmation(entry),
              tooltip: 'Delete permanently',
            ),
          ],
        ),
      ),
    );
  }

  void _showEntryDeleteConfirmation(Entry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text(
          'This entry will be permanently deleted and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TrashProvider>().permanentlyDeleteEntry(entry.id);
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
