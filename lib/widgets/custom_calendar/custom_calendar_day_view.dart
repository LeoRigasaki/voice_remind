// Custom Calendar - Day View with Timeline
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reminder.dart';
import '../../services/storage_service.dart';
import '../../widgets/reminder_card_widget.dart';

/// Custom day view - Shows hourly timeline with reminders
class CustomCalendarDayView extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime)? onDateSelected;
  final Function(Reminder)? onReminderEdit;
  final Function(Reminder)? onReminderDelete;
  final Function(List<String>)? onAddToSpace;

  const CustomCalendarDayView({
    super.key,
    required this.initialDate,
    this.onDateSelected,
    this.onReminderEdit,
    this.onReminderDelete,
    this.onAddToSpace,
  });

  @override
  State<CustomCalendarDayView> createState() => CustomCalendarDayViewState();
}

class CustomCalendarDayViewState extends State<CustomCalendarDayView> {
  late DateTime _currentDate;
  List<Reminder> _reminders = [];
  final ScrollController _scrollController = ScrollController();

  // Timeline constants
  static const int _startHour = 6; // 6 AM
  static const int _endHour = 22; // 10 PM
  static const double _hourHeight = 80.0;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _loadReminders();
    _listenToReminderChanges();

    // Scroll to current time after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadReminders() async {
    final reminders = await StorageService.getReminders();
    setState(() {
      _reminders = reminders;
    });
  }

  void _listenToReminderChanges() {
    StorageService.remindersStream.listen((reminders) {
      if (mounted) {
        setState(() {
          _reminders = reminders;
        });
      }
    });
  }

  List<Reminder> _getRemindersForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _reminders.where((reminder) {
      return reminder.scheduledTime.isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
          reminder.scheduledTime.isBefore(dayEnd);
    }).toList()..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  Reminder? _getNextReminder(List<Reminder> reminders) {
    final now = DateTime.now();
    for (final reminder in reminders) {
      if (reminder.scheduledTime.isAfter(now) && !reminder.isCompleted) {
        return reminder;
      }
    }
    return null;
  }

  void _scrollToCurrentTime() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return; // Check if attached to scroll view

    final now = DateTime.now();
    final isToday = _isToday(_currentDate);

    if (isToday && now.hour >= _startHour && now.hour <= _endHour) {
      final hour = now.hour;
      final minute = now.minute;
      final offset = ((hour - _startHour) * _hourHeight) + ((minute / 60) * _hourHeight);

      // Scroll with some padding above
      _scrollController.animateTo(
        offset - 100,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void navigateToPreviousDay() {
    setState(() {
      _currentDate = _currentDate.subtract(const Duration(days: 1));
    });
    widget.onDateSelected?.call(_currentDate);
  }

  void navigateToNextDay() {
    setState(() {
      _currentDate = _currentDate.add(const Duration(days: 1));
    });
    widget.onDateSelected?.call(_currentDate);
  }

  void navigateToToday() {
    final now = DateTime.now();
    setState(() {
      _currentDate = DateTime(now.year, now.month, now.day);
    });
    widget.onDateSelected?.call(_currentDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dayReminders = _getRemindersForDate(_currentDate);
    final theme = Theme.of(context);
    final isToday = _isToday(_currentDate);
    final nextReminder = isToday ? _getNextReminder(dayReminders) : null;
    final completedCount = dayReminders.where((r) => r.isCompleted).length;

    return Column(
      children: [
        // Header with date and progress
        _buildDayHeader(theme, isToday, dayReminders.length, completedCount),

        // "What's Next" card if there's an upcoming reminder today
        if (nextReminder != null)
          _buildWhatsNextCard(theme, nextReminder),

        // Timeline
        Expanded(
          child: dayReminders.isEmpty
              ? _buildEmptyState(theme)
              : _buildTimeline(theme, dayReminders, isToday),
        ),
      ],
    );
  }

  Widget _buildDayHeader(ThemeData theme, bool isToday, int total, int completed) {
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(_currentDate),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM d, y').format(_currentDate),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),

          // Progress bar if there are reminders
          if (total > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$completed/$total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWhatsNextCard(ThemeData theme, Reminder reminder) {
    final now = DateTime.now();
    final diff = reminder.scheduledTime.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    String timeUntil;
    if (hours > 0) {
      timeUntil = '${hours}h ${minutes}m';
    } else {
      timeUntil = '${minutes}m';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'What\'s Next',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'in $timeUntil',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reminder.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('h:mm a').format(reminder.scheduledTime),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No reminders for this day',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your free time!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(ThemeData theme, List<Reminder> reminders, bool isToday) {
    final now = DateTime.now();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _endHour - _startHour,
      itemBuilder: (context, index) {
        final hour = _startHour + index;
        final hourReminders = reminders.where((r) {
          return r.scheduledTime.hour == hour;
        }).toList()..sort((a, b) => a.scheduledTime.minute.compareTo(b.scheduledTime.minute));

        final isCurrentHour = isToday && now.hour == hour;
        final currentMinute = now.minute;

        return _buildHourSlot(theme, hour, hourReminders, isCurrentHour, currentMinute, reminders);
      },
    );
  }

  Widget _buildHourSlot(ThemeData theme, int hour, List<Reminder> hourReminders, bool isCurrentHour, int currentMinute, List<Reminder> allDayReminders) {
    final hourLabel = DateFormat('h a').format(DateTime(2000, 1, 1, hour));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time label
          SizedBox(
            width: 70,
            child: Container(
              padding: const EdgeInsets.only(right: 12, top: 8, left: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Text(
                hourLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isCurrentHour
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: isCurrentHour ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),

          // Timeline area with reminders
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                minHeight: hourReminders.isEmpty ? _hourHeight : 0,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Stack(
                children: [
                  // Current time indicator line
                  if (isCurrentHour)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: hourReminders.isEmpty
                          ? (currentMinute / 60) * _hourHeight
                          : 0, // When there are reminders, show at top
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Reminders column
                  if (hourReminders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: hourReminders.map((reminder) {
                          final index = allDayReminders.indexOf(reminder);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildTimelineReminderCard(theme, reminder, allDayReminders, index),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineReminderCard(ThemeData theme, Reminder reminder, List<Reminder> allReminders, int index) {
    return ReminderCardWidget(
      reminder: reminder,
      onEdit: widget.onReminderEdit,
      onDelete: widget.onReminderDelete,
      onAddToSpace: widget.onAddToSpace,
      allReminders: allReminders,
      currentIndex: index,
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  DateTime get currentDate => _currentDate;
}
