import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum ReminderStatus {
  pending,
  completed,
  overdue,
}

enum RepeatType {
  none,
  daily,
  weekly,
  monthly,
}

/// Individual time slot within a reminder
class TimeSlot {
  final String id;
  final TimeOfDay time;
  final String? description;
  final ReminderStatus status;
  final DateTime? completedAt;

  TimeSlot({
    String? id,
    required this.time,
    this.description,
    this.status = ReminderStatus.pending,
    this.completedAt,
  }) : id = id ?? const Uuid().v4();

  /// Helper methods
  bool get isCompleted => status == ReminderStatus.completed;
  bool isOverdueFor(DateTime reminderDate) {
    final now = DateTime.now();
    final slotDateTime = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      time.hour,
      time.minute,
    );
    return status == ReminderStatus.pending && slotDateTime.isBefore(now);
  }

  /// 🔧 Backward compatibility - assumes current date for single-time reminders
  bool get isOverdue {
    final now = DateTime.now();
    final todayWithTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return status == ReminderStatus.pending && todayWithTime.isBefore(now);
  }

  String get formattedTime {
    final hour =
        time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String get formattedTime24 {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int get timeInMinutes => time.hour * 60 + time.minute;

  /// Create a copy with modified fields
  TimeSlot copyWith({
    TimeOfDay? time,
    String? description,
    ReminderStatus? status,
    DateTime? completedAt,
  }) {
    return TimeSlot(
      id: id,
      time: time ?? this.time,
      description: description ?? this.description,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'description': description,
      'status': status.index,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  /// Create from Map
  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      id: map['id'],
      time: TimeOfDay(hour: map['hour'], minute: map['minute']),
      description: map['description'],
      status: ReminderStatus.values[map['status']],
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
    );
  }

  @override
  String toString() {
    return 'TimeSlot(id: $id, time: $formattedTime, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeSlot && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class Reminder {
  final String id;
  final String title;
  final String? description;
  final DateTime
      scheduledTime; // For backward compatibility (single-time reminders)
  final ReminderStatus status;
  final RepeatType repeatType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isNotificationEnabled;
  final String? spaceId;
  final List<TimeSlot> timeSlots; // New: Multiple time slots
  final bool isMultiTime; // New: UI rendering flag

  Reminder({
    String? id,
    required this.title,
    this.description,
    required this.scheduledTime,
    this.status = ReminderStatus.pending,
    this.repeatType = RepeatType.none,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isNotificationEnabled = true,
    this.spaceId,
    List<TimeSlot>? timeSlots,
    bool? isMultiTime,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        timeSlots = timeSlots ?? [],
        isMultiTime = isMultiTime ?? (timeSlots?.isNotEmpty == true);

  /// Smart getters for multi-time logic
  bool get hasMultipleTimes => timeSlots.isNotEmpty;

  ///Overall status now uses correct date for overdue calculation
  ReminderStatus get overallStatus {
    if (!hasMultipleTimes) return status; // Single-time reminder

    if (timeSlots.every((slot) => slot.isCompleted)) {
      return ReminderStatus.completed;
    } else if (timeSlots.any((slot) => slot.isOverdueFor(scheduledTime))) {
      return ReminderStatus.overdue;
    } else {
      return ReminderStatus.pending;
    }
  }

  ///Next pending slot now considers the reminder's date
  TimeSlot? get nextPendingSlot {
    if (!hasMultipleTimes) return null;

    final now = DateTime.now();
    final pendingSlots = timeSlots
        .where((slot) => slot.status == ReminderStatus.pending)
        .toList();

    if (pendingSlots.isEmpty) return null;

    // Sort by time
    pendingSlots.sort((a, b) => a.timeInMinutes.compareTo(b.timeInMinutes));
    final reminderDate = scheduledTime;

    // If reminder is for today, use current time comparison
    if (reminderDate.year == now.year &&
        reminderDate.month == now.month &&
        reminderDate.day == now.day) {
      final currentTimeInMinutes = now.hour * 60 + now.minute;

      // Find next slot after current time
      final nextSlot = pendingSlots.firstWhere(
        (slot) => slot.timeInMinutes > currentTimeInMinutes,
        orElse: () => pendingSlots.first, // Wrap around to first slot if needed
      );
      return nextSlot;
    } else {
      // If reminder is for future/past date, return first pending slot
      return pendingSlots.first;
    }
  }

  TimeSlot? get activeTimeSlot {
    return nextPendingSlot; // For now, active = next pending
  }

  double get progressPercentage {
    if (!hasMultipleTimes) {
      return isCompleted ? 1.0 : 0.0;
    }

    final completedCount = timeSlots.where((slot) => slot.isCompleted).length;
    return timeSlots.isEmpty ? 0.0 : completedCount / timeSlots.length;
  }

  /// Backward compatibility helpers
  bool get isOverdue {
    if (hasMultipleTimes) {
      return overallStatus == ReminderStatus.overdue;
    }
    return status == ReminderStatus.pending &&
        scheduledTime.isBefore(DateTime.now());
  }

  bool get isCompleted {
    if (hasMultipleTimes) {
      return overallStatus == ReminderStatus.completed;
    }
    return status == ReminderStatus.completed;
  }

  bool get isPending {
    if (hasMultipleTimes) {
      return overallStatus == ReminderStatus.pending;
    }
    return status == ReminderStatus.pending;
  }

  String get statusText {
    if (hasMultipleTimes) {
      switch (overallStatus) {
        case ReminderStatus.pending:
          return overallStatus == ReminderStatus.overdue
              ? 'Overdue'
              : 'Pending';
        case ReminderStatus.completed:
          return 'Completed';
        case ReminderStatus.overdue:
          return 'Overdue';
      }
    }

    switch (status) {
      case ReminderStatus.pending:
        return isOverdue ? 'Overdue' : 'Pending';
      case ReminderStatus.completed:
        return 'Completed';
      case ReminderStatus.overdue:
        return 'Overdue';
    }
  }

  String get repeatText {
    switch (repeatType) {
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

  /// Create a copy with modified fields
  Reminder copyWith({
    String? title,
    String? description,
    DateTime? scheduledTime,
    ReminderStatus? status,
    RepeatType? repeatType,
    DateTime? updatedAt,
    bool? isNotificationEnabled,
    String? spaceId,
    List<TimeSlot>? timeSlots,
    bool? isMultiTime,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      repeatType: repeatType ?? this.repeatType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isNotificationEnabled:
          isNotificationEnabled ?? this.isNotificationEnabled,
      spaceId: spaceId ?? this.spaceId,
      timeSlots: timeSlots ?? this.timeSlots,
      isMultiTime: isMultiTime ?? this.isMultiTime,
    );
  }

  /// Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'status': status.index,
      'repeatType': repeatType.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isNotificationEnabled': isNotificationEnabled,
      'spaceId': spaceId,
      'timeSlots': timeSlots.map((slot) => slot.toMap()).toList(),
      'isMultiTime': isMultiTime,
    };
  }

  /// Create from Map with migration support
  factory Reminder.fromMap(Map<String, dynamic> map) {
    // Handle migration from old single-time format
    final timeSlotsList = map['timeSlots'] as List<dynamic>?;
    final timeSlotsConverted = timeSlotsList
            ?.map(
                (slotMap) => TimeSlot.fromMap(slotMap as Map<String, dynamic>))
            .toList() ??
        [];

    final isMultiTimeValue = map['isMultiTime'] as bool? ?? false;

    return Reminder(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(map['scheduledTime']),
      status: ReminderStatus.values[map['status']],
      repeatType: RepeatType.values[map['repeatType']],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      isNotificationEnabled: map['isNotificationEnabled'] ?? true,
      spaceId: map['spaceId'],
      timeSlots: timeSlotsConverted,
      isMultiTime: isMultiTimeValue,
    );
  }

  @override
  String toString() {
    return 'Reminder(id: $id, title: $title, scheduledTime: $scheduledTime, status: $status, spaceId: $spaceId, multiTime: $isMultiTime, slots: ${timeSlots.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Reminder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
