// [lib/screens]/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';
import '../services/ai_reminder_service.dart';
import '../services/storage_service.dart';
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

  // AI Configuration variables
  String _selectedAIProvider = 'none';
  bool _hasGeminiKey = false;
  bool _hasGroqKey = false;
  String _geminiKeyStatus = 'Not configured';
  String _groqKeyStatus = 'Not configured';

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

    // Load AI settings
    _loadAISettings();
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

  Future<void> _loadAISettings() async {
    try {
      final geminiKey = await StorageService.getGeminiApiKey();
      final groqKey = await StorageService.getGroqApiKey();
      final selectedProvider = await StorageService.getSelectedAIProvider();

      if (mounted) {
        setState(() {
          _hasGeminiKey = geminiKey?.isNotEmpty == true;
          _hasGroqKey = groqKey?.isNotEmpty == true;
          _selectedAIProvider = selectedProvider ?? 'none';

          _geminiKeyStatus = _hasGeminiKey
              ? 'Configured (${geminiKey!.substring(0, 8)}...)'
              : 'Not configured';
          _groqKeyStatus = _hasGroqKey
              ? 'Configured (${groqKey!.substring(0, 8)}...)'
              : 'Not configured';
        });
      }
    } catch (e) {
      debugPrint('Failed to load AI settings: $e');
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
          // AI Settings Section
          _buildSectionHeader('AI Configuration'),
          const SizedBox(height: 8),
          _buildAISettings(),

          const SizedBox(height: 32),

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

  Widget _buildAISettings() {
    return Column(
      children: [
        // AI Provider Selection
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAIProvider,
                isExpanded: true,
                icon: const Icon(Icons.expand_more),
                hint: const Text('Select AI Provider'),
                onChanged: (String? newProvider) {
                  if (newProvider != null) {
                    _updateAIProvider(newProvider);
                  }
                },
                items: [
                  DropdownMenuItem<String>(
                    value: 'none',
                    child: Row(
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'No AI Provider',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'gemini',
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 20,
                          color: _hasGeminiKey
                              ? Colors.green
                              : Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Google Gemini',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (_hasGeminiKey) ...[
                          const Spacer(),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'groq',
                    child: Row(
                      children: [
                        Icon(
                          Icons.flash_on,
                          size: 20,
                          color: _hasGroqKey
                              ? Colors.blue
                              : Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Groq',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (_hasGroqKey) ...[
                          const Spacer(),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ].map((item) {
                  return DropdownMenuItem<String>(
                    value: item.value,
                    child: item.child,
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Gemini API Key Configuration
        _buildSettingsTile(
          icon: Icons.auto_awesome,
          title: 'Gemini API Key',
          subtitle: _geminiKeyStatus,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasGeminiKey)
                IconButton(
                  onPressed: () => _removeApiKey('gemini'),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              IconButton(
                onPressed: () => _showAPIKeyDialog('gemini'),
                icon: Icon(
                  _hasGeminiKey ? Icons.edit : Icons.add,
                  size: 20,
                ),
              ),
            ],
          ),
          onTap: () => _showAPIKeyDialog('gemini'),
        ),

        const SizedBox(height: 8),

        // Groq API Key Configuration
        _buildSettingsTile(
          icon: Icons.flash_on,
          title: 'Groq API Key',
          subtitle: _groqKeyStatus,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasGroqKey)
                IconButton(
                  onPressed: () => _removeApiKey('groq'),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              IconButton(
                onPressed: () => _showAPIKeyDialog('groq'),
                icon: Icon(
                  _hasGroqKey ? Icons.edit : Icons.add,
                  size: 20,
                ),
              ),
            ],
          ),
          onTap: () => _showAPIKeyDialog('groq'),
        ),

        const SizedBox(height: 8),

        // Get API Keys Help
        _buildSettingsTile(
          icon: Icons.help_outline,
          title: 'How to get API Keys',
          subtitle: 'Free guide to obtain Gemini & Groq API keys',
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: _showAPIKeyHelpDialog,
        ),

        const SizedBox(height: 8),

        // Test AI Connection
        if (_selectedAIProvider != 'none')
          _buildSettingsTile(
            icon: Icons.network_check,
            title: 'Test AI Connection',
            subtitle: 'Verify your API key is working',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _testAIConnection,
          ),
      ],
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

  // AI Configuration Methods
  Future<void> _updateAIProvider(String provider) async {
    setState(() {
      _selectedAIProvider = provider;
    });

    await StorageService.setSelectedAIProvider(provider);

    if (provider != 'none') {
      // Check if the selected provider has an API key
      bool hasKey = false;
      if (provider == 'gemini' && _hasGeminiKey) {
        hasKey = true;
      } else if (provider == 'groq' && _hasGroqKey) {
        hasKey = true;
      }

      if (hasKey) {
        // Reinitialize AI service with selected provider
        try {
          await AIReminderService.reinitializeWithStoredKeys();
          _showSuccessSnackBar(
              'AI provider updated to ${provider.toUpperCase()}');
        } catch (e) {
          _showErrorSnackBar('Failed to initialize $provider: $e');
          setState(() {
            _selectedAIProvider = 'none';
          });
        }
      } else {
        // Prompt user to add API key
        _showAPIKeyDialog(provider);
      }
    } else {
      _showSuccessSnackBar('AI features disabled');
    }

    HapticFeedback.lightImpact();
  }

  Future<void> _showAPIKeyDialog(String provider) async {
    final controller = TextEditingController();
    final isEdit = provider == 'gemini' ? _hasGeminiKey : _hasGroqKey;
    bool obscureText = !isEdit; // Show text when editing, hide when adding new

    if (isEdit) {
      // Load existing key for editing
      final existingKey = provider == 'gemini'
          ? await StorageService.getGeminiApiKey()
          : await StorageService.getGroqApiKey();
      controller.text = existingKey ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
                '${isEdit ? 'Edit' : 'Add'} ${provider.toUpperCase()} API Key'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider == 'gemini' ? 'Enter your Google Gemini' : 'Enter your Groq'} API key:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText:
                        'Paste your ${provider.toUpperCase()} API key here',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: !isEdit
                        ? IconButton(
                            icon: Icon(
                              obscureText
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 20,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureText = !obscureText;
                              });
                            },
                          )
                        : null,
                  ),
                  obscureText: obscureText,
                  maxLines: 1, // API keys are single line
                  keyboardType: TextInputType.visiblePassword,
                ),
                const SizedBox(height: 16),
                Text(
                  '💡 Your API key is stored securely on your device and never shared.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final apiKey = controller.text.trim();
                  if (apiKey.isEmpty) {
                    _showErrorSnackBar('Please enter a valid API key');
                    return;
                  }

                  Navigator.pop(context);
                  await _saveAPIKey(provider, apiKey);
                },
                child: Text(isEdit ? 'Update' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAPIKey(String provider, String apiKey) async {
    try {
      if (provider == 'gemini') {
        await StorageService.setGeminiApiKey(apiKey);
      } else {
        await StorageService.setGroqApiKey(apiKey);
      }

      // Update the selected provider if not already set
      if (_selectedAIProvider == 'none') {
        await StorageService.setSelectedAIProvider(provider);
        setState(() {
          _selectedAIProvider = provider;
        });
      }

      // Reinitialize AI service
      await AIReminderService.reinitializeWithStoredKeys();

      await _loadAISettings(); // Refresh the UI

      _showSuccessSnackBar(
          '${provider.toUpperCase()} API key saved and configured!');
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showErrorSnackBar('Failed to save API key: $e');
    }
  }

  Future<void> _removeApiKey(String provider) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${provider.toUpperCase()} API Key'),
        content: Text(
          'Are you sure you want to remove your ${provider.toUpperCase()} API key? You\'ll need to add it again to use AI features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              if (provider == 'gemini') {
                await StorageService.setGeminiApiKey(null);
              } else {
                await StorageService.setGroqApiKey(null);
              }

              // If this was the selected provider, switch to none
              if (_selectedAIProvider == provider) {
                await StorageService.setSelectedAIProvider('none');
                setState(() {
                  _selectedAIProvider = 'none';
                });
              }

              await _loadAISettings();
              _showSuccessSnackBar('${provider.toUpperCase()} API key removed');
              HapticFeedback.lightImpact();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAIConnection() async {
    if (_selectedAIProvider == 'none') {
      _showErrorSnackBar('Please select an AI provider first');
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testing AI connection...'),
          ],
        ),
      ),
    );

    try {
      final response = await AIReminderService.parseRemindersFromText(
          'Test reminder for tomorrow at 9am');

      Navigator.pop(context); // Close loading dialog

      if (response.reminders.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Connection Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${_selectedAIProvider.toUpperCase()} is working correctly!'),
                const SizedBox(height: 16),
                Text('Generated test reminder:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '• ${response.reminders.first.title}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Great!'),
              ),
            ],
          ),
        );
        HapticFeedback.mediumImpact();
      } else {
        _showErrorSnackBar('Connection successful but no reminders generated');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorSnackBar('Connection failed: ${e.toString()}');
    }
  }

  void _showAPIKeyHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Get Free API Keys'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAPIKeyStep(
                title: '🟡 Google Gemini (Recommended)',
                steps: [
                  '1. Go to ai.google.dev',
                  '2. Click "Get API key"',
                  '3. Sign in with Google account',
                  '4. Create new project or select existing',
                  '5. Generate API key',
                  '6. Copy the key and paste it here',
                ],
                benefits: 'Free tier: 15 requests/minute',
              ),
              const SizedBox(height: 20),
              _buildAPIKeyStep(
                title: '🔵 Groq (Fastest)',
                steps: [
                  '1. Visit console.groq.com',
                  '2. Sign up for free account',
                  '3. Go to API Keys section',
                  '4. Create new API key',
                  '5. Copy the key and paste it here',
                ],
                benefits: 'Free tier: 14,400 requests/day',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔒 Privacy & Security',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• API keys are stored locally on your device\n'
                      '• Keys are never shared or uploaded\n'
                      '• You have full control over your data',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse('https://aistudio.google.com/apikey');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Open Gemini'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse('https://console.groq.com/keys');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Open Groq'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAPIKeyStep({
    required String title,
    required List<String> steps,
    required String benefits,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              step,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            benefits,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
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

  // Helper methods for showing messages
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
