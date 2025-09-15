// [lib/services]/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import 'storage_service.dart';
import '../services/alarm_service.dart';

@pragma('vm:entry-point')
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String completeActionId = 'complete_action';
  static const String snoozeAction1Id = 'snooze_action_1';
  static const String snoozeAction2Id = 'snooze_action_2';

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    // Create notification channels for both regular and mixed mode
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinNotificationAction completeAction =
        DarwinNotificationAction.plain(
      completeActionId,
      '✖️ Dismiss',
    );

    final snoozeConfig = await _getSnoozeConfig();
    final snoozeActions =
        (snoozeConfig['actions'] as List<Map<String, dynamic>>)
            .map((action) => DarwinNotificationAction.plain(
                  action['id'] as String,
                  action['label'] as String,
                ))
            .toList();

    final DarwinNotificationCategory reminderCategory =
        DarwinNotificationCategory(
      'reminder_category',
      actions: <DarwinNotificationAction>[
        completeAction,
        ...snoozeActions,
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    );

    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [reminderCategory],
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationTapped,
    );

    await _requestPermissions();

    // Create notification channels for mixed mode
    await _createNotificationChannels();
  }

  static Future<void> _createNotificationChannels() async {
    try {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Regular reminder channel
        const reminderChannel = AndroidNotificationChannel(
          'reminder_channel',
          'Reminders',
          description: 'Notifications for scheduled reminders',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        // Mixed mode channel with alarm sound
        const mixedModeChannel = AndroidNotificationChannel(
          'mixed_mode_channel',
          'Mixed Mode Alarms',
          description: 'Alarm-sound notifications for mixed mode',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          sound: RawResourceAndroidNotificationSound('alarm'),
        );

        await androidPlugin.createNotificationChannel(reminderChannel);
        await androidPlugin.createNotificationChannel(mixedModeChannel);

        debugPrint(
            '✅ Created notification channels for regular and mixed mode');
      }
    } catch (e) {
      debugPrint('⚠️ Error creating notification channels: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<Map<String, dynamic>> _getSnoozeConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final useCustom = prefs.getBool('snooze_use_custom') ?? false;
      final customMinutes = prefs.getInt('snooze_custom_minutes') ?? 15;

      if (useCustom) {
        String secondLabel;
        Duration secondDuration;

        if (customMinutes <= 30) {
          secondLabel = '1hour';
          secondDuration = const Duration(hours: 1);
        } else if (customMinutes <= 60) {
          secondLabel = '2hours';
          secondDuration = const Duration(hours: 2);
        } else {
          final halfCustom = (customMinutes / 2).round();
          secondLabel = '${halfCustom}min';
          secondDuration = Duration(minutes: halfCustom);
        }

        return {
          'useCustom': true,
          'actions': [
            {
              'id': snoozeAction1Id,
              'label': '${customMinutes}min',
              'duration': Duration(minutes: customMinutes)
            },
            {
              'id': snoozeAction2Id,
              'label': secondLabel,
              'duration': secondDuration
            },
          ],
        };
      } else {
        return {
          'useCustom': false,
          'actions': [
            {
              'id': snoozeAction1Id,
              'label': '10min',
              'duration': Duration(minutes: 10)
            },
            {
              'id': snoozeAction2Id,
              'label': '1hour',
              'duration': Duration(hours: 1)
            },
          ],
        };
      }
    } catch (e) {
      debugPrint('Error getting snooze config: $e');
      return {
        'useCustom': false,
        'actions': [
          {
            'id': snoozeAction1Id,
            'label': '10min',
            'duration': Duration(minutes: 10)
          },
          {
            'id': snoozeAction2Id,
            'label': '1hour',
            'duration': Duration(hours: 1)
          },
        ],
      };
    }
  }

  static Future<List<AndroidNotificationAction>>
      _buildAndroidNotificationActions() async {
    final snoozeConfig = await _getSnoozeConfig();
    final snoozeActions =
        (snoozeConfig['actions'] as List<Map<String, dynamic>>)
            .map((action) => AndroidNotificationAction(
                  action['id'] as String,
                  action['label'] as String,
                  showsUserInterface: false,
                  cancelNotification: true,
                ))
            .toList();

    return [
      AndroidNotificationAction(
        completeActionId,
        '✖️ Dismiss',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      ...snoozeActions,
    ];
  }

  static Future<void> refreshNotificationCategories() async {
    debugPrint(
        'Refreshing iOS notification categories for settings changes...');

    try {
      final snoozeConfig = await _getSnoozeConfig();
      final completeAction =
          DarwinNotificationAction.plain(completeActionId, '✖️ Dismiss');
      final snoozeActions =
          (snoozeConfig['actions'] as List<Map<String, dynamic>>)
              .map((action) => DarwinNotificationAction.plain(
                    action['id'] as String,
                    action['label'] as String,
                  ))
              .toList();

      final reminderCategory = DarwinNotificationCategory(
        'reminder_category',
        actions: <DarwinNotificationAction>[completeAction, ...snoozeActions],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      );

      // Reinitialize with updated categories
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false, // Don't re-request permissions
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [reminderCategory],
      );

      final initSettings =
          InitializationSettings(iOS: iosSettings, macOS: iosSettings);
      await _notifications.initialize(initSettings);

      debugPrint('iOS notification categories refreshed successfully');
    } catch (e) {
      debugPrint('Error refreshing iOS notification categories: $e');
    }
  }

  static Future<Duration> _getSnoozeDurationForAction(String actionId) async {
    final snoozeConfig = await _getSnoozeConfig();
    final actions = snoozeConfig['actions'] as List<Map<String, dynamic>>;

    for (final action in actions) {
      if (action['id'] == actionId) {
        return action['duration'] as Duration;
      }
    }

    debugPrint('Unknown snooze action ID: $actionId, defaulting to 10 minutes');
    return const Duration(minutes: 10);
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
        'Notification tapped: ${response.payload}, Action: ${response.actionId}');
    _handleNotificationAction(response);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('Background notification response received');
    debugPrint('Action: ${response.actionId}');
    debugPrint('Payload: ${response.payload}');
    _handleNotificationAction(response);
  }

  @pragma('vm:entry-point')
  static Future<void> _handleNotificationAction(
      NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    debugPrint('Processing notification action: $actionId');

    if (payload == null) return;

    try {
      await _ensureStorageInitialized();

      final parts = payload.split(':');
      final reminderId = parts[0];
      final timeSlotId = parts.length > 1 ? parts[1] : null;

      switch (actionId) {
        case completeActionId:
          debugPrint('Processing dismiss action');
          await _handleCompleteAction(reminderId, timeSlotId);
          break;
        case snoozeAction1Id:
        case snoozeAction2Id:
          debugPrint('Processing snooze action: $actionId');
          final snoozeDuration = await _getSnoozeDurationForAction(actionId!);
          await _handleSnoozeAction(reminderId, timeSlotId, snoozeDuration);
          break;
        default:
          debugPrint('Regular notification tap');
          break;
      }

      debugPrint('Notification action completed successfully');
    } catch (e) {
      debugPrint('Error handling notification action: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _forceMainAppUpdate() async {
    try {
      await StorageService.markNotificationUpdate();
      await Future.delayed(const Duration(milliseconds: 50));
      await StorageService.forceImmediateRefresh();
      debugPrint('Forced main app update complete');
    } catch (e) {
      debugPrint('Error forcing main app update: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _ensureStorageInitialized() async {
    try {
      debugPrint('Initializing services for background operation');

      tz.initializeTimeZones();
      debugPrint('Timezone initialized for background isolate');

      await StorageService.initialize();

      final reminders = await StorageService.getReminders();
      debugPrint(
          'Background StorageService initialized - found ${reminders.length} reminders');

      for (final reminder in reminders) {
        debugPrint('Available reminder: ${reminder.id} - ${reminder.title}');
      }
    } catch (e) {
      debugPrint('Failed to initialize services in background: $e');
      rethrow;
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _handleCompleteAction(
      String reminderId, String? timeSlotId) async {
    try {
      debugPrint('Processing dismiss action for reminder: $reminderId');

      final reminder = await StorageService.getReminderById(reminderId);
      if (reminder == null) {
        debugPrint('Cannot dismiss - reminder not found: $reminderId');
        return;
      }

      final notificationId = timeSlotId != null
          ? generateTimeSlotNotificationId(reminderId, timeSlotId)
          : reminderId.hashCode;
      await _notifications.cancel(notificationId);

      if (timeSlotId != null) {
        await StorageService.updateTimeSlotStatus(
            reminderId, timeSlotId, ReminderStatus.completed);
        debugPrint('Dismissed/completed time slot $timeSlotId');
      } else {
        await StorageService.updateReminderStatus(
            reminderId, ReminderStatus.completed);
        debugPrint('Dismissed/completed reminder $reminderId');
      }

      await _forceMainAppUpdate();

      debugPrint('Dismiss action completed successfully');
    } catch (e) {
      debugPrint('Error dismissing reminder: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _handleSnoozeAction(
      String reminderId, String? timeSlotId, Duration snoozeDuration) async {
    try {
      debugPrint('Starting snooze action for reminder: $reminderId');
      debugPrint('Snooze duration: ${snoozeDuration.inMinutes} minutes');

      final reminder = await StorageService.getReminderById(reminderId);
      if (reminder == null) {
        debugPrint('Cannot snooze - reminder not found: $reminderId');
        return;
      }
      debugPrint('Found reminder: ${reminder.title}');

      final currentNotificationId = timeSlotId != null
          ? generateTimeSlotNotificationId(reminderId, timeSlotId)
          : reminderId.hashCode;
      await _notifications.cancel(currentNotificationId);
      debugPrint('Cancelled current notification: $currentNotificationId');

      final snoozeTime = DateTime.now().add(snoozeDuration);
      debugPrint('New snooze time: $snoozeTime');

      if (timeSlotId != null && reminder.hasMultipleTimes) {
        debugPrint('Processing multi-time reminder snooze');
        final timeSlot = reminder.timeSlots.firstWhere(
          (slot) => slot.id == timeSlotId,
          orElse: () => throw Exception('Time slot not found'),
        );

        final snoozedTimeSlot = timeSlot.copyWith(
          time: TimeOfDay(hour: snoozeTime.hour, minute: snoozeTime.minute),
        );

        await StorageService.updateTimeSlot(
            reminderId, timeSlotId, snoozedTimeSlot);
        debugPrint('Updated time slot in storage');

        await _scheduleTimeSlotNotification(
          reminder: reminder.copyWith(
              timeSlots: reminder.timeSlots
                  .map((slot) => slot.id == timeSlotId ? snoozedTimeSlot : slot)
                  .toList()),
          timeSlot: snoozedTimeSlot,
          scheduledTime: snoozeTime,
        );

        debugPrint('Snoozed time slot for ${snoozeDuration.inMinutes}min');
      } else {
        debugPrint('Processing single-time reminder snooze');
        final snoozedReminder = reminder.copyWith(scheduledTime: snoozeTime);
        await StorageService.updateReminder(snoozedReminder);
        debugPrint('Updated reminder in storage');

        await _scheduleSingleTimeReminder(snoozedReminder);
        debugPrint('Scheduled new notification');

        debugPrint('Snoozed reminder for ${snoozeDuration.inMinutes}min');
      }

      await _forceMainAppUpdate();
      debugPrint('Snooze action completed successfully');
    } catch (e) {
      debugPrint('Error snoozing reminder: $e');
      debugPrint('Error details: ${e.toString()}');
    }
  }

  static Future<void> scheduleReminder(Reminder reminder) async {
    try {
      if (!reminder.isNotificationEnabled) {
        debugPrint('Skipping reminder scheduling - notifications disabled');
        return;
      }

      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();

      if (useAlarm) {
        debugPrint(
            'User chose MIXED MODE - scheduling both alarm and notification');

        // Schedule alarm for full-screen when app inactive/phone locked
        if (reminder.hasMultipleTimes) {
          await AlarmService.setMultiTimeAlarmReminder(reminder);
        } else {
          await AlarmService.setAlarmReminder(reminder);
        }

        // Schedule notification for when other apps are active
        if (reminder.hasMultipleTimes) {
          await _scheduleMixedModeMultiTimeReminder(reminder);
        } else {
          await _scheduleMixedModeNotification(reminder: reminder);
        }

        debugPrint('Mixed mode scheduling completed for: ${reminder.title}');
        return;
      } else {
        debugPrint(
            'User chose NOTIFICATION mode - scheduling notification only');
        if (reminder.hasMultipleTimes) {
          await _scheduleMultiTimeReminder(reminder);
        } else {
          await _scheduleSingleTimeReminder(reminder);
        }
        return;
      }
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  static Future<void> _scheduleMultiTimeReminder(Reminder reminder) async {
    debugPrint('Scheduling multi-time reminder: ${reminder.title}');
    debugPrint('Time slots count: ${reminder.timeSlots.length}');

    for (int i = 0; i < reminder.timeSlots.length; i++) {
      final timeSlot = reminder.timeSlots[i];
      debugPrint(
          'Processing time slot $i: ${timeSlot.formattedTime} (${timeSlot.status})');

      if (timeSlot.status != ReminderStatus.pending) {
        debugPrint('Skipping non-pending time slot');
        continue;
      }

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
          debugPrint(
              'Time has passed, scheduling for tomorrow: $notificationTime');
        } else {
          debugPrint('Time has passed and no daily repeat, skipping');
          continue;
        }
      }

      await _scheduleTimeSlotNotification(
        reminder: reminder,
        timeSlot: timeSlot,
        scheduledTime: notificationTime,
      );

      debugPrint(
          'Scheduled notification for time slot: ${timeSlot.formattedTime}');
    }

    debugPrint('Completed scheduling multi-time reminder');
  }

  static Future<void> _scheduleTimeSlotNotification({
    required Reminder reminder,
    required TimeSlot timeSlot,
    required DateTime scheduledTime,
  }) async {
    final notificationId =
        generateTimeSlotNotificationId(reminder.id, timeSlot.id);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Notifications for scheduled reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: const BigTextStyleInformation(''),
      actions: await _buildAndroidNotificationActions(),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'reminder_category',
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final title = reminder.title;
    final body = timeSlot.description?.isNotEmpty == true
        ? '${timeSlot.formattedTime} - ${timeSlot.description}'
        : '${timeSlot.formattedTime} reminder';

    final payload = '${reminder.id}:${timeSlot.id}';

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      _convertToTZDateTime(scheduledTime),
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: _getMatchDateTimeComponents(reminder.repeatType),
    );

    debugPrint(
        'Scheduled time slot notification: ID $notificationId, Time: $scheduledTime');
  }

  static Future<void> _scheduleSingleTimeReminder(Reminder reminder) async {
    try {
      final now = DateTime.now();

      if (reminder.scheduledTime
          .isBefore(now.subtract(const Duration(minutes: 5)))) {
        debugPrint(
            'Skipping notification for reminder ${reminder.id} - time is ${reminder.scheduledTime}, which is too far in the past');
        return;
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'reminder_channel',
        'Reminders',
        channelDescription: 'Notifications for scheduled reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: const BigTextStyleInformation(''),
        actions: await _buildAndroidNotificationActions(),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'reminder_category',
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        reminder.id.hashCode,
        reminder.title,
        reminder.description ?? 'Reminder notification',
        _convertToTZDateTime(reminder.scheduledTime),
        notificationDetails,
        payload: reminder.id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents:
            _getMatchDateTimeComponents(reminder.repeatType),
      );

      debugPrint('Scheduled notification for ${reminder.title}');
    } catch (e) {
      debugPrint('Error scheduling single-time reminder ${reminder.id}: $e');
    }
  }

  static Future<void> _scheduleMixedModeNotification({
    required Reminder reminder,
    TimeSlot? timeSlot,
    DateTime? scheduledTime,
  }) async {
    try {
      final now = DateTime.now();
      final finalScheduledTime = scheduledTime ?? reminder.scheduledTime;

      if (finalScheduledTime
          .isBefore(now.subtract(const Duration(minutes: 5)))) {
        debugPrint('Skipping mixed mode notification - time too far in past');
        return;
      }

      final notificationId = timeSlot != null
          ? generateTimeSlotNotificationId(reminder.id, timeSlot.id)
          : reminder.id.hashCode;

      // Use ALARM sound instead of notification sound for mixed mode
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'mixed_mode_channel', // Different channel for mixed mode
        'Mixed Mode Alarms',
        channelDescription: 'Alarm-sound notifications for mixed mode',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: const BigTextStyleInformation(''),
        actions: await _buildAndroidNotificationActions(),
        // Use alarm sound instead of default notification sound
        sound: const RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        enableLights: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'reminder_category',
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      final title = reminder.title;
      final body = timeSlot != null
          ? (timeSlot.description?.isNotEmpty == true
              ? '${timeSlot.formattedTime} - ${timeSlot.description}'
              : '${timeSlot.formattedTime} reminder')
          : (reminder.description ?? 'Mixed mode alarm reminder');

      final payload =
          timeSlot != null ? '${reminder.id}:${timeSlot.id}' : reminder.id;

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        _convertToTZDateTime(finalScheduledTime),
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents:
            _getMatchDateTimeComponents(reminder.repeatType),
      );

      debugPrint(
          'Scheduled mixed mode notification: ID $notificationId, Time: $finalScheduledTime');
    } catch (e) {
      debugPrint('Error scheduling mixed mode notification: $e');
    }
  }

  static Future<void> _scheduleMixedModeMultiTimeReminder(
      Reminder reminder) async {
    debugPrint('Scheduling mixed mode multi-time reminder: ${reminder.title}');

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

      await _scheduleMixedModeNotification(
        reminder: reminder,
        timeSlot: timeSlot,
        scheduledTime: notificationTime,
      );
    }
  }

  static Future<void> cancelReminder(String reminderId) async {
    try {
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();

      if (useAlarm) {
        debugPrint('Alarm mode - cancelling alarm only');
        await AlarmService.stopAlarm(reminderId);

        final reminder = await StorageService.getReminderById(reminderId);
        if (reminder != null && reminder.hasMultipleTimes) {
          for (final timeSlot in reminder.timeSlots) {
            await AlarmService.stopAlarm(reminderId, timeSlotId: timeSlot.id);
          }
        }
      } else {
        debugPrint('Notification mode - cancelling notifications only');
        await _notifications.cancel(reminderId.hashCode);

        final reminder = await StorageService.getReminderById(reminderId);
        if (reminder != null && reminder.hasMultipleTimes) {
          for (final timeSlot in reminder.timeSlots) {
            final notificationId =
                generateTimeSlotNotificationId(reminderId, timeSlot.id);
            await _notifications.cancel(notificationId);
          }
        }
      }

      debugPrint('Cancelled for: $reminderId');
    } catch (e) {
      debugPrint('Error cancelling reminder: $e');
    }
  }

  static Future<void> cancelTimeSlotNotification(
      String reminderId, String timeSlotId) async {
    final notificationId =
        generateTimeSlotNotificationId(reminderId, timeSlotId);
    await _notifications.cancel(notificationId);
  }

  static Future<void> cancelNotification(int notificationId) async {
    try {
      await _notifications.cancel(notificationId);
      debugPrint('🔕 Canceled notification ID: $notificationId');
    } catch (e) {
      debugPrint('⚠️ Error canceling notification ID $notificationId: $e');
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

  static Future<void> scheduleTimeSlotNotifications(
      Reminder reminder, List<TimeSlot> pendingSlots) async {
    if (!reminder.isNotificationEnabled) return;

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
  }

  static int generateTimeSlotNotificationId(
      String reminderId, String timeSlotId) {
    final combined = '$reminderId:$timeSlotId';
    return combined.hashCode.abs();
  }

  static Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  static tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  static DateTimeComponents? _getMatchDateTimeComponents(
      RepeatType repeatType) {
    switch (repeatType) {
      case RepeatType.daily:
        return DateTimeComponents.time;
      case RepeatType.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case RepeatType.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case RepeatType.none:
        return null;
    }
  }

  static Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'immediate_channel',
      'Immediate Notifications',
      channelDescription: 'Immediate notifications for testing',
      importance: Importance.high,
      priority: Priority.high,
      actions: await _buildAndroidNotificationActions(),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'reminder_category',
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  static Future<void> testMultiTimeNotification(Reminder reminder) async {
    if (!reminder.hasMultipleTimes) return;

    for (int i = 0; i < reminder.timeSlots.length; i++) {
      final timeSlot = reminder.timeSlots[i];
      if (timeSlot.status == ReminderStatus.pending) {
        final testTime = DateTime.now().add(Duration(seconds: 5 + (i * 2)));

        await _scheduleTimeSlotNotification(
          reminder: reminder,
          timeSlot: timeSlot,
          scheduledTime: testTime,
        );
      }
    }
  }

  static Future<int> getScheduledNotificationsCount() async {
    final pendingNotifications =
        await _notifications.pendingNotificationRequests();
    return pendingNotifications.length;
  }

  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static Future<void> refreshAllNotifications(
      List<Reminder> allReminders) async {
    await cancelAllReminders();

    for (final reminder in allReminders) {
      if (reminder.isNotificationEnabled) {
        await scheduleReminder(reminder);
      }
    }
  }
}
