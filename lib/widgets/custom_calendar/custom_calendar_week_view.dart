// Custom Calendar - Week View
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reminder.dart';
import '../../services/storage_service.dart';
import '../../widgets/reminder_card_widget.dart';

/// Custom week view - Shows reminders for current week
class CustomCalendarWeekView extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime)? onDateSelected;
  final Function(Reminder)? onReminderEdit;
  final Function(Reminder)? onReminderDelete;
  final Function(List<String>)? onAddToSpace;

  const CustomCalendarWeekView({
    super.key,
    required this.initialDate,
    this.onDateSelected,
    this.onReminderEdit,
    this.onReminderDelete,
    this.onAddToSpace,
  });

  @override
  State<CustomCalendarWeekView> createState() => CustomCalendarWeekViewState();
}

class CustomCalendarWeekViewState extends State<CustomCalendarWeekView> {
  late DateTime _currentWeekStart;
  List<Reminder> _reminders = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(widget.initialDate);
    _loadReminders();
    _listenToReminderChanges();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    // Get Sunday of the week
    return date.subtract(Duration(days: date.weekday % 7));
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

  List<Reminder> _getWeekReminders() {
    final weekEnd = _currentWeekStart.add(const Duration(days: 7));

    return _reminders.where((reminder) {
      return reminder.scheduledTime.isAfter(_currentWeekStart.subtract(const Duration(milliseconds: 1))) &&
          reminder.scheduledTime.isBefore(weekEnd);
    }).toList()..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  Map<DateTime, List<Reminder>> _getRemindersByDay() {
    final weekReminders = _getWeekReminders();
    final Map<DateTime, List<Reminder>> byDay = {};

    for (int i = 0; i < 7; i++) {
      final day = _currentWeekStart.add(Duration(days: i));
      final dayKey = DateTime(day.year, day.month, day.day);
      byDay[dayKey] = [];
    }

    for (final reminder in weekReminders) {
      final dayKey = DateTime(
        reminder.scheduledTime.year,
        reminder.scheduledTime.month,
        reminder.scheduledTime.day,
      );
      if (byDay.containsKey(dayKey)) {
        byDay[dayKey]!.add(reminder);
      }
    }

    return byDay;
  }

  void navigateToPreviousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
    widget.onDateSelected?.call(_currentWeekStart);
  }

  void navigateToNextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
    widget.onDateSelected?.call(_currentWeekStart);
  }

  void navigateToToday() {
    final now = DateTime.now();
    setState(() {
      _currentWeekStart = _getWeekStart(now);
    });
    widget.onDateSelected?.call(now);
  }

  @override
  Widget build(BuildContext context) {
    final remindersByDay = _getRemindersByDay();
    final theme = Theme.of(context);
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    final totalReminders = _getWeekReminders().length;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Week header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week of ${DateFormat('MMM d').format(_currentWeekStart)} - ${DateFormat('MMM d, y').format(weekEnd)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalReminders ${totalReminders == 1 ? 'reminder' : 'reminders'} this week',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Days list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final day = _currentWeekStart.add(Duration(days: index));
              final dayReminders = remindersByDay[DateTime(day.year, day.month, day.day)] ?? [];
              return _buildDaySection(day, dayReminders, theme);
            },
            childCount: 7,
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildDaySection(DateTime day, List<Reminder> reminders, ThemeData theme) {
    final isToday = _isToday(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isToday
              ? theme.colorScheme.primary.withValues(alpha: 0.05)
              : null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMM d').format(day),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isToday ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isToday
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${reminders.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isToday
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Day reminders
        if (reminders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No reminders',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          ...reminders.map((reminder) {
            final index = reminders.indexOf(reminder);
            return ReminderCardWidget(
              reminder: reminder,
              onEdit: widget.onReminderEdit,
              onDelete: widget.onReminderDelete,
              onAddToSpace: widget.onAddToSpace,
              allReminders: reminders,
              currentIndex: index,
            );
          }),

        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  DateTime get currentWeekStart => _currentWeekStart;
}
