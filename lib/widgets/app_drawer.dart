import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/folder.dart';
import '../providers/folders_provider.dart';
import '../providers/notebooks_provider.dart';
import '../screens/archived_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/trash_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FoldersProvider>().loadFolders();
    });
  }

  void _navigateToSettings() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _navigateToTrash() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrashScreen()),
    );
  }

  void _navigateToArchived() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArchivedScreen()),
    );
  }

  void _selectFolder(String? folderId) {
    context.read<FoldersProvider>().selectFolder(folderId);
    context.read<NotebooksProvider>().setFolderId(folderId);
    context.read<NotebooksProvider>().loadNotebooks();
    Navigator.pop(context);
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await context.read<FoldersProvider>().createFolder(name: name);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showFolderOptions(Folder folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameFolderDialog(folder);
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
                _showDeleteFolderConfirmation(folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameFolderDialog(Folder folder) {
    final controller = TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Folder Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await context.read<FoldersProvider>().updateFolder(
                folder.copyWith(name: name),
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderConfirmation(Folder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text(
          '"${folder.name}" will be deleted. Notebooks in this folder will not be deleted, they will return to the main list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              context.read<FoldersProvider>().deleteFolder(folder.id);
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
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  Text(
                    'Folders',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _showCreateFolderDialog,
                    tooltip: 'New Folder',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: Consumer<FoldersProvider>(
                builder: (context, foldersProvider, _) {
                  if (foldersProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // All Notebooks (no folder)
                      _buildDrawerItem(
                        icon: Icons.book_outlined,
                        label: 'All Notebooks',
                        isSelected: foldersProvider.isShowingAll,
                        onTap: () => _selectFolder(null),
                      ),

                      // Folders section
                      if (foldersProvider.folders.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'FOLDERS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ...foldersProvider.folders.map(
                          (folder) => _buildFolderItem(folder, foldersProvider),
                        ),
                      ],

                      const Divider(height: 24),

                      // Archived
                      _buildDrawerItem(
                        icon: Icons.archive_outlined,
                        label: 'Archived',
                        onTap: _navigateToArchived,
                      ),

                      // Trash
                      _buildDrawerItem(
                        icon: Icons.delete_outline,
                        label: 'Trash',
                        onTap: _navigateToTrash,
                      ),

                      const Divider(height: 24),

                      // Settings
                      _buildDrawerItem(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: _navigateToSettings,
                      ),
                    ],
                  );
                },
              ),
            ),

            // Footer branding
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3b19e6), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_note,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'MonoLog',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? theme.colorScheme.primary
            : isDark
            ? Colors.grey[400]
            : Colors.grey[600],
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
      onTap: onTap,
    );
  }

  Widget _buildFolderItem(Folder folder, FoldersProvider provider) {
    final theme = Theme.of(context);
    final isSelected = provider.selectedFolderId == folder.id;
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        Icons.folder_outlined,
        color: isSelected
            ? theme.colorScheme.primary
            : isDark
            ? Colors.grey[400]
            : Colors.grey[600],
      ),
      title: Text(
        folder.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, size: 20),
        onPressed: () => _showFolderOptions(folder),
      ),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
      onTap: () => _selectFolder(folder.id),
    );
  }
}
