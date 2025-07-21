import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateResult updateResult;
  final bool isManualCheck;

  const UpdateDialog({
    super.key,
    required this.updateResult,
    this.isManualCheck = false,
  });

  // Static method to show the dialog - FIXED
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

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8, // Limit height
        ),
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
                      _isDownloading
                          ? Icons.download_rounded
                          : Icons.system_update_alt_rounded,
                      size: 32,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    _isDownloading
                        ? 'Downloading Update...'
                        : widget.updateResult.isUpdateAvailable
                            ? (widget.updateResult.isPrerelease
                                ? 'Beta Update Available!'
                                : 'Update Available!')
                            : 'You\'re Up to Date!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Download progress
                  if (_isDownloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  // Beta badge if it's a prerelease
                  if (widget.updateResult.isUpdateAvailable &&
                      widget.updateResult.isPrerelease &&
                      !_isDownloading) ...[
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

            // Content - Now scrollable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Download error message
                    if (_downloadError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Download Failed',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _downloadError!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (widget.updateResult.isUpdateAvailable &&
                        !_isDownloading) ...[
                      // Version comparison
                      _buildVersionRow(
                        context,
                        'Current Version',
                        widget.updateResult.currentVersion,
                        Icons.smartphone_rounded,
                        theme.colorScheme.outline,
                      ),

                      const SizedBox(height: 12),

                      _buildVersionRow(
                        context,
                        'Latest Version',
                        widget.updateResult.isPrerelease
                            ? '${widget.updateResult.latestVersion} (Beta)'
                            : widget.updateResult.latestVersion,
                        Icons.star_rounded,
                        widget.updateResult.isPrerelease
                            ? Colors.orange
                            : theme.colorScheme.primary,
                      ),

                      const SizedBox(height: 20),

                      // Release notes (if available)
                      if (widget.updateResult.releaseNotes.isNotEmpty) ...[
                        Text(
                          'What\'s New:',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                              maxHeight: 120), // Reduced height
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              widget.updateResult.releaseNotes,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else if (!widget.updateResult.isUpdateAvailable) ...[
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
                              'Version ${widget.updateResult.currentVersion}',
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
                    if (widget.updateResult.isUpdateAvailable &&
                        !_isDownloading) ...[
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

                          // Update button - now downloads APK directly
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed:
                                  widget.updateResult.apkDownloadUrl != null
                                      ? _downloadAndInstallUpdate
                                      : () => _openGitHubReleases(),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                widget.updateResult.apkDownloadUrl != null
                                    ? Icons.download_rounded
                                    : Icons.open_in_new_rounded,
                                size: 16,
                              ),
                              label: Text(
                                widget.updateResult.apkDownloadUrl != null
                                    ? (widget.updateResult.isPrerelease
                                        ? 'Download Beta'
                                        : 'Download')
                                    : 'Open GitHub',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_isDownloading) ...[
                      // Downloading - show cancel button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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

  // Download and install update
  Future<void> _downloadAndInstallUpdate() async {
    if (widget.updateResult.apkDownloadUrl == null) {
      _openGitHubReleases();
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadError = null;
    });

    try {
      // Download APK
      final downloadResult = await UpdateService.downloadApk(
        widget.updateResult.apkDownloadUrl!,
        (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (!downloadResult.success) {
        setState(() {
          _isDownloading = false;
          _downloadError = downloadResult.error ?? 'Download failed';
        });
        return;
      }

      // Download successful, now install
      if (downloadResult.filePath != null) {
        final installResult =
            await UpdateService.installApk(downloadResult.filePath!);

        if (!installResult.success) {
          setState(() {
            _isDownloading = false;
            _downloadError = installResult.error ?? 'Installation failed';
          });
          return;
        }

        // Installation started successfully
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Update installer opened. Please follow the installation prompts.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadError = 'Download failed: ${e.toString()}';
      });
    }
  }

  Future<void> _openGitHubReleases() async {
    try {
      HapticFeedback.lightImpact();
      final uri = Uri.parse(widget.updateResult.releaseUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      Navigator.of(context).pop();
    } catch (e) {
      // Handle error silently
    }
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
