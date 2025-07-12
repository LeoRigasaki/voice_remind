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

class Reminder {
  final String id;
  final String title;
  final String? description;
  final DateTime scheduledTime;
  final ReminderStatus status;
  final RepeatType repeatType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isNotificationEnabled;
  final String? spaceId; // New field for space association

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
    this.spaceId, // Optional space association
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Create a copy with modified fields
  Reminder copyWith({
    String? title,
    String? description,
    DateTime? scheduledTime,
    ReminderStatus? status,
    RepeatType? repeatType,
    DateTime? updatedAt,
    bool? isNotificationEnabled,
    String? spaceId,
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
    );
  }

  // Convert to Map for storage
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
      'spaceId': spaceId, // Include spaceId in serialization
    };
  }

  // Create from Map
  factory Reminder.fromMap(Map<String, dynamic> map) {
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
      spaceId: map['spaceId'], // Include spaceId in deserialization
    );
  }

  // Helper methods
  bool get isOverdue {
    return status == ReminderStatus.pending &&
        scheduledTime.isBefore(DateTime.now());
  }

  bool get isCompleted => status == ReminderStatus.completed;

  bool get isPending => status == ReminderStatus.pending;

  String get statusText {
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

  @override
  String toString() {
    return 'Reminder(id: $id, title: $title, scheduledTime: $scheduledTime, status: $status, spaceId: $spaceId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Reminder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
