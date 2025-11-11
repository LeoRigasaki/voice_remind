// [lib/services]/calendar_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:voice_remind/models/custom_repeat_config.dart';
import '../models/calendar_event.dart';
import '../models/reminder.dart';
import '../models/space.dart';
import '../services/storage_service.dart';
import '../services/spaces_service.dart';
import '../services/notification_service.dart';

/// Service for managing calendar events and their integration with reminders
class CalendarService {
  static CalendarService? _instance;
  static CalendarService get instance => _instance ??= CalendarService._();

  CalendarService._();

  // Stream controllers for real-time updates
  final _eventsController = StreamController<List<CalendarEvent>>.broadcast();
  final _selectedDateController = StreamController<DateTime>.broadcast();

  // Cache
  List<CalendarEvent> _cachedEvents = [];
  Map<String, Space> _cachedSpaces = {};
  DateTime _selectedDate = DateTime.now();

  // Getters for streams
  Stream<List<CalendarEvent>> get eventsStream => _eventsController.stream;
  Stream<DateTime> get selectedDateStream => _selectedDateController.stream;

  // Getters for current state
  List<CalendarEvent> get currentEvents => List.unmodifiable(_cachedEvents);
  DateTime get selectedDate => _selectedDate;

  /// Initialize the calendar service
  static Future<void> initialize() async {
    debugPrint('🗓️ Initializing Calendar Service...');
    await instance._loadInitialData();
    instance._listenToReminderChanges();
    debugPrint('✅ Calendar Service initialized');
  }

  /// Load initial calendar data
  Future<void> _loadInitialData() async {
    try {
      // Load spaces first for color mapping
      await _loadSpaces();

      // Load and convert reminders to calendar events
      await _loadEventsFromReminders();
    } catch (e) {
      debugPrint('❌ Error loading calendar data: $e');
    }
  }

  /// Load spaces for color mapping
  Future<void> _loadSpaces() async {
    try {
      final spaces = await SpacesService.getSpaces();
      _cachedSpaces = {for (var space in spaces) space.id: space};
      debugPrint('📁 Loaded ${spaces.length} spaces for calendar');
    } catch (e) {
      debugPrint('⚠️ Error loading spaces: $e');
    }
  }

  /// Convert reminders to calendar events
  Future<void> _loadEventsFromReminders() async {
    try {
      final reminders = await StorageService.getReminders();

      _cachedEvents = reminders.map((reminder) {
        final space =
            reminder.spaceId != null ? _cachedSpaces[reminder.spaceId!] : null;
        return CalendarEvent.fromReminder(reminder, space: space);
      }).toList();

      // Sort events by start time
      _cachedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Notify listeners
      _eventsController.add(_cachedEvents);

      debugPrint('📅 Loaded ${_cachedEvents.length} calendar events');
    } catch (e) {
      debugPrint('❌ Error loading calendar events: $e');
    }
  }

  /// Listen to reminder changes and update calendar
  void _listenToReminderChanges() {
    StorageService.remindersStream.listen((reminders) {
      _updateEventsFromReminders(reminders);
    });
  }

  /// Update events when reminders change
  Future<void> _updateEventsFromReminders(List<Reminder> reminders) async {
    try {
      // Reload spaces if needed
      if (_cachedSpaces.isEmpty) {
        await _loadSpaces();
      }

      _cachedEvents = reminders.map((reminder) {
        final space =
            reminder.spaceId != null ? _cachedSpaces[reminder.spaceId!] : null;
        return CalendarEvent.fromReminder(reminder, space: space);
      }).toList();

      // Sort events by start time
      _cachedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Notify listeners
      _eventsController.add(_cachedEvents);
    } catch (e) {
      debugPrint('❌ Error updating calendar events: $e');
    }
  }

  /// Get events for a specific date range
  List<CalendarEvent> getEventsForDateRange(DateTime start, DateTime end) {
    return _cachedEvents.where((event) {
      return event.startTime.isAfter(start.subtract(const Duration(days: 1))) &&
          event.startTime.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get events for a specific date
  List<CalendarEvent> getEventsForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _cachedEvents.where((event) {
      return event.startTime
              .isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
          event.startTime.isBefore(dayEnd);
    }).toList();
  }

  /// Create a new reminder from calendar
  Future<CalendarEvent?> createReminderFromCalendar({
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    String? spaceId,
    RepeatType repeatType = RepeatType.none,
    CustomRepeatConfig? customRepeatConfig,
  }) async {
    try {
      // Create the reminder
      final reminder = Reminder(
        title: title,
        description: description?.isNotEmpty == true ? description : null,
        scheduledTime: startTime,
        repeatType: repeatType,
        spaceId: spaceId,
        isNotificationEnabled: true,
        customRepeatConfig: customRepeatConfig,
      );

      // Save to storage
      await StorageService.addReminder(reminder);

      // Schedule notification
      await NotificationService.scheduleReminder(reminder);

      debugPrint('✅ Created reminder from calendar: $title');

      // Return the calendar event (will be updated via stream)
      final space = spaceId != null ? _cachedSpaces[spaceId] : null;
      return CalendarEvent.fromReminder(reminder, space: space);
    } catch (e) {
      debugPrint('❌ Error creating reminder from calendar: $e');
      return null;
    }
  }

  /// UPDATED: Enhanced reminder update with endTime support
  Future<bool> updateReminderFromCalendar({
    required String reminderId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime, // Added endTime support
    String? spaceId,
    RepeatType? repeatType,
  }) async {
    try {
      // Get the original reminder
      final reminders = await StorageService.getReminders();
      final originalReminder = reminders.firstWhere((r) => r.id == reminderId);

      // Calculate duration preservation logic
      DateTime newScheduledTime = startTime ?? originalReminder.scheduledTime;

      // If we have both start and end times from drag operation, use the start time
      // The end time is mainly for calendar display duration, but reminders use scheduledTime
      if (startTime != null && endTime != null) {
        newScheduledTime = startTime;
        debugPrint(
            '🕐 Updated reminder time from ${originalReminder.scheduledTime} to $newScheduledTime');
      }

      // Create updated reminder
      final updatedReminder = originalReminder.copyWith(
        title: title ?? originalReminder.title,
        description: description ?? originalReminder.description,
        scheduledTime: newScheduledTime,
        repeatType: repeatType ?? originalReminder.repeatType,
        spaceId: spaceId ?? originalReminder.spaceId,
      );

      // Update in storage
      await StorageService.updateReminder(updatedReminder);

      // Reschedule notification if the time changed
      if (startTime != null) {
        await NotificationService.cancelReminder(reminderId);
        if (updatedReminder.isNotificationEnabled &&
            updatedReminder.scheduledTime.isAfter(DateTime.now())) {
          await NotificationService.scheduleReminder(updatedReminder);
        }
      }

      debugPrint('✅ Updated reminder from calendar: ${updatedReminder.title}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating reminder from calendar: $e');
      return false;
    }
  }

  /// Delete a reminder from calendar
  Future<bool> deleteReminderFromCalendar(String reminderId) async {
    try {
      await StorageService.deleteReminder(reminderId);
      await NotificationService.cancelReminder(reminderId);
      debugPrint('✅ Deleted reminder from calendar: $reminderId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting reminder from calendar: $e');
      return false;
    }
  }

  /// Toggle reminder completion from calendar
  Future<bool> toggleReminderCompletion(String reminderId) async {
    try {
      final reminders = await StorageService.getReminders();
      final reminder = reminders.firstWhere((r) => r.id == reminderId);

      final newStatus = reminder.isCompleted
          ? ReminderStatus.pending
          : ReminderStatus.completed;

      await StorageService.updateReminderStatus(reminderId, newStatus);

      if (newStatus == ReminderStatus.completed) {
        await NotificationService.cancelReminder(reminderId);
      } else if (reminder.scheduledTime.isAfter(DateTime.now())) {
        await NotificationService.scheduleReminder(
            reminder.copyWith(status: newStatus));
      }

      debugPrint('✅ Toggled reminder completion: $reminderId');
      return true;
    } catch (e) {
      debugPrint('❌ Error toggling reminder completion: $e');
      return false;
    }
  }

  /// Update selected date
  void updateSelectedDate(DateTime date) {
    _selectedDate = date;
    _selectedDateController.add(date);
  }

  /// Get events count for date (for calendar badges)
  int getEventsCountForDate(DateTime date) {
    return getEventsForDate(date).length;
  }

  /// Get pending events count for date
  int getPendingEventsCountForDate(DateTime date) {
    return getEventsForDate(date).where((event) => !event.isCompleted).length;
  }

  /// Get overdue events
  List<CalendarEvent> getOverdueEvents() {
    final now = DateTime.now();
    return _cachedEvents.where((event) {
      return event.startTime.isBefore(now) &&
          !event.isCompleted &&
          event.status != ReminderStatus.completed;
    }).toList();
  }

  /// Get today's events
  List<CalendarEvent> getTodayEvents() {
    return getEventsForDate(DateTime.now());
  }

  /// Get upcoming events (next 7 days)
  List<CalendarEvent> getUpcomingEvents({int days = 7}) {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));

    return _cachedEvents.where((event) {
      return event.startTime.isAfter(now) &&
          event.startTime.isBefore(future) &&
          !event.isCompleted;
    }).toList();
  }

  /// Get events grouped by date for better organization
  Map<DateTime, List<CalendarEvent>> getEventsGroupedByDate({int days = 30}) {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));

    final eventsInRange = _cachedEvents.where((event) {
      return event.startTime.isAfter(now.subtract(const Duration(days: 1))) &&
          event.startTime.isBefore(future);
    }).toList();

    final Map<DateTime, List<CalendarEvent>> groupedEvents = {};

    for (final event in eventsInRange) {
      final dateKey = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );

      if (groupedEvents[dateKey] == null) {
        groupedEvents[dateKey] = [];
      }
      groupedEvents[dateKey]!.add(event);
    }

    // Sort events within each day
    for (final events in groupedEvents.values) {
      events.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return groupedEvents;
  }

  /// Get statistics for dashboard/overview
  Map<String, dynamic> getCalendarStatistics() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekFromNow = today.add(const Duration(days: 7));

    final todayEvents = getEventsForDate(today);
    final tomorrowEvents = getEventsForDate(tomorrow);
    final weekEvents = getEventsForDateRange(today, weekFromNow);
    final overdueEvents = getOverdueEvents();

    return {
      'totalEvents': _cachedEvents.length,
      'todayEvents': todayEvents.length,
      'tomorrowEvents': tomorrowEvents.length,
      'weekEvents': weekEvents.length,
      'overdueEvents': overdueEvents.length,
      'completedToday': todayEvents.where((e) => e.isCompleted).length,
      'pendingToday': todayEvents.where((e) => !e.isCompleted).length,
    };
  }

  /// Refresh calendar data
  Future<void> refresh() async {
    await _loadInitialData();
  }

  /// Dispose of the service
  void dispose() {
    _eventsController.close();
    _selectedDateController.close();
  }
}
