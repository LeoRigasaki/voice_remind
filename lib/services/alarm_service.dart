// [lib/services]/alarm_service.dart
import 'dart:async';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
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

  static bool _isAppInForeground = true;
  static bool _isScreenOn = true;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('Initializing Alarm Service...');

    try {
      await Alarm.init();
      debugPrint('Alarm plugin initialized');

      _setupAlarmListener();
      setupAppLifecycleListener();
      await _cleanupOrphanedAlarms();

      _isInitialized = true;
      debugPrint('Alarm Service initialized successfully');
    } catch (e) {
      debugPrint('Alarm Service initialization failed: $e');
      rethrow;
    }
  }

  static void setupAppLifecycleListener() {
    // Enhanced app lifecycle detection for better mixed mode decisions
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
    debugPrint('🔄 Enhanced app lifecycle listener set up');
  }

  static void updateAppState({bool? isInForeground, bool? isScreenOn}) {
    if (isInForeground != null) {
      _isAppInForeground = isInForeground;
      debugPrint('App foreground state: $_isAppInForeground');
    }
    if (isScreenOn != null) {
      _isScreenOn = isScreenOn;
      debugPrint('Screen state: $_isScreenOn');
    }
  }

  static void _setupAlarmListener() {
    Alarm.ringing.listen((AlarmSet alarmSet) {
      for (final alarmSettings in alarmSet.alarms) {
        debugPrint('Alarm ringing: ${alarmSettings.id}');
        _handleAlarmRinging(alarmSettings);
      }
    });
  }

  static void _handleAlarmRinging(AlarmSettings alarmSettings) async {
    try {
      var alarmContext = _activeAlarms[alarmSettings.id];

      if (alarmContext == null) {
        debugPrint('Alarm context not found, attempting to reconstruct...');
        alarmContext = await _reconstructAlarmContext(alarmSettings.id);

        if (alarmContext == null) {
          debugPrint(
              'Could not reconstruct alarm context for ID: ${alarmSettings.id}');
          return;
        }

        _activeAlarms[alarmSettings.id] = alarmContext;
      }

      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();
      if (!useAlarm) {
        debugPrint('User switched to notifications - stopping alarm');
        await Alarm.stop(alarmSettings.id);
        return;
      }

      final shouldShowFullScreen = _shouldShowFullScreenAlarm();

      // 🚨 MIXED MODE COLLISION DETECTION
      if (shouldShowFullScreen) {
        // Show full-screen alarm - cancel the mixed mode notification
        debugPrint(
            '🔥 MIXED MODE: Showing full-screen alarm, canceling notification');

        final notificationId = alarmContext.timeSlotId != null
            ? NotificationService.generateTimeSlotNotificationId(
                alarmContext.reminder.id, alarmContext.timeSlotId!)
            : alarmContext.reminder.id.hashCode;

        try {
          await NotificationService.cancelNotification(notificationId);
          debugPrint('✅ Canceled notification ID: $notificationId');
        } catch (e) {
          debugPrint('⚠️ Error canceling notification: $e');
        }

        _isFullScreenAlarmShowing = true;
        _currentFullScreenAlarmId = alarmContext.reminder.id;
        _currentTimeSlotId = alarmContext.timeSlotId;
      } else {
        // Show notification - stop this alarm and let notification handle it
        debugPrint(
            '📱 MIXED MODE: Other app active, stopping alarm, letting notification show');

        await Alarm.stop(alarmSettings.id);
        _activeAlarms.remove(alarmSettings.id);

        // Don't emit alarm event since notification will handle it
        return;
      }

      debugPrint(
          'Alarm context: ReminderId=${alarmContext.reminder.id}, TimeSlotId=${alarmContext.timeSlotId}');

      final alarmEvent = AlarmEvent(
        type: AlarmEventType.ringing,
        reminder: alarmContext.reminder,
        alarmSettings: alarmSettings,
        shouldShowFullScreen: shouldShowFullScreen,
        timeSlotId: alarmContext.timeSlotId,
      );

      _alarmEventController.add(alarmEvent);
      debugPrint(
          'Alarm event emitted: ${alarmContext.reminder.title} (TimeSlot: ${alarmContext.timeSlotId})');
    } catch (e) {
      debugPrint('Error handling alarm ringing: $e');
    }
  }

  // NEW: Enhanced alarm context reconstruction
  static Future<AlarmContext?> _reconstructAlarmContext(int alarmId) async {
    try {
      final allReminders = await StorageService.getReminders();

      for (final reminder in allReminders) {
        // Check single-time reminder
        if (_generateAlarmId(reminder.id) == alarmId) {
          debugPrint(
              'Reconstructed single-time alarm context for: ${reminder.id}');
          return AlarmContext(reminder: reminder, timeSlotId: null);
        }

        // Check multi-time reminder time slots
        if (reminder.hasMultipleTimes) {
          for (final timeSlot in reminder.timeSlots) {
            final timeSlotAlarmId =
                _generateTimeSlotAlarmId(reminder.id, timeSlot.id);
            if (timeSlotAlarmId == alarmId) {
              debugPrint(
                  'Reconstructed multi-time alarm context for: ${reminder.id}, TimeSlot: ${timeSlot.id}');
              return AlarmContext(reminder: reminder, timeSlotId: timeSlot.id);
            }
          }
        }
      }

      debugPrint('No matching reminder found for alarm ID: $alarmId');
      return null;
    } catch (e) {
      debugPrint('Error reconstructing alarm context: $e');
      return null;
    }
  }

  static bool _shouldShowFullScreenAlarm() {
    // Show full-screen alarm when:
    // 1. VoiceRemind is in foreground (user actively using app)
    // 2. Phone is idle/locked (screen off, regardless of app state)
    //
    // Show notification when:
    // - Other apps are active (screen on but VoiceRemind not in foreground)

    final showFullScreen = _isAppInForeground || !_isScreenOn;
    debugPrint(
        '🔍 App state check: foreground=$_isAppInForeground, screenOn=$_isScreenOn, showFullScreen=$showFullScreen');
    return showFullScreen;
  }

  static Future<void> setAlarmReminder(Reminder reminder) async {
    try {
      debugPrint('Setting alarm for reminder: ${reminder.title}');

      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();

      if (!useAlarm) {
        debugPrint(
            'User prefers notifications - delegating to NotificationService');
        return;
      }

      final defaultSoundPath = await DefaultSoundService.getDefaultAlarmPath();
      final alarmId = _generateAlarmId(reminder.id);
      final shouldUseFullScreen = _shouldShowFullScreenAlarm();

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: reminder.scheduledTime,
        assetAudioPath: defaultSoundPath,
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: false,
        androidFullScreenIntent: shouldUseFullScreen,
        volumeSettings: const VolumeSettings.fixed(),
        notificationSettings: NotificationSettings(
          title: reminder.title,
          body: reminder.description ?? 'Alarm reminder',
          stopButton: shouldUseFullScreen ? null : 'Dismiss',
          icon: 'notification_icon',
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
      _activeAlarms[alarmId] = AlarmContext(
        reminder: reminder,
        timeSlotId: null,
      );

      debugPrint('Alarm set for ${reminder.title} with ID: $alarmId');
    } catch (e) {
      debugPrint('Error setting alarm reminder: $e');
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

      final defaultSoundPath = await DefaultSoundService.getDefaultAlarmPath();
      final alarmId = _generateTimeSlotAlarmId(reminder.id, timeSlot.id);
      final shouldUseFullScreen = _shouldShowFullScreenAlarm();

      final title = reminder.title;
      final body = timeSlot.description?.isNotEmpty == true
          ? '${timeSlot.formattedTime} - ${timeSlot.description}'
          : '${timeSlot.formattedTime} reminder';

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: scheduledTime,
        assetAudioPath: defaultSoundPath,
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: false,
        androidFullScreenIntent: shouldUseFullScreen,
        volumeSettings: const VolumeSettings.fixed(),
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          stopButton: shouldUseFullScreen ? null : 'Dismiss',
          icon: 'notification_icon',
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
      _activeAlarms[alarmId] = AlarmContext(
        reminder: reminder,
        timeSlotId: timeSlot.id,
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
          ? _generateTimeSlotAlarmId(reminderId, timeSlotId)
          : _generateAlarmId(reminderId);

      await Alarm.stop(alarmId);
      _activeAlarms.remove(alarmId);

      if (_currentFullScreenAlarmId == reminderId &&
          _currentTimeSlotId == timeSlotId) {
        _isFullScreenAlarmShowing = false;
        _currentFullScreenAlarmId = null;
        _currentTimeSlotId = null;
        debugPrint('Cleared full-screen alarm tracking');
      }

      debugPrint(
          'Stopped alarm for reminder: $reminderId${timeSlotId != null ? ', TimeSlot: $timeSlotId' : ''}');
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
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
      debugPrint('🔕 Canceled mixed mode notification: $notificationId');
    } catch (e) {
      debugPrint('⚠️ Error canceling mixed mode notification: $e');
    }
  }

  static Future<void> snoozeAlarm(String reminderId, Duration snoozeDuration,
      {String? timeSlotId}) async {
    try {
      debugPrint(
          '🟡 SNOOZE DEBUG: Input reminderId=$reminderId, timeSlotId=$timeSlotId');

      // Check if reminderId is actually an alarm ID (numeric) vs UUID
      bool isAlarmId = int.tryParse(reminderId) != null;
      String actualReminderId = reminderId;
      String? actualTimeSlotId = timeSlotId;

      if (isAlarmId) {
        debugPrint(
            '🔍 Input appears to be alarm ID, searching for actual reminder...');
        // Find the actual reminder from active alarms
        final alarmIdInt = int.parse(reminderId);
        final alarmContext = _activeAlarms[alarmIdInt];

        if (alarmContext != null) {
          actualReminderId = alarmContext.reminder.id;
          actualTimeSlotId = alarmContext.timeSlotId;
          debugPrint(
              '🎯 Found actual reminder: $actualReminderId, timeSlot: $actualTimeSlotId');
        } else {
          debugPrint('❌ No alarm context found for alarm ID: $alarmIdInt');
          return;
        }
      }

      debugPrint(
          '🟡 SNOOZE: Processing reminderId=$actualReminderId${actualTimeSlotId != null ? ', TimeSlot: $actualTimeSlotId' : ''} by ${snoozeDuration.inMinutes} minutes');

      final reminder = await StorageService.getReminderById(actualReminderId);
      if (reminder == null) {
        debugPrint('Reminder not found for snooze: $actualReminderId');
        return;
      }

      await stopAlarm(actualReminderId, timeSlotId: actualTimeSlotId);

      final snoozeTime = DateTime.now().add(snoozeDuration);

      if (actualTimeSlotId != null && reminder.hasMultipleTimes) {
        final timeSlot = reminder.timeSlots.firstWhere(
          (slot) => slot.id == actualTimeSlotId,
          orElse: () => throw Exception('Time slot not found'),
        );

        final snoozedTimeSlot = timeSlot.copyWith(
          time: TimeOfDay(hour: snoozeTime.hour, minute: snoozeTime.minute),
        );

        await StorageService.updateTimeSlot(
            actualReminderId, actualTimeSlotId, snoozedTimeSlot);
        await _setTimeSlotAlarm(reminder, snoozedTimeSlot, snoozeTime);

        debugPrint('Snoozed time slot $actualTimeSlotId until $snoozeTime');
      } else {
        final snoozedReminder = reminder.copyWith(scheduledTime: snoozeTime);
        await StorageService.updateReminder(snoozedReminder);
        await setAlarmReminder(snoozedReminder);

        debugPrint('Snoozed single reminder until $snoozeTime');
      }

      if (_currentFullScreenAlarmId == actualReminderId &&
          _currentTimeSlotId == actualTimeSlotId) {
        _isFullScreenAlarmShowing = false;
        _currentFullScreenAlarmId = null;
        _currentTimeSlotId = null;
        debugPrint('Cleared full-screen alarm tracking after snooze');
      }

      await StorageService.markNotificationUpdate();
      await StorageService.refreshData();

      debugPrint('Alarm snoozed until $snoozeTime');
    } catch (e) {
      debugPrint('Error snoozing alarm: $e');
    }
  }

  static Future<void> dismissAlarm(String reminderId,
      {String? timeSlotId}) async {
    try {
      debugPrint(
          '🔴 DISMISS DEBUG: Input reminderId=$reminderId, timeSlotId=$timeSlotId');

      // Check if reminderId is actually an alarm ID (numeric) vs UUID
      bool isAlarmId = int.tryParse(reminderId) != null;
      String actualReminderId = reminderId;
      String? actualTimeSlotId = timeSlotId;

      if (isAlarmId) {
        debugPrint(
            '🔍 Input appears to be alarm ID, searching for actual reminder...');
        // Find the actual reminder from active alarms
        final alarmIdInt = int.parse(reminderId);
        final alarmContext = _activeAlarms[alarmIdInt];

        if (alarmContext != null) {
          actualReminderId = alarmContext.reminder.id;
          actualTimeSlotId = alarmContext.timeSlotId;
          debugPrint(
              '🎯 Found actual reminder: $actualReminderId, timeSlot: $actualTimeSlotId');
        } else {
          debugPrint('❌ No alarm context found for alarm ID: $alarmIdInt');
          return;
        }
      }

      debugPrint(
          '🔴 DISMISS: Processing reminderId=$actualReminderId, timeSlotId=$actualTimeSlotId');

      await stopAlarm(actualReminderId, timeSlotId: actualTimeSlotId);

      if (actualTimeSlotId != null) {
        await StorageService.updateTimeSlotStatus(
            actualReminderId, actualTimeSlotId, ReminderStatus.completed);
        debugPrint('✅ Marked time slot $actualTimeSlotId as complete');
      } else {
        await StorageService.updateReminderStatus(
            actualReminderId, ReminderStatus.completed);
        debugPrint('✅ Marked reminder $actualReminderId as complete');
      }

      if (_currentFullScreenAlarmId == actualReminderId &&
          _currentTimeSlotId == actualTimeSlotId) {
        _isFullScreenAlarmShowing = false;
        _currentFullScreenAlarmId = null;
        _currentTimeSlotId = null;
        debugPrint('Cleared full-screen alarm tracking after dismiss');
      }

      await StorageService.markNotificationUpdate();
      await StorageService.refreshData();

      debugPrint(
          '✅ Alarm dismissed and ${actualTimeSlotId != null ? 'time slot' : 'reminder'} completed');
    } catch (e) {
      debugPrint('Error dismissing alarm: $e');
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

  static int _generateAlarmId(String reminderId) {
    return reminderId.hashCode.abs();
  }

  static int _generateTimeSlotAlarmId(String reminderId, String timeSlotId) {
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
  final AlarmSettings? alarmSettings;
  final DateTime timestamp;
  final bool shouldShowFullScreen;
  final String? timeSlotId;

  AlarmEvent({
    required this.type,
    required this.reminder,
    this.alarmSettings,
    DateTime? timestamp,
    this.shouldShowFullScreen = false,
    this.timeSlotId,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔄 App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // VoiceRemind is active
        AlarmService.updateAppState(isInForeground: true);
        break;
      case AppLifecycleState.inactive:
        // App is transitioning or partially obscured
        AlarmService.updateAppState(isInForeground: false);
        break;
      case AppLifecycleState.paused:
        // Other apps are active or phone is backgrounded
        AlarmService.updateAppState(isInForeground: false);
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        AlarmService.updateAppState(isInForeground: false);
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  @override
  void didChangeMetrics() {
    // Detect screen on/off state changes
    final window = WidgetsBinding.instance.window;
    final isScreenOn =
        window.physicalSize.width > 0 && window.physicalSize.height > 0;
    AlarmService.updateAppState(isScreenOn: isScreenOn);
    debugPrint('📱 Screen state changed: $isScreenOn');
  }
}
