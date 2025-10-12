// [lib/services]/alarm_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/default_sound_service.dart';

class AlarmService {
  static AlarmService? _instance;
  static AlarmService get instance => _instance ??= AlarmService._();
  AlarmService._();

  static final StreamController<AlarmEvent> _alarmEventController =
      StreamController<AlarmEvent>.broadcast();

  static Stream<AlarmEvent> get alarmEventStream =>
      _alarmEventController.stream;

  static final Map<int, AlarmContext> _activeAlarms = {};
  static bool _isInitialized = false;

  static bool _isFullScreenAlarmShowing = false;
  static String? _currentFullScreenAlarmId;
  static String? _currentTimeSlotId;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('Initializing Alarm Service with awesome_notifications...');

    try {
      // No more Alarm.init() - we're using awesome_notifications now
      debugPrint('✅ Alarm service ready (using awesome_notifications)');

      await _cleanupOrphanedAlarms();

      _isInitialized = true;
      debugPrint('Alarm Service initialized successfully');
    } catch (e) {
      debugPrint('Alarm Service initialization failed: $e');
      rethrow;
    }
  }

  static Future<void> setAlarmReminder(Reminder reminder) async {
    try {
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();
      if (!useAlarm) {
        debugPrint('Alarm mode disabled, using notification only');
        return;
      }

      debugPrint(
          'Setting alarm for: ${reminder.title} at ${reminder.scheduledTime}');

      if (reminder.scheduledTime.isBefore(DateTime.now())) {
        debugPrint('⚠️ Scheduled time is in the past, skipping alarm');
        return;
      }

      final alarmId = generateAlarmId(reminder.id);

      // Store alarm context for later retrieval
      _activeAlarms[alarmId] = AlarmContext(
        reminder: reminder,
        timeSlotId: null,
      );

      // Schedule with awesome_notifications instead of alarm package
      // This will be handled by notification_service now
      await NotificationService.scheduleAlarmNotification(
        reminder: reminder,
        alarmId: alarmId,
      );

      debugPrint('✅ Alarm scheduled for ${reminder.title} with ID: $alarmId');
    } catch (e) {
      debugPrint('❌ Error setting alarm reminder: $e');
      rethrow;
    }
  }

  static Future<void> setMultiTimeAlarmReminder(Reminder reminder) async {
    if (!reminder.hasMultipleTimes) {
      await setAlarmReminder(reminder);
      return;
    }

    try {
      debugPrint('Setting multi-time alarms for reminder: ${reminder.title}');

      for (final timeSlot in reminder.timeSlots) {
        if (timeSlot.status != ReminderStatus.pending) continue;

        final now = DateTime.now();
        DateTime notificationTime = DateTime(
          now.year,
          now.month,
          now.day,
          timeSlot.time.hour,
          timeSlot.time.minute,
        );

        if (notificationTime.isBefore(now)) {
          if (reminder.repeatType == RepeatType.daily) {
            notificationTime = notificationTime.add(const Duration(days: 1));
          } else {
            continue;
          }
        }

        await _setTimeSlotAlarm(reminder, timeSlot, notificationTime);
      }
    } catch (e) {
      debugPrint('Error setting multi-time alarm: $e');
      rethrow;
    }
  }

  static Future<void> _setTimeSlotAlarm(
      Reminder reminder, TimeSlot timeSlot, DateTime scheduledTime) async {
    try {
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();
      if (!useAlarm) return;

      final alarmId = generateTimeSlotAlarmId(reminder.id, timeSlot.id);

      // Store alarm context
      _activeAlarms[alarmId] = AlarmContext(
        reminder: reminder,
        timeSlotId: timeSlot.id,
      );

      // Schedule with awesome_notifications
      await NotificationService.scheduleAlarmNotification(
        reminder: reminder,
        alarmId: alarmId,
        customTime: scheduledTime,
        timeSlot: timeSlot,
      );

      debugPrint(
          'Time slot alarm set: ${timeSlot.formattedTime} with ID: $alarmId for TimeSlot: ${timeSlot.id}');
    } catch (e) {
      debugPrint('Error setting time slot alarm: $e');
      rethrow;
    }
  }

  static Future<void> stopAlarm(String reminderId, {String? timeSlotId}) async {
    try {
      final alarmId = timeSlotId != null
          ? generateTimeSlotAlarmId(reminderId, timeSlotId)
          : generateAlarmId(reminderId);

      debugPrint('Stopping alarm ID: $alarmId');

      // Stop sound if playing
      if (DefaultSoundService.isPlaying) {
        await DefaultSoundService.stop();
      }

      // Cancel awesome_notifications notification
      await NotificationService.cancelNotification(alarmId);

      _activeAlarms.remove(alarmId);

      if (_currentFullScreenAlarmId == reminderId &&
          _currentTimeSlotId == timeSlotId) {
        _isFullScreenAlarmShowing = false;
        _currentFullScreenAlarmId = null;
        _currentTimeSlotId = null;
      }

      debugPrint('✅ Alarm stopped: $alarmId');
    } catch (e) {
      debugPrint('❌ Error stopping alarm: $e');
    }
  }

  static Future<void> cancelMixedModeNotification(String reminderId,
      {String? timeSlotId}) async {
    try {
      final notificationId = timeSlotId != null
          ? NotificationService.generateTimeSlotNotificationId(
              reminderId, timeSlotId)
          : reminderId.hashCode;

      await NotificationService.cancelNotification(notificationId);
      debugPrint('📕 Canceled mixed mode notification: $notificationId');
    } catch (e) {
      debugPrint('⚠️ Error canceling mixed mode notification: $e');
    }
  }

  static Future<void> snoozeAlarm(String reminderId, Duration snoozeDuration,
      {String? timeSlotId}) async {
    try {
      debugPrint(
          'Snoozing alarm: $reminderId for ${snoozeDuration.inMinutes} minutes');

      // Stop current alarm sound
      if (DefaultSoundService.isPlaying) {
        await DefaultSoundService.stop();
      }

      final alarmId = timeSlotId != null
          ? generateTimeSlotAlarmId(reminderId, timeSlotId)
          : generateAlarmId(reminderId);

      // Cancel current notification
      await NotificationService.cancelNotification(alarmId);

      // Get reminder and reschedule
      final reminders = await StorageService.getReminders();
      final reminder = reminders.firstWhere((r) => r.id == reminderId);

      final newScheduledTime = DateTime.now().add(snoozeDuration);

      if (timeSlotId != null && reminder.hasMultipleTimes) {
        // Handle multi-time snooze
        final timeSlot =
            reminder.timeSlots.firstWhere((ts) => ts.id == timeSlotId);
        await NotificationService.scheduleAlarmNotification(
          reminder: reminder,
          alarmId: alarmId,
          customTime: newScheduledTime,
          timeSlot: timeSlot,
        );
      } else {
        // Handle single-time snooze
        await NotificationService.scheduleAlarmNotification(
          reminder: reminder,
          alarmId: alarmId,
          customTime: newScheduledTime,
        );
      }

      _isFullScreenAlarmShowing = false;
      _currentFullScreenAlarmId = null;
      _currentTimeSlotId = null;

      debugPrint('✅ Alarm snoozed successfully');
    } catch (e) {
      debugPrint('❌ Error snoozing alarm: $e');
    }
  }

  static Future<void> dismissAlarm(String reminderId,
      {String? timeSlotId}) async {
    try {
      debugPrint('✅ dismissAlarm called: $reminderId, timeSlot: $timeSlotId');

      // Stop sound
      if (DefaultSoundService.isPlaying) {
        await DefaultSoundService.stop();
        debugPrint('🔇 Sound stopped in dismissAlarm');
      }

      // Stop alarm
      await stopAlarm(reminderId, timeSlotId: timeSlotId);

      // Get the reminder from storage
      final reminders = await StorageService.getReminders();
      final reminderIndex = reminders.indexWhere((r) => r.id == reminderId);

      if (reminderIndex == -1) {
        debugPrint('⚠️ Reminder not found: $reminderId');
        return;
      }

      final reminder = reminders[reminderIndex];
      debugPrint('📋 Found reminder: ${reminder.title}');

      // Check if this is a repeating reminder
      if (reminder.repeatType != RepeatType.none) {
        debugPrint('🔄 This is a repeating reminder: ${reminder.repeatType}');

        // For repeating reminders, update to next occurrence instead of completing
        if (timeSlotId != null && reminder.hasMultipleTimes) {
          // Multi-time repeating reminder
          debugPrint('📋 Marking time slot as completed: $timeSlotId');

          final updatedSlots = reminder.timeSlots.map((slot) {
            if (slot.id == timeSlotId) {
              debugPrint('✅ Updating slot ${slot.id} to completed');
              return slot.copyWith(status: ReminderStatus.completed);
            }
            return slot;
          }).toList();

          // Check if all slots are completed
          final allCompleted = updatedSlots
              .every((slot) => slot.status == ReminderStatus.completed);

          if (allCompleted && reminder.repeatType != RepeatType.none) {
            // Reset all slots for next occurrence
            debugPrint('🔄 All slots completed, resetting for next occurrence');
            final resetSlots = updatedSlots.map((slot) {
              return slot.copyWith(
                status: ReminderStatus.pending,
                completedAt: null,
              );
            }).toList();

            // Calculate next occurrence
            final nextScheduledTime = _calculateNextOccurrence(
              reminder.scheduledTime,
              reminder.repeatType,
            );

            final updatedReminder = reminder.copyWith(
              timeSlots: resetSlots,
              scheduledTime: nextScheduledTime,
              updatedAt: DateTime.now(),
            );

            await StorageService.updateReminder(updatedReminder);
            debugPrint('✅ Repeating reminder reset for next occurrence');

            // CRITICAL: Auto-reschedule the alarm/notification
            await _rescheduleRepeatingReminder(updatedReminder);
          } else {
            // Just update this slot
            final updatedReminder = reminder.copyWith(
              timeSlots: updatedSlots,
            );

            await StorageService.updateReminder(updatedReminder);
            debugPrint('✅ Time slot marked as completed and saved');
          }
        } else {
          // Single-time repeating reminder
          debugPrint('📋 Updating to next occurrence for repeating reminder');

          final nextScheduledTime = _calculateNextOccurrence(
            reminder.scheduledTime,
            reminder.repeatType,
          );

          final updatedReminder = reminder.copyWith(
            scheduledTime: nextScheduledTime,
            status: ReminderStatus.pending,
            completedAt: null,
            updatedAt: DateTime.now(),
          );

          await StorageService.updateReminder(updatedReminder);
          debugPrint('✅ Repeating reminder updated to next occurrence');

          // CRITICAL: Auto-reschedule the alarm/notification
          await _rescheduleRepeatingReminder(updatedReminder);
        }
      } else {
        // Non-repeating reminder - mark as completed
        if (timeSlotId != null && reminder.hasMultipleTimes) {
          debugPrint('📋 Marking time slot as completed: $timeSlotId');

          final updatedSlots = reminder.timeSlots.map((slot) {
            if (slot.id == timeSlotId) {
              debugPrint('✅ Updating slot ${slot.id} to completed');
              return slot.copyWith(status: ReminderStatus.completed);
            }
            return slot;
          }).toList();

          final updatedReminder = reminder.copyWith(
            timeSlots: updatedSlots,
          );

          await StorageService.updateReminder(updatedReminder);
          debugPrint('✅ Time slot marked as completed and saved');
        } else {
          debugPrint('📋 Marking entire reminder as completed');

          final updatedReminder = reminder.copyWith(
            status: ReminderStatus.completed,
          );

          await StorageService.updateReminder(updatedReminder);
          debugPrint('✅ Reminder marked as completed and saved');
        }
      }

      _isFullScreenAlarmShowing = false;
      _currentFullScreenAlarmId = null;
      _currentTimeSlotId = null;

      debugPrint('✅ Alarm dismissed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error dismissing alarm: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Calculate next occurrence for repeating reminders
  static DateTime _calculateNextOccurrence(
      DateTime currentTime, RepeatType repeatType) {
    switch (repeatType) {
      case RepeatType.daily:
        return currentTime.add(const Duration(days: 1));
      case RepeatType.weekly:
        return currentTime.add(const Duration(days: 7));
      case RepeatType.monthly:
        return DateTime(
          currentTime.year,
          currentTime.month + 1,
          currentTime.day,
          currentTime.hour,
          currentTime.minute,
        );
      case RepeatType.none:
        return currentTime;
    }
  }

  /// Automatically reschedule a repeating reminder after it's been dismissed
  static Future<void> _rescheduleRepeatingReminder(Reminder reminder) async {
    try {
      debugPrint('🔄 Auto-rescheduling repeating reminder: ${reminder.title}');
      debugPrint('   Repeat type: ${reminder.repeatType}');
      debugPrint('   Next scheduled time: ${reminder.scheduledTime}');

      // Check if alarm mode is enabled
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();

      if (useAlarm) {
        // Schedule as alarm (Mixed Mode)
        if (reminder.hasMultipleTimes) {
          await setMultiTimeAlarmReminder(reminder);
        } else {
          await setAlarmReminder(reminder);
        }
      } else {
        // Schedule as notification
        await NotificationService.scheduleReminder(reminder);
      }

      debugPrint(
          '✅ Auto-rescheduled repeating reminder for: ${reminder.scheduledTime}');
    } catch (e) {
      debugPrint('❌ Error auto-rescheduling repeating reminder: $e');
    }
  }

  static Future<bool> areAlarmsEnabled() async {
    return await StorageService.getUseAlarmInsteadOfNotification();
  }

  static Future<void> updateAlarmReminder(Reminder reminder) async {
    try {
      await stopAlarm(reminder.id);

      if (reminder.hasMultipleTimes) {
        for (final timeSlot in reminder.timeSlots) {
          if (timeSlot.status == ReminderStatus.pending) {
            await stopAlarm(reminder.id, timeSlotId: timeSlot.id);
          }
        }
      }

      if (reminder.status == ReminderStatus.pending &&
          reminder.scheduledTime.isAfter(DateTime.now())) {
        if (reminder.hasMultipleTimes) {
          await setMultiTimeAlarmReminder(reminder);
        } else {
          await setAlarmReminder(reminder);
        }
      }
    } catch (e) {
      debugPrint('Error updating alarm reminder: $e');
    }
  }

  static Future<void> _cleanupOrphanedAlarms() async {
    try {
      _activeAlarms.clear();
      _isFullScreenAlarmShowing = false;
      _currentFullScreenAlarmId = null;
      _currentTimeSlotId = null;
      debugPrint('Cleaned up orphaned alarms');
    } catch (e) {
      debugPrint('Error cleaning up orphaned alarms: $e');
    }
  }

  static int generateAlarmId(String reminderId) {
    return reminderId.hashCode.abs();
  }

  static int generateTimeSlotAlarmId(String reminderId, String timeSlotId) {
    return '$reminderId:$timeSlotId'.hashCode.abs();
  }

  static Map<int, AlarmContext> getActiveAlarms() {
    return Map.unmodifiable(_activeAlarms);
  }

  static bool get isFullScreenAlarmShowing => _isFullScreenAlarmShowing;
  static String? get currentFullScreenAlarmId => _currentFullScreenAlarmId;
  static String? get currentTimeSlotId => _currentTimeSlotId;

  static Future<void> testAlarm() async {
    try {
      debugPrint('Testing alarm in 5 seconds...');

      final testTime = DateTime.now().add(const Duration(seconds: 5));
      final testReminder = Reminder(
        id: 'test_alarm',
        title: 'Test Alarm',
        description: 'This is a test alarm',
        scheduledTime: testTime,
        status: ReminderStatus.pending,
        isNotificationEnabled: true,
      );

      await setAlarmReminder(testReminder);
      debugPrint('Test alarm scheduled');
    } catch (e) {
      debugPrint('Error testing alarm: $e');
    }
  }

  static void dispose() {
    _alarmEventController.close();
    DefaultSoundService.stop();
    _activeAlarms.clear();
    _isFullScreenAlarmShowing = false;
    _currentFullScreenAlarmId = null;
    _currentTimeSlotId = null;
    _isInitialized = false;
  }
}

class AlarmContext {
  final Reminder reminder;
  final String? timeSlotId;

  AlarmContext({
    required this.reminder,
    this.timeSlotId,
  });
}

enum AlarmEventType {
  ringing,
  dismissed,
  snoozed,
  stopped,
}

class AlarmEvent {
  final AlarmEventType type;
  final Reminder reminder;
  final DateTime timestamp;
  final bool shouldShowFullScreen;
  final String? timeSlotId;

  AlarmEvent({
    required this.type,
    required this.reminder,
    DateTime? timestamp,
    this.shouldShowFullScreen = false,
    this.timeSlotId,
  }) : timestamp = timestamp ?? DateTime.now();
}
