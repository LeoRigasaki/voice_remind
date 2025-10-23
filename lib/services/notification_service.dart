// [lib/services]/notification_service.dart
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/reminder.dart';
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

      // Initialize awesome_notifications with SOUND enabled
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
            // Use default notification sound
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
            importance: NotificationImportance.Max, // CRITICAL for full-screen
            channelShowBadge: true,
            playSound: false,
            enableVibration: true,
            criticalAlerts: true,
            locked: true,
            // Use default alarm sound (system will use loudest ringtone)
            soundSource: null,
          ),
        ],
        debug: true,
      );

      // CRITICAL: Request permissions first
      await AwesomeNotifications().requestPermissionToSendNotifications();

      // CRITICAL: Initialize action listeners AFTER permissions
      await initializeActionListeners();

      // Set up foreground/background detection
      _setupAppStateListener();

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
      rethrow;
    }
  }

  static Future<void> initializeActionListeners() async {
    try {
      debugPrint('🎯 Setting up action listeners...');

      // CRITICAL: Set up the listeners for notification actions
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

  /// Request full-screen intent permission for Android 10+
  static Future<void> requestFullScreenPermission() async {
    try {
      // Request permission to show full-screen intents
      final permissionGranted = await AwesomeNotifications()
          .isNotificationAllowed()
          .then((isAllowed) async {
        if (!isAllowed) {
          return await AwesomeNotifications()
              .requestPermissionToSendNotifications();
        }
        return true;
      });

      if (permissionGranted) {
        debugPrint('✅ Full-screen notification permission granted');
      } else {
        debugPrint('⚠️ Full-screen notification permission denied');
      }
    } catch (e) {
      debugPrint('❌ Error requesting full-screen permission: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint('🔔 ========================================');
    debugPrint('🔔 Action Type: ${receivedAction.actionType}');
    debugPrint('🔔 Channel Key: ${receivedAction.channelKey}');
    debugPrint('🔔 NOTIFICATION ACTION RECEIVED!');
    debugPrint('🔔 Button pressed: ${receivedAction.buttonKeyPressed}');
    debugPrint('🔔 Notification ID: ${receivedAction.id}');
    debugPrint('🔔 Payload: ${receivedAction.payload}');
    debugPrint('🔔 ========================================');

    try {
      final payload = receivedAction.payload;
      if (payload == null || payload.isEmpty) {
        debugPrint('⚠️ No payload in notification action');
        return;
      }

      final reminderId = payload['reminder_id'];
      final timeSlotId = payload['time_slot_id'];

      if (reminderId == null) {
        debugPrint('⚠️ No reminder ID in payload');
        return;
      }

      debugPrint('📋 Processing action for reminder: $reminderId');

      // SAFETY CHECK: Verify reminder still exists
      final reminder = await StorageService.getReminderById(reminderId);
      if (reminder == null) {
        debugPrint(
            '⚠️ Reminder $reminderId no longer exists - ignoring ghost notification');
        // Stop any playing sound
        if (DefaultSoundService.isPlaying) {
          await DefaultSoundService.stop();
        }
        // Cancel this ghost notification
        await cancelNotification(receivedAction.id ?? 0);
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

    // Stop alarm sound if it's playing (for swipe dismiss)
    if (DefaultSoundService.isPlaying) {
      await DefaultSoundService.stop();
      debugPrint('🔇 Stopped alarm sound on swipe dismiss');
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

      // CRITICAL: Notify storage of background update
      await StorageService.markNotificationUpdate();

      debugPrint('🚫 ========================================');
      debugPrint('🚫 DISMISS COMPLETED SUCCESSFULLY');
      debugPrint('🚫 ========================================');
    } catch (e, stackTrace) {
      debugPrint('❌ Error dismissing alarm: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Replace the _handleSnoozeAction method in notification_service.dart

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

      // CRITICAL: Notify storage of background update
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
        schedule: NotificationCalendar.fromDate(
          date: scheduledTime,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
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

  static Future<void> _scheduleSingleTimeReminder(Reminder reminder) async {
    try {
      final now = DateTime.now();

      if (reminder.scheduledTime
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
        schedule: NotificationCalendar.fromDate(
          date: reminder.scheduledTime,
          allowWhileIdle: true,
          preciseAlarm: true, // ← ADD THIS LINE!
        ),
      );

      debugPrint('✅ Scheduled notification for ${reminder.title}');
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
      schedule: NotificationCalendar.fromDate(
        date: scheduledTime,
        allowWhileIdle: true,
      ),
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
}
