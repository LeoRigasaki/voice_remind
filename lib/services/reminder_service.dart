// [lib/services]/reminder_service.dart
// Business logic service for creating, updating, and managing reminders

import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../models/custom_repeat_config.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class ReminderService {
  /// Creates a new reminder with notification scheduling
  /// Returns the created reminder
  static Future<Reminder> createReminder({
    required String title,
    String? description,
    required DateTime scheduledTime,
    RepeatType repeatType = RepeatType.none,
    bool isNotificationEnabled = true,
    String? spaceId,
    List<TimeSlot> timeSlots = const [],
    bool isMultiTime = false,
    CustomRepeatConfig? customRepeatConfig,
  }) async {
    try {
      final reminder = Reminder(
        title: title.trim(),
        description: description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        scheduledTime: scheduledTime,
        repeatType: repeatType,
        isNotificationEnabled: isNotificationEnabled,
        spaceId: spaceId,
        timeSlots: timeSlots,
        isMultiTime: isMultiTime,
        customRepeatConfig: customRepeatConfig,
      );

      await StorageService.addReminder(reminder);

      if (isNotificationEnabled) {
        await NotificationService.scheduleReminder(reminder);
      }

      debugPrint('✅ Reminder created: ${reminder.title}');
      return reminder;
    } catch (e) {
      debugPrint('❌ Error creating reminder: $e');
      rethrow;
    }
  }

  /// Updates an existing reminder with notification rescheduling
  /// Returns the updated reminder
  static Future<Reminder> updateReminder({
    required Reminder originalReminder,
    required String title,
    String? description,
    required DateTime scheduledTime,
    RepeatType repeatType = RepeatType.none,
    bool isNotificationEnabled = true,
    String? spaceId,
    List<TimeSlot> timeSlots = const [],
    bool isMultiTime = false,
    CustomRepeatConfig? customRepeatConfig,
  }) async {
    try {
      final updatedReminder = originalReminder.copyWith(
        title: title.trim(),
        description: description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        scheduledTime: scheduledTime,
        repeatType: repeatType,
        isNotificationEnabled: isNotificationEnabled,
        spaceId: spaceId,
        timeSlots: timeSlots,
        isMultiTime: isMultiTime,
        customRepeatConfig: customRepeatConfig,
        clearCustomRepeatConfig: repeatType != RepeatType.custom,
      );

      await StorageService.updateReminder(updatedReminder);

      // Cancel existing notifications
      await NotificationService.cancelReminder(updatedReminder.id);

      // Reschedule if notifications are enabled
      if (isNotificationEnabled) {
        await NotificationService.scheduleReminder(updatedReminder);
      }

      debugPrint('✅ Reminder updated: ${updatedReminder.title}');
      return updatedReminder;
    } catch (e) {
      debugPrint('❌ Error updating reminder: $e');
      rethrow;
    }
  }

  /// Deletes a reminder and cancels its notifications
  static Future<void> deleteReminder(String reminderId) async {
    try {
      await NotificationService.cancelReminder(reminderId);
      await StorageService.deleteReminder(reminderId);
      debugPrint('✅ Reminder deleted: $reminderId');
    } catch (e) {
      debugPrint('❌ Error deleting reminder: $e');
      rethrow;
    }
  }

  /// Saves a reminder (creates if new, updates if existing)
  /// This is a convenience method that handles both create and update
  static Future<Reminder> saveReminder({
    Reminder? existingReminder,
    required String title,
    String? description,
    required DateTime scheduledTime,
    RepeatType repeatType = RepeatType.none,
    bool isNotificationEnabled = true,
    String? spaceId,
    List<TimeSlot> timeSlots = const [],
    bool isMultiTime = false,
    CustomRepeatConfig? customRepeatConfig,
  }) async {
    if (existingReminder != null) {
      return updateReminder(
        originalReminder: existingReminder,
        title: title,
        description: description,
        scheduledTime: scheduledTime,
        repeatType: repeatType,
        isNotificationEnabled: isNotificationEnabled,
        spaceId: spaceId,
        timeSlots: timeSlots,
        isMultiTime: isMultiTime,
        customRepeatConfig: customRepeatConfig,
      );
    } else {
      return createReminder(
        title: title,
        description: description,
        scheduledTime: scheduledTime,
        repeatType: repeatType,
        isNotificationEnabled: isNotificationEnabled,
        spaceId: spaceId,
        timeSlots: timeSlots,
        isMultiTime: isMultiTime,
        customRepeatConfig: customRepeatConfig,
      );
    }
  }

  /// Validates multi-time reminder configuration
  static String? validateMultiTimeReminder({
    required bool isMultiTime,
    required List<TimeSlot> timeSlots,
  }) {
    if (isMultiTime && timeSlots.isEmpty) {
      return 'Please add at least one time slot for multi-time reminders';
    }
    return null;
  }

  /// Validates reminder data before saving
  static String? validateReminderData({
    required String title,
    required bool isMultiTime,
    required List<TimeSlot> timeSlots,
  }) {
    // Validate title
    if (title.trim().isEmpty) {
      return 'Please enter a title';
    }

    // Validate multi-time configuration
    if (isMultiTime && timeSlots.isEmpty) {
      return 'Please add at least one time slot for multi-time reminders';
    }

    return null;
  }
}
