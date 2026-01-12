import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../utils/constants.dart';
import 'trash_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Trash
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            title: const Text('Trash'),
            subtitle: const Text('View and restore deleted entries'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              );
            },
          ),

          const Divider(height: 32),

          // Export/Import section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'DATA',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.upload_file,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: const Text('Export All Data'),
            subtitle: const Text('Create a backup of all notebooks'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportData(context),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.download,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: const Text('Import Data'),
            subtitle: const Text('Restore from a backup file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _importData(context),
          ),

          const Divider(height: 32),

          // Appearance section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'APPEARANCE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),

          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    themeProvider.themeMode == ThemeMode.dark
                        ? Icons.dark_mode
                        : themeProvider.themeMode == ThemeMode.light
                        ? Icons.light_mode
                        : Icons.brightness_auto,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                title: const Text('Theme'),
                subtitle: Text(
                  themeProvider.themeMode == ThemeMode.dark
                      ? 'Dark'
                      : themeProvider.themeMode == ThemeMode.light
                      ? 'Light'
                      : 'System',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context),
              );
            },
          ),

          const Divider(height: 32),

          // About section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'ABOUT',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            title: const Text(appName),
            subtitle: Text('Version $appVersion'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              subtitle: const Text('Follow device settings'),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                themeProvider.setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                themeProvider.setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                themeProvider.setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Exporting data...'),
          ],
        ),
      ),
    );

    try {
      final exportService = ExportService();
      final filePath = await exportService.exportAllData();

      Navigator.pop(context); // Close loading dialog

      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data exported successfully'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => exportService.shareExport(filePath),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Export failed')));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importData(BuildContext context) async {
    final importService = ImportService();

    // Show options dialog
    final mergeOption = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text('How would you like to handle existing data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );

    if (mergeOption == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Importing data...'),
          ],
        ),
      ),
    );

    try {
      final success = await importService.importData(merge: mergeOption);

      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data imported successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import cancelled or failed')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: appName,
      applicationVersion: appVersion,
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.book,
          size: 32,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        const Text(
          'A journal-style note-taking app with messaging-style input for capturing daily moments.',
        ),
      ],
    );
  }
}
