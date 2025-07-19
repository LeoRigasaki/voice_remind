// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  // Add a parameter to detect navigation method
  final bool isFromNavbar;

  const SettingsScreen({
    super.key,
    this.isFromNavbar = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeType _selectedTheme = ThemeService.currentTheme;

  // Update checker variables
  bool _autoCheckUpdates = true;
  bool _isCheckingForUpdates = false;
  String _lastUpdateCheck = 'Never';
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();

    // Listen to theme changes
    ThemeService.themeStream.listen((themeType) {
      if (mounted) {
        setState(() {
          _selectedTheme = themeType;
        });
      }
    });

    // Load update settings
    _loadUpdateSettings();
  }

  Future<void> _loadUpdateSettings() async {
    try {
      // Load update settings
      final autoCheck = await UpdateService.getAutoCheckEnabled();
      final lastCheck = await UpdateService.getLastCheckTime();

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();

      if (mounted) {
        setState(() {
          _autoCheckUpdates = autoCheck;
          _lastUpdateCheck = lastCheck;
          _currentVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('Failed to load update settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        // Only show back button if not from navbar OR if we can actually pop
        leading: widget.isFromNavbar
            ? null
            : (Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null),
        // Add automaticallyImplyLeading to prevent default back button
        automaticallyImplyLeading:
            !widget.isFromNavbar && Navigator.canPop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance'),
          const SizedBox(height: 8),
          _buildThemeDropdown(),

          const SizedBox(height: 32),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          const SizedBox(height: 8),
          _buildNotificationSettings(),

          const SizedBox(height: 32),

          // Voice Settings Section (for future)
          _buildSectionHeader('Voice'),
          const SizedBox(height: 8),
          _buildVoiceSettings(),

          const SizedBox(height: 32),

          // Data Section
          _buildSectionHeader('Data'),
          const SizedBox(height: 8),
          _buildDataSettings(),

          const SizedBox(height: 32),

          // App Updates Section
          _buildSectionHeader('App Updates'),
          const SizedBox(height: 8),
          _buildUpdateSettings(),

          const SizedBox(height: 32),

          // About Section
          _buildSectionHeader('About'),
          const SizedBox(height: 8),
          _buildAboutSettings(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
    );
  }

  Widget _buildUpdateSettings() {
    return Column(
      children: [
        // Check for Updates Button
        _buildSettingsTile(
          icon: _isCheckingForUpdates
              ? Icons.sync_rounded
              : Icons.system_update_alt_rounded,
          title: 'Check for Updates',
          subtitle: 'Current version: $_currentVersion',
          trailing: _isCheckingForUpdates
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isCheckingForUpdates ? null : _checkForUpdates,
          enabled: !_isCheckingForUpdates,
        ),

        const SizedBox(height: 8),

        // Auto-check Toggle
        _buildSwitchTile(
          icon: Icons.autorenew_rounded,
          title: 'Auto-check for Updates',
          subtitle: 'Check for updates automatically on app start',
          value: _autoCheckUpdates,
          onChanged: _toggleAutoCheck,
        ),

        const SizedBox(height: 8),

        // Last Check Time
        _buildSettingsTile(
          icon: Icons.history_rounded,
          title: 'Last Update Check',
          subtitle: _lastUpdateCheck,
          trailing: const Icon(Icons.info_outline, size: 16),
          enabled: false,
        ),

        const SizedBox(height: 8),

        // GitHub Releases Link
        _buildSettingsTile(
          icon: Icons.open_in_new_rounded,
          title: 'View All Releases',
          subtitle: 'Browse all versions on GitHub',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _openGitHubReleases,
        ),
      ],
    );
  }

  Widget _buildThemeDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ThemeType>(
            value: _selectedTheme,
            isExpanded: true,
            icon: const Icon(Icons.expand_more),
            onChanged: (ThemeType? newTheme) {
              if (newTheme != null) {
                setState(() {
                  _selectedTheme = newTheme;
                });
                ThemeService.setTheme(newTheme);
                HapticFeedback.lightImpact();
              }
            },
            items: ThemeType.values.map((ThemeType theme) {
              return DropdownMenuItem<ThemeType>(
                value: theme,
                child: Row(
                  children: [
                    Icon(
                      _getThemeIcon(theme),
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getThemeName(theme),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  IconData _getThemeIcon(ThemeType theme) {
    switch (theme) {
      case ThemeType.light:
        return Icons.light_mode_outlined;
      case ThemeType.dark:
        return Icons.dark_mode_outlined;
      case ThemeType.system:
        return Icons.brightness_auto_outlined;
    }
  }

  String _getThemeName(ThemeType theme) {
    switch (theme) {
      case ThemeType.light:
        return 'Light';
      case ThemeType.dark:
        return 'Dark';
      case ThemeType.system:
        return 'System';
    }
  }

  Widget _buildNotificationSettings() {
    return Column(
      children: [
        _buildSettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Reminder Notifications',
          subtitle: 'Coming soon...',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          enabled: false,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.schedule_outlined,
          title: 'Smart Timing',
          subtitle: 'Coming soon...',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          enabled: false,
        ),
      ],
    );
  }

  Widget _buildVoiceSettings() {
    return Column(
      children: [
        _buildSettingsTile(
          icon: Icons.mic_outlined,
          title: 'Voice Recognition',
          subtitle: 'Coming soon...',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          enabled: false,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.volume_up_outlined,
          title: 'Voice Playback',
          subtitle: 'Coming soon...',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          enabled: false,
        ),
      ],
    );
  }

  Widget _buildDataSettings() {
    return Column(
      children: [
        _buildSettingsTile(
          icon: Icons.upload_outlined,
          title: 'Export Data',
          subtitle: 'Export your reminders',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // TODO: Implement data export
            _showComingSoonSnackBar('Export data');
          },
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.download_outlined,
          title: 'Import Data',
          subtitle: 'Import reminders from file',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // TODO: Implement data import
            _showComingSoonSnackBar('Import data');
          },
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.delete_outline,
          title: 'Clear All Data',
          subtitle: 'Delete all reminders',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          textColor: Theme.of(context).colorScheme.error,
          onTap: () {
            _showClearDataDialog();
          },
        ),
      ],
    );
  }

  Widget _buildAboutSettings() {
    return Column(
      children: [
        _buildSettingsTile(
          icon: Icons.info_outline,
          title: 'App Information',
          subtitle: 'Version, build info, and credits',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            _showAboutDialog();
          },
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help using VoiceRemind',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            _showComingSoonSnackBar('Help & Support');
          },
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'How we handle your data',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            _showComingSoonSnackBar('Privacy Policy');
          },
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        enabled: enabled,
        leading: Icon(
          icon,
          color: enabled
              ? (textColor ?? Theme.of(context).colorScheme.primary)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: enabled
                ? (textColor ?? Theme.of(context).colorScheme.onSurface)
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
          ),
        ),
        trailing: trailing,
        onTap: enabled ? onTap : null,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: SwitchListTile(
        secondary: Icon(
          icon,
          color: enabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
          ),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Update-related methods
  Future<void> _checkForUpdates() async {
    if (_isCheckingForUpdates) return;

    setState(() {
      _isCheckingForUpdates = true;
    });

    HapticFeedback.lightImpact();

    try {
      final result = await UpdateService.checkForUpdates();

      if (mounted) {
        setState(() {
          _isCheckingForUpdates = false;
          _lastUpdateCheck = 'Just now';
        });

        if (result.success) {
          await UpdateDialog.show(context, result, isManualCheck: true);
        } else {
          await UpdateErrorDialog.show(
              context, result.error ?? 'Unknown error');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingForUpdates = false;
        });
        await UpdateErrorDialog.show(
            context, 'Failed to check for updates: $e');
      }
    }
  }

  Future<void> _toggleAutoCheck(bool value) async {
    HapticFeedback.lightImpact();

    setState(() {
      _autoCheckUpdates = value;
    });

    await UpdateService.setAutoCheckEnabled(value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Auto-check enabled. App will check for updates daily.'
                : 'Auto-check disabled.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _openGitHubReleases() async {
    HapticFeedback.lightImpact();

    try {
      final url = UpdateService.getReleasesUrl();
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: show dialog with URL
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('GitHub Releases'),
              content: SelectableText(url),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open releases page: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  // Existing methods (kept intact)
  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Data'),
          content: const Text(
            'This will permanently delete all your reminders. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implement clear all data
                _showComingSoonSnackBar('Clear all data');
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'VoiceRemind',
      applicationVersion: _currentVersion,
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.primary,
        ),
        child: Icon(
          Icons.mic,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 32,
        ),
      ),
      children: [
        const Text(
          'A beautiful voice-first reminder application built with Flutter. '
          'VoiceRemind helps you create and manage reminders through natural speech.',
        ),
      ],
    );
  }
}
