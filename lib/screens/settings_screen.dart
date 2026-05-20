import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_lock_provider.dart';
import '../providers/theme_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../utils/constants.dart';
import 'trash_screen.dart';

enum _ExportDataChoice { plainZip, encryptedBackup }

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
                final isDarkModeEnabled =
                    Theme.of(context).brightness == Brightness.dark;

                return Column(
                  children: [
                    _buildSettingsItem(
                      context: context,
                      icon: isDarkModeEnabled ? Icons.dark_mode : Icons.light_mode,
                      iconBg: iconBg,
                      title: isDarkModeEnabled ? 'Dark Mode' : 'Light Mode',
                      subtitle: 'Switch between Light and Dark',
                      trailing: Switch.adaptive(
                        value: isDarkModeEnabled,
                        onChanged: (value) {
                          themeProvider.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                        activeColor: primary,
                      ),
                    ),
                    _buildDivider(context),
                    _buildSettingsItem(
                      context: context,
                      icon: Icons.text_fields,
                      iconBg: iconBg,
                      title: 'Font Size',
                      subtitle: themeProvider.fontSizeOption.displayName,
                      onTap: () => _showFontSizeBottomSheet(context, themeProvider),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Privacy Section
          _buildSectionHeader(context, 'PRIVACY'),
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
            child: Consumer<AppLockProvider>(
              builder: (context, appLock, _) {
                final subtitle = appLock.canAuthenticate
                    ? 'Require biometrics or device passcode'
                    : 'Set up biometrics or device passcode first';

                return _buildSettingsItem(
                  context: context,
                  icon: Icons.lock_outline,
                  iconBg: iconBg,
                  title: 'App Lock',
                  subtitle: subtitle,
                  trailing: Switch.adaptive(
                    value: appLock.isEnabled,
                    onChanged: appLock.isAuthenticating
                        ? null
                        : (value) => _setAppLock(context, value),
                    activeThumbColor: primary,
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

  Future<void> _setAppLock(BuildContext context, bool enabled) async {
    final appLock = context.read<AppLockProvider>();

    if (!enabled) {
      await appLock.disableAppLock();
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('App Lock disabled')));
      return;
    }

    final success = await appLock.enableAppLock();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'App Lock enabled'
              : 'Could not enable App Lock on this device',
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final choice = await _showExportChoiceDialog(context);
    if (!context.mounted) return;
    if (choice == null) return;

    String? password;
    if (choice == _ExportDataChoice.encryptedBackup) {
      password = await _showCreateBackupPasswordDialog(context);
      if (!context.mounted) return;
      if (password == null) return;
    }

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
      final filePath = choice == _ExportDataChoice.encryptedBackup
          ? await exportService.exportAllDataEncrypted(password: password!)
          : await exportService.exportAllData();

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              choice == _ExportDataChoice.encryptedBackup
                  ? 'Encrypted backup exported successfully'
                  : 'Data exported successfully',
            ),
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
      if (!context.mounted) return;
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

    if (!context.mounted) return;
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
      final result = await importService.importData(
        merge: mergeOption,
        encryptedPasswordProvider: () => _showImportPasswordDialog(context),
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      final message = switch (result) {
        ImportDataResult.success => 'Data imported successfully',
        ImportDataResult.cancelled => 'Import cancelled',
        ImportDataResult.invalidPassword =>
          'Import failed or password is incorrect',
        ImportDataResult.passwordRequired =>
          'Password is required for encrypted backups',
        ImportDataResult.failed => 'Import cancelled or failed',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<_ExportDataChoice?> _showExportChoiceDialog(
    BuildContext context,
  ) async {
    return showDialog<_ExportDataChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Choose a backup format.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ExportDataChoice.plainZip),
            child: const Text('Plain ZIP'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _ExportDataChoice.encryptedBackup),
            child: const Text('Encrypted Backup'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCreateBackupPasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Encrypt Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a password for this backup. If you forget it, the backup cannot be recovered.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final password = passwordController.text;
                final confirm = confirmController.text;
                if (password.isEmpty) {
                  setState(() => errorText = 'Enter a password');
                  return;
                }
                if (password != confirm) {
                  setState(() => errorText = 'Passwords do not match');
                  return;
                }
                Navigator.pop(context, password);
              },
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
    return password;
  }

  Future<String?> _showImportPasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    String? errorText;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Encrypted Backup'),
          content: TextField(
            controller: passwordController,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final password = passwordController.text;
                if (password.isEmpty) {
                  setState(() => errorText = 'Enter the backup password');
                  return;
                }
                Navigator.pop(context, password);
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    return password;
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

  void _showFontSizeBottomSheet(BuildContext context, ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF3b19e6);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer<ThemeProvider>(
          builder: (context, provider, _) {
            final scale = provider.fontSizeScaleFactor;
            final option = provider.fontSizeOption;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Title
                    Text(
                      'Font Size',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Preview Bubble Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141121) : const Color(0xFFF6F6F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREVIEW',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white38 : Colors.black38,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? primary : primary.withOpacity(0.12),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                  bottomRight: Radius.circular(4),
                                ),
                              ),
                              child: Text(
                                'This is a preview of the text size. Slide below to adjust.',
                                style: TextStyle(
                                  fontSize: 14.0 * scale,
                                  color: isDark ? Colors.white : const Color(0xFF1F1B2E),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Slider controls (A- on left, A+ on right)
                    Row(
                      children: [
                        Text(
                          'A',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        Expanded(
                          child: Slider.adaptive(
                            value: option.index.toDouble(),
                            min: 0.0,
                            max: (FontSizeOption.values.length - 1).toDouble(),
                            divisions: FontSizeOption.values.length - 1,
                            activeColor: primary,
                            inactiveColor: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1),
                            onChanged: (value) {
                              final newOption = FontSizeOption.values[value.toInt()];
                              provider.setFontSizeOption(newOption);
                            },
                          ),
                        ),
                        Text(
                          'A',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Selected size label
                    Text(
                      '${option.displayName}${option == FontSizeOption.medium ? " (Default)" : ""}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF9C93C8) : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
