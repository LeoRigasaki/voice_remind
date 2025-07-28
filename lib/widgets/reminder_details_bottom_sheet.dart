import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/space_tag_widget.dart';

class ReminderDetailsBottomSheet extends StatefulWidget {
  final Reminder reminder;
  final List<Reminder> allReminders;
  final int currentIndex;
  final Function(Reminder)? onEdit;
  final Function(Reminder)? onDelete;
  final VoidCallback? onStatusToggle;

  const ReminderDetailsBottomSheet({
    super.key,
    required this.reminder,
    required this.allReminders,
    required this.currentIndex,
    this.onEdit,
    this.onDelete,
    this.onStatusToggle,
  });

  @override
  State<ReminderDetailsBottomSheet> createState() =>
      _ReminderDetailsBottomSheetState();
}

class _ReminderDetailsBottomSheetState extends State<ReminderDetailsBottomSheet>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _slideController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateToPrevious() {
    if (_currentIndex > 0) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToNext() {
    if (_currentIndex < widget.allReminders.length - 1) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      )),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle and Header
            _buildHeader(),

            // Page View for Reminders
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: widget.allReminders.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: _fadeController,
                    child: _buildReminderDetails(widget.allReminders[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canGoPrevious = _currentIndex > 0;
    final canGoNext = _currentIndex < widget.allReminders.length - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // Navigation Header
          Row(
            children: [
              // Previous Button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: canGoPrevious
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: canGoPrevious
                        ? Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2)
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: canGoPrevious ? _navigateToPrevious : null,
                    child: Icon(
                      Icons.chevron_left,
                      color: canGoPrevious
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Title and Counter
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Reminder Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentIndex + 1} of ${widget.allReminders.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),

              // Next Button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: canGoNext
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: canGoNext
                        ? Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2)
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: canGoNext ? _navigateToNext : null,
                    child: Icon(
                      Icons.chevron_right,
                      color: canGoNext
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderDetails(Reminder reminder) {
    final now = DateTime.now();
    final isOverdue =
        !reminder.isCompleted && reminder.scheduledTime.isBefore(now);

    final statusColor = reminder.isCompleted
        ? const Color(0xFF28A745)
        : isOverdue
            ? const Color(0xFFDC3545)
            : Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  reminder.isCompleted
                      ? Icons.check_circle_outline
                      : isOverdue
                          ? Icons.error_outline
                          : Icons.schedule_outlined,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Text(
                  reminder.statusText.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            reminder.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration:
                      reminder.isCompleted ? TextDecoration.lineThrough : null,
                ),
          ),

          const SizedBox(height: 16),

          // Space Tag
          if (reminder.spaceId != null) ...[
            SpaceTagWidget(
              spaceId: reminder.spaceId!,
              fontSize: 13,
              horizontalPadding: 12,
              verticalPadding: 6,
            ),
            const SizedBox(height: 16),
          ],

          // Description
          if (reminder.description?.isNotEmpty == true) ...[
            _buildDetailSection(
              'Description',
              Icons.description_outlined,
              reminder.description!,
            ),
            const SizedBox(height: 20),
          ],

          // Date & Time
          _buildDetailSection(
            'Scheduled Time',
            Icons.schedule_outlined,
            DateFormat('EEEE, MMMM d, y • h:mm a')
                .format(reminder.scheduledTime),
          ),

          const SizedBox(height: 20),

          // Time Remaining/Overdue
          _buildDetailSection(
            reminder.isCompleted
                ? 'Completed'
                : isOverdue
                    ? 'Overdue'
                    : 'Time Remaining',
            reminder.isCompleted
                ? Icons.check_circle_outline
                : isOverdue
                    ? Icons.error_outline
                    : Icons.timer_outlined,
            reminder.isCompleted
                ? 'Task completed'
                : _formatTimeRemaining(reminder.scheduledTime),
            color: statusColor,
          ),

          const SizedBox(height: 20),

          // Repeat Info
          if (reminder.repeatType != RepeatType.none) ...[
            _buildDetailSection(
              'Repeat',
              Icons.repeat,
              _getRepeatText(reminder.repeatType),
            ),
            const SizedBox(height: 20),
          ],

          // Creation Date
          _buildDetailSection(
            'Created',
            Icons.add_circle_outline,
            DateFormat('MMM d, y • h:mm a').format(reminder.createdAt),
          ),

          const SizedBox(height: 32),

          // Action Buttons
          _buildActionButtons(reminder),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, String content,
      {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: color ??
                    Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color ??
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color ?? Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Reminder reminder) {
    return Column(
      children: [
        // Primary Action Row
        Row(
          children: [
            // Toggle Status Button
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: reminder.isCompleted
                      ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                      : const Color(0xFF28A745).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: reminder.isCompleted
                        ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                        : const Color(0xFF28A745).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await _toggleStatus(reminder);
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          reminder.isCompleted ? Icons.refresh : Icons.check,
                          color: reminder.isCompleted
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF28A745),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          reminder.isCompleted ? 'REOPEN' : 'COMPLETE',
                          style: TextStyle(
                            color: reminder.isCompleted
                                ? const Color(0xFF007AFF)
                                : const Color(0xFF28A745),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Edit Button
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onEdit?.call(reminder);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'EDIT',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Delete Button
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFDC3545).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFDC3545).withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete?.call(reminder);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC3545),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'DELETE',
                    style: TextStyle(
                      color: Color(0xFFDC3545),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleStatus(Reminder reminder) async {
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

  String _formatTimeRemaining(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now);

    if (difference.isNegative) {
      final overdueDuration = now.difference(reminderTime);
      if (overdueDuration.inDays > 0) {
        return '${overdueDuration.inDays} day${overdueDuration.inDays == 1 ? '' : 's'} overdue';
      } else if (overdueDuration.inHours > 0) {
        return '${overdueDuration.inHours} hour${overdueDuration.inHours == 1 ? '' : 's'} overdue';
      } else {
        return '${overdueDuration.inMinutes} minute${overdueDuration.inMinutes == 1 ? '' : 's'} overdue';
      }
    }

    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;

    if (totalDays > 7) {
      return 'In ${totalDays} days';
    } else if (totalDays >= 1) {
      return 'In $totalDays day${totalDays == 1 ? '' : 's'}';
    } else if (totalHours >= 1) {
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return 'In $totalHours hour${totalHours == 1 ? '' : 's'}';
      }
      return 'In ${totalHours}h ${remainingMinutes}m';
    } else if (totalMinutes >= 1) {
      return 'In $totalMinutes minute${totalMinutes == 1 ? '' : 's'}';
    } else {
      return 'Any moment now';
    }
  }

  String _getRepeatText(RepeatType repeat) {
    switch (repeat) {
      case RepeatType.none:
        return 'No repeat';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
    }
  }
}
