// Custom Month View Calendar - Clean, bug-free implementation
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../models/reminder.dart';
import '../../services/calendar_service.dart';
import 'month_day_cell.dart';
import 'day_events_sheet.dart';
import '../../screens/add_reminder_screen.dart';

/// Custom month view calendar widget
/// - Clean grid layout
/// - Proper event dot counting (no phantom bugs!)
/// - Drag and drop support for moving events between days
class CustomMonthView extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime)? onDateSelected;
  final Function(CalendarEvent)? onEventTapped;

  const CustomMonthView({
    super.key,
    required this.initialDate,
    this.onDateSelected,
    this.onEventTapped,
  });

  @override
  State<CustomMonthView> createState() => CustomMonthViewState();
}

class CustomMonthViewState extends State<CustomMonthView> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  List<CalendarEvent> _events = [];
  CalendarEvent? _draggingEvent;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
    _selectedDate = widget.initialDate;
    _loadEvents();
    _listenToEventChanges();
  }

  void _loadEvents() {
    final events = CalendarService.instance.currentEvents;
    setState(() {
      _events = events;
    });
  }

  void _listenToEventChanges() {
    CalendarService.instance.eventsStream.listen((events) {
      if (mounted) {
        setState(() {
          _events = events;
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
    final endDate =
        lastDayOfMonth.add(Duration(days: 6 - lastWeekday));

    // Generate all days
    final days = <DateTime>[];
    DateTime current = startDate;
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  /// Get events for a specific date
  List<CalendarEvent> _getEventsForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _events.where((event) {
      return event.startTime.isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
          event.startTime.isBefore(dayEnd);
    }).toList();
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

  /// Handle day tap
  void _onDayTapped(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    widget.onDateSelected?.call(date);

    final events = _getEventsForDate(date);
    if (events.isNotEmpty) {
      // Show day events sheet
      _showDayEventsSheet(date, events);
    } else {
      // No events, open add reminder screen for this date
      _openAddReminderScreen(date);
    }
  }

  /// Show day events bottom sheet
  void _showDayEventsSheet(DateTime date, List<CalendarEvent> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayEventsSheet(
        date: date,
        events: events,
        onEventTap: (event) {
          Navigator.pop(context);
          widget.onEventTapped?.call(event);
        },
        onAddTap: () {
          Navigator.pop(context);
          _openAddReminderScreen(date);
        },
      ),
    );
  }

  /// Open add reminder screen for specific date
  Future<void> _openAddReminderScreen(DateTime date) async {
    // Create a new reminder template with the selected date
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(
          reminder: newReminder,
        ),
      ),
    );
  }

  /// Handle event drag start
  void _onEventDragStart(CalendarEvent event) {
    setState(() {
      _draggingEvent = event;
    });
  }

  /// Handle event drag end on a new day
  Future<void> _onEventDroppedOnDay(DateTime newDate) async {
    if (_draggingEvent == null) return;

    final event = _draggingEvent!;
    final oldDate = event.startTime;

    // Calculate new time (keep same time of day, just change the date)
    final newDateTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      oldDate.hour,
      oldDate.minute,
    );

    // Update the event
    final success = await CalendarService.instance.updateReminderFromCalendar(
      reminderId: event.id,
      startTime: newDateTime,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Moved to ${DateFormat('MMM d').format(newDate)}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Text('Failed to move reminder'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _draggingEvent = null;
    });
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

  @override
  Widget build(BuildContext context) {
    final days = _getCalendarDays();
    final theme = Theme.of(context);

    return Column(
      children: [
        // Weekday headers
        _buildWeekdayHeaders(theme),

        const SizedBox(height: 8),

        // Calendar grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85, // Slightly taller cells
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              final events = _getEventsForDate(date);
              final isToday = _isToday(date);
              final isInMonth = _isInCurrentMonth(date);
              final isSelected = _isSelected(date);

              return MonthDayCell(
                date: date,
                events: events,
                isToday: isToday,
                isInCurrentMonth: isInMonth,
                isSelected: isSelected,
                isDraggingOver: false,
                onTap: () => _onDayTapped(date),
                onEventDragStart: _onEventDragStart,
                onEventDropped: () => _onEventDroppedOnDay(date),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders(ThemeData theme) {
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  /// Get current month as DateTime
  DateTime get currentMonth => _currentMonth;

  /// Get selected date
  DateTime? get selectedDate => _selectedDate;
}
