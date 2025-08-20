// [lib/services]/alarm_service.dart
import 'dart:async';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/default_sound_service.dart';

class AlarmService {
  static AlarmService? _instance;
  static AlarmService get instance => _instance ??= AlarmService._();
  AlarmService._();

  // Stream to track alarm events
  static final StreamController<AlarmEvent> _alarmEventController =
      StreamController<AlarmEvent>.broadcast();

  static Stream<AlarmEvent> get alarmEventStream =>
      _alarmEventController.stream;

  // Active alarms tracking
  static final Map<int, Reminder> _activeAlarms = {};
  static bool _isInitialized = false;

  // Track if full-screen alarm is currently showing
  static bool _isFullScreenAlarmShowing = false;
  static String? _currentFullScreenAlarmId;

  // App state tracking for better coordination
  static bool _isAppInForeground = true;
  static bool _isScreenOn = true;

  /// Initialize the alarm service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('Initializing Alarm Service...');

    try {
      // Initialize the alarm plugin
      await Alarm.init();
      debugPrint('✅ Alarm plugin initialized');

      // Listen to alarm events
      _setupAlarmListener();

      // Clean up any orphaned alarms
      await _cleanupOrphanedAlarms();

      _isInitialized = true;
      debugPrint('✅ Alarm Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Alarm Service initialization failed: $e');
      rethrow;
    }
  }

  /// Update app state for better alarm/notification coordination
  static void updateAppState({bool? isInForeground, bool? isScreenOn}) {
    if (isInForeground != null) {
      _isAppInForeground = isInForeground;
      debugPrint('📱 App foreground state: $_isAppInForeground');
    }
    if (isScreenOn != null) {
      _isScreenOn = isScreenOn;
      debugPrint('📱 Screen state: $_isScreenOn');
    }
  }

  /// Setup alarm event listener
  static void _setupAlarmListener() {
    Alarm.ringing.listen((AlarmSet alarmSet) {
      for (final alarmSettings in alarmSet.alarms) {
        debugPrint('Alarm ringing: ${alarmSettings.id}');
        _handleAlarmRinging(alarmSettings);
      }
    });
  }

  /// Handle alarm ringing event
  static void _handleAlarmRinging(AlarmSettings alarmSettings) async {
    try {
      final reminder = _activeAlarms[alarmSettings.id];
      if (reminder == null) {
        debugPrint('⚠️ No reminder found for alarm ID: ${alarmSettings.id}');
        return;
      }

      // Check user preference again at runtime
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();
      if (!useAlarm) {
        debugPrint('🔔 User switched to notifications - stopping alarm');
        await Alarm.stop(alarmSettings.id);
        return;
      }

      // SIMPLIFIED: Always show full-screen alarm when alarm mode is chosen
      // The user chose "Alarm" mode, so always show alarm screen
      _isFullScreenAlarmShowing = true;
      _currentFullScreenAlarmId = reminder.id;

      final alarmEvent = AlarmEvent(
        type: AlarmEventType.ringing,
        reminder: reminder,
        alarmSettings: alarmSettings,
        shouldShowFullScreen: true, // Always true for alarm mode
      );

      _alarmEventController.add(alarmEvent);
      debugPrint('⏰ Alarm event emitted (full-screen): ${reminder.title}');
    } catch (e) {
      debugPrint('⚠️ Error handling alarm ringing: $e');
    }
  }

  /// Set an alarm for a reminder
  static Future<void> setAlarmReminder(Reminder reminder) async {
    try {
      debugPrint('⏰ Setting alarm for reminder: ${reminder.title}');

      // Get user preference first
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();

      if (!useAlarm) {
        debugPrint(
            '🔔 User prefers notifications - delegating to NotificationService');
        // Don't set alarm, let NotificationService handle it
        return;
      }

      // Get user's default alarm sound
      final defaultSoundPath = await DefaultSoundService.getDefaultAlarmPath();

      final alarmId = _generateAlarmId(reminder.id);

      // CRITICAL: Set alarm with NO notification settings when user chose alarm mode
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: reminder.scheduledTime,
        assetAudioPath: defaultSoundPath,
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: false,
        androidFullScreenIntent: true,
        volumeSettings: const VolumeSettings.fixed(),
        notificationSettings: NotificationSettings(
          title: reminder.title,
          body: reminder.description ?? 'Alarm reminder',
          stopButton: null, // Remove stop button to avoid notification actions
          icon: 'notification_icon',
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
      _activeAlarms[alarmId] = reminder;

      debugPrint('✅ Pure alarm (no notification) set for ${reminder.title}');
    } catch (e) {
      debugPrint('⚠️ Error setting alarm reminder: $e');
      rethrow;
    }
  }

  /// Set alarms for multi-time reminders
  static Future<void> setMultiTimeAlarmReminder(Reminder reminder) async {
    if (!reminder.hasMultipleTimes) {
      await setAlarmReminder(reminder);
      return;
    }

    try {
      debugPrint('Setting multi-time alarms for reminder: ${reminder.title}');

      for (final timeSlot in reminder.timeSlots) {
        if (timeSlot.status != ReminderStatus.pending) continue;

        // Create notification time for today (or next occurrence if time has passed)
        final now = DateTime.now();
        DateTime notificationTime = DateTime(
          now.year,
          now.month,
          now.day,
          timeSlot.time.hour,
          timeSlot.time.minute,
        );

        // If time has passed today, schedule for tomorrow (if daily repeat)
        if (notificationTime.isBefore(now)) {
          if (reminder.repeatType == RepeatType.daily) {
            notificationTime = notificationTime.add(const Duration(days: 1));
          } else {
            continue; // Skip this time slot
          }
        }

        // Create time slot specific reminder
        final timeSlotReminder = reminder.copyWith(
          scheduledTime: notificationTime,
          description: timeSlot.description ?? reminder.description,
        );

        await setAlarmReminder(timeSlotReminder);
      }
    } catch (e) {
      debugPrint('❌ Error setting multi-time alarm: $e');
      rethrow;
    }
  }

  /// Stop/cancel an alarm
  static Future<void> stopAlarm(String reminderId) async {
    try {
      final alarmId = _generateAlarmId(reminderId);
      await Alarm.stop(alarmId);
      _activeAlarms.remove(alarmId);

      // Don't auto-mark as complete - let the caller decide
      debugPrint('Alarm stopped for reminder: $reminderId');

      // Clear full-screen tracking if this was the current alarm
      if (_currentFullScreenAlarmId == reminderId) {
        _isFullScreenAlarmShowing = false;
        _currentFullScreenAlarmId = null;
        debugPrint('🖥️ Cleared full-screen alarm tracking');
      }

      debugPrint('Stopped alarm for reminder: $reminderId');
    } catch (e) {
      debugPrint('❌ Error stopping alarm: $e');
    }
  }

  /// Snooze an alarm
  static Future<void> snoozeAlarm(
      String reminderId, Duration snoozeDuration) async {
    try {
      debugPrint(
          'Snoozing alarm for $reminderId by ${snoozeDuration.inMinutes} minutes');

      // Get the reminder
      final reminder = await StorageService.getReminderById(reminderId);
      if (reminder == null) {
        debugPrint('❌ Reminder not found for snooze: $reminderId');
        return;
      }

      // Stop current alarm
      await stopAlarm(reminderId);

      // Calculate snooze time
      final snoozeTime = DateTime.now().add(snoozeDuration);

      // Update reminder with snooze time
      final snoozedReminder = reminder.copyWith(scheduledTime: snoozeTime);
      await StorageService.updateReminder(snoozedReminder);

      // Set new alarm for snooze time
      await setAlarmReminder(snoozedReminder);

      // Clear full-screen tracking since alarm is snoozed
      if (_currentFullScreenAlarmId == reminderId) {
        _isFullScreenAlarmShowing = false;
        _currentFullScreenAlarmId = null;
        debugPrint('🖥️ Cleared full-screen alarm tracking after snooze');
      }

      // Mark background update
      await StorageService.markNotificationUpdate();
      await StorageService.refreshData();

      debugPrint('✅ Alarm snoozed until $snoozeTime');
    } catch (e) {
      debugPrint('❌ Error snoozing alarm: $e');
    }
  }

  /// Dismiss an alarm (mark reminder as completed)
  static Future<void> dismissAlarm(String reminderId) async {
    try {
      debugPrint('Dismissing alarm for reminder: $reminderId');

      // Stop the alarm first
      await stopAlarm(reminderId);

      // Mark reminder as completed
      await StorageService.updateReminderStatus(
          reminderId, ReminderStatus.completed);
      debugPrint('✅ Marked reminder $reminderId as complete');

      // Clear full-screen tracking since alarm is dismissed
      if (_currentFullScreenAlarmId == reminderId) {
        _isFullScreenAlarmShowing = false;
        _currentFullScreenAlarmId = null;
        debugPrint('🖥️ Cleared full-screen alarm tracking after dismiss');
      }

      // Force background update
      await StorageService.markNotificationUpdate();
      await StorageService.refreshData();

      debugPrint('✅ Alarm dismissed and reminder completed');
    } catch (e) {
      debugPrint('❌ Error dismissing alarm: $e');
    }
  }

  /// Check if alarms are enabled globally
  static Future<bool> areAlarmsEnabled() async {
    return await StorageService.getUseAlarmInsteadOfNotification();
  }

  /// Update existing alarm for a reminder
  static Future<void> updateAlarmReminder(Reminder reminder) async {
    try {
      // Stop existing alarm
      await stopAlarm(reminder.id);

      // Set new alarm if still needed
      if (reminder.status == ReminderStatus.pending &&
          reminder.scheduledTime.isAfter(DateTime.now())) {
        if (reminder.hasMultipleTimes) {
          await setMultiTimeAlarmReminder(reminder);
        } else {
          await setAlarmReminder(reminder);
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating alarm reminder: $e');
    }
  }

  /// Clean up orphaned alarms (alarms without corresponding reminders)
  static Future<void> _cleanupOrphanedAlarms() async {
    try {
      // This would require getting all active alarms from the alarm plugin
      // For now, we'll implement a basic cleanup
      _activeAlarms.clear();
      _isFullScreenAlarmShowing = false;
      _currentFullScreenAlarmId = null;
      debugPrint('Cleaned up orphaned alarms');
    } catch (e) {
      debugPrint('❌ Error cleaning up orphaned alarms: $e');
    }
  }

  /// Generate unique alarm ID from reminder ID
  static int _generateAlarmId(String reminderId) {
    return reminderId.hashCode.abs();
  }

  /// Get all active alarms
  static Map<int, Reminder> getActiveAlarms() {
    return Map.unmodifiable(_activeAlarms);
  }

  // Get current full-screen alarm status
  static bool get isFullScreenAlarmShowing => _isFullScreenAlarmShowing;
  static String? get currentFullScreenAlarmId => _currentFullScreenAlarmId;

  /// Test alarm functionality
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
      debugPrint('✅ Test alarm scheduled');
    } catch (e) {
      debugPrint('❌ Error testing alarm: $e');
    }
  }

  /// Dispose resources
  static void dispose() {
    _alarmEventController.close();
    DefaultSoundService.stop();
    _activeAlarms.clear();
    _isFullScreenAlarmShowing = false;
    _currentFullScreenAlarmId = null;
    _isInitialized = false;
  }
}

/// Alarm event types
enum AlarmEventType {
  ringing,
  dismissed,
  snoozed,
  stopped,
}

/// Alarm event data
class AlarmEvent {
  final AlarmEventType type;
  final Reminder reminder;
  final AlarmSettings? alarmSettings;
  final DateTime timestamp;
  final bool shouldShowFullScreen; // Indicates if full-screen should be shown

  AlarmEvent({
    required this.type,
    required this.reminder,
    this.alarmSettings,
    DateTime? timestamp,
    this.shouldShowFullScreen = false, // Default to false
  }) : timestamp = timestamp ?? DateTime.now();
}
