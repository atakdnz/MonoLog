import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/notebook.dart';
import '../providers/notebooks_provider.dart';
import '../utils/constants.dart';
import '../widgets/notebook_card.dart';
import 'notebook_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotebooksProvider>().loadNotebooks();
    });
  }

  void _navigateToNotebook(Notebook notebook) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotebookScreen(notebook: notebook)),
    ).then((_) {
      // Refresh notebooks when returning
      context.read<NotebooksProvider>().loadNotebooks();
    });
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ).then((_) {
      // Refresh notebooks in case notebook was restored from trash
      context.read<NotebooksProvider>().loadNotebooks();
    });
  }

  void _showCreateNotebookDialog() {
    final titleController = TextEditingController();
    String selectedColor = NotebookColors.toHex(NotebookColors.getDefault());
    String selectedEntryStyle = NotebookEntryStyles.chat;

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
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Create Notebook',
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
                      hintText: 'Enter a name...',
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
                    'Note Style',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: NotebookEntryStyles.chat,
                        icon: Icon(Icons.chat_bubble_outline),
                        label: Text('Chat'),
                      ),
                      ButtonSegment(
                        value: NotebookEntryStyles.classic,
                        icon: Icon(Icons.notes_outlined),
                        label: Text('Classic'),
                      ),
                    ],
                    selected: {selectedEntryStyle},
                    onSelectionChanged: (selection) {
                      setModalState(() => selectedEntryStyle = selection.first);
                    },
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
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
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

                        final notebook = await context
                            .read<NotebooksProvider>()
                            .createNotebook(
                              title: title,
                              color: selectedColor,
                              entryStyle: selectedEntryStyle,
                            );

                        if (mounted) {
                          Navigator.pop(context);
                          _navigateToNotebook(notebook);
                        }
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Create'),
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

  void _showNotebookOptions(Notebook notebook) {
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
                  notebook.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(notebook.isPinned ? 'Unpin' : 'Pin'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<NotebooksProvider>().togglePin(notebook.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditNotebookDialog(notebook);
                },
              ),
              ListTile(
                leading: Icon(
                  notebook.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(notebook.isArchived ? 'Unarchive' : 'Archive'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<NotebooksProvider>().toggleArchive(notebook.id);
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
                  _showDeleteConfirmation(notebook);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditNotebookDialog(Notebook notebook) {
    final titleController = TextEditingController(text: notebook.title);
    String selectedColor = notebook.color;

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
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.1),
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

                        await context.read<NotebooksProvider>().updateNotebook(
                          notebook.copyWith(
                            title: title,
                            color: selectedColor,
                            updatedAt: DateTime.now(),
                          ),
                        );

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

  void _showDeleteConfirmation(Notebook notebook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notebook?'),
        content: Text(
          '"${notebook.title}" will be moved to trash. You can restore it within 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NotebooksProvider>().deleteNotebook(notebook.id);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          appName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _navigateToSearch,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: Consumer<NotebooksProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final hasNotebooks =
              provider.pinnedNotebooks.isNotEmpty ||
              provider.regularNotebooks.isNotEmpty ||
              provider.archivedNotebooks.isNotEmpty;

          if (!hasNotebooks) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: provider.loadNotebooks,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Pinned section
                if (provider.pinnedNotebooks.isNotEmpty) ...[
                  _buildSectionHeader('PINNED'),
                  const SizedBox(height: 12),
                  _buildNotebookGrid(provider.pinnedNotebooks),
                  const SizedBox(height: 24),
                ],

                // Regular notebooks section
                if (provider.regularNotebooks.isNotEmpty) ...[
                  _buildSectionHeader('NOTEBOOKS'),
                  const SizedBox(height: 12),
                  _buildNotebookGrid(provider.regularNotebooks),
                  const SizedBox(height: 24),
                ],

                // Archived section (collapsible)
                if (provider.archivedNotebooks.isNotEmpty) ...[
                  InkWell(
                    onTap: provider.toggleShowArchived,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          _buildSectionHeader('ARCHIVED'),
                          const SizedBox(width: 8),
                          Text(
                            '(${provider.archivedNotebooks.length})',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.5),
                                ),
                          ),
                          const Spacer(),
                          Icon(
                            provider.showArchived
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.showArchived) ...[
                    const SizedBox(height: 12),
                    _buildNotebookGrid(provider.archivedNotebooks),
                  ],
                ],

                // Bottom padding for FAB
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateNotebookDialog,
        backgroundColor: const Color(0xFF3b19e6),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No notebooks yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to create your first notebook',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
          onTap: () => _navigateToNotebook(notebook),
          onOptionsTap: () => _showNotebookOptions(notebook),
        );
      },
      onReorder: (oldIndex, newIndex) {
        context.read<NotebooksProvider>().reorderNotebooks(
              notebooks,
              oldIndex,
              newIndex,
            );
      },
    );
  }
}
