// Custom Calendar - Month View
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reminder.dart';
import '../../services/storage_service.dart';
import '../../widgets/reminder_card_widget.dart';
import '../../widgets/ai_add_reminder_modal.dart';

/// Custom month view calendar - Shows actual reminder cards
class CustomCalendarMonthView extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime)? onDateSelected;
  final Function(Reminder)? onReminderEdit;
  final Function(Reminder)? onReminderDelete;
  final Function(List<String>)? onAddToSpace;

  const CustomCalendarMonthView({
    super.key,
    required this.initialDate,
    this.onDateSelected,
    this.onReminderEdit,
    this.onReminderDelete,
    this.onAddToSpace,
  });

  @override
  State<CustomCalendarMonthView> createState() => CustomCalendarMonthViewState();
}

class CustomCalendarMonthViewState extends State<CustomCalendarMonthView> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  List<Reminder> _reminders = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
    _selectedDate = widget.initialDate;
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

  /// Calculate all days to display in the month grid (6 weeks)
  List<DateTime> _getCalendarDays() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    // Start from the first Sunday/Monday before or on the first day
    int firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final startDate = firstDayOfMonth.subtract(Duration(days: firstWeekday));

    // End at the last Saturday/Sunday after or on the last day
    int lastWeekday = lastDayOfMonth.weekday % 7;
    final endDate = lastDayOfMonth.add(Duration(days: 6 - lastWeekday));

    // Generate all days
    final days = <DateTime>[];
    DateTime current = startDate;
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  /// Get reminders for a specific date
  List<Reminder> _getRemindersForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _reminders.where((reminder) {
      return reminder.scheduledTime
              .isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
          reminder.scheduledTime.isBefore(dayEnd);
    }).toList();
  }

  /// Get reminders for currently selected date (for the list below)
  List<Reminder> _getSelectedDateReminders() {
    if (_selectedDate == null) {
      // If no date selected, show today's reminders
      final now = DateTime.now();
      return _getRemindersForDate(now);
    }
    return _getRemindersForDate(_selectedDate!);
  }

  /// Check if date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is in current month
  bool _isInCurrentMonth(DateTime date) {
    return date.month == _currentMonth.month &&
        date.year == _currentMonth.year;
  }

  /// Check if date is selected
  bool _isSelected(DateTime date) {
    if (_selectedDate == null) return false;
    return date.year == _selectedDate!.year &&
        date.month == _selectedDate!.month &&
        date.day == _selectedDate!.day;
  }

  /// Handle day tap - ALWAYS show day sheet
  void _onDayTapped(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    widget.onDateSelected?.call(date);

    final reminders = _getRemindersForDate(date);
    // ALWAYS show day sheet (even for empty days)
    _showDayRemindersSheet(date, reminders);
  }

  /// Show day reminders in bottom sheet
  void _showDayRemindersSheet(DateTime date, List<Reminder> reminders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayRemindersSheet(
        date: date,
        reminders: reminders,
        onEdit: widget.onReminderEdit,
        onDelete: widget.onReminderDelete,
        onAddToSpace: widget.onAddToSpace,
        onNavigatePrevious: () {
          final prevDay = date.subtract(const Duration(days: 1));
          Navigator.pop(context);
          _onDayTapped(prevDay);
        },
        onNavigateNext: () {
          final nextDay = date.add(const Duration(days: 1));
          Navigator.pop(context);
          _onDayTapped(nextDay);
        },
        onAddReminderTap: () {
          Navigator.pop(context);
          _openAddReminderForDate(date);
        },
        buildDraggableCard: (reminder, allReminders, index) {
          return _buildDraggableReminderCard(
            reminder: reminder,
            allReminders: allReminders,
            currentIndex: index,
          );
        },
      ),
    );
  }

  /// Open AIAddReminderModal with date pre-selected
  Future<void> _openAddReminderForDate(DateTime date) async {
    // Create a new reminder with the selected date
    final newReminder = Reminder(
      title: '',
      scheduledTime: DateTime(
        date.year,
        date.month,
        date.day,
        9, // Default to 9 AM
        0,
      ),
    );

    // Show the AI/Manual/Voice modal
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return AIAddReminderModal(
          reminder: newReminder,
        );
      },
    );
  }

  /// Navigate to previous month
  void navigateToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  /// Navigate to next month
  void navigateToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  /// Navigate to today
  void navigateToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDate = now;
    });
    widget.onDateSelected?.call(now);
  }

  /// Reschedule reminder to new date (drag & drop)
  Future<void> _rescheduleReminder(Reminder reminder, DateTime newDate) async {
    // Keep the same time, just change the date
    final newScheduledTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      reminder.scheduledTime.hour,
      reminder.scheduledTime.minute,
    );

    final updatedReminder = reminder.copyWith(
      scheduledTime: newScheduledTime,
      updatedAt: DateTime.now(),
    );

    await StorageService.updateReminder(updatedReminder);

    // Show snackbar to confirm
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder moved to ${DateFormat('MMM d').format(newDate)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _getCalendarDays();
    final selectedDateReminders = _getSelectedDateReminders();
    final theme = Theme.of(context);
    final selectedDateFormatted = _selectedDate != null
        ? DateFormat('MMM d, y').format(_selectedDate!)
        : DateFormat('MMM d, y').format(DateTime.now());

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Weekday headers
        SliverToBoxAdapter(
          child: _buildWeekdayHeaders(theme),
        ),

        // Calendar grid
        SliverToBoxAdapter(
          child: _buildCalendarGrid(days, theme),
        ),

        // Divider
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        ),

        // Selected date reminders list header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Text(
                  selectedDateFormatted,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${selectedDateReminders.length}',
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

        // Selected date reminders list
        selectedDateReminders.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No reminders for this day',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final reminder = selectedDateReminders[index];
                    return _buildDraggableReminderCard(
                      reminder: reminder,
                      allReminders: selectedDateReminders,
                      currentIndex: index,
                    );
                  },
                  childCount: selectedDateReminders.length,
                ),
              ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders(ThemeData theme) {
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: weekdays.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(List<DateTime> days, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: List.generate(6, (weekIndex) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(7, (dayIndex) {
              final index = weekIndex * 7 + dayIndex;
              if (index >= days.length) return const Expanded(child: SizedBox(height: 60)); // Uniform height

              final date = days[index];
              final reminders = _getRemindersForDate(date);
              final isToday = _isToday(date);
              final isInMonth = _isInCurrentMonth(date);
              final isSelected = _isSelected(date);

              return Expanded(
                child: SizedBox(
                  height: 60, // Fixed height for all cells
                  child: _buildDayCell(
                    date,
                    reminders,
                    isToday,
                    isInMonth,
                    isSelected,
                    theme,
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    List<Reminder> reminders,
    bool isToday,
    bool isInMonth,
    bool isSelected,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return DragTarget<Reminder>(
      onAcceptWithDetails: (details) {
        // Reschedule the dragged reminder to this date
        _rescheduleReminder(details.data, date);
      },
      builder: (context, candidateData, rejectedData) {
        final isHoveringDrag = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: () => _onDayTapped(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isHoveringDrag
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : isSelected
                      ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.15)
                      : isToday
                          ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.1 : 0.05)
                          : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHoveringDrag
                    ? theme.colorScheme.primary
                    : isSelected
                        ? theme.colorScheme.primary
                        : isToday
                            ? theme.colorScheme.primary.withValues(alpha: 0.5)
                            : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: isHoveringDrag || isSelected || isToday ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date number
                Text(
                  '${date.day}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    color: isInMonth
                        ? (isToday || isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: isToday ? 14 : 12,
                  ),
                ),
                // Reminder count indicator
                if (reminders.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${reminders.length}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build a draggable reminder card for drag & drop
  Widget _buildDraggableReminderCard({
    required Reminder reminder,
    required List<Reminder> allReminders,
    required int currentIndex,
  }) {
    return LongPressDraggable<Reminder>(
      data: reminder,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.event,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reminder.title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: ReminderCardWidget(
          reminder: reminder,
          onEdit: widget.onReminderEdit,
          onDelete: widget.onReminderDelete,
          onAddToSpace: widget.onAddToSpace,
          allReminders: allReminders,
          currentIndex: currentIndex,
        ),
      ),
      child: ReminderCardWidget(
        reminder: reminder,
        onEdit: widget.onReminderEdit,
        onDelete: widget.onReminderDelete,
        onAddToSpace: widget.onAddToSpace,
        allReminders: allReminders,
        currentIndex: currentIndex,
      ),
    );
  }

  /// Get current month as DateTime
  DateTime get currentMonth => _currentMonth;

  /// Get selected date
  DateTime? get selectedDate => _selectedDate;
}

/// Day reminders bottom sheet with navigation
class _DayRemindersSheet extends StatelessWidget {
  final DateTime date;
  final List<Reminder> reminders;
  final Function(Reminder)? onEdit;
  final Function(Reminder)? onDelete;
  final Function(List<String>)? onAddToSpace;
  final VoidCallback onNavigatePrevious;
  final VoidCallback onNavigateNext;
  final VoidCallback onAddReminderTap;
  final Widget Function(Reminder reminder, List<Reminder> allReminders, int index)? buildDraggableCard;

  const _DayRemindersSheet({
    required this.date,
    required this.reminders,
    this.onEdit,
    this.onDelete,
    this.onAddToSpace,
    required this.onNavigatePrevious,
    required this.onNavigateNext,
    required this.onAddReminderTap,
    this.buildDraggableCard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header with navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  // Previous day button
                  IconButton(
                    onPressed: onNavigatePrevious,
                    icon: const Icon(Icons.chevron_left),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Date info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(date),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMMM d, y').format(date),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reminder count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${reminders.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Next day button
                  IconButton(
                    onPressed: onNavigateNext,
                    icon: const Icon(Icons.chevron_right),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // Reminders list with Add button
            reminders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 48,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No reminders for this day',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onAddReminderTap,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Reminder'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 16), // Reduced padding
                        itemCount: reminders.length + 1, // +1 for the Add button
                        itemBuilder: (context, index) {
                          // Last item is the Add Reminder button
                          if (index == reminders.length) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: onAddReminderTap,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Reminder'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final reminder = reminders[index];
                          // Use draggable card builder if provided, otherwise use regular card
                          if (buildDraggableCard != null) {
                            return buildDraggableCard!(reminder, reminders, index);
                          }
                          return ReminderCardWidget(
                            reminder: reminder,
                            onEdit: onEdit,
                            onDelete: onDelete,
                            onAddToSpace: onAddToSpace,
                            allReminders: reminders,
                            currentIndex: index,
                          );
                        },
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}
