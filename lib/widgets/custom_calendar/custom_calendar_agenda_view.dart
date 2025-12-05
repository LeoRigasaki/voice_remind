// Custom Calendar - Agenda View
import 'package:flutter/material.dart';
import '../../models/reminder.dart';
import '../../services/storage_service.dart';
import '../../widgets/reminder_card_widget.dart';

/// Custom agenda view - Shows all upcoming reminders chronologically
class CustomCalendarAgendaView extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime)? onDateSelected;
  final Function(Reminder)? onReminderEdit;
  final Function(Reminder)? onReminderDelete;
  final Function(List<String>)? onAddToSpace;

  const CustomCalendarAgendaView({
    super.key,
    required this.initialDate,
    this.onDateSelected,
    this.onReminderEdit,
    this.onReminderDelete,
    this.onAddToSpace,
  });

  @override
  State<CustomCalendarAgendaView> createState() => CustomCalendarAgendaViewState();
}

class CustomCalendarAgendaViewState extends State<CustomCalendarAgendaView> {
  List<Reminder> _reminders = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _listenToReminderChanges();
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

  Map<String, List<Reminder>> _getGroupedReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get all reminders sorted by time
    final sortedReminders = List<Reminder>.from(_reminders)
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    final Map<String, List<Reminder>> grouped = {
      'Overdue': [],
      'Today': [],
      'Tomorrow': [],
      'This Week': [],
      'Later': [],
    };

    for (final reminder in sortedReminders) {
      if (reminder.isCompleted) continue; // Skip completed

      final reminderDate = DateTime(
        reminder.scheduledTime.year,
        reminder.scheduledTime.month,
        reminder.scheduledTime.day,
      );

      if (reminderDate.isBefore(today)) {
        grouped['Overdue']!.add(reminder);
      } else if (reminderDate.isAtSameMomentAs(today)) {
        grouped['Today']!.add(reminder);
      } else if (reminderDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
        grouped['Tomorrow']!.add(reminder);
      } else if (reminderDate.isBefore(today.add(const Duration(days: 7)))) {
        grouped['This Week']!.add(reminder);
      } else {
        grouped['Later']!.add(reminder);
      }
    }

    // Remove empty sections
    grouped.removeWhere((key, value) => value.isEmpty);

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedReminders = _getGroupedReminders();
    final theme = Theme.of(context);
    final totalReminders = groupedReminders.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agenda',
                  style: theme.textTheme.headlineSmall?.copyWith(
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
                    '$totalReminders ${totalReminders == 1 ? 'upcoming reminder' : 'upcoming reminders'}',
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

        // Grouped reminders
        if (groupedReminders.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 64,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No upcoming reminders',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...groupedReminders.entries.map((entry) {
            return _buildSection(entry.key, entry.value, theme);
          }),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Reminder> reminders, ThemeData theme) {
    final isOverdue = title == 'Overdue';
    final isToday = title == 'Today';

    return SliverList(
      delegate: SliverChildListDelegate([
        // Section header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isOverdue
                      ? theme.colorScheme.error
                      : isToday
                          ? theme.colorScheme.primary
                          : null,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? theme.colorScheme.error.withValues(alpha: 0.1)
                      : isToday
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
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
                    color: isOverdue
                        ? theme.colorScheme.error
                        : isToday
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Reminders
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ]),
    );
  }

  // No navigation methods needed for agenda - it's always "now forward"
  void navigateToToday() {
    // Refresh to current state
    _loadReminders();
  }
}
