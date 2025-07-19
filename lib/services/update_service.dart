import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/LeoRigasaki/voice_remind/releases';
  static const String _githubRepoUrl =
      'https://github.com/LeoRigasaki/voice_remind';
  static const String _lastCheckKey = 'last_update_check';
  static const String _autoCheckKey = 'auto_check_updates';

  // Check for updates manually
  static Future<UpdateResult> checkForUpdates() async {
    try {
      if (kDebugMode) {
        print('Checking for updates at: $_githubApiUrl');
      }

      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'VoiceRemind-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('GitHub API Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);

        if (releases.isEmpty) {
          return UpdateResult(
            success: false,
            error: 'No releases found in repository',
          );
        }

        // Get the first release (latest, including pre-releases)
        final Map<String, dynamic> latestRelease = releases.first;

        // Get current app version
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        // Parse GitHub release data
        final latestVersion =
            latestRelease['tag_name']?.toString().replaceFirst('v', '') ?? '';
        final releaseUrl =
            latestRelease['html_url']?.toString() ?? _githubRepoUrl;
        final releaseNotes = latestRelease['body']?.toString() ?? '';
        final publishedAt = latestRelease['published_at']?.toString() ?? '';
        final isPrerelease = latestRelease['prerelease'] ?? false;

        if (kDebugMode) {
          print('Current version: $currentVersion');
          print('Latest version: $latestVersion');
          print('Is prerelease: $isPrerelease');
        }

        // Store last check time
        await _saveLastCheckTime();

        // Compare versions
        final isUpdateAvailable =
            _isVersionNewer(latestVersion, currentVersion);

        return UpdateResult(
          isUpdateAvailable: isUpdateAvailable,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          releaseUrl: releaseUrl,
          releaseNotes: releaseNotes,
          publishedAt: publishedAt,
          success: true,
          isPrerelease: isPrerelease,
        );
      } else if (response.statusCode == 404) {
        return UpdateResult(
          success: false,
          error: 'Repository not found. Please check:\n'
              '• Repository URL: $_githubRepoUrl\n'
              '• Repository is public\n'
              'API URL: $_githubApiUrl',
        );
      } else {
        return UpdateResult(
          success: false,
          error: 'GitHub API returned status ${response.statusCode}\n'
              'Response: ${response.body}',
        );
      }
    } catch (e) {
      return UpdateResult(
        success: false,
        error: 'Network error: ${e.toString()}\n'
            'API URL: $_githubApiUrl',
      );
    }
  }

  // Auto-check for updates (called on app startup)
  static Future<UpdateResult?> autoCheckForUpdates() async {
    try {
      // Check if auto-check is enabled
      final isAutoCheckEnabled = await getAutoCheckEnabled();
      if (!isAutoCheckEnabled) {
        return null;
      }

      // Check if we should check (not too frequently)
      final shouldCheck = await _shouldAutoCheck();
      if (!shouldCheck) {
        return null;
      }

      return await checkForUpdates();
    } catch (e) {
      if (kDebugMode) {
        print('Auto update check failed: $e');
      }
      return null;
    }
  }

  // Check if we should perform auto-check (once per day)
  static Future<bool> _shouldAutoCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckString = prefs.getString(_lastCheckKey);

      if (lastCheckString == null) {
        return true; // First time, check immediately
      }

      final lastCheck = DateTime.parse(lastCheckString);
      final now = DateTime.now();
      final hoursSinceLastCheck = now.difference(lastCheck).inHours;

      // Check once every 24 hours
      return hoursSinceLastCheck >= 24;
    } catch (e) {
      return true; // If error, allow check
    }
  }

  // Save last check time
  static Future<void> _saveLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save last check time: $e');
      }
    }
  }

  // Get auto-check preference
  static Future<bool> getAutoCheckEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoCheckKey) ?? true; // Default: enabled
    } catch (e) {
      return true; // Default: enabled
    }
  }

  // Set auto-check preference
  static Future<void> setAutoCheckEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoCheckKey, enabled);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save auto-check preference: $e');
      }
    }
  }

  // Get last check time for display
  static Future<String> getLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckString = prefs.getString(_lastCheckKey);

      if (lastCheckString == null) {
        return 'Never';
      }

      final lastCheck = DateTime.parse(lastCheckString);
      final now = DateTime.now();
      final difference = now.difference(lastCheck);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Never';
    }
  }

  // Compare version strings (semantic versioning)
  static bool _isVersionNewer(String latestVersion, String currentVersion) {
    try {
      final latest = _parseVersion(latestVersion);
      final current = _parseVersion(currentVersion);

      if (kDebugMode) {
        print('Comparing versions: latest=$latest vs current=$current');
      }

      // Compare major.minor.patch
      for (int i = 0; i < 3; i++) {
        if (latest[i] > current[i]) {
          return true;
        } else if (latest[i] < current[i]) {
          return false;
        }
      }

      return false; // Versions are equal
    } catch (e) {
      if (kDebugMode) {
        print('Version parsing error: $e');
      }
      // If parsing fails, assume update is available to be safe
      return true;
    }
  }

  // Parse version string into [major, minor, patch]
  static List<int> _parseVersion(String version) {
    // Remove common prefixes like 'v' and suffixes like '-beta'
    final cleanVersion = version
        .replaceAll(RegExp(r'^v'), '')
        .replaceAll(RegExp(r'-.*$'), '')
        .replaceAll(RegExp(r'[^0-9.]'), '');

    final parts = cleanVersion.split('.');

    return [
      int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0,
    ];
  }

  // Open GitHub releases page
  static String getReleasesUrl() {
    return '$_githubRepoUrl/releases';
  }
}

class UpdateResult {
  final bool success;
  final bool isUpdateAvailable;
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String releaseNotes;
  final String publishedAt;
  final String? error;
  final bool isPrerelease;

  UpdateResult({
    this.success = false,
    this.isUpdateAvailable = false,
    this.currentVersion = '',
    this.latestVersion = '',
    this.releaseUrl = '',
    this.releaseNotes = '',
    this.publishedAt = '',
    this.error,
    this.isPrerelease = false,
  });

  @override
  String toString() {
    return 'UpdateResult(success: $success, isUpdateAvailable: $isUpdateAvailable, '
        'currentVersion: $currentVersion, latestVersion: $latestVersion, '
        'isPrerelease: $isPrerelease, error: $error)';
  }
}
