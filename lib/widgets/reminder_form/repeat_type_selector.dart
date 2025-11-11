// [lib/widgets/reminder_form]/repeat_type_selector.dart
// Reusable repeat type selector widget

import 'package:flutter/material.dart';
import '../../models/reminder.dart';
import '../../models/custom_repeat_config.dart';
import '../../utils/reminder_helpers.dart';
import 'custom_repeat_dialog.dart';

class RepeatTypeSelector extends StatelessWidget {
  final RepeatType selectedRepeat;
  final ValueChanged<RepeatType> onRepeatChanged;
  final String? title;
  final CustomRepeatConfig? customRepeatConfig;
  final ValueChanged<CustomRepeatConfig?>? onCustomRepeatChanged;

  const RepeatTypeSelector({
    super.key,
    required this.selectedRepeat,
    required this.onRepeatChanged,
    this.title,
    this.customRepeatConfig,
    this.onCustomRepeatChanged,
  });

  void _showRepeatSelector(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Calculate available height
    final availableHeight = screenHeight -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        keyboardHeight -
        32; // margins

    // Determine device size categories
    final isSmallDevice = screenHeight < 700;
    final isVerySmallDevice = screenHeight < 600;

    // Calculate responsive dimensions
    final maxModalHeight = isVerySmallDevice
        ? availableHeight * 0.85
        : isSmallDevice
            ? availableHeight * 0.75
            : availableHeight * 0.6;

    final horizontalMargin = isSmallDevice ? 12.0 : 16.0;
    final verticalPadding = isVerySmallDevice
        ? 12.0
        : isSmallDevice
            ? 16.0
            : 20.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: EdgeInsets.only(
          left: horizontalMargin,
          right: horizontalMargin,
          top: 16,
          bottom: 16 + keyboardHeight,
        ),
        constraints: BoxConstraints(
          maxHeight: maxModalHeight,
          minHeight: 200,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Padding(
              padding: EdgeInsets.all(verticalPadding),
              child: Row(
                children: [
                  Text(
                    'REPEAT OPTIONS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const Spacer(),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.1),
                        width: 0.5,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // SCROLLABLE CONTENT
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (RepeatType repeat in RepeatType.values)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            if (repeat == RepeatType.custom) {
                              // Open custom repeat dialog
                              Navigator.pop(context);
                              final config = await showDialog<CustomRepeatConfig>(
                                context: context,
                                builder: (context) => CustomRepeatDialog(
                                  initialConfig: customRepeatConfig,
                                ),
                              );

                              if (config != null) {
                                onRepeatChanged(RepeatType.custom);
                                onCustomRepeatChanged?.call(config);
                              }
                            } else {
                              // Clear custom config when selecting standard repeat
                              onCustomRepeatChanged?.call(null);
                              onRepeatChanged(repeat);
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: isVerySmallDevice
                                  ? 12.0
                                  : isSmallDevice
                                      ? 14.0
                                      : 16.0,
                            ),
                            child: Row(
                              children: [
                                // Radio button
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedRepeat == repeat
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Theme.of(context).colorScheme.outline,
                                      width: selectedRepeat == repeat ? 6 : 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Text content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        getRepeatDisplayName(repeat),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              fontSize: isVerySmallDevice
                                                  ? 14.0
                                                  : isSmallDevice
                                                      ? 15.0
                                                      : 16.0,
                                            ),
                                      ),
                                      SizedBox(
                                          height: isVerySmallDevice ? 2.0 : 4.0),
                                      Text(
                                        getRepeatDescription(repeat),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                              fontSize: isVerySmallDevice
                                                  ? 11.0
                                                  : isSmallDevice
                                                      ? 12.0
                                                      : 13.0,
                                              height:
                                                  isVerySmallDevice ? 1.3 : 1.4,
                                            ),
                                        maxLines: isVerySmallDevice ? 2 : 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRepeatSelector(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.repeat,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? 'Repeat',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedRepeat == RepeatType.custom && customRepeatConfig != null
                          ? customRepeatConfig!.formatInterval()
                          : getRepeatDisplayName(selectedRepeat),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
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
}
