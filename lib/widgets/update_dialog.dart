import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateResult updateResult;
  final bool isManualCheck;

  const UpdateDialog({
    super.key,
    required this.updateResult,
    this.isManualCheck = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient background
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Update icon with animation
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      size: 32,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    updateResult.isUpdateAvailable
                        ? (updateResult.isPrerelease
                            ? 'Beta Update Available!'
                            : 'Update Available!')
                        : 'You\'re Up to Date!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Beta badge if it's a prerelease
                  if (updateResult.isUpdateAvailable &&
                      updateResult.isPrerelease) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: const Text(
                        'BETA',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (updateResult.isUpdateAvailable) ...[
                    // Version comparison
                    _buildVersionRow(
                      context,
                      'Current Version',
                      updateResult.currentVersion,
                      Icons.smartphone_rounded,
                      theme.colorScheme.outline,
                    ),

                    const SizedBox(height: 12),

                    _buildVersionRow(
                      context,
                      'Latest Version',
                      updateResult.isPrerelease
                          ? '${updateResult.latestVersion} (Beta)'
                          : updateResult.latestVersion,
                      Icons.star_rounded,
                      updateResult.isPrerelease
                          ? Colors.orange
                          : theme.colorScheme.primary,
                    ),

                    const SizedBox(height: 20),

                    // Release notes (if available)
                    if (updateResult.releaseNotes.isNotEmpty) ...[
                      Text(
                        'What\'s New:',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 150),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            updateResult.releaseNotes,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Up to date message
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'You have the latest version of VoiceRemind!',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Version ${updateResult.currentVersion}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action buttons
                  if (updateResult.isUpdateAvailable) ...[
                    // Update available - show both buttons
                    Row(
                      children: [
                        // Later button
                        Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              'Later',
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Update button
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () {
                              _openReleaseUrl(updateResult.releaseUrl);
                              Navigator.of(context).pop();
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              updateResult.isPrerelease ? 'Beta' : 'Update',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Up to date - show close button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionRow(
    BuildContext context,
    String label,
    String version,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  version,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReleaseUrl(String url) async {
    try {
      HapticFeedback.lightImpact();
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle error silently or show snackbar
    }
  }

  // Static method to show the dialog
  static Future<void> show(
    BuildContext context,
    UpdateResult updateResult, {
    bool isManualCheck = false,
  }) async {
    HapticFeedback.mediumImpact();

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => UpdateDialog(
        updateResult: updateResult,
        isManualCheck: isManualCheck,
      ),
    );
  }
}

// Error dialog for update check failures
class UpdateErrorDialog extends StatelessWidget {
  final String error;

  const UpdateErrorDialog({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      icon: Icon(
        Icons.error_outline_rounded,
        size: 32,
        color: theme.colorScheme.error,
      ),
      title: Text(
        'Update Check Failed',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        error,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> show(BuildContext context, String error) async {
    HapticFeedback.lightImpact();

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => UpdateErrorDialog(error: error),
    );
  }
}
