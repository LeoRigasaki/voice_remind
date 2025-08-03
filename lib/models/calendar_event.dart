// [lib/models]/calendar_event.dart
import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../models/space.dart';

/// Calendar event model that wraps our existing Reminder for kalender integration
class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final Color color;
  final String? spaceId;
  final String? spaceName;
  final bool isCompleted;
  final RepeatType repeatType;
  final ReminderStatus status;
  final Reminder originalReminder;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    required this.color,
    this.spaceId,
    this.spaceName,
    this.isCompleted = false,
    this.repeatType = RepeatType.none,
    this.status = ReminderStatus.pending,
    required this.originalReminder,
  });

  /// Create CalendarEvent from Reminder
  factory CalendarEvent.fromReminder(Reminder reminder, {Space? space}) {
    // Calculate end time (default 1 hour duration for calendar display)
    final endTime = reminder.scheduledTime.add(const Duration(hours: 1));

    // Determine color from space or default
    Color eventColor =
        space?.color ?? const Color(0xFF6366F1); // Default indigo

    // Adjust alpha based on completion status
    if (reminder.isCompleted) {
      eventColor = eventColor.withValues(alpha: 0.5);
    }

    return CalendarEvent(
      id: reminder.id,
      title: reminder.title,
      description: reminder.description,
      startTime: reminder.scheduledTime,
      endTime: endTime,
      isAllDay: _isAllDayEvent(reminder.scheduledTime),
      color: eventColor,
      spaceId: reminder.spaceId,
      spaceName: space?.name,
      isCompleted: reminder.isCompleted,
      repeatType: reminder.repeatType,
      status: reminder.status,
      originalReminder: reminder,
    );
  }

  /// Check if event should be displayed as all-day
  static bool _isAllDayEvent(DateTime dateTime) {
    // Consider all-day if time is exactly midnight
    return dateTime.hour == 0 && dateTime.minute == 0 && dateTime.second == 0;
  }

  /// Convert to DateTimeRange for kalender
  DateTimeRange get dateTimeRange => DateTimeRange(
        start: startTime,
        end: endTime,
      );

  /// Get display duration text
  String get durationText {
    if (isAllDay) return 'All day';

    final duration = endTime.difference(startTime);
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h';
    } else {
      return '${duration.inDays}d';
    }
  }

  /// Get status icon
  IconData get statusIcon {
    switch (status) {
      case ReminderStatus.completed:
        return Icons.check_circle;
      case ReminderStatus.overdue:
        return Icons.warning;
      case ReminderStatus.pending:
        return Icons.schedule;
    }
  }

  /// Get status color
  Color get statusColor {
    switch (status) {
      case ReminderStatus.completed:
        return Colors.green;
      case ReminderStatus.overdue:
        return Colors.red;
      case ReminderStatus.pending:
        return Colors.blue;
    }
  }

  /// Create a copy with updated properties
  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    Color? color,
    String? spaceId,
    String? spaceName,
    bool? isCompleted,
    RepeatType? repeatType,
    ReminderStatus? status,
    Reminder? originalReminder,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
      spaceId: spaceId ?? this.spaceId,
      spaceName: spaceName ?? this.spaceName,
      isCompleted: isCompleted ?? this.isCompleted,
      repeatType: repeatType ?? this.repeatType,
      status: status ?? this.status,
      originalReminder: originalReminder ?? this.originalReminder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CalendarEvent{id: $id, title: $title, startTime: $startTime}';
  }
}
