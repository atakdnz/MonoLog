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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const primary = Color(0xFF3b19e6);
    final cardBg = isDark ? const Color(0xFF1F1B2E) : Colors.white;
    final iconBg = isDark ? const Color(0xFF2A2447) : primary.withOpacity(0.1);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Done',
              style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Data Management Section
          _buildSectionHeader(context, 'DATA MANAGEMENT'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Column(
              children: [
                _buildSettingsItem(
                  context: context,
                  icon: Icons.delete_outline,
                  iconBg: iconBg,
                  title: 'Trash',
                  subtitle: 'Recover deleted entries',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                  },
                ),
                _buildDivider(context),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.ios_share,
                  iconBg: iconBg,
                  title: 'Export Data',
                  subtitle: 'Backup your journal',
                  onTap: () => _exportData(context),
                ),
                _buildDivider(context),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.download_outlined,
                  iconBg: iconBg,
                  title: 'Import Data',
                  subtitle: 'Restore from a previous backup',
                  onTap: () => _importData(context),
                ),
                _buildDivider(context),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.note_add_outlined,
                  iconBg: iconBg,
                  title: 'Import Single Notebook',
                  subtitle: 'Add notebook from exported file',
                  onTap: () => _importSingleNotebook(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader(context, 'APPEARANCE'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return _buildSettingsItem(
                  context: context,
                  icon: themeProvider.themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : themeProvider.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.brightness_auto,
                  iconBg: iconBg,
                  title: 'Dark Mode',
                  subtitle: 'Switch between Light and Dark',
                  trailing: Switch.adaptive(
                    value: themeProvider.themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      themeProvider.setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                    activeColor: primary,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader(context, 'ABOUT'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Column(
              children: [
                _buildSettingsItem(
                  context: context,
                  icon: Icons.info_outline,
                  iconBg: iconBg,
                  title: 'Version',
                  subtitle: '$appName v$appVersion',
                  showArrow: false,
                ),
              ],
            ),
          ),

          // Footer branding
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primary, Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  appName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFF9C93C8) : Colors.grey[600],
                  ),
                ),
                Text(
                  'Your private conversation.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? const Color(0xFF9C93C8).withOpacity(0.7)
                        : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool showArrow = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isDark ? Colors.white : const Color(0xFF3b19e6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? const Color(0xFF9C93C8)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else if (showArrow && onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Container(
        height: 1,
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
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

  Future<void> _importSingleNotebook(BuildContext context) async {
    final importService = ImportService();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Importing notebook...'),
          ],
        ),
      ),
    );

    try {
      final success = await importService.importSingleNotebookAsNew();

      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notebook imported successfully')),
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
}
