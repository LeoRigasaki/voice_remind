import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/space_tag_widget.dart';
import '../widgets/reminder_details_bottom_sheet.dart';

class ReminderCardWidget extends StatelessWidget {
  final Reminder reminder;
  final String searchQuery;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionToggle;
  final Function(Reminder)? onEdit;
  final Function(Reminder)? onDelete;
  final Function(List<String>)? onAddToSpace;
  final List<Reminder>? allReminders; // For navigation in bottom sheet
  final int? currentIndex; // For navigation in bottom sheet

  const ReminderCardWidget({
    super.key,
    required this.reminder,
    this.searchQuery = '',
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onSelectionToggle,
    this.onEdit,
    this.onDelete,
    this.onAddToSpace,
    this.allReminders,
    this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue =
        !reminder.isCompleted && reminder.scheduledTime.isBefore(now);

    // Warmer, softer colors - Nothing Phone inspired
    final statusColor = reminder.isCompleted
        ? const Color(0xFF28A745) // Warmer green
        : isOverdue
            ? const Color(0xFFDC3545) // Softer red
            : (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF8E8E93)
                : const Color(0xFF6D6D70)); // Neutral gray

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Slidable(
        key: ValueKey(reminder.id),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: onAddToSpace != null ? 0.52 : 0.35,
          children: _buildSlideActions(context),
        ),
        child: GestureDetector(
          onLongPress: onLongPress,
          onLongPressStart: (details) {
            HapticFeedback.selectionClick();
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF5F5F5))
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFF453A)
                    : Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isSelectionMode
                    ? onSelectionToggle
                    : () => _showReminderDetails(context),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Left side (85% - Main content area)
                      Expanded(
                        flex: 85,
                        child: GestureDetector(
                          onTap: isSelectionMode
                              ? onSelectionToggle
                              : () => _showReminderDetails(context),
                          behavior: HitTestBehavior.translucent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Selection checkbox (ONLY in selection mode)
                                  if (isSelectionMode) ...[
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFFF453A)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(0xFFFF453A),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 14,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                  ],

                                  // Title and Space Name Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title with search highlighting
                                        searchQuery.isNotEmpty
                                            ? _buildHighlightedText(
                                                reminder.title,
                                                searchQuery,
                                                Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      decoration:
                                                          reminder.isCompleted
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 16,
                                                      letterSpacing: -0.2,
                                                    ),
                                              )
                                            : Text(
                                                reminder.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      decoration:
                                                          reminder.isCompleted
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 16,
                                                      letterSpacing: -0.2,
                                                    ),
                                              ),

                                        // Space Tag (Visual Chip)
                                        if (reminder.spaceId != null) ...[
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: SpaceTagWidget(
                                              spaceId: reminder.spaceId!,
                                              fontSize: 11,
                                              horizontalPadding: 8,
                                              verticalPadding: 4,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Description with 45 character limit and ellipsis
                              if (reminder.description?.isNotEmpty == true) ...[
                                const SizedBox(height: 12),
                                searchQuery.isNotEmpty
                                    ? _buildHighlightedText(
                                        _truncateDescription(
                                            reminder.description!),
                                        searchQuery,
                                        Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                              fontSize: 14,
                                              height: 1.4,
                                              letterSpacing: -0.1,
                                            ),
                                      )
                                    : Text(
                                        _truncateDescription(
                                            reminder.description!),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                              fontSize: 14,
                                              height: 1.4,
                                              letterSpacing: -0.1,
                                            ),
                                      ),
                              ],

                              const SizedBox(height: 16),

                              // Bottom row
                              Row(
                                children: [
                                  Text(
                                    DateFormat('MMM dd • h:mm a')
                                        .format(reminder.scheduledTime),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    reminder.statusText.toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: statusColor.withValues(
                                              alpha: 0.8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.2,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right side (15% - Status toggle area)
                      if (!isSelectionMode)
                        Expanded(
                          flex: 15,
                          child: GestureDetector(
                            onTap: () => _toggleReminderStatus(context),
                            behavior: HitTestBehavior.translucent,
                            child: Container(
                              padding: const EdgeInsets.only(left: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                                .withValues(alpha: 0.2)
                                            : Colors.black
                                                .withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: reminder.isCompleted
                                          ? Icon(
                                              Icons.check_circle,
                                              size: 24,
                                              color: statusColor,
                                            )
                                          : Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 32,
                                                  height: 32,
                                                  child: CustomPaint(
                                                    painter:
                                                        CircularCountdownPainter(
                                                      progress:
                                                          _calculateProgress(
                                                              reminder),
                                                      backgroundColor:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .outline
                                                              .withValues(
                                                                  alpha: 0.2),
                                                      progressColor: isOverdue
                                                          ? const Color(
                                                              0xFFDC3545)
                                                          : (Theme.of(context)
                                                                      .brightness ==
                                                                  Brightness
                                                                      .dark
                                                              ? Colors.white
                                                              : Colors.black),
                                                      strokeWidth: 2.5,
                                                    ),
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.check,
                                                  size: 12,
                                                  color: (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Use flexible container for status text with proper width
                                  SizedBox(
                                    width:
                                        60, // Fixed width to prevent text wrapping
                                    child: Text(
                                      reminder.isCompleted
                                          ? 'DONE'
                                          : _formatTimeRemaining(
                                              reminder.scheduledTime),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: reminder.isCompleted
                                                ? statusColor
                                                : isOverdue
                                                    ? Colors.red
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.7),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.1,
                                          ),
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
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSlideActions(BuildContext context) {
    List<Widget> actions = [
      // Edit Action
      Expanded(
        child: Container(
          margin: const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onEdit?.call(reminder),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Delete Action
      Expanded(
        child: Container(
          margin: const EdgeInsets.only(left: 2, right: 4, top: 2, bottom: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onDelete?.call(reminder),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];

    // Add Space action if callback is provided (home screen only)
    if (onAddToSpace != null) {
      actions.add(
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 2, right: 4, top: 2, bottom: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onAddToSpace?.call([reminder.id]),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.folder_outlined,
                        color: Color(0xFF007AFF),
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Space',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return actions;
  }

  void _showReminderDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReminderDetailsBottomSheet(
        reminder: reminder,
        allReminders: allReminders ?? [reminder],
        currentIndex: currentIndex ?? 0,
        onEdit: onEdit,
        onDelete: onDelete,
        onStatusToggle: () => _toggleReminderStatus(context),
      ),
    );
  }

  Future<void> _toggleReminderStatus(BuildContext context) async {
    HapticFeedback.lightImpact();

    try {
      final newStatus = reminder.isCompleted
          ? ReminderStatus.pending
          : ReminderStatus.completed;

      await StorageService.updateReminderStatus(reminder.id, newStatus);

      if (newStatus == ReminderStatus.completed) {
        await NotificationService.cancelReminder(reminder.id);
      } else if (reminder.scheduledTime.isAfter(DateTime.now())) {
        await NotificationService.scheduleReminder(
          reminder.copyWith(status: newStatus),
        );
      }
    } catch (e) {
      debugPrint('Error updating reminder: $e');
    }
  }

  String _truncateDescription(String description) {
    if (description.length <= 45) {
      return description;
    }
    return '${description.substring(0, 45)}...';
  }

  Widget _buildHighlightedText(
      String text, String searchTerm, TextStyle? style) {
    if (searchTerm.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerSearchTerm = searchTerm.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerSearchTerm, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + searchTerm.length),
        style: style?.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + searchTerm.length;
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _formatTimeRemaining(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now);

    if (difference.isNegative) {
      final overdueDuration = now.difference(reminderTime);
      if (overdueDuration.inDays > 0) {
        return '${overdueDuration.inDays}d ago';
      } else if (overdueDuration.inHours > 0) {
        return '${overdueDuration.inHours}h ago';
      } else {
        return '${overdueDuration.inMinutes}m ago';
      }
    }

    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;

    if (totalDays > 7) {
      return DateFormat('MMM dd').format(reminderTime);
    } else if (totalDays >= 1) {
      return '${totalDays}d';
    } else if (totalHours >= 1) {
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return '${totalHours}h';
      }
      return '${totalHours}h${remainingMinutes}m';
    } else if (totalMinutes >= 10) {
      return '${totalMinutes}m';
    } else {
      final seconds = difference.inSeconds % 60;
      if (totalMinutes == 0) {
        return '${seconds}s';
      }
      return '${totalMinutes}m${seconds}s';
    }
  }

  double _calculateProgress(Reminder reminder) {
    final now = DateTime.now();
    final createdTime = reminder.createdAt;
    final scheduledTime = reminder.scheduledTime;

    if (reminder.isCompleted) return 1.0;

    final totalDuration = scheduledTime.difference(createdTime);
    if (totalDuration.inMilliseconds <= 0) return 0.0;

    final elapsedDuration = now.difference(createdTime);
    final progress =
        elapsedDuration.inMilliseconds / totalDuration.inMilliseconds;

    return progress.clamp(0.0, 1.0);
  }
}

// Custom painter for circular countdown progress indicator
class CircularCountdownPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  CircularCountdownPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is CircularCountdownPainter &&
        (oldDelegate.progress != progress ||
            oldDelegate.backgroundColor != backgroundColor ||
            oldDelegate.progressColor != progressColor ||
            oldDelegate.strokeWidth != strokeWidth);
  }
}
