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
