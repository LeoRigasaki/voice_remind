// lib/screens/settings_screen.dart
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
  bool _autoCheckUpdates = true;
  bool _isCheckingForUpdates = false;
  String _lastUpdateCheck = 'Never';
  String _currentVersion = '1.0.0';
  String _selectedAIProvider = 'none';
  bool _hasGeminiKey = false;
  bool _hasGroqKey = false;
  String _defaultReminderTab = 'Manual';
  bool _snoozeUseCustom = false;
  int _snoozeCustomMinutes = 15;
  bool _useAlarmInsteadOfNotification = false;

  bool _isDefaultTabExpanded = false;
  bool _isAppearanceExpanded = false;
  bool _isAlarmModeExpanded = false;
  bool _isSnoozeExpanded = false;

  @override
  void initState() {
    super.initState();
    ThemeService.themeStream.listen((themeType) {
      if (mounted) setState(() => _selectedTheme = themeType);
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
      if (mounted) setState(() => _defaultReminderTab = defaultTab);
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
      if (mounted) setState(() => _useAlarmInsteadOfNotification = useAlarm);
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
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingTile(
            icon: Icons.auto_awesome,
            title: 'AI Configuration',
            subtitle: _getAIStatusText(),
            onTap: () => _navigateToAISettings(),
          ),
          _buildExpandableSettingTile(
            icon: Icons.add_circle_outline,
            title: 'Default Reminder Creation',
            subtitle: 'Opens $_defaultReminderTab tab by default',
            isExpanded: _isDefaultTabExpanded,
            onTap: () =>
                setState(() => _isDefaultTabExpanded = !_isDefaultTabExpanded),
            expandedContent: _buildDefaultTabOptions(),
          ),
          _buildExpandableSettingTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: _getThemeText(),
            isExpanded: _isAppearanceExpanded,
            onTap: () =>
                setState(() => _isAppearanceExpanded = !_isAppearanceExpanded),
            expandedContent: _buildAppearanceOptions(),
          ),
          _buildSettingTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Reminder and alert settings',
            onTap: () => _showComingSoonSnackBar('Notifications'),
          ),
          _buildExpandableSettingTile(
            icon: Icons.alarm,
            title: 'Alarm Mode',
            subtitle:
                _useAlarmInsteadOfNotification ? 'Mixed mode' : 'Notifications',
            isExpanded: _isAlarmModeExpanded,
            onTap: () =>
                setState(() => _isAlarmModeExpanded = !_isAlarmModeExpanded),
            expandedContent: _buildAlarmModeOptions(),
          ),
          _buildExpandableSettingTile(
            icon: Icons.snooze_outlined,
            title: 'Snooze Duration',
            subtitle: _getSnoozeStatusText(),
            isExpanded: _isSnoozeExpanded,
            onTap: () => setState(() => _isSnoozeExpanded = !_isSnoozeExpanded),
            expandedContent: _buildSnoozeOptions(),
          ),
          _buildSettingTile(
            icon: Icons.mic_outlined,
            title: 'Voice',
            subtitle: 'Voice recognition and playback',
            onTap: () => _showComingSoonSnackBar('Voice settings'),
          ),
          _buildSettingTile(
            icon: Icons.storage_outlined,
            title: 'Data',
            subtitle: 'Export, import, and manage data',
            onTap: () => _navigateToDataSettings(),
          ),
          _buildSettingTile(
            icon: Icons.system_update_alt_outlined,
            title: 'App Updates',
            subtitle: 'Version $_currentVersion',
            onTap: () => _navigateToUpdateSettings(),
          ),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App info, help, and privacy',
            onTap: () => _navigateToAboutSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon,
                    size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget expandedContent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 24, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: expandedContent,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultTabOptions() {
    return Column(
      children: [
        _buildInlineOption(
          icon: Icons.edit_outlined,
          title: 'Manual',
          value: 'Manual',
          groupValue: _defaultReminderTab,
          onChanged: (v) => _updateDefaultTab(v!),
        ),
        const SizedBox(height: 8),
        _buildInlineOption(
          icon: Icons.auto_awesome,
          title: 'AI Text',
          value: 'AI Text',
          groupValue: _defaultReminderTab,
          onChanged: (v) => _updateDefaultTab(v!),
        ),
        const SizedBox(height: 8),
        _buildInlineOption(
          icon: Icons.mic_outlined,
          title: 'Voice',
          value: 'Voice',
          groupValue: _defaultReminderTab,
          onChanged: (v) => _updateDefaultTab(v!),
        ),
      ],
    );
  }

  Widget _buildAppearanceOptions() {
    return Column(
      children: [
        _buildInlineOption(
          icon: Icons.light_mode_outlined,
          title: 'Light',
          value: ThemeType.light,
          groupValue: _selectedTheme,
          onChanged: (v) => _updateTheme(v!),
        ),
        const SizedBox(height: 8),
        _buildInlineOption(
          icon: Icons.dark_mode_outlined,
          title: 'Dark',
          value: ThemeType.dark,
          groupValue: _selectedTheme,
          onChanged: (v) => _updateTheme(v!),
        ),
        const SizedBox(height: 8),
        _buildInlineOption(
          icon: Icons.brightness_auto_outlined,
          title: 'System',
          value: ThemeType.system,
          groupValue: _selectedTheme,
          onChanged: (v) => _updateTheme(v!),
        ),
      ],
    );
  }

  Widget _buildAlarmModeOptions() {
    return Column(
      children: [
        _buildInlineOption(
          icon: Icons.notifications_outlined,
          title: 'Notifications Only',
          value: false,
          groupValue: _useAlarmInsteadOfNotification,
          onChanged: (v) => _updateAlarmMode(v!),
        ),
        const SizedBox(height: 8),
        _buildInlineOption(
          icon: Icons.alarm,
          title: 'Mixed Mode',
          value: true,
          groupValue: _useAlarmInsteadOfNotification,
          onChanged: (v) => _updateAlarmMode(v!),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mixed mode: Full-screen alarm when idle, notifications when active',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSnoozeOptions() {
    return Column(
      children: [
        _buildInlineOption(
          icon: Icons.restore,
          title: 'Default (10min, 1hr)',
          value: false,
          groupValue: _snoozeUseCustom,
          onChanged: (v) => _updateSnoozeMode(v!),
        ),
        const SizedBox(height: 8),
        _buildInlineOption(
          icon: Icons.tune,
          title: 'Custom Duration',
          value: true,
          groupValue: _snoozeUseCustom,
          onChanged: (v) => _updateSnoozeMode(v!),
        ),
        if (_snoozeUseCustom) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '$_snoozeCustomMinutes minutes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: _snoozeCustomMinutes > 1
                          ? () => setState(() => _snoozeCustomMinutes--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Expanded(
                      child: Slider(
                        value: _snoozeCustomMinutes.toDouble(),
                        min: 1,
                        max: 120,
                        divisions: 119,
                        onChanged: (v) =>
                            setState(() => _snoozeCustomMinutes = v.round()),
                      ),
                    ),
                    IconButton(
                      onPressed: _snoozeCustomMinutes < 120
                          ? () => setState(() => _snoozeCustomMinutes++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [5, 10, 15, 30, 60]
                      .map((m) => FilterChip(
                            label: Text('${m}m'),
                            selected: _snoozeCustomMinutes == m,
                            onSelected: (_) =>
                                setState(() => _snoozeCustomMinutes = m),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInlineOption<T>({
    required IconData icon,
    required String title,
    required T value,
    required T groupValue,
    required Function(T?) onChanged,
  }) {
    final isSelected = value == groupValue;
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                ),
              ),
              Radio<T>(
                value: value,
                groupValue: groupValue,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAIStatusText() {
    if (_selectedAIProvider == 'none') return 'No provider selected';
    if (_selectedAIProvider == 'gemini' && _hasGeminiKey)
      return 'Gemini configured';
    if (_selectedAIProvider == 'groq' && _hasGroqKey) return 'Groq configured';
    return 'API key required';
  }

  String _getThemeText() {
    switch (_selectedTheme) {
      case ThemeType.light:
        return 'Light theme';
      case ThemeType.dark:
        return 'Dark theme';
      case ThemeType.system:
        return 'System default';
    }
  }

  String _getSnoozeStatusText() {
    return _snoozeUseCustom
        ? 'Custom: $_snoozeCustomMinutes min'
        : 'Default: 10min, 1hr';
  }

  void _navigateToAISettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => _AISettingsPage(
        selectedProvider: _selectedAIProvider,
        hasGeminiKey: _hasGeminiKey,
        hasGroqKey: _hasGroqKey,
        onProviderChanged: (provider) =>
            setState(() => _selectedAIProvider = provider),
        onKeysChanged: _loadAISettings,
      ),
    ));
  }

  Future<void> _updateDefaultTab(String newTab) async {
    setState(() => _defaultReminderTab = newTab);
    try {
      await StorageService.setDefaultReminderTabByMode(newTab);
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Default set to $newTab'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateTheme(ThemeType theme) async {
    setState(() => _selectedTheme = theme);
    ThemeService.setTheme(theme);
    HapticFeedback.lightImpact();
  }

  Future<void> _updateAlarmMode(bool useAlarm) async {
    setState(() => _useAlarmInsteadOfNotification = useAlarm);
    try {
      await StorageService.setUseAlarmInsteadOfNotification(useAlarm);
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alarm mode ${useAlarm ? 'enabled' : 'disabled'}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateSnoozeMode(bool useCustom) async {
    setState(() => _snoozeUseCustom = useCustom);
    try {
      await StorageService.setSnoozeUseCustom(useCustom);
      await StorageService.setSnoozeCustomMinutes(_snoozeCustomMinutes);
      await NotificationService.refreshNotificationCategories();
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to save snooze settings: $e');
    }
  }

  void _navigateToDataSettings() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const _DataSettingsPage()));
  }

  void _navigateToUpdateSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => _UpdateSettingsPage(
        currentVersion: _currentVersion,
        autoCheckUpdates: _autoCheckUpdates,
        lastUpdateCheck: _lastUpdateCheck,
        isCheckingForUpdates: _isCheckingForUpdates,
        onAutoCheckChanged: (value) {
          setState(() => _autoCheckUpdates = value);
          _toggleAutoCheck(value);
        },
        onCheckForUpdates: _checkForUpdates,
      ),
    ));
  }

  void _navigateToAboutSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => _AboutSettingsPage(currentVersion: _currentVersion),
    ));
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingForUpdates) return;
    setState(() => _isCheckingForUpdates = true);
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
        setState(() => _isCheckingForUpdates = false);
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
          content: Text(value ? 'Auto-check enabled' : 'Auto-check disabled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

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
      appBar: AppBar(title: const Text('AI Configuration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Provider'),
          _buildProviderTile(
            icon: Icons.cancel_outlined,
            title: 'Disabled',
            value: 'none',
            hasKey: true,
          ),
          const SizedBox(height: 8),
          _buildProviderTile(
            icon: Icons.auto_awesome,
            title: 'Google Gemini',
            value: 'gemini',
            hasKey: widget.hasGeminiKey,
          ),
          const SizedBox(height: 8),
          _buildProviderTile(
            icon: Icons.flash_on,
            title: 'Groq',
            value: 'groq',
            hasKey: widget.hasGroqKey,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('API Keys'),
          _buildKeyTile(
            icon: Icons.auto_awesome,
            title: 'Gemini API Key',
            hasKey: widget.hasGeminiKey,
            onTap: () => _showAPIKeyBottomSheet('gemini'),
          ),
          const SizedBox(height: 8),
          _buildKeyTile(
            icon: Icons.flash_on,
            title: 'Groq API Key',
            hasKey: widget.hasGroqKey,
            onTap: () => _showAPIKeyBottomSheet('groq'),
          ),
          const SizedBox(height: 8),
          _buildKeyTile(
            icon: Icons.help_outline,
            title: 'How to get API Keys',
            hasKey: true,
            onTap: _showAPIKeyHelpDialog,
          ),
          if (_selectedProvider != 'none') ...[
            const SizedBox(height: 8),
            _buildKeyTile(
              icon: Icons.network_check,
              title: 'Test Connection',
              hasKey: true,
              onTap: _testAIConnection,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildProviderTile({
    required IconData icon,
    required String title,
    required String value,
    required bool hasKey,
  }) {
    final isSelected = _selectedProvider == value;
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _updateAIProvider(value),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                ),
              ),
              if (value != 'none' && hasKey)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              Radio<String>(
                value: value,
                groupValue: _selectedProvider,
                onChanged: (v) => v != null ? _updateAIProvider(v) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyTile({
    required IconData icon,
    required String title,
    required bool hasKey,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Icon(
                hasKey ? Icons.edit : Icons.add,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
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
    setState(() => _selectedProvider = provider);
    await StorageService.setSelectedAIProvider(provider);
    widget.onProviderChanged(provider);

    if (provider != 'none') {
      bool hasKey = (provider == 'gemini' && widget.hasGeminiKey) ||
          (provider == 'groq' && widget.hasGroqKey);
      if (hasKey) {
        try {
          await AIReminderService.reinitializeWithStoredKeys();
          _showSnackBar('AI provider updated', Colors.green);
        } catch (e) {
          _showSnackBar('Failed to initialize: $e', Colors.red);
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
      _showSnackBar('Select a provider first', Colors.red);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testing connection...'),
          ],
        ),
      ),
    );

    try {
      final response = await AIReminderService.parseRemindersFromText(
          'Test reminder for tomorrow at 9am');
      Navigator.pop(context);

      if (response.reminders.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connection Successful'),
            content: Text(
                '${_selectedProvider == 'gemini' ? 'Gemini' : 'Groq'} is working'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        HapticFeedback.mediumImpact();
      } else {
        _showSnackBar('No reminders generated', Colors.orange);
      }
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('Connection failed: $e', Colors.red);
    }
  }

  void _showAPIKeyHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get Free API Keys'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Google Gemini',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              const Text('1. Go to ai.google.dev\n'
                  '2. Create API key\n'
                  '3. Free: 15 requests/minute'),
              const SizedBox(height: 16),
              Text(
                'Groq',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              const Text('1. Visit console.groq.com\n'
                  '2. Create API key\n'
                  '3. Free: 14,400 requests/day'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse('https://aistudio.google.com/apikey');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('Gemini'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse('https://console.groq.com/keys');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('Groq'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

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
      _obscureText = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerName = widget.provider == 'gemini' ? 'Gemini' : 'Groq';
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
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
            Row(
              children: [
                Text(
                  '$providerName API Key',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'Paste your API key',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              obscureText: _obscureText,
            ),
            const SizedBox(height: 16),
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
                  Icon(Icons.security,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stored securely on your device',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
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
      _showSnackBar('Enter a valid API key', Colors.red);
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
      _showSnackBar('API key saved', Colors.green);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showSnackBar('Failed to save: $e', Colors.red);
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
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _DataSettingsPage extends StatelessWidget {
  const _DataSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDataTile(
            context,
            icon: Icons.upload_outlined,
            title: 'Export Data',
            subtitle: 'Export reminders to file',
            onTap: () => _showComingSoon(context, 'Export data'),
          ),
          const SizedBox(height: 8),
          _buildDataTile(
            context,
            icon: Icons.download_outlined,
            title: 'Import Data',
            subtitle: 'Import reminders from file',
            onTap: () => _showComingSoon(context, 'Import data'),
          ),
          const SizedBox(height: 8),
          _buildDataTile(
            context,
            icon: Icons.delete_outline,
            title: 'Clear All Data',
            subtitle: 'Delete all reminders',
            isDestructive: true,
            onTap: () => _showClearDataDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isDestructive
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDestructive
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all reminders. This action cannot be undone.',
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
      appBar: AppBar(title: const Text('App Updates')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isCheckingForUpdates ? null : onCheckForUpdates,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isCheckingForUpdates
                          ? Icons.sync
                          : Icons.system_update_alt_outlined,
                      size: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check for Updates',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Version $currentVersion',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (isCheckingForUpdates)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              secondary: Icon(
                Icons.autorenew,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
              title: Text(
                'Auto-check Updates',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              subtitle: Text(
                'Check daily on app start',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              value: autoCheckUpdates,
              onChanged: onAutoCheckChanged,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 24,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Check',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        Text(
                          lastUpdateCheck,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openGitHubReleases(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.open_in_new,
                      size: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'View All Releases',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Browse versions on GitHub',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _AboutSettingsPage extends StatelessWidget {
  final String currentVersion;

  const _AboutSettingsPage({required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showAboutDialog(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Information',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Version and credits',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showComingSoon(context, 'Help and Support'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      size: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Help and Support',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Get help using the app',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showComingSoon(context, 'Privacy Policy'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      size: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy Policy',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'How we handle your data',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
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
          'A beautiful voice-first reminder application built with Flutter.',
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
