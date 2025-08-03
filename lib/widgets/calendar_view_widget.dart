// [lib/widgets]/calendar_view_widget.dart
import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart' as kalender;
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import 'calendar_event_tile.dart';
import 'quick_add_event_dialog.dart';
import 'event_details_sheet.dart';
import '../screens/add_reminder_screen.dart';

/// Calendar widget wrapper that integrates kalender with our reminder system
class CalendarViewWidget extends StatefulWidget {
  final kalender.ViewConfiguration viewConfiguration;
  final Function(CalendarEvent)? onEventTapped;
  final Function(CalendarEvent)? onEventEdit;
  final Function(CalendarEvent)? onEventDelete;
  final Function(DateTime)? onDateSelected;

  const CalendarViewWidget({
    super.key,
    required this.viewConfiguration,
    this.onEventTapped,
    this.onEventEdit,
    this.onEventDelete,
    this.onDateSelected,
  });

  @override
  State<CalendarViewWidget> createState() => CalendarViewWidgetState();
}

class CalendarViewWidgetState extends State<CalendarViewWidget> {
  late kalender.DefaultEventsController<CalendarEvent> _eventsController;
  late kalender.CalendarController<CalendarEvent> _calendarController;
  CalendarEvent? _selectedEvent;
  bool _isLoading = true;

  // Interaction and snapping configurations
  late ValueNotifier<kalender.CalendarInteraction> _calendarInteraction;
  late ValueNotifier<kalender.CalendarSnapping> _calendarSnapping;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeInteractionSettings();
    _loadEvents();
    _listenToEventChanges();

    // Navigate to today when calendar opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToToday();
    });
  }

  void _initializeControllers() {
    _eventsController = kalender.DefaultEventsController<CalendarEvent>();
    _calendarController = kalender.CalendarController<CalendarEvent>();
  }

  void _initializeInteractionSettings() {
    // Updated interaction settings based on requirements
    _calendarInteraction = ValueNotifier(kalender.CalendarInteraction(
      allowResizing: true,
      allowRescheduling: true, // This enables drag and drop via long press
      allowEventCreation: true,
      createEventGesture:
          kalender.CreateEventGesture.tap, // Changed from longPress to tap
    ));

    // Configure snapping for better UX
    _calendarSnapping = ValueNotifier(const kalender.CalendarSnapping(
      snapIntervalMinutes: 15, // Snap to 15-minute intervals
      snapToTimeIndicator: true,
      snapToOtherEvents: true,
      snapRange: Duration(minutes: 5),
    ));
  }

  /// Navigate to today's date and current time
  void _navigateToToday() {
    final now = DateTime.now();

    // Navigate to today's date
    _calendarController.animateToDateTime(now);

    // Update selected date
    widget.onDateSelected?.call(now);

    debugPrint('📅 Navigated to today: $now');
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final events = CalendarService.instance.currentEvents;

      // Convert to kalender events
      final kalenderEvents = events.map((event) {
        return kalender.CalendarEvent<CalendarEvent>(
          dateTimeRange: DateTimeRange(
            start: event.startTime,
            end: event.endTime,
          ),
          data: event,
        );
      }).toList();

      _eventsController.addEvents(kalenderEvents);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading calendar events: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenToEventChanges() {
    CalendarService.instance.eventsStream.listen((events) {
      if (mounted) {
        _updateEventsInController(events);
      }
    });
  }

  void _updateEventsInController(List<CalendarEvent> events) {
    // Clear existing events
    _eventsController.removeEvents(_eventsController.events.toList());

    // Add new events
    final kalenderEvents = events.map((event) {
      return kalender.CalendarEvent<CalendarEvent>(
        dateTimeRange: DateTimeRange(
          start: event.startTime,
          end: event.endTime,
        ),
        data: event,
      );
    }).toList();

    _eventsController.addEvents(kalenderEvents);
  }

  @override
  void dispose() {
    _eventsController.dispose();
    _calendarController.dispose();
    _calendarInteraction.dispose();
    _calendarSnapping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return kalender.CalendarView<CalendarEvent>(
      eventsController: _eventsController,
      calendarController: _calendarController,
      viewConfiguration: widget.viewConfiguration,

      // Enhanced calendar callbacks with new tap behavior
      callbacks: kalender.CalendarCallbacks<CalendarEvent>(
        // When user taps on a reminder - show details with edit/delete options
        onEventTapped: (event, renderBox) => _showEventDetails(event),

        // When user taps on empty space - add new reminder for that time/date
        onTapped: _onEmptySpaceTapped,
        onMultiDayTapped: _onMultiDayTapped,

        // FIXED: Drag and drop handling with proper data persistence
        onEventChanged: _onEventChanged,
        onEventCreated: _onEventCreated,
        onEventCreate: _onEventCreate,
      ),

      // Calendar header with proper tile components
      header: kalender.CalendarHeader<CalendarEvent>(
        multiDayTileComponents: _buildTileComponents(),
      ),

      // Calendar body with interaction and snapping
      body: kalender.CalendarBody<CalendarEvent>(
        multiDayTileComponents: _buildTileComponents(),
        monthTileComponents: _buildTileComponents(),
        scheduleTileComponents: _buildScheduleTileComponents(),
        multiDayBodyConfiguration: kalender.MultiDayBodyConfiguration(
          minimumTileHeight: 32.0,
          horizontalPadding: const EdgeInsets.only(left: 4, right: 4),
          eventLayoutStrategy: kalender.overlapLayoutStrategy,
        ),
        monthBodyConfiguration: kalender.MonthBodyConfiguration(
          tileHeight: 32,
        ),
        scheduleBodyConfiguration: kalender.ScheduleBodyConfiguration(
          emptyDay: kalender.EmptyDayBehavior.hide,
        ),
        // Pass interaction and snapping configurations
        interaction: _calendarInteraction,
        snapping: _calendarSnapping,
      ),
    );
  }

  /// Build tile components for event rendering with drag and drop support
  kalender.TileComponents<CalendarEvent> _buildTileComponents() {
    return kalender.TileComponents<CalendarEvent>(
      // Normal stationary tile
      tileBuilder: (event, tileRange) => _buildEventTile(event),

      // Tile when being dragged (shows in original position)
      tileWhenDraggingBuilder: (event) => _buildDraggingEventTile(event),

      // Feedback tile (follows cursor/finger during drag)
      feedbackTileBuilder: (event, size) =>
          _buildFeedbackEventTile(event, size),

      // Drop target tile (shows where event will be dropped)
      dropTargetTile: (event) => _buildDropTargetTile(event),
    );
  }

  /// Build schedule-specific tile components
  kalender.ScheduleTileComponents<CalendarEvent>
      _buildScheduleTileComponents() {
    return kalender.ScheduleTileComponents<CalendarEvent>(
      tileBuilder: (event, tileRange) => _buildScheduleEventTile(event),
      tileWhenDraggingBuilder: (event) => _buildDraggingEventTile(event),
      feedbackTileBuilder: (event, size) =>
          _buildFeedbackEventTile(event, size),
      dropTargetTile: (event) => _buildDropTargetTile(event),
    );
  }

  /// Build event tile - only handles display, tap opens details
  Widget _buildEventTile(kalender.CalendarEvent<CalendarEvent> event) {
    final calendarEvent = event.data;
    if (calendarEvent == null) return const SizedBox.shrink();

    return CalendarEventTile(
      event: calendarEvent,
      isSelected: _selectedEvent?.id == calendarEvent.id,
      // Tap shows details instead of selection
      onTap: () => _showEventDetails(event),
      showTimeInfo: true,
    );
  }

  /// Build dragging event tile with visual feedback
  Widget _buildDraggingEventTile(kalender.CalendarEvent<CalendarEvent> event) {
    final calendarEvent = event.data;
    if (calendarEvent == null) return const SizedBox.shrink();

    return Opacity(
      opacity: 0.5,
      child: CalendarEventTile(
        event: calendarEvent,
        isSelected: _selectedEvent?.id == calendarEvent.id,
        isDragging: true,
        onTap: () => _showEventDetails(event),
        showTimeInfo: true,
      ),
    );
  }

  /// Build feedback tile (follows cursor/finger when dragging)
  Widget _buildFeedbackEventTile(
      kalender.CalendarEvent<CalendarEvent> event, Size dropTargetWidgetSize) {
    final calendarEvent = event.data;
    if (calendarEvent == null) return const SizedBox.shrink();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      shadowColor: calendarEvent.color.withValues(alpha: 0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: calendarEvent.color,
            width: 2,
          ),
        ),
        child: CalendarEventTile(
          event: calendarEvent,
          isSelected: true,
          isDragging: true,
          onTap: () => _showEventDetails(event),
          showTimeInfo: true,
          width: dropTargetWidgetSize.width,
          height: dropTargetWidgetSize.height,
        ),
      ),
    );
  }

  /// Build drop target tile
  Widget _buildDropTargetTile(kalender.CalendarEvent<CalendarEvent> event) {
    final calendarEvent = event.data;
    if (calendarEvent == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: calendarEvent.color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: calendarEvent.color,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.adjust,
          color: calendarEvent.color,
          size: 24,
        ),
      ),
    );
  }

  /// Build schedule view event tile
  Widget _buildScheduleEventTile(kalender.CalendarEvent<CalendarEvent> event) {
    final calendarEvent = event.data;
    if (calendarEvent == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: 2,
      child: CalendarEventTile(
        event: calendarEvent,
        isSelected: _selectedEvent?.id == calendarEvent.id,
        onTap: () => _showEventDetails(event),
        showTimeInfo: true,
      ),
    );
  }

  /// Show event details with edit/delete options (replaces old tap behavior)
  void _showEventDetails(kalender.CalendarEvent<CalendarEvent> event) {
    final calendarEvent = event.data;
    if (calendarEvent == null) return;

    // Update selected event
    setState(() {
      _selectedEvent = calendarEvent;
    });

    // Update calendar controller selection
    _calendarController.selectEvent(event);

    // Show new modern details sheet
    showEventDetailsSheet(
      context: context,
      event: calendarEvent,
      onEdit: () => _editEvent(calendarEvent),
      onDelete: () => _deleteEvent(calendarEvent),
      onToggleCompletion: () => _toggleCompletion(calendarEvent),
    );

    widget.onEventTapped?.call(calendarEvent);
  }

  /// Handle taps on empty calendar space (day view)
  void _onEmptySpaceTapped(DateTime dateTime) {
    debugPrint('📅 Tapped empty space at: $dateTime');

    // Clear selection
    setState(() {
      _selectedEvent = null;
    });
    _calendarController.deselectEvent();

    // Show quick add dialog for the tapped time
    _showQuickAddDialog(DateTimeRange(
      start: dateTime,
      end: dateTime.add(const Duration(hours: 1)),
    ));
  }

  /// Handle taps on multi-day headers or month cells
  void _onMultiDayTapped(DateTimeRange dateRange) {
    debugPrint('📅 Tapped multi-day area: ${dateRange.start}');

    // Clear selection
    setState(() {
      _selectedEvent = null;
    });
    _calendarController.deselectEvent();

    // Show quick add dialog for the tapped date
    _showQuickAddDialog(dateRange);
  }

  /// FIXED: Handle event changed (drag/drop or resize) with proper data persistence
  Future<void> _onEventChanged(
    kalender.CalendarEvent<CalendarEvent> originalEvent,
    kalender.CalendarEvent<CalendarEvent> updatedEvent,
  ) async {
    final calendarEvent = originalEvent.data;
    if (calendarEvent == null) return;

    debugPrint(
        '🔄 Event dragged from ${originalEvent.dateTimeRange.start} to ${updatedEvent.dateTimeRange.start}');

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Updating reminder...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // FIXED: Properly update the reminder with new time from drag operation
    final success = await CalendarService.instance.updateReminderFromCalendar(
      reminderId: calendarEvent.id,
      startTime: updatedEvent.dateTimeRange.start,
      // Also update end time to maintain duration
      endTime: updatedEvent.dateTimeRange.end,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Reminder moved successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Text('Failed to move reminder'),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _onEventChanged(originalEvent, updatedEvent),
            ),
          ),
        );
      }
    }
  }

  /// Handle event created
  Future<void> _onEventCreated(
      kalender.CalendarEvent<CalendarEvent> event) async {
    debugPrint('Event created: ${event.data?.title}');
  }

  /// Create new event (called before creation)
  kalender.CalendarEvent<CalendarEvent>? _onEventCreate(
      kalender.CalendarEvent<CalendarEvent> event) {
    // We handle creation via dialog, so return null
    return null;
  }

  /// Show quick add dialog
  Future<void> _showQuickAddDialog(DateTimeRange? dateTimeRange) async {
    final result = await showDialog<CalendarEvent>(
      context: context,
      barrierDismissible: true,
      builder: (context) => QuickAddEventDialog(
        initialDateTime: dateTimeRange?.start,
      ),
    );

    if (result != null) {
      debugPrint('✅ Quick add result: ${result.title}');
    }
  }

  /// Toggle reminder completion
  Future<void> _toggleCompletion(CalendarEvent event) async {
    final success =
        await CalendarService.instance.toggleReminderCompletion(event.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.isCompleted
                ? 'Reminder marked as incomplete'
                : 'Reminder completed!'),
            backgroundColor: event.isCompleted ? Colors.orange : Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update reminder'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Edit an existing event
  Future<void> _editEvent(CalendarEvent event) async {
    widget.onEventEdit?.call(event);

    // Navigate to full edit screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(
          reminder: event.originalReminder,
        ),
      ),
    );

    if (result == true) {
      debugPrint('✅ Event edited successfully');
    }
  }

  /// Delete an event
  Future<void> _deleteEvent(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: Text(
          'Are you sure you want to delete "${event.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onEventDelete?.call(event);

      final success =
          await CalendarService.instance.deleteReminderFromCalendar(event.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.delete, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Reminder deleted'),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete reminder'),
            ),
          );
        }
      }
    }
  }

  /// Get current selected event
  CalendarEvent? get selectedEvent => _selectedEvent;

  /// Clear selection
  void clearSelection() {
    setState(() {
      _selectedEvent = null;
    });
    _calendarController.deselectEvent();
  }

  /// Navigate to specific date
  void navigateToDate(DateTime date) {
    _calendarController.animateToDate(date);
    widget.onDateSelected?.call(date);
  }

  /// Navigate to today
  void navigateToToday() {
    _navigateToToday();
  }

  /// Navigate to previous view
  void navigateToPrevious() {
    _calendarController.animateToPreviousPage();
  }

  /// Navigate to next view
  void navigateToNext() {
    _calendarController.animateToNextPage();
  }
}
