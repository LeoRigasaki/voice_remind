// [lib/services]/notification_service.dart
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../models/custom_repeat_config.dart';
import 'storage_service.dart';
import '../services/alarm_service.dart';
import '../services/default_sound_service.dart';

@pragma('vm:entry-point')
class NotificationService {
  static bool _isInitialized = false;
  static bool _isAppInForeground = true;

  static const String completeActionId = 'complete_action';
  static const String snoozeAction1Id = 'snooze_action_1';
  static const String snoozeAction2Id = 'snooze_action_2';

  /// Create a NotificationCalendar that works reliably in background isolates
  /// by manually setting all components instead of using fromDate()
  static NotificationCalendar _createSafeNotificationCalendar(DateTime scheduledTime) {
    // CRITICAL: We must provide an explicit timezone string to avoid calling
    // TimeZone.getDefault() which can be null in background isolates.
    //
    // We convert to UTC and mark it as UTC. The notification system will
    // fire at this absolute moment in time, regardless of timezone changes.
    final utcTime = scheduledTime.toUtc();

    debugPrint('🕐 Scheduling notification:');
    debugPrint('   Local time: $scheduledTime');
    debugPrint('   UTC time: $utcTime');

    return NotificationCalendar(
      year: utcTime.year,
      month: utcTime.month,
      day: utcTime.day,
      hour: utcTime.hour,
      minute: utcTime.minute,
      second: utcTime.second,
      millisecond: 0,
      allowWhileIdle: true,
      preciseAlarm: true,
      timeZone: 'UTC', // Explicitly use UTC to avoid TimeZone.getDefault() call
    );
  }

  @pragma('vm:entry-point')
  static Future<void> _initializeBackgroundServices() async {
    try {
      debugPrint('🔧 ========================================');
      debugPrint('🔧 INITIALIZING BACKGROUND ISOLATE SERVICES');
      debugPrint('🔧 ========================================');

      //Ensure Flutter bindings are initialized
      WidgetsFlutterBinding.ensureInitialized();
      debugPrint('✅ Flutter bindings initialized');

      // CRITICAL FIX: Initialize timezone data in background isolate
      // This is needed for NotificationCalendar.fromDate() to work
      tz.initializeTimeZones();
      debugPrint('✅ Timezone data initialized in background isolate');

      // CRITICAL FIX: Re-initialize AwesomeNotifications in background isolate
      // This ensures the plugin's native components (including Java TimeZone handling)
      // are properly initialized when scheduling from background
      try {
        final isInitialized = await AwesomeNotifications().isNotificationAllowed();
        debugPrint('✅ AwesomeNotifications checked in background: $isInitialized');
      } catch (e) {
        debugPrint('⚠️ AwesomeNotifications check failed (may be normal): $e');
      }

      //Initialize StorageService with fresh instance
      await StorageService.initialize();
      debugPrint('✅ StorageService initialized in background');

      // Small delay to ensure all native components are fully initialized
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('✅ Initialization delay completed');

      debugPrint('🔧 ========================================');
      debugPrint('🔧 BACKGROUND SERVICES READY');
      debugPrint('🔧 ========================================');
    } catch (e, stackTrace) {
      debugPrint('❌Failed to initialize background services');
      debugPrint('❌ Error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Initialize notification service (Activity-independent parts only)
  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ NotificationService already initialized');
      return;
    }

    debugPrint(
        '🔔 Initializing NotificationService with awesome_notifications...');

    try {
      // Initialize timezone
      tz.initializeTimeZones();

      // Initialize awesome_notifications channels (no Activity needed)
      await AwesomeNotifications().initialize(
        null, // default app icon
        [
          // Regular reminder channel with DEFAULT sound
          NotificationChannel(
            channelKey: 'reminder_channel',
            channelName: 'Reminders',
            channelDescription: 'Notifications for scheduled reminders',
            defaultColor: const Color(0xFF9D50DD),
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
            soundSource: null,
          ),
          // Alarm channel for full-screen alarms with LOUD ALARM sound
          NotificationChannel(
            channelKey: 'alarm_channel_v3',
            channelName: 'Alarms',
            channelDescription:
                'Full-screen alarm notifications with loud sound',
            defaultColor: const Color(0xFFFF0000),
            ledColor: Colors.red,
            importance: NotificationImportance.Max,
            channelShowBadge: true,
            playSound: false,
            enableVibration: true,
            criticalAlerts: true,
            locked: true,
            soundSource: null,
          ),
        ],
        debug: true,
      );

      // Initialize action listeners (no Activity needed)
      await initializeActionListeners();

      // Set up foreground/background detection
      _setupAppStateListener();

      // Check if device was rebooted and reinitialize if needed
      await checkAndReinitializeAfterBoot();

      _isInitialized = true;
      debugPrint('✅ NotificationService core initialization complete');
      debugPrint('⏳ Permissions will be requested after Activity is ready');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize NotificationService: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Initialize Activity-dependent features (call after first frame)
  static Future<void> initializeActivityDependentFeatures() async {
    if (!_isInitialized) {
      debugPrint(
          '⚠️ Cannot initialize Activity features - service not initialized');
      return;
    }

    try {
      debugPrint('🎯 Initializing Activity-dependent notification features...');

      // Now we can safely request permissions
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();

      if (!isAllowed) {
        final granted =
            await AwesomeNotifications().requestPermissionToSendNotifications();
        if (granted) {
          debugPrint('✅ Notification permissions granted');
        } else {
          debugPrint('⚠️ Notification permissions denied by user');
        }
      } else {
        debugPrint('✅ Notification permissions already granted');
      }

      debugPrint('✅ Activity-dependent features initialized');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Failed to initialize Activity-dependent features: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - this is non-fatal
    }
  }

  static Future<void> initializeActionListeners() async {
    try {
      debugPrint('🎯 Setting up action listeners...');

      //Set up the listeners for notification actions
      await AwesomeNotifications().setListeners(
        onActionReceivedMethod: _onActionReceivedMethod,
        onNotificationCreatedMethod: _onNotificationCreatedMethod,
        onNotificationDisplayedMethod: _onNotificationDisplayedMethod,
        onDismissActionReceivedMethod: _onDismissActionReceivedMethod,
      );

      debugPrint('✅ Action listeners initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing action listeners: $e');
      rethrow;
    }
  }

  static void _setupAppStateListener() {
    // Use flutter_fgbg for accurate app state detection
    FGBGEvents.instance.stream.listen((event) {
      _isAppInForeground = (event == FGBGType.foreground);
      debugPrint(
          '📱 App state: ${_isAppInForeground ? "FOREGROUND" : "BACKGROUND"}');
    });
  }

  /// Request full-screen intent permissions (Activity-safe)
  static Future<void> requestFullScreenPermission() async {
    try {
      debugPrint('🔐 Requesting full-screen intent permissions...');

      final isAllowed = await AwesomeNotifications().isNotificationAllowed();

      if (!isAllowed) {
        final permissionGranted =
            await AwesomeNotifications().requestPermissionToSendNotifications();

        if (permissionGranted) {
          debugPrint('✅ Full-screen notification permission granted');
        } else {
          debugPrint('⚠️ Full-screen notification permission denied');
        }
      } else {
        debugPrint('✅ Full-screen notifications already allowed');
      }
    } catch (e) {
      debugPrint('⚠️ Error requesting full-screen permission: $e');
      // Non-fatal - permissions might already be granted
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint('🔔 ========================================');
    debugPrint('🔔 Action Type: ${receivedAction.actionType}');
    debugPrint('🔔 Channel Key: ${receivedAction.channelKey}');
    debugPrint('🔔 NOTIFICATION ACTION RECEIVED!');
    debugPrint('🔔 Notification ID: ${receivedAction.id}');
    debugPrint('🔔 Button pressed: ${receivedAction.buttonKeyPressed}');
    debugPrint('🔔 Payload: ${receivedAction.payload}');
    debugPrint('🔔 ========================================');

    try {
      // CRITICAL FIX: Initialize services in background isolate
      // This ensures StorageService works when app is closed
      debugPrint('🔧 Initializing background services...');
      await _initializeBackgroundServices();
      debugPrint('✅ Background services ready');

      // Extract reminder ID from payload
      final reminderId = receivedAction.payload?['reminder_id'];
      final timeSlotId = receivedAction.payload?['time_slot_id'];

      if (reminderId == null || reminderId.isEmpty) {
        debugPrint('❌ No reminder ID in payload');
        debugPrint(
            '   Payload keys: ${receivedAction.payload?.keys.join(', ') ?? '0'}');
        return;
      }
      if (timeSlotId != null) {
        debugPrint('📋 Time slot: $timeSlotId');
      }

      // Handle different action button presses
      final buttonKey = receivedAction.buttonKeyPressed;

      if (buttonKey == 'DISMISS' || buttonKey == 'COMPLETE') {
        debugPrint('🚫 Handling DISMISS/COMPLETE action');
        await _handleDismissAction(reminderId, timeSlotId);
      } else if (buttonKey == 'SNOOZE_5') {
        debugPrint('⏰ Handling SNOOZE 5min action');
        await _handleSnoozeAction(
            reminderId, const Duration(minutes: 5), timeSlotId);
      } else if (buttonKey == 'SNOOZE_10') {
        debugPrint('⏰ Handling SNOOZE 10min action');
        await _handleSnoozeAction(
            reminderId, const Duration(minutes: 10), timeSlotId);
      } else if (buttonKey == 'SNOOZE_15') {
        debugPrint('⏰ Handling SNOOZE 15min action');
        await _handleSnoozeAction(
            reminderId, const Duration(minutes: 15), timeSlotId);
      } else if (buttonKey.isEmpty) {
        // User tapped the notification body (not a button)
        debugPrint('👆 User tapped notification body, opening app...');

        // CRITICAL FIX: Stop alarm sound if it's playing
        if (DefaultSoundService.isPlaying) {
          await DefaultSoundService.stop();
          debugPrint('🔇 Stopped alarm sound on notification tap');
        }

        // Cancel the notification to clear it from the tray
        final alarmId = timeSlotId != null
            ? AlarmService.generateTimeSlotAlarmId(reminderId, timeSlotId)
            : reminderId.hashCode;
        await cancelNotification(alarmId);
        debugPrint('🔴 Cancelled notification on tap: $alarmId');
      } else {
        debugPrint('⚠️ Unknown button key: $buttonKey');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling notification action: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    debugPrint('🔔 Notification created: ${receivedNotification.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    debugPrint('📢 Notification displayed: ${receivedNotification.id}');

    // Check if this is an alarm notification (Mixed Mode)
    if (receivedNotification.payload?['type'] == 'alarm') {
      // Play alarm sound using flutter_ringtone_player
      await DefaultSoundService.playAlarmSound();
      debugPrint('🔊 Started playing alarm sound for notification');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint('🗑️ ========================================');
    debugPrint('🗑️ SWIPE DISMISS or AUTO DISMISS');
    debugPrint('🗑️ Notification ID: ${receivedAction.id}');
    debugPrint('🗑️ Button pressed: ${receivedAction.buttonKeyPressed}');
    debugPrint('🗑️ Payload: ${receivedAction.payload}');
    debugPrint('🗑️ ========================================');

    // If this was triggered by action buttons, don't process here
    // It will be handled by _onActionReceivedMethod
    if (receivedAction.buttonKeyPressed.isNotEmpty) {
      debugPrint('⚠️ Action button detected in dismiss handler - ignoring');
      debugPrint('   Button: ${receivedAction.buttonKeyPressed}');
      debugPrint('   (Will be processed by _onActionReceivedMethod)');
      return;
    }

    try {
      // Stop alarm sound if it's playing (for swipe dismiss)
      if (DefaultSoundService.isPlaying) {
        await DefaultSoundService.stop();
        debugPrint('🔇 Stopped alarm sound on swipe dismiss');
      }

      // CRITICAL FIX: Ensure the notification is actually cancelled from the system
      // This prevents stale notifications from accumulating and causing badge count issues
      await cancelNotification(receivedAction.id!);
      debugPrint('🔴 Ensured notification ${receivedAction.id} is cancelled from system');
    } catch (e) {
      debugPrint('⚠️ Error handling swipe dismiss: $e');
    }
  }

  static Future<void> _handleDismissAction(
      String reminderId, String? timeSlotId) async {
    debugPrint('🚫 ========================================');
    debugPrint('🚫 DISMISS ACTION STARTING');
    debugPrint('🚫 Reminder: $reminderId');
    debugPrint('🚫 Time slot: $timeSlotId');
    debugPrint('🚫 ========================================');

    try {
      // Stop any playing alarm sound
      if (DefaultSoundService.isPlaying) {
        await DefaultSoundService.stop();
        debugPrint('🔇 Stopped alarm sound');
      }

      // Cancel the notification
      final alarmId = timeSlotId != null
          ? AlarmService.generateTimeSlotAlarmId(reminderId, timeSlotId)
          : reminderId.hashCode;
      await cancelNotification(alarmId);
      debugPrint('🔴 Cancelled notification: $alarmId');

      // Mark reminder as completed using AlarmService
      await AlarmService.dismissAlarm(reminderId, timeSlotId: timeSlotId);
      debugPrint('✅ Marked reminder as completed');

      //Notify storage of background update
      await StorageService.markNotificationUpdate();

      debugPrint('🚫 ========================================');
      debugPrint('🚫 DISMISS COMPLETED SUCCESSFULLY');
      debugPrint('🚫 ========================================');
    } catch (e, stackTrace) {
      debugPrint('❌ Error dismissing alarm: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<void> _handleSnoozeAction(
      String reminderId, Duration snoozeDuration, String? timeSlotId) async {
    debugPrint('💤 ========================================');
    debugPrint('💤 SNOOZE ACTION STARTING');
    debugPrint('💤 Reminder: $reminderId');
    debugPrint('💤 Duration: ${snoozeDuration.inMinutes} minutes');
    debugPrint('💤 Time slot: $timeSlotId');
    debugPrint('💤 ========================================');

    try {
      // Stop any playing alarm sound
      if (DefaultSoundService.isPlaying) {
        await DefaultSoundService.stop();
        debugPrint('🔇 Stopped alarm sound');
      }

      // Cancel current notification
      final alarmId = timeSlotId != null
          ? AlarmService.generateTimeSlotAlarmId(reminderId, timeSlotId)
          : reminderId.hashCode;
      await cancelNotification(alarmId);
      debugPrint('🔴 Cancelled current notification: $alarmId');

      // Get the reminder
      final reminder = await StorageService.getReminderById(reminderId);
      if (reminder == null) {
        debugPrint('❌ Reminder not found: $reminderId');
        return;
      }

      // Calculate new scheduled time
      final newScheduledTime = DateTime.now().add(snoozeDuration);
      debugPrint('⏰ New alarm time: $newScheduledTime');

      // CRITICAL FIX: Update the reminder's scheduledTime in storage
      Reminder updatedReminder;

      if (timeSlotId != null && reminder.hasMultipleTimes) {
        // Handle multi-time snooze - update the specific time slot
        final updatedTimeSlots = reminder.timeSlots.map((slot) {
          if (slot.id == timeSlotId) {
            // Update the time slot's time to the snoozed time
            return slot.copyWith(
              time: TimeOfDay(
                hour: newScheduledTime.hour,
                minute: newScheduledTime.minute,
              ),
            );
          }
          return slot;
        }).toList();

        updatedReminder = reminder.copyWith(
          timeSlots: updatedTimeSlots,
          updatedAt: DateTime.now(),
        );

        debugPrint('📝 Updated time slot: $timeSlotId to $newScheduledTime');
      } else {
        // Handle single-time snooze - update the main scheduledTime
        updatedReminder = reminder.copyWith(
          scheduledTime: newScheduledTime,
          updatedAt: DateTime.now(),
        );

        debugPrint('📝 Updated reminder scheduledTime to: $newScheduledTime');
      }

      // Save the updated reminder to storage
      await StorageService.updateReminder(updatedReminder);
      debugPrint('💾 Saved updated reminder to storage');

      // CRITICAL FIX: Check mode before rescheduling
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();

      if (useAlarm) {
        // Mixed Mode: Reschedule as alarm notification
        debugPrint('📢 Rescheduling in MIXED MODE (alarm_channel)');
        if (timeSlotId != null && updatedReminder.hasMultipleTimes) {
          final timeSlot =
              updatedReminder.timeSlots.firstWhere((ts) => ts.id == timeSlotId);
          await scheduleAlarmNotification(
            reminder: updatedReminder,
            alarmId: alarmId,
            customTime: newScheduledTime,
            timeSlot: timeSlot,
          );
          debugPrint('✅ Rescheduled multi-time alarm');
        } else {
          await scheduleAlarmNotification(
            reminder: updatedReminder,
            alarmId: alarmId,
            customTime: newScheduledTime,
          );
          debugPrint('✅ Rescheduled single-time alarm');
        }
      } else {
        // Notification Mode: Reschedule as regular notification
        debugPrint('📢 Rescheduling in NOTIFICATION MODE (reminder_channel)');
        if (timeSlotId != null && updatedReminder.hasMultipleTimes) {
          final timeSlot =
              updatedReminder.timeSlots.firstWhere((ts) => ts.id == timeSlotId);
          await _scheduleTimeSlotNotification(
            reminder: updatedReminder,
            timeSlot: timeSlot,
            scheduledTime: newScheduledTime,
          );
          debugPrint('✅ Rescheduled multi-time notification');
        } else {
          await _scheduleSingleTimeReminder(updatedReminder);
          debugPrint('✅ Rescheduled single-time notification');
        }
      }

      //Notify storage of background update
      await StorageService.markNotificationUpdate();

      debugPrint('💤 ========================================');
      debugPrint('💤 SNOOZE COMPLETED SUCCESSFULLY');
      debugPrint('💤 New time: $newScheduledTime');
      debugPrint('💤 ========================================');
    } catch (e, stackTrace) {
      debugPrint('❌ Error snoozing alarm: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<void> scheduleAlarmNotification({
    required Reminder reminder,
    required int alarmId,
    DateTime? customTime,
    TimeSlot? timeSlot,
  }) async {
    try {
      var scheduledTime = customTime ?? reminder.scheduledTime;

      final now = DateTime.now();

      // Handle custom repeat for alarm notifications
      if (customTime == null &&
          reminder.repeatType == RepeatType.custom &&
          reminder.customRepeatConfig != null) {
        final nextOccurrence = _calculateNextCustomOccurrence(
          reminder.scheduledTime,
          reminder.customRepeatConfig!,
        );

        if (nextOccurrence == null) {
          debugPrint('No more occurrences for custom repeat - end date reached');
          return;
        }

        scheduledTime = nextOccurrence;
        debugPrint('Custom repeat alarm: Next occurrence at $scheduledTime');
      }

      // Check if time is in the past
      if (scheduledTime.isBefore(now)) {
        debugPrint('⚠️ Scheduled time is in the past');
        debugPrint('   Scheduled: $scheduledTime');
        debugPrint('   Now: $now');

        // CRITICAL FIX: Don't auto-adjust snooze times - they should already be in the future
        if (customTime != null) {
          // Snooze times are calculated as now + duration, so if they're in the past,
          // something is very wrong. Log error and skip.
          debugPrint(
              '❌ ERROR: Snooze time is in the past - this should not happen!');
          debugPrint('   Custom time: $customTime');
          return;
        } else {
          debugPrint('   Skipping notification - time is in the past');
          return;
        }
      }

      // If scheduled time is very close (within 3 seconds), add a small buffer
      final difference = scheduledTime.difference(now).inSeconds;
      if (difference < 3 && difference >= 0) {
        debugPrint(
            '⏰ Scheduled time is very close ($difference seconds), adding buffer');
        scheduledTime = now.add(const Duration(seconds: 3));
      }

      final title = reminder.title;
      final body = timeSlot != null
          ? '${timeSlot.formattedTime} - ${timeSlot.description ?? "Reminder"}'
          : reminder.description ?? 'Reminder alarm';

      // Build action buttons for snooze and dismiss
      final actionButtons = <NotificationActionButton>[
        NotificationActionButton(
          key: 'COMPLETE',
          label: 'Dismiss',
          actionType: ActionType.SilentAction,
          isDangerousOption: true,
        ),
        NotificationActionButton(
          key: 'SNOOZE_5',
          label: 'Snooze 5min',
          actionType: ActionType.SilentAction,
        ),
        NotificationActionButton(
          key: 'SNOOZE_10',
          label: 'Snooze 10min',
          actionType: ActionType.SilentAction,
        ),
      ];

      // Create notification payload
      final payload = <String, String>{
        'reminder_id': reminder.id,
        if (timeSlot != null) 'time_slot_id': timeSlot.id,
        'type': 'alarm',
      };

      // Cancel any existing notification with this ID first
      try {
        await AwesomeNotifications().cancel(alarmId);
        debugPrint('🔴 Cancelled existing notification: $alarmId');
      } catch (e) {
        debugPrint('⚠️ No existing notification to cancel: $e');
      }

      // Small delay to ensure cancellation completes
      await Future.delayed(const Duration(milliseconds: 100));

      // CRITICAL FIX: createNotification returns void, not bool
      // Just call it and trust it works
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: alarmId,
          channelKey: 'alarm_channel_v3',
          title: title,
          body: body,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
          fullScreenIntent: true,
          criticalAlert: true,
          payload: payload,
          autoDismissible: false,
          locked: true,
        ),
        actionButtons: actionButtons,
        schedule: _createSafeNotificationCalendar(scheduledTime),
      );

      // Always assume success since method doesn't return bool
      debugPrint(
          '✅ Alarm notification scheduled: ID $alarmId at $scheduledTime');
      debugPrint(
          '   Full-screen: true, Channel: alarm_channel (RED with SOUND)');
      debugPrint(
          '   Time until trigger: ${scheduledTime.difference(now).inSeconds} seconds');
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling alarm notification: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<void> scheduleReminder(Reminder reminder) async {
    try {
      if (!reminder.isNotificationEnabled) {
        debugPrint('Skipping reminder scheduling - notifications disabled');
        return;
      }

      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();
      debugPrint('🔔 scheduleReminder called for: ${reminder.title}');
      debugPrint('🔔 Mode: ${useAlarm ? "MIXED MODE" : "NOTIFICATION MODE"}');
      debugPrint('🔔 Multi-time: ${reminder.hasMultipleTimes}');
      debugPrint('🔔 Scheduled: ${reminder.scheduledTime}');

      if (useAlarm) {
        debugPrint(
            'User chose MIXED MODE - scheduling alarm notification (red, loud)');

        // Schedule alarm notification (red, loud, full-screen)
        if (reminder.hasMultipleTimes) {
          for (final timeSlot in reminder.timeSlots) {
            if (timeSlot.status != ReminderStatus.pending) continue;

            final now = DateTime.now();
            DateTime notificationTime = DateTime(
              reminder.scheduledTime.year,
              reminder.scheduledTime.month,
              reminder.scheduledTime.day,
              timeSlot.time.hour,
              timeSlot.time.minute,
            );

            if (notificationTime.isBefore(now)) {
              if (reminder.repeatType == RepeatType.daily) {
                notificationTime =
                    notificationTime.add(const Duration(days: 1));
              } else {
                continue;
              }
            }

            final alarmId =
                AlarmService.generateTimeSlotAlarmId(reminder.id, timeSlot.id);
            await scheduleAlarmNotification(
              reminder: reminder,
              alarmId: alarmId,
              customTime: notificationTime,
              timeSlot: timeSlot,
            );
          }
        } else {
          final alarmId = AlarmService.generateAlarmId(reminder.id);
          await scheduleAlarmNotification(
            reminder: reminder,
            alarmId: alarmId,
          );
        }
      } else {
        debugPrint('Notification-only mode (blue, standard sound)');
        // Schedule regular notifications (blue, standard)
        if (reminder.hasMultipleTimes) {
          await _scheduleMultiTimeReminder(reminder);
        } else {
          await _scheduleSingleTimeReminder(reminder);
        }
      }
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Calculate the next occurrence for a custom repeat reminder
  static DateTime? _calculateNextCustomOccurrence(
    DateTime startTime,
    CustomRepeatConfig config,
  ) {
    final now = DateTime.now();
    DateTime nextTime = startTime;

    // If start time is in the past, calculate the next valid occurrence
    if (nextTime.isBefore(now)) {
      final intervalMinutes = config.totalMinutes;
      final minutesSinceStart = now.difference(startTime).inMinutes;
      final occurrencesPassed = (minutesSinceStart / intervalMinutes).ceil();

      nextTime = startTime.add(Duration(minutes: intervalMinutes * occurrencesPassed));

      // Ensure we're not scheduling in the past
      while (nextTime.isBefore(now)) {
        nextTime = nextTime.add(Duration(minutes: intervalMinutes));
      }
    }

    // Check if we've passed the end date
    if (config.endDate != null && nextTime.isAfter(config.endDate!)) {
      return null; // No more occurrences
    }

    // Check if this falls on a specific day requirement
    if (config.specificDays != null && config.specificDays!.isNotEmpty) {
      // Keep advancing until we find a valid day
      int attempts = 0;
      while (attempts < 1000) { // Safety limit
        final weekday = nextTime.weekday; // 1=Mon, 7=Sun
        if (config.specificDays!.contains(weekday)) {
          break; // Found a valid day
        }

        // Advance to next occurrence
        nextTime = nextTime.add(Duration(minutes: config.totalMinutes));

        // Check end date again
        if (config.endDate != null && nextTime.isAfter(config.endDate!)) {
          return null;
        }

        attempts++;
      }
    }

    return nextTime;
  }

  static Future<void> _scheduleSingleTimeReminder(Reminder reminder) async {
    try {
      final now = DateTime.now();
      DateTime scheduledTime = reminder.scheduledTime;

      // Handle custom repeat
      if (reminder.repeatType == RepeatType.custom && reminder.customRepeatConfig != null) {
        final nextOccurrence = _calculateNextCustomOccurrence(
          reminder.scheduledTime,
          reminder.customRepeatConfig!,
        );

        if (nextOccurrence == null) {
          debugPrint('No more occurrences for custom repeat - end date reached');
          return;
        }

        scheduledTime = nextOccurrence;
        debugPrint('Custom repeat: Next occurrence at $scheduledTime');
      } else if (reminder.scheduledTime
          .isBefore(now.subtract(const Duration(minutes: 5)))) {
        debugPrint('Skipping notification - time is too far in the past');
        return;
      }

      final title = reminder.title;
      final body = reminder.description ?? 'Reminder notification';

      // Build action buttons
      final actionButtons = <NotificationActionButton>[
        NotificationActionButton(
          key: 'COMPLETE',
          label: 'Dismiss',
          actionType: ActionType.SilentAction,
        ),
        NotificationActionButton(
          key: 'SNOOZE_5',
          label: 'Snooze 5min',
          actionType: ActionType.SilentAction,
        ),
      ];

      final payload = <String, String>{
        'reminder_id': reminder.id,
        'type': 'notification',
      };

      // For custom repeat, we schedule as one-time and will need to reschedule after trigger
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: reminder.id.hashCode,
          channelKey: 'reminder_channel',
          title: title,
          body: body,
          category: NotificationCategory.Reminder,
          wakeUpScreen: false,
          payload: payload,
        ),
        actionButtons: actionButtons,
        schedule: _createSafeNotificationCalendar(scheduledTime),
      );

      debugPrint('✅ Scheduled notification for ${reminder.title} at $scheduledTime');
    } catch (e) {
      debugPrint('❌ Error scheduling single-time reminder: $e');
    }
  }

  static Future<void> _scheduleMultiTimeReminder(Reminder reminder) async {
    try {
      debugPrint('Scheduling multi-time notifications for: ${reminder.title}');

      for (final timeSlot in reminder.timeSlots) {
        if (timeSlot.status != ReminderStatus.pending) continue;

        final now = DateTime.now();
        DateTime notificationTime = DateTime(
          reminder.scheduledTime.year,
          reminder.scheduledTime.month,
          reminder.scheduledTime.day,
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

        await _scheduleTimeSlotNotification(
          reminder: reminder,
          timeSlot: timeSlot,
          scheduledTime: notificationTime,
        );
      }
    } catch (e) {
      debugPrint('❌ Error scheduling multi-time reminder: $e');
    }
  }

  static Future<void> _scheduleTimeSlotNotification({
    required Reminder reminder,
    required TimeSlot timeSlot,
    required DateTime scheduledTime,
  }) async {
    final notificationId =
        generateTimeSlotNotificationId(reminder.id, timeSlot.id);

    final title = reminder.title;
    final body = timeSlot.description?.isNotEmpty == true
        ? '${timeSlot.formattedTime} - ${timeSlot.description}'
        : '${timeSlot.formattedTime} reminder';

    final actionButtons = <NotificationActionButton>[
      NotificationActionButton(
        key: 'COMPLETE',
        label: 'Dismiss',
        actionType: ActionType.SilentAction,
      ),
      NotificationActionButton(
        key: 'SNOOZE_5',
        label: 'Snooze 5min',
        actionType: ActionType.SilentAction,
      ),
    ];

    final payload = <String, String>{
      'reminder_id': reminder.id,
      'time_slot_id': timeSlot.id,
      'type': 'notification',
    };

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: 'reminder_channel',
        title: title,
        body: body,
        category: NotificationCategory.Reminder,
        payload: payload,
      ),
      actionButtons: actionButtons,
      schedule: _createSafeNotificationCalendar(scheduledTime),
    );

    debugPrint('✅ Scheduled time slot notification: ID $notificationId');
  }

  static Future<void> cancelReminder(String reminderId) async {
    try {
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();

      if (useAlarm) {
        debugPrint('Mixed mode - cancelling alarm notifications');
        await AwesomeNotifications().cancel(reminderId.hashCode);

        final reminder = await StorageService.getReminderById(reminderId);
        if (reminder != null && reminder.hasMultipleTimes) {
          for (final timeSlot in reminder.timeSlots) {
            final alarmId =
                AlarmService.generateTimeSlotAlarmId(reminderId, timeSlot.id);
            await AwesomeNotifications().cancel(alarmId);
          }
        }
      } else {
        debugPrint('Notification mode - cancelling notifications');
        await AwesomeNotifications().cancel(reminderId.hashCode);

        final reminder = await StorageService.getReminderById(reminderId);
        if (reminder != null && reminder.hasMultipleTimes) {
          for (final timeSlot in reminder.timeSlots) {
            final notificationId =
                generateTimeSlotNotificationId(reminderId, timeSlot.id);
            await AwesomeNotifications().cancel(notificationId);
          }
        }
      }

      debugPrint('✅ Cancelled for: $reminderId');
    } catch (e) {
      debugPrint('❌ Error cancelling reminder: $e');
    }
  }

  static Future<void> cancelTimeSlotNotification(
      String reminderId, String timeSlotId) async {
    final notificationId =
        generateTimeSlotNotificationId(reminderId, timeSlotId);
    await AwesomeNotifications().cancel(notificationId);
  }

  static Future<void> cancelNotification(int notificationId) async {
    try {
      await AwesomeNotifications().cancel(notificationId);
      debugPrint('📕 Canceled notification ID: $notificationId');
    } catch (e) {
      debugPrint('⚠️ Error canceling notification ID $notificationId: $e');
    }
  }

  static Future<void> cancelAllReminders() async {
    try {
      await AwesomeNotifications().cancelAll();
      debugPrint('📕 Canceled all notifications');
    } catch (e) {
      debugPrint('⚠️ Error canceling all notifications: $e');
    }
  }

  static Future<bool> isMixedModeEnabled() async {
    return await StorageService.getUseAlarmInsteadOfNotification();
  }

  static Future<void> updateReminderNotifications(Reminder reminder) async {
    try {
      await cancelReminder(reminder.id);
      await scheduleReminder(reminder);
    } catch (e) {
      debugPrint(
          'Error updating notifications/alarms for reminder ${reminder.id}: $e');
    }
  }

  static int generateTimeSlotNotificationId(
      String reminderId, String timeSlotId) {
    final combined = '$reminderId:$timeSlotId';
    return combined.hashCode.abs();
  }

  static Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'reminder_channel',
          title: title,
          body: body,
          category: NotificationCategory.Reminder,
          payload: payload != null ? {'data': payload} : null,
        ),
      );
      debugPrint('✅ Immediate notification shown');
    } catch (e) {
      debugPrint('❌ Error showing immediate notification: $e');
    }
  }

  /// Schedule notifications for specific time slots
  static Future<void> scheduleTimeSlotNotifications(
    Reminder reminder,
    List<TimeSlot> pendingSlots,
  ) async {
    if (!reminder.isNotificationEnabled) return;

    try {
      for (final timeSlot in pendingSlots) {
        if (timeSlot.status == ReminderStatus.pending) {
          final now = DateTime.now();
          DateTime notificationTime = DateTime(
            reminder.scheduledTime.year,
            reminder.scheduledTime.month,
            reminder.scheduledTime.day,
            timeSlot.time.hour,
            timeSlot.time.minute,
          );

          if (notificationTime.isBefore(now) &&
              reminder.repeatType == RepeatType.daily) {
            notificationTime = notificationTime.add(const Duration(days: 1));
          }

          if (notificationTime.isAfter(now)) {
            await _scheduleTimeSlotNotification(
              reminder: reminder,
              timeSlot: timeSlot,
              scheduledTime: notificationTime,
            );
          }
        }
      }

      debugPrint('✅ Scheduled ${pendingSlots.length} time slot notifications');
    } catch (e) {
      debugPrint('❌ Error scheduling time slot notifications: $e');
    }
  }

  /// Refresh notification categories (no-op for awesome_notifications)
  /// This method exists for compatibility with old code that called it
  static Future<void> refreshNotificationCategories() async {
    // awesome_notifications handles categories automatically
    // No need to manually refresh like flutter_local_notifications
    debugPrint(
        'ℹ️ refreshNotificationCategories called (no-op with awesome_notifications)');
  }

  /// Clean up stale notifications that don't have corresponding active reminders
  /// This prevents badge count issues from accumulating stale notifications
  static Future<void> cleanupStaleNotifications() async {
    try {
      debugPrint('🧹 ========================================');
      debugPrint('🧹 CLEANING UP STALE NOTIFICATIONS');
      debugPrint('🧹 ========================================');

      // Get all active notifications from the system
      final activeNotifications = await AwesomeNotifications().listScheduledNotifications();
      debugPrint('📋 Found ${activeNotifications.length} scheduled notifications in system');

      if (activeNotifications.isEmpty) {
        debugPrint('✅ No scheduled notifications to clean up');
        return;
      }

      // Get all reminders from storage
      final reminders = await StorageService.getReminders();
      debugPrint('📋 Found ${reminders.length} reminders in storage');

      // Build a set of valid notification IDs
      final validNotificationIds = <int>{};

      for (final reminder in reminders) {
        if (reminder.status == ReminderStatus.pending && reminder.isNotificationEnabled) {
          // Add main reminder notification ID
          validNotificationIds.add(reminder.id.hashCode);

          // Add time slot notification IDs if multi-time
          if (reminder.hasMultipleTimes) {
            for (final timeSlot in reminder.timeSlots) {
              if (timeSlot.status == ReminderStatus.pending) {
                final notificationId = generateTimeSlotNotificationId(reminder.id, timeSlot.id);
                validNotificationIds.add(notificationId);

                // Also add alarm ID for mixed mode
                final alarmId = AlarmService.generateTimeSlotAlarmId(reminder.id, timeSlot.id);
                validNotificationIds.add(alarmId);
              }
            }
          }

          // Add alarm ID for mixed mode
          final alarmId = AlarmService.generateAlarmId(reminder.id);
          validNotificationIds.add(alarmId);
        }
      }

      debugPrint('✅ Built set of ${validNotificationIds.length} valid notification IDs');

      // Cancel any notifications that aren't in the valid set
      int cancelledCount = 0;
      for (final notification in activeNotifications) {
        if (!validNotificationIds.contains(notification.content?.id)) {
          await cancelNotification(notification.content!.id!);
          debugPrint('🗑️ Cancelled stale notification: ${notification.content!.id} - ${notification.content!.title}');
          cancelledCount++;
        }
      }

      debugPrint('🧹 ========================================');
      debugPrint('✅ CLEANUP COMPLETE');
      debugPrint('   Scheduled: ${activeNotifications.length}');
      debugPrint('   Cancelled: $cancelledCount');
      debugPrint('   Remaining: ${activeNotifications.length - cancelledCount}');
      debugPrint('🧹 ========================================');
    } catch (e, stackTrace) {
      debugPrint('❌ Error cleaning up stale notifications: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<void> checkAndReinitializeAfterBoot() async {
    try {
      debugPrint('🔍 ========================================');
      debugPrint('🔍 CHECKING FOR BOOT RESCHEDULE FLAG');
      debugPrint('🔍 ========================================');

      final prefs = await SharedPreferences.getInstance();
      final bootCompleted =
          prefs.getBool('flutter.boot_reschedule_completed') ?? false;

      debugPrint('🔍 Boot flag value: $bootCompleted');

      if (bootCompleted) {
        debugPrint('========================================');
        debugPrint('📱 DEVICE WAS REBOOTED - RESCHEDULING ALL');
        debugPrint('========================================');

        // Clear the flag FIRST
        await prefs.setBool('flutter.boot_reschedule_completed', false);
        debugPrint('✅ Cleared boot reschedule flag');

        // ALWAYS trigger a full reschedule after boot
        debugPrint('🔄 Forcing full reschedule of all pending reminders...');

        final reminders = await StorageService.getReminders();
        debugPrint('📋 Found ${reminders.length} total reminders');

        int rescheduled = 0;
        int skipped = 0;

        for (final reminder in reminders) {
          debugPrint('🔍 Checking reminder: ${reminder.title}');
          debugPrint('   Status: ${reminder.status}');
          debugPrint('   Enabled: ${reminder.isNotificationEnabled}');
          debugPrint('   Time: ${reminder.scheduledTime}');

          if (reminder.status == ReminderStatus.pending &&
              reminder.isNotificationEnabled) {
            final now = DateTime.now();

            // Skip past reminders unless they're repeating
            if (reminder.scheduledTime.isBefore(now) &&
                reminder.repeatType == RepeatType.none) {
              debugPrint(
                  '⏭️ Skipping past non-repeating reminder: ${reminder.title}');
              skipped++;
              continue;
            }

            try {
              final useAlarm =
                  await StorageService.getUseAlarmInsteadOfNotification();
              debugPrint(
                  '🔄 Rescheduling ${reminder.title} (useAlarm: $useAlarm)');

              if (useAlarm) {
                await AlarmService.setAlarmReminder(reminder);
              } else {
                await scheduleReminder(reminder);
              }
              rescheduled++;
              debugPrint('✅ Rescheduled: ${reminder.title}');
            } catch (e) {
              debugPrint('❌ Failed to reschedule ${reminder.title}: $e');
            }
          } else {
            debugPrint(
                '⏭️ Skipping reminder (not pending or disabled): ${reminder.title}');
            skipped++;
          }
        }

        debugPrint('========================================');
        debugPrint('✅ BOOT RESCHEDULE COMPLETE');
        debugPrint('   Total: ${reminders.length}');
        debugPrint('   Rescheduled: $rescheduled');
        debugPrint('   Skipped: $skipped');
        debugPrint('========================================');

        // Clean up any stale notifications after rescheduling
        await cleanupStaleNotifications();
      } else {
        debugPrint('ℹ️ No boot reschedule flag detected - normal launch');

        // Still run cleanup on normal launch to clear any stale notifications
        await cleanupStaleNotifications();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in boot reschedule: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}
