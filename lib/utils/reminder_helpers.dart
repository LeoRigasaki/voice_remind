// [lib/utils]/reminder_helpers.dart
// Shared helper functions for reminder creation and management

import '../models/reminder.dart';

/// Get the display name for a RepeatType
String getRepeatDisplayName(RepeatType repeat) {
  switch (repeat) {
    case RepeatType.none:
      return 'No Repeat';
    case RepeatType.daily:
      return 'Daily';
    case RepeatType.weekly:
      return 'Weekly';
    case RepeatType.monthly:
      return 'Monthly';
    case RepeatType.custom:
      return 'Custom';
  }
}

/// Get the description for a RepeatType
String getRepeatDescription(RepeatType repeat) {
  switch (repeat) {
    case RepeatType.none:
      return 'This reminder will only trigger once';
    case RepeatType.daily:
      return 'Repeat every day at the same time';
    case RepeatType.weekly:
      return 'Repeat every week on the same day';
    case RepeatType.monthly:
      return 'Repeat every month on the same date';
    case RepeatType.custom:
      return 'Create a custom repeat schedule with flexible intervals';
  }
}

/// Validates if a reminder title is valid
String? validateReminderTitle(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter a title';
  }
  return null;
}

/// Trims the description text and returns null if empty
String? processDescription(String? description) {
  if (description == null || description.trim().isEmpty) {
    return null;
  }
  return description.trim();
}
