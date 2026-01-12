import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/trash_provider.dart';
import '../database/database_helper.dart';
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

  void _showEntryPreview(Entry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                _notebookNames[entry.notebookId] ?? 'Unknown Notebook',
              ),
            ),
            if (entry.isStarred)
              Icon(Icons.star, size: 20, color: Colors.amber[600]),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.hasContent) Text(entry.content!),
              if (entry.hasImage) ...[
                if (entry.hasContent) const SizedBox(height: 12),
                Text(
                  '📷 Has attached image',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Original date: ${TimeUtils.formatDate(entry.displayTime)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              if (entry.deletedAt != null)
                Text(
                  'Deleted: ${TimeUtils.getRelativeTime(entry.deletedAt!)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TrashProvider>().restoreEntry(entry.id);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Entry restored')));
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Entry entry) {
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

  void _showEmptyTrashConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text(
          'All entries in trash will be permanently deleted. This action cannot be undone.',
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
              if (provider.trashEntries.isEmpty) return const SizedBox.shrink();
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

          if (provider.trashEntries.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: provider.loadTrash,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.trashEntries.length,
              itemBuilder: (context, index) {
                final entry = provider.trashEntries[index];
                return _buildTrashItem(entry);
              },
            ),
          );
        },
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Trash is empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deleted entries will appear here for 30 days',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrashItem(Entry entry) {
    final notebookName = _notebookNames[entry.notebookId] ?? 'Unknown Notebook';

    return Dismissible(
      key: Key(entry.id),
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
          // Restore
          context.read<TrashProvider>().restoreEntry(entry.id);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Entry restored')));
          return false;
        } else {
          // Delete permanently
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
        onTap: () => _showEntryPreview(entry),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            entry.hasImage ? Icons.image : Icons.note,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        title: Text(
          entry.content ?? '📷 Image',
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
              onPressed: () => _showDeleteConfirmation(entry),
              tooltip: 'Delete permanently',
            ),
          ],
        ),
      ),
    );
  }
}
