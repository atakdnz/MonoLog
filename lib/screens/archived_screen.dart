import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../database/database_helper.dart';
import '../models/notebook.dart';
import '../providers/notebooks_provider.dart';
import '../widgets/notebook_card.dart';
import 'notebook_screen.dart';

class ArchivedScreen extends StatefulWidget {
  const ArchivedScreen({super.key});

  @override
  State<ArchivedScreen> createState() => _ArchivedScreenState();
}

class _ArchivedScreenState extends State<ArchivedScreen> {
  final Set<String> _selectedNotebookIds = {};
  bool get _isSelectingNotebooks => _selectedNotebookIds.isNotEmpty;
  List<Notebook> _archivedNotebooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  Future<void> _loadArchived() async {
    final notebooks = await DatabaseHelper().getArchivedNotebooks();
    setState(() {
      _archivedNotebooks = notebooks;
      _isLoading = false;
    });
  }

  void _navigateToNotebook(Notebook notebook) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotebookScreen(notebook: notebook)),
    ).then((_) => _loadArchived());
  }

  void _toggleNotebookSelection(Notebook notebook) {
    setState(() {
      if (_selectedNotebookIds.contains(notebook.id)) {
        _selectedNotebookIds.remove(notebook.id);
      } else {
        _selectedNotebookIds.add(notebook.id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedNotebookIds.clear());
  }

  List<Notebook> _getSelectedNotebooks() {
    return _archivedNotebooks
        .where((n) => _selectedNotebookIds.contains(n.id))
        .toList();
  }

  void _handleBatchAction(String action) {
    final selected = _getSelectedNotebooks();
    if (selected.isEmpty) return;

    switch (action) {
      case 'unarchive':
        for (var n in selected) {
          context.read<NotebooksProvider>().toggleArchive(n.id);
        }
        _clearSelection();
        _loadArchived();
        break;
      case 'delete':
        _showBatchDeleteConfirmation(selected);
        break;
    }
  }

  void _showBatchDeleteConfirmation(List<Notebook> notebooks) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${notebooks.length} Notebooks?'),
        content: const Text(
          'They will be moved to the trash and can be restored within 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              for (var n in notebooks) {
                context.read<NotebooksProvider>().deleteNotebook(n.id);
              }
              _clearSelection();
              _loadArchived();
            },
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.errorContainer.withOpacity(0.5),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectingNotebooks,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectingNotebooks) {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: _isSelectingNotebooks
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
                title: Text(
                  '${_selectedNotebookIds.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: _handleBatchAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'unarchive',
                        child: Text('Unarchive'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              )
            : AppBar(
                title: const Text(
                  'Archived',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _archivedNotebooks.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadArchived,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildNotebookGrid(_archivedNotebooks),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 16),
          Text(
            'No archived notebooks',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Archived notebooks will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotebookGrid(List<Notebook> notebooks) {
    return ReorderableGridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: notebooks.length,
      itemBuilder: (context, index) {
        final notebook = notebooks[index];
        return NotebookCard(
          key: ValueKey(notebook.id),
          notebook: notebook,
          isSelected: _selectedNotebookIds.contains(notebook.id),
          onSelect: () => _toggleNotebookSelection(notebook),
          onTap: () {
            if (_isSelectingNotebooks) {
              _toggleNotebookSelection(notebook);
            } else {
              _navigateToNotebook(notebook);
            }
          },
        );
      },
      onReorder: (oldIndex, newIndex) {},
    );
  }
}
