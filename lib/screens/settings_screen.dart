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
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
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

  // Default Tab variables
  String _defaultReminderTab = 'Manual';
  bool _snoozeUseCustom = false;
  int _snoozeCustomMinutes = 15;

  bool _useAlarmInsteadOfNotification = false;

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

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await Future.wait([
      _loadUpdateSettings(),
      _loadAISettings(),
      _loadDefaultTabSettings(),
      _loadSnoozeSettings(),
      _loadAlarmSettings(),
    ]);
  }

  Future<void> _loadUpdateSettings() async {
    try {
      final autoCheck = await UpdateService.getAutoCheckEnabled();
      final lastCheck = await UpdateService.getLastCheckTime();
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
        });
      }
    } catch (e) {
      debugPrint('Failed to load AI settings: $e');
    }
  }

  Future<void> _loadDefaultTabSettings() async {
    try {
      final defaultTab = await StorageService.getDefaultReminderTabMode();
      if (mounted) {
        setState(() {
          _defaultReminderTab = defaultTab;
        });
      }
    } catch (e) {
      debugPrint('Failed to load default tab settings: $e');
    }
  }

  Future<void> _loadSnoozeSettings() async {
    try {
      final useCustom = await StorageService.getSnoozeUseCustom();
      final customMinutes = await StorageService.getSnoozeCustomMinutes();
      if (mounted) {
        setState(() {
          _snoozeUseCustom = useCustom;
          _snoozeCustomMinutes = customMinutes;
        });
      }
    } catch (e) {
      debugPrint('Failed to load snooze settings: $e');
    }
  }

  Future<void> _loadAlarmSettings() async {
    try {
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();
      if (mounted) {
        setState(() {
          _useAlarmInsteadOfNotification = useAlarm;
        });
      }
    } catch (e) {
      debugPrint('Failed to load alarm settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: widget.isFromNavbar
            ? null
            : (Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null),
        automaticallyImplyLeading:
            !widget.isFromNavbar && Navigator.canPop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // AI Configuration
          _buildCleanSettingTile(
            icon: Icons.auto_awesome,
            title: 'AI Configuration',
            subtitle: _getAIStatusText(),
            onTap: () => _navigateToAISettings(),
          ),

          const SizedBox(height: 8),

          // Default Reminder Creation
          _buildCleanSettingTile(
            icon: Icons.add_circle_outline,
            title: 'Default Reminder Creation',
            subtitle: 'Opens $_defaultReminderTab tab by default',
            onTap: () => _navigateToDefaultTabSettings(),
          ),

          const SizedBox(height: 8),

          // Appearance
          _buildCleanSettingTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Change the vibe of your app',
            onTap: () => _navigateToAppearanceSettings(),
          ),

          const SizedBox(height: 8),

          // Notifications
          _buildCleanSettingTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Reminder and alert settings',
            onTap: () => _showComingSoonSnackBar('Notifications'),
          ),

          const SizedBox(height: 8),

          // Alarm Mode
          _buildCleanSettingTile(
            icon: Icons.alarm,
            title: 'Alarm Mode',
            subtitle: _getAlarmModeStatusText(),
            onTap: () => _navigateToAlarmSettings(),
          ),

          const SizedBox(height: 8),
          // Snooze Duration
          _buildCleanSettingTile(
            icon: Icons.snooze_outlined,
            title: 'Snooze Duration',
            subtitle: _getSnoozeStatusText(),
            onTap: () => _navigateToSnoozeSettings(),
          ),

          const SizedBox(height: 8),

          // Voice Settings
          _buildCleanSettingTile(
            icon: Icons.mic_outlined,
            title: 'Voice',
            subtitle: 'Voice recognition and playback',
            onTap: () => _showComingSoonSnackBar('Voice settings'),
          ),

          const SizedBox(height: 8),

          // Data Management
          _buildCleanSettingTile(
            icon: Icons.storage_outlined,
            title: 'Data',
            subtitle: 'Export, import, and manage your data',
            onTap: () => _navigateToDataSettings(),
          ),

          const SizedBox(height: 8),

          // App Updates
          _buildCleanSettingTile(
            icon: Icons.system_update_alt_outlined,
            title: 'App Updates',
            subtitle: 'Version $_currentVersion • Check for updates',
            onTap: () => _navigateToUpdateSettings(),
          ),

          const SizedBox(height: 8),

          // About
          _buildCleanSettingTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App info, help, and privacy',
            onTap: () => _navigateToAboutSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        icon,
        size: 24,
        color: enabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: enabled
                  ? Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
            ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      onTap: enabled ? onTap : null,
    );
  }

  String _getAIStatusText() {
    if (_selectedAIProvider == 'none') {
      return 'No AI provider selected';
    } else if (_selectedAIProvider == 'gemini' && _hasGeminiKey) {
      return 'Google Gemini configured';
    } else if (_selectedAIProvider == 'groq' && _hasGroqKey) {
      return 'Groq configured';
    } else {
      return '${_selectedAIProvider.toUpperCase()} - needs API key';
    }
  }

  String _getAlarmModeStatusText() {
    if (_useAlarmInsteadOfNotification) {
      return 'Mixed mode: Full-screen when idle, notifications when busy with other apps';
    } else {
      return 'Notifications enabled (shows notification with dismiss/snooze)';
    }
  }

  // Navigation methods
  void _navigateToAISettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AISettingsPage(
          selectedProvider: _selectedAIProvider,
          hasGeminiKey: _hasGeminiKey,
          hasGroqKey: _hasGroqKey,
          onProviderChanged: (provider) {
            setState(() {
              _selectedAIProvider = provider;
            });
          },
          onKeysChanged: () {
            _loadAISettings();
          },
        ),
      ),
    );
  }

  void _navigateToDefaultTabSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _DefaultTabSettingsPage(
          selectedTab: _defaultReminderTab,
          onTabChanged: (tab) {
            setState(() {
              _defaultReminderTab = tab;
            });
          },
        ),
      ),
    );
  }

  void _navigateToAppearanceSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AppearanceSettingsPage(
          selectedTheme: _selectedTheme,
          onThemeChanged: (theme) {
            setState(() {
              _selectedTheme = theme;
            });
            ThemeService.setTheme(theme);
            HapticFeedback.lightImpact();
          },
        ),
      ),
    );
  }

  void _navigateToDataSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const _DataSettingsPage(),
      ),
    );
  }

  void _navigateToUpdateSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _UpdateSettingsPage(
          currentVersion: _currentVersion,
          autoCheckUpdates: _autoCheckUpdates,
          lastUpdateCheck: _lastUpdateCheck,
          isCheckingForUpdates: _isCheckingForUpdates,
          onAutoCheckChanged: (value) {
            setState(() {
              _autoCheckUpdates = value;
            });
            _toggleAutoCheck(value);
          },
          onCheckForUpdates: _checkForUpdates,
        ),
      ),
    );
  }

  void _navigateToAboutSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AboutSettingsPage(
          currentVersion: _currentVersion,
        ),
      ),
    );
  }

  String _getSnoozeStatusText() {
    if (_snoozeUseCustom) {
      return 'Custom: $_snoozeCustomMinutes minutes';
    } else {
      return 'Default: 10min, 1hour';
    }
  }

  void _navigateToSnoozeSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _SnoozeSettingsPage(
          useCustom: _snoozeUseCustom,
          customMinutes: _snoozeCustomMinutes,
          onSnoozeChanged: (useCustom, customMinutes) {
            setState(() {
              _snoozeUseCustom = useCustom;
              _snoozeCustomMinutes = customMinutes;
            });
          },
        ),
      ),
    );
  }

  void _navigateToAlarmSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AlarmSettingsPage(
          useAlarm: _useAlarmInsteadOfNotification,
          onAlarmChanged: (useAlarm) {
            setState(() {
              _useAlarmInsteadOfNotification = useAlarm;
            });
          },
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

  // Helper methods
  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Default Tab Settings Page
class _DefaultTabSettingsPage extends StatefulWidget {
  final String selectedTab;
  final Function(String) onTabChanged;

  const _DefaultTabSettingsPage({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  State<_DefaultTabSettingsPage> createState() =>
      _DefaultTabSettingsPageState();
}

class _DefaultTabSettingsPageState extends State<_DefaultTabSettingsPage> {
  late String _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.selectedTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Default Reminder Creation'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Text(
            'Choose Default Tab',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select which tab should open by default when you tap the + button to create a new reminder.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 24),

          // Manual option
          _buildTabOptionTile(
            icon: Icons.edit_outlined,
            title: 'Manual',
            subtitle: 'Create reminders by filling out forms',
            value: 'Manual',
            description:
                'Perfect for precise control over reminder details, scheduling, and repeat options.',
          ),

          const SizedBox(height: 8),

          // AI Text option
          _buildTabOptionTile(
            icon: Icons.auto_awesome,
            title: 'AI Text',
            subtitle: 'Type naturally and let AI create reminders',
            value: 'AI Text',
            description:
                'Great for creating multiple reminders quickly from natural language descriptions.',
          ),

          const SizedBox(height: 8),

          // Voice option
          _buildTabOptionTile(
            icon: Icons.mic_outlined,
            title: 'Voice',
            subtitle: 'Speak your reminders out loud',
            value: 'Voice',
            description:
                'Ideal for hands-free reminder creation while you\'re busy or on the go.',
          ),
        ],
      ),
    );
  }

  Widget _buildTabOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String description,
  }) {
    final isSelected = _selectedTab == value;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          icon,
          size: 28,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                height: 1.3,
              ),
            ),
          ],
        ),
        trailing: Radio<String>(
          value: value,
          groupValue: _selectedTab,
          onChanged: (String? newValue) {
            if (newValue != null) {
              _updateDefaultTab(newValue);
            }
          },
        ),
        onTap: () => _updateDefaultTab(value),
      ),
    );
  }

  Future<void> _updateDefaultTab(String newTab) async {
    setState(() {
      _selectedTab = newTab;
    });

    try {
      await StorageService.setDefaultReminderTabByMode(newTab);
      widget.onTabChanged(newTab);

      HapticFeedback.lightImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Default reminder creation set to $newTab'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preference: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }
}

// AI Settings Page
class _AISettingsPage extends StatefulWidget {
  final String selectedProvider;
  final bool hasGeminiKey;
  final bool hasGroqKey;
  final Function(String) onProviderChanged;
  final VoidCallback onKeysChanged;

  const _AISettingsPage({
    required this.selectedProvider,
    required this.hasGeminiKey,
    required this.hasGroqKey,
    required this.onProviderChanged,
    required this.onKeysChanged,
  });

  @override
  State<_AISettingsPage> createState() => _AISettingsPageState();
}

class _AISettingsPageState extends State<_AISettingsPage> {
  late String _selectedProvider;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.selectedProvider;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Configuration'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // AI Provider Selection
          Text(
            'AI Provider',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),

          // None option
          _buildProviderTile(
            icon: Icons.cancel_outlined,
            title: 'No AI Provider',
            subtitle: 'Disable AI features',
            value: 'none',
            isSelected: _selectedProvider == 'none',
            statusColor: Colors.grey,
          ),

          const SizedBox(height: 4),

          // Gemini option
          _buildProviderTile(
            icon: Icons.auto_awesome,
            title: 'Google Gemini',
            subtitle: widget.hasGeminiKey ? 'Configured' : 'Needs API key',
            value: 'gemini',
            isSelected: _selectedProvider == 'gemini',
            statusColor: widget.hasGeminiKey ? Colors.green : Colors.orange,
            hasKey: widget.hasGeminiKey,
          ),

          const SizedBox(height: 4),

          // Groq option
          _buildProviderTile(
            icon: Icons.flash_on,
            title: 'Groq',
            subtitle: widget.hasGroqKey ? 'Configured' : 'Needs API key',
            value: 'groq',
            isSelected: _selectedProvider == 'groq',
            statusColor: widget.hasGroqKey ? Colors.green : Colors.orange,
            hasKey: widget.hasGroqKey,
          ),

          const SizedBox(height: 24),

          // API Key Management
          Text(
            'API Key Management',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),

          // Gemini API Key
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.auto_awesome, size: 24),
            title: const Text('Gemini API Key'),
            subtitle: Text(widget.hasGeminiKey
                ? 'Configured'
                : 'Add your Google Gemini API key'),
            trailing: Icon(
              widget.hasGeminiKey ? Icons.edit : Icons.add,
              size: 20,
            ),
            onTap: () => _showAPIKeyBottomSheet('gemini'),
          ),

          const SizedBox(height: 4),

          // Groq API Key
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.flash_on, size: 24),
            title: const Text('Groq API Key'),
            subtitle: Text(
                widget.hasGroqKey ? 'Configured' : 'Add your Groq API key'),
            trailing: Icon(
              widget.hasGroqKey ? Icons.edit : Icons.add,
              size: 20,
            ),
            onTap: () => _showAPIKeyBottomSheet('groq'),
          ),

          const SizedBox(height: 4),

          // Help
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.help_outline, size: 24),
            title: const Text('How to get API Keys'),
            subtitle: const Text('Free guide to obtain API keys'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: _showAPIKeyHelpDialog,
          ),

          if (_selectedProvider != 'none') ...[
            const SizedBox(height: 4),

            // Test Connection
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.network_check, size: 24),
              title: const Text('Test AI Connection'),
              subtitle: const Text('Verify your API key is working'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _testAIConnection,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required bool isSelected,
    required Color statusColor,
    bool hasKey = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        icon,
        size: 24,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasKey) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Radio<String>(
            value: value,
            groupValue: _selectedProvider,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedProvider = newValue;
                });
                widget.onProviderChanged(newValue);
                _updateAIProvider(newValue);
              }
            },
          ),
        ],
      ),
      onTap: () {
        setState(() {
          _selectedProvider = value;
        });
        widget.onProviderChanged(value);
        _updateAIProvider(value);
      },
    );
  }

  void _showAPIKeyBottomSheet(String provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _APIKeyBottomSheet(
        provider: provider,
        onSaved: () {
          widget.onKeysChanged();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _updateAIProvider(String provider) async {
    await StorageService.setSelectedAIProvider(provider);

    if (provider != 'none') {
      bool hasKey = false;
      if (provider == 'gemini' && widget.hasGeminiKey) {
        hasKey = true;
      } else if (provider == 'groq' && widget.hasGroqKey) {
        hasKey = true;
      }

      if (hasKey) {
        try {
          await AIReminderService.reinitializeWithStoredKeys();
          _showSnackBar(
              'AI provider updated to ${provider.toUpperCase()}', Colors.green);
        } catch (e) {
          _showSnackBar('Failed to initialize $provider: $e', Colors.red);
        }
      } else {
        _showAPIKeyBottomSheet(provider);
      }
    } else {
      _showSnackBar('AI features disabled', Colors.green);
    }

    HapticFeedback.lightImpact();
  }

  Future<void> _testAIConnection() async {
    if (_selectedProvider == 'none') {
      _showSnackBar('Please select an AI provider first', Colors.red);
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
                    '${_selectedProvider.toUpperCase()} is working correctly!'),
                const SizedBox(height: 16),
                const Text('Generated test reminder:'),
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
                  child: Text('• ${response.reminders.first.title}'),
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
        _showSnackBar(
            'Connection successful but no reminders generated', Colors.orange);
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showSnackBar('Connection failed: ${e.toString()}', Colors.red);
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final uri = Uri.parse('https://aistudio.google.com/apikey');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                // Handle error silently or show snackbar
                debugPrint('Failed to open Gemini URL: $e');
              }
            },
            child: const Text('Open Gemini'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final uri = Uri.parse('https://console.groq.com/keys');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                // Handle error silently or show snackbar
                debugPrint('Failed to open Groq URL: $e');
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// API Key Bottom Sheet
class _APIKeyBottomSheet extends StatefulWidget {
  final String provider;
  final VoidCallback onSaved;

  const _APIKeyBottomSheet({
    required this.provider,
    required this.onSaved,
  });

  @override
  State<_APIKeyBottomSheet> createState() => _APIKeyBottomSheetState();
}

class _APIKeyBottomSheetState extends State<_APIKeyBottomSheet> {
  final _controller = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingKey();
  }

  Future<void> _loadExistingKey() async {
    final existingKey = widget.provider == 'gemini'
        ? await StorageService.getGeminiApiKey()
        : await StorageService.getGroqApiKey();

    if (existingKey?.isNotEmpty == true) {
      _controller.text = existingKey!;
      _obscureText = false; // Show existing key
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  '${widget.provider.toUpperCase()} API Key',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              'Enter your ${widget.provider == 'gemini' ? 'Google Gemini' : 'Groq'} API key to enable AI features.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),

            const SizedBox(height: 24),

            // Text Field
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText:
                    'Paste your ${widget.provider.toUpperCase()} API key here',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              obscureText: _obscureText,
              maxLines: 1,
            ),

            const SizedBox(height: 16),

            // Security note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your API key is stored securely on your device and never shared.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveAPIKey,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAPIKey() async {
    final apiKey = _controller.text.trim();
    if (apiKey.isEmpty) {
      _showSnackBar('Please enter a valid API key', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.provider == 'gemini') {
        await StorageService.setGeminiApiKey(apiKey);
      } else {
        await StorageService.setGroqApiKey(apiKey);
      }

      await AIReminderService.reinitializeWithStoredKeys();

      widget.onSaved();
      _showSnackBar(
          '${widget.provider.toUpperCase()} API key saved!', Colors.green);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showSnackBar('Failed to save API key: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Appearance Settings Page
class _AppearanceSettingsPage extends StatefulWidget {
  final ThemeType selectedTheme;
  final Function(ThemeType) onThemeChanged;

  const _AppearanceSettingsPage({
    required this.selectedTheme,
    required this.onThemeChanged,
  });

  @override
  State<_AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<_AppearanceSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Text(
            'Theme',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),

          // Light Theme
          _buildThemeTile(
            icon: Icons.light_mode_outlined,
            title: 'Light',
            subtitle: 'Light theme for bright environments',
            themeType: ThemeType.light,
          ),

          const SizedBox(height: 4),

          // Dark Theme
          _buildThemeTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark',
            subtitle: 'Dark theme for low-light environments',
            themeType: ThemeType.dark,
          ),

          const SizedBox(height: 4),

          // System Theme
          _buildThemeTile(
            icon: Icons.brightness_auto_outlined,
            title: 'System',
            subtitle: 'Follow system theme settings',
            themeType: ThemeType.system,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeType themeType,
  }) {
    final isSelected = widget.selectedTheme == themeType;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        icon,
        size: 24,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Radio<ThemeType>(
        value: themeType,
        groupValue: widget.selectedTheme,
        onChanged: (ThemeType? value) {
          if (value != null) {
            widget.onThemeChanged(value);
          }
        },
      ),
      onTap: () => widget.onThemeChanged(themeType),
    );
  }
}

// Data Settings Page
class _DataSettingsPage extends StatelessWidget {
  const _DataSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.upload_outlined, size: 24),
            title: const Text('Export Data'),
            subtitle: const Text('Export your reminders to a file'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showComingSoon(context, 'Export data'),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.download_outlined, size: 24),
            title: const Text('Import Data'),
            subtitle: const Text('Import reminders from a file'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showComingSoon(context, 'Import data'),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(
              Icons.delete_outline,
              size: 24,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Clear All Data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Delete all your reminders permanently'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showClearDataDialog(context),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your reminders. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoon(context, 'Clear all data');
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

// Update Settings Page
class _UpdateSettingsPage extends StatelessWidget {
  final String currentVersion;
  final bool autoCheckUpdates;
  final String lastUpdateCheck;
  final bool isCheckingForUpdates;
  final Function(bool) onAutoCheckChanged;
  final VoidCallback onCheckForUpdates;

  const _UpdateSettingsPage({
    required this.currentVersion,
    required this.autoCheckUpdates,
    required this.lastUpdateCheck,
    required this.isCheckingForUpdates,
    required this.onAutoCheckChanged,
    required this.onCheckForUpdates,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Updates'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Check for Updates
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(
              isCheckingForUpdates
                  ? Icons.sync
                  : Icons.system_update_alt_outlined,
              size: 24,
            ),
            title: const Text('Check for Updates'),
            subtitle: Text('Current version: $currentVersion'),
            trailing: isCheckingForUpdates
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: isCheckingForUpdates ? null : onCheckForUpdates,
          ),

          const SizedBox(height: 4),

          // Auto-check Toggle
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            secondary: const Icon(Icons.autorenew, size: 24),
            title: const Text('Auto-check for Updates'),
            subtitle:
                const Text('Check for updates automatically on app start'),
            value: autoCheckUpdates,
            onChanged: onAutoCheckChanged,
          ),

          const SizedBox(height: 4),

          // Last Check Time
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.history, size: 24),
            title: const Text('Last Update Check'),
            subtitle: Text(lastUpdateCheck),
            trailing: const Icon(Icons.info_outline, size: 16),
            enabled: false,
          ),

          const SizedBox(height: 4),

          // GitHub Releases
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.open_in_new, size: 24),
            title: const Text('View All Releases'),
            subtitle: const Text('Browse all versions on GitHub'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _openGitHubReleases(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openGitHubReleases(BuildContext context) async {
    HapticFeedback.lightImpact();

    try {
      final url = UpdateService.getReleasesUrl();
      final uri = Uri.parse(url);

      // Use launchUrl directly without canLaunchUrl check
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
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
}

// About Settings Page
class _AboutSettingsPage extends StatelessWidget {
  final String currentVersion;

  const _AboutSettingsPage({
    required this.currentVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.info_outline, size: 24),
            title: const Text('App Information'),
            subtitle: const Text('Version, build info, and credits'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showAboutDialog(context),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.help_outline, size: 24),
            title: const Text('Help & Support'),
            subtitle: const Text('Get help using VoiceRemind'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showComingSoon(context, 'Help & Support'),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.privacy_tip_outlined, size: 24),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How we handle your data'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showComingSoon(context, 'Privacy Policy'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'VoiceRemind',
      applicationVersion: currentVersion,
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
      children: const [
        Text(
          'A beautiful voice-first reminder application built with Flutter. '
          'VoiceRemind helps you create and manage reminders through natural speech.',
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _SnoozeSettingsPage extends StatefulWidget {
  final bool useCustom;
  final int customMinutes;
  final Function(bool, int) onSnoozeChanged;

  const _SnoozeSettingsPage({
    required this.useCustom,
    required this.customMinutes,
    required this.onSnoozeChanged,
  });

  @override
  State<_SnoozeSettingsPage> createState() => _SnoozeSettingsPageState();
}

class _SnoozeSettingsPageState extends State<_SnoozeSettingsPage> {
  late bool _useCustom;
  late double _customMinutes;

  @override
  void initState() {
    super.initState();
    _useCustom = widget.useCustom;
    _customMinutes = widget.customMinutes.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snooze Duration'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Text(
            'Snooze Options',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose how long reminders should be snoozed when you tap the snooze button.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 24),

          // Default option
          _buildSnoozeOptionTile(
            icon: Icons.restore,
            title: 'Default',
            subtitle: 'Two snooze options: 10 minutes and 1 hour',
            value: false,
            description:
                'Classic snooze with quick 10-minute option and longer 1-hour option.',
          ),

          const SizedBox(height: 8),

          // Custom option
          _buildSnoozeOptionTile(
            icon: Icons.tune,
            title: 'Custom',
            subtitle: 'Set your own snooze duration',
            value: true,
            description: 'Choose any duration between 1 and 120 minutes.',
          ),

          if (_useCustom) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Snooze Duration',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Slider
                  Row(
                    children: [
                      // Minus button
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: IconButton(
                          onPressed: _customMinutes > 1
                              ? () {
                                  setState(() {
                                    _customMinutes =
                                        (_customMinutes - 1).clamp(1, 120);
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove),
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),

                      // Slider
                      Expanded(
                        child: Slider(
                          value: _customMinutes,
                          min: 1,
                          max: 120,
                          divisions: 119,
                          label: '${_customMinutes.round()} min',
                          onChanged: (value) {
                            setState(() {
                              _customMinutes = value;
                            });
                          },
                        ),
                      ),

                      // Plus button
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: IconButton(
                          onPressed: _customMinutes < 120
                              ? () {
                                  setState(() {
                                    _customMinutes =
                                        (_customMinutes + 1).clamp(1, 120);
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add),
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildPresetButton(5),
                      _buildPresetButton(10),
                      _buildPresetButton(15),
                      _buildPresetButton(30),
                      _buildPresetButton(60),
                    ],
                  ),

                  const SizedBox(height: 16),

// Direct input field
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Or enter directly: ',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: '15',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (value) {
                            final intValue = int.tryParse(value);
                            if (intValue != null &&
                                intValue >= 1 &&
                                intValue <= 120) {
                              setState(() {
                                _customMinutes = intValue.toDouble();
                              });
                            }
                          },
                        ),
                      ),
                      const Text(' min'),
                    ],
                  ),
                  // Current value display
                  Center(
                    child: Text(
                      '${_customMinutes.round()} minutes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Range indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1 min',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      Text(
                        '120 min',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Save button
          FilledButton(
            onPressed: _saveSettings,
            child: const Text('Save Settings'),
          ),

          const SizedBox(height: 16),

          // Reset to default button
          if (_useCustom)
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _useCustom = false;
                  _customMinutes = 15;
                });
                _saveSettings();
              },
              child: const Text('Reset to Default'),
            ),
        ],
      ),
    );
  }

  Widget _buildSnoozeOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required String description,
  }) {
    final isSelected = _useCustom == value;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          icon,
          size: 28,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                height: 1.3,
              ),
            ),
          ],
        ),
        trailing: Radio<bool>(
          value: value,
          groupValue: _useCustom,
          onChanged: (bool? newValue) {
            if (newValue != null) {
              setState(() {
                _useCustom = newValue;
              });
            }
          },
        ),
        onTap: () => setState(() => _useCustom = value),
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      await StorageService.setSnoozeUseCustom(_useCustom);
      await StorageService.setSnoozeCustomMinutes(_customMinutes.round());

      widget.onSnoozeChanged(_useCustom, _customMinutes.round());

      // Refresh iOS notification categories when snooze settings change
      try {
        await NotificationService.refreshNotificationCategories();
        debugPrint('Refreshed notification categories after snooze change');
      } catch (e) {
        debugPrint('Error refreshing notification categories: $e');
      }

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to save snooze settings: $e');
    }
  }

  Widget _buildPresetButton(int minutes) {
    final isSelected = _customMinutes.round() == minutes;

    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _customMinutes = minutes.toDouble();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            '${minutes}m',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlarmSettingsPage extends StatefulWidget {
  final bool useAlarm;
  final Function(bool) onAlarmChanged;

  const _AlarmSettingsPage({
    required this.useAlarm,
    required this.onAlarmChanged,
  });

  @override
  State<_AlarmSettingsPage> createState() => _AlarmSettingsPageState();
}

class _AlarmSettingsPageState extends State<_AlarmSettingsPage> {
  late bool _useAlarm;

  @override
  void initState() {
    super.initState();
    _useAlarm = widget.useAlarm;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Display Mode'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Text(
            'Reminder Display Mode',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose how reminders should appear when they trigger. Mixed mode intelligently switches between full-screen alarms and notifications based on your activity.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 24),

          // Notification option
          _buildAlarmOptionTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications Only',
            subtitle: 'Always show notification banner with quick actions',
            value: false,
            description:
                'Standard notification experience with dismiss and snooze buttons in the notification panel.',
          ),

          const SizedBox(height: 8),

          // Mixed mode option (previously called "Alarm")
          _buildAlarmOptionTile(
            icon: Icons.alarm,
            title: 'Mixed Mode (Recommended)',
            subtitle:
                'Smart switching: alarms when idle, notifications when busy',
            value: true,
            description:
                'Shows full-screen alarm when phone is idle/locked, but shows notification with alarm sound when you\'re using other apps.',
          ),

          const SizedBox(height: 32),

          // Updated info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'About Mixed Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Full-screen alarm when phone is idle or locked\n'
                  '• Notification with alarm sound when using other apps\n'
                  '• Full-screen alarm when VoiceRemind is active\n'
                  '• Uses device\'s default alarm sound automatically\n'
                  '• Dismiss action marks reminder as complete',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required String description,
  }) {
    final isSelected = _useAlarm == value;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          icon,
          size: 28,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                height: 1.3,
              ),
            ),
          ],
        ),
        trailing: Radio<bool>(
          value: value,
          groupValue: _useAlarm,
          onChanged: (bool? newValue) {
            if (newValue != null) {
              _updateAlarmMode(newValue);
            }
          },
        ),
        onTap: () => _updateAlarmMode(value),
      ),
    );
  }

  Future<void> _updateAlarmMode(bool useAlarm) async {
    setState(() {
      _useAlarm = useAlarm;
    });

    try {
      await StorageService.setUseAlarmInsteadOfNotification(useAlarm);
      widget.onAlarmChanged(useAlarm);

      HapticFeedback.lightImpact();

      if (mounted) {
        final mode = useAlarm ? 'Full-screen alarms' : 'Notifications';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder mode set to $mode'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preference: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }
}
