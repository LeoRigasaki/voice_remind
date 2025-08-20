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

  // Action IDs for notification buttons
  static const String completeActionId = 'complete_action';
  static const String snoozeAction1Id = 'snooze_action_1';
  static const String snoozeAction2Id = 'snooze_action_2';

  static Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS notification categories with actions
    final DarwinNotificationAction completeAction =
        DarwinNotificationAction.plain(
      completeActionId,
      '✖️ Dismiss', // Changed from "Complete"
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

    // iOS initialization with categories
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

    // Request permissions
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    // Request permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request permissions for iOS
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Get user's snooze configuration
  static Future<Map<String, dynamic>> _getSnoozeConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final useCustom = prefs.getBool('snooze_use_custom') ?? false;
      final customMinutes = prefs.getInt('snooze_custom_minutes') ?? 15;

      if (useCustom) {
        // Smart second option based on custom duration
        String secondLabel;
        Duration secondDuration;

        if (customMinutes <= 30) {
          // If custom is 30min or less, offer 1 hour
          secondLabel = '1hour';
          secondDuration = const Duration(hours: 1);
        } else if (customMinutes <= 60) {
          // If custom is 31-60min, offer 2 hours
          secondLabel = '2hours';
          secondDuration = const Duration(hours: 2);
        } else {
          // If custom is over 60min, offer half the custom duration as shorter option
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
      debugPrint('❌ Error getting snooze config: $e');
      // Fallback to default
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

  // Build dynamic Android notification actions based on user preferences
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
      // Use "Dismiss" instead of "Complete" for alarm notifications
      AndroidNotificationAction(
        completeActionId,
        '✖️ Dismiss', // Changed from "Complete"
        showsUserInterface: false,
        cancelNotification: true,
      ),
      ...snoozeActions,
    ];
  }

  static Future<Duration> _getSnoozeDurationForAction(String actionId) async {
    final snoozeConfig = await _getSnoozeConfig();
    final actions = snoozeConfig['actions'] as List<Map<String, dynamic>>;

    for (final action in actions) {
      if (action['id'] == actionId) {
        return action['duration'] as Duration;
      }
    }

    // Fallback to 10 minutes if action not found
    debugPrint(
        '⚠️ Unknown snooze action ID: $actionId, defaulting to 10 minutes');
    return const Duration(minutes: 10);
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
        'Notification tapped: ${response.payload}, Action: ${response.actionId}');
    _handleNotificationAction(response);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('🌙 Background notification response received');
    debugPrint('🌙 Action: ${response.actionId}');
    debugPrint('🌙 Payload: ${response.payload}');
    _handleNotificationAction(response);
  }

  /// Handle notification actions (Complete, Snooze, etc.)
  @pragma('vm:entry-point')
  static Future<void> _handleNotificationAction(
      NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    debugPrint('🔔 Processing notification action: $actionId');

    if (payload == null) return;

    try {
      await _ensureStorageInitialized();

      final parts = payload.split(':');
      final reminderId = parts[0];
      final timeSlotId = parts.length > 1 ? parts[1] : null;

      switch (actionId) {
        case completeActionId:
          debugPrint('✖️ Processing dismiss action');
          await _handleCompleteAction(reminderId, timeSlotId);
          break;
        case snoozeAction1Id:
        case snoozeAction2Id:
          debugPrint('⏰ Processing snooze action: $actionId');
          final snoozeDuration = await _getSnoozeDurationForAction(actionId!);
          await _handleSnoozeAction(reminderId, timeSlotId, snoozeDuration);
          break;
        default:
          debugPrint('👆 Regular notification tap');
          break;
      }

      debugPrint('🔔 Notification action completed successfully');
    } catch (e) {
      debugPrint('⚠️ Error handling notification action: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _forceMainAppUpdate() async {
    try {
      await StorageService.markNotificationUpdate();
      await Future.delayed(const Duration(milliseconds: 50));
      await StorageService.forceImmediateRefresh();
      debugPrint('🔄 Forced main app update complete');
    } catch (e) {
      debugPrint('⚠️ Error forcing main app update: $e');
    }
  }

  /// Ensure StorageService is properly initialized for background operations
  @pragma('vm:entry-point')
  static Future<void> _ensureStorageInitialized() async {
    try {
      debugPrint('📱 Initializing services for background operation');

      // Initialize timezone database for background isolate
      tz.initializeTimeZones();
      debugPrint('📱 Timezone initialized for background isolate');

      // Always reinitialize StorageService in background isolate to ensure fresh connection
      await StorageService.initialize();

      // Verify we can access data
      final reminders = await StorageService.getReminders();
      debugPrint(
          '📱 Background StorageService initialized - found ${reminders.length} reminders');

      // Debug: List all reminder IDs for verification
      for (final reminder in reminders) {
        debugPrint('📱 Available reminder: ${reminder.id} - ${reminder.title}');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize services in background: $e');
      rethrow;
    }
  }

  /// Handle Complete action
  @pragma('vm:entry-point')
  static Future<void> _handleCompleteAction(
      String reminderId, String? timeSlotId) async {
    try {
      debugPrint('✖️ Processing dismiss action for reminder: $reminderId');

      final reminder = await StorageService.getReminderById(reminderId);
      if (reminder == null) {
        debugPrint('⚠️ Cannot dismiss - reminder not found: $reminderId');
        return;
      }

      // Cancel the notification first
      final notificationId = timeSlotId != null
          ? _generateTimeSlotNotificationId(reminderId, timeSlotId)
          : reminderId.hashCode;
      await _notifications.cancel(notificationId);

      if (timeSlotId != null) {
        // Multi-time reminder - complete specific time slot
        await StorageService.updateTimeSlotStatus(
            reminderId, timeSlotId, ReminderStatus.completed);
        debugPrint('✅ Dismissed/completed time slot $timeSlotId');
      } else {
        // Single-time reminder - complete entire reminder
        await StorageService.updateReminderStatus(
            reminderId, ReminderStatus.completed);
        debugPrint('✅ Dismissed/completed reminder $reminderId');
      }

      // CRITICAL: Force immediate update
      await _forceMainAppUpdate();

      debugPrint('✅ Dismiss action completed successfully');
    } catch (e) {
      debugPrint('⚠️ Error dismissing reminder: $e');
    }
  }

  /// Handle Snooze action
  @pragma('vm:entry-point')
  static Future<void> _handleSnoozeAction(
      String reminderId, String? timeSlotId, Duration snoozeDuration) async {
    try {
      debugPrint('Starting snooze action for reminder: $reminderId');
      debugPrint('Snooze duration: ${snoozeDuration.inMinutes} minutes');

      // Verify reminder exists before proceeding
      final reminder = await StorageService.getReminderById(reminderId);
      if (reminder == null) {
        debugPrint('❌ Cannot snooze - reminder not found: $reminderId');
        return;
      }
      debugPrint('Found reminder: ${reminder.title}');

      // Cancel current notification first
      final currentNotificationId = timeSlotId != null
          ? _generateTimeSlotNotificationId(reminderId, timeSlotId)
          : reminderId.hashCode;
      await _notifications.cancel(currentNotificationId);
      debugPrint('Cancelled current notification: $currentNotificationId');

      // Calculate new time
      final snoozeTime = DateTime.now().add(snoozeDuration);
      debugPrint('New snooze time: $snoozeTime');

      if (timeSlotId != null && reminder.hasMultipleTimes) {
        debugPrint('Processing multi-time reminder snooze');
        // Multi-time reminder - snooze specific time slot
        final timeSlot = reminder.timeSlots.firstWhere(
          (slot) => slot.id == timeSlotId,
          orElse: () => throw Exception('Time slot not found'),
        );

        // Create new time slot with snoozed time
        final snoozedTimeSlot = timeSlot.copyWith(
          time: TimeOfDay(hour: snoozeTime.hour, minute: snoozeTime.minute),
        );

        // Update the time slot
        await StorageService.updateTimeSlot(
            reminderId, timeSlotId, snoozedTimeSlot);
        debugPrint('Updated time slot in storage');

        // Schedule new notification for snoozed time
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
        // Single-time reminder - snooze entire reminder
        final snoozedReminder = reminder.copyWith(scheduledTime: snoozeTime);
        await StorageService.updateReminder(snoozedReminder);
        debugPrint('Updated reminder in storage');

        // Schedule new notification for snoozed time
        await _scheduleSingleTimeReminder(snoozedReminder);
        debugPrint('Scheduled new notification');

        debugPrint('Snoozed reminder for ${snoozeDuration.inMinutes}min');
      }

      debugPrint('Snooze action completed successfully');
    } catch (e) {
      debugPrint('❌ Error snoozing reminder: $e');
      debugPrint('❌ Error details: ${e.toString()}');
    }
  }

  /// Schedule reminder notifications or alarms based on user preference
  static Future<void> scheduleReminder(Reminder reminder) async {
    try {
      if (!reminder.isNotificationEnabled) {
        debugPrint('⚠️ Skipping reminder scheduling - notifications disabled');
        return;
      }

      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();

      if (useAlarm) {
        debugPrint(
            '⏰ User chose ALARM mode - ONLY scheduling alarm, NO notification');
        if (reminder.hasMultipleTimes) {
          await AlarmService.setMultiTimeAlarmReminder(reminder);
        } else {
          await AlarmService.setAlarmReminder(reminder);
        }
        // CRITICAL: Return here - don't schedule any notification
        return;
      } else {
        debugPrint(
            '🔔 User chose NOTIFICATION mode - ONLY scheduling notification, NO alarm');
        if (reminder.hasMultipleTimes) {
          await _scheduleMultiTimeReminder(reminder);
        } else {
          await _scheduleSingleTimeReminder(reminder);
        }
        // CRITICAL: Return here - don't schedule any alarm
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Error scheduling reminder: $e');
    }
  }

  /// Schedule notifications for multi-time reminder
  static Future<void> _scheduleMultiTimeReminder(Reminder reminder) async {
    for (final timeSlot in reminder.timeSlots) {
      // Only schedule for pending time slots
      if (timeSlot.status != ReminderStatus.pending) {
        continue;
      }

      // Create notification time for today (or next occurrence if time has passed)
      final now = DateTime.now();
      DateTime notificationTime = DateTime(
        now.year,
        now.month,
        now.day,
        timeSlot.time.hour,
        timeSlot.time.minute,
      );

      // If time has passed today, schedule for tomorrow (if daily repeat) or skip
      if (notificationTime.isBefore(now)) {
        if (reminder.repeatType == RepeatType.daily) {
          notificationTime = notificationTime.add(const Duration(days: 1));
        } else {
          continue; // Skip this time slot if it's already passed and not repeating
        }
      }

      await _scheduleTimeSlotNotification(
        reminder: reminder,
        timeSlot: timeSlot,
        scheduledTime: notificationTime,
      );
    }
  }

  /// Schedule notification for a specific time slot
  static Future<void> _scheduleTimeSlotNotification({
    required Reminder reminder,
    required TimeSlot timeSlot,
    required DateTime scheduledTime,
  }) async {
    // Create unique notification ID combining reminder ID and time slot ID
    final notificationId =
        _generateTimeSlotNotificationId(reminder.id, timeSlot.id);

    // Create Android notification with action buttons
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

    // Create iOS notification with category
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

    // Create notification title and body
    final title = reminder.title;
    final body = timeSlot.description?.isNotEmpty == true
        ? '${timeSlot.formattedTime} - ${timeSlot.description}'
        : '${timeSlot.formattedTime} reminder';

    // Create payload with reminder ID and time slot ID
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
  }

  /// Schedule notification for single-time reminder (backward compatibility)
  static Future<void> _scheduleSingleTimeReminder(Reminder reminder) async {
    try {
      final now = DateTime.now();

      // For editing/updating reminders, be more lenient with past times
      // Only skip if the time is more than 5 minutes in the past (to handle editing overdue reminders)
      if (reminder.scheduledTime
          .isBefore(now.subtract(const Duration(minutes: 5)))) {
        debugPrint(
            '⚠️ Skipping notification for reminder ${reminder.id} - time is ${reminder.scheduledTime}, which is too far in the past');
        return;
      }

      // Create Android notification with action buttons
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

      // Create iOS notification with category
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
        reminder.id.hashCode, // Use hashCode as unique int ID
        reminder.title,
        reminder.description ?? 'Reminder notification',
        _convertToTZDateTime(reminder.scheduledTime),
        notificationDetails,
        payload: reminder.id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents:
            _getMatchDateTimeComponents(reminder.repeatType),
      );

      debugPrint('📅 Scheduled notification for ${reminder.title}');
    } catch (e) {
      debugPrint('❌ Error scheduling single-time reminder ${reminder.id}: $e');
      // Don't rethrow - allow the save operation to continue
    }
  }

  /// Cancel all notifications/alarms for a reminder
  static Future<void> cancelReminder(String reminderId) async {
    try {
      final useAlarm = await StorageService.getUseAlarmInsteadOfNotification();

      if (useAlarm) {
        debugPrint('⏰ Alarm mode - cancelling alarm ONLY');
        await AlarmService.stopAlarm(reminderId);
      } else {
        debugPrint('🔔 Notification mode - cancelling notifications ONLY');
        await _notifications.cancel(reminderId.hashCode);

        // Cancel multi-time notifications
        for (int i = 0; i < 24; i++) {
          final potentialId =
              _generateTimeSlotNotificationId(reminderId, 'slot_$i');
          await _notifications.cancel(potentialId);
        }
      }

      debugPrint('🗑️ Cancelled for: $reminderId');
    } catch (e) {
      debugPrint('⚠️ Error cancelling reminder: $e');
    }
  }

  /// Cancel specific time slot notification
  static Future<void> cancelTimeSlotNotification(
      String reminderId, String timeSlotId) async {
    final notificationId =
        _generateTimeSlotNotificationId(reminderId, timeSlotId);
    await _notifications.cancel(notificationId);
  }

  /// Update notifications/alarms for a reminder (reschedule)
  static Future<void> updateReminderNotifications(Reminder reminder) async {
    try {
      // Cancel existing notifications/alarms first
      await cancelReminder(reminder.id);

      // Reschedule with updated information using the current mode
      await scheduleReminder(reminder);
    } catch (e) {
      debugPrint(
          '❌ Error updating notifications/alarms for reminder ${reminder.id}: $e');
      // Don't rethrow - allow reminder update to continue even if notification update fails
    }
  }

  /// Schedule notifications only for pending time slots
  static Future<void> scheduleTimeSlotNotifications(
      Reminder reminder, List<TimeSlot> pendingSlots) async {
    if (!reminder.isNotificationEnabled) return;

    for (final timeSlot in pendingSlots) {
      if (timeSlot.status == ReminderStatus.pending) {
        final now = DateTime.now();
        DateTime notificationTime = DateTime(
          now.year,
          now.month,
          now.day,
          timeSlot.time.hour,
          timeSlot.time.minute,
        );

        // If time has passed today, schedule for tomorrow (if daily repeat)
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

  /// Generate unique notification ID for time slot
  static int _generateTimeSlotNotificationId(
      String reminderId, String timeSlotId) {
    // Combine reminder ID and time slot ID to create unique notification ID
    final combined = '$reminderId:$timeSlotId';
    return combined.hashCode;
  }

  /// Cancel all reminders
  static Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  /// Helper method to convert DateTime to TZDateTime
  static tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Helper method to get repeat matching components
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

  /// Show immediate notification (for testing)
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

  /// Test multi-time notification (for development)
  static Future<void> testMultiTimeNotification(Reminder reminder) async {
    if (!reminder.hasMultipleTimes) return;

    for (int i = 0; i < reminder.timeSlots.length; i++) {
      final timeSlot = reminder.timeSlots[i];
      if (timeSlot.status == ReminderStatus.pending) {
        // Schedule test notification 5 seconds from now for each slot
        final testTime = DateTime.now().add(Duration(seconds: 5 + (i * 2)));

        await _scheduleTimeSlotNotification(
          reminder: reminder,
          timeSlot: timeSlot,
          scheduledTime: testTime,
        );
      }
    }
  }

  /// Get scheduled notifications count (for debugging)
  static Future<int> getScheduledNotificationsCount() async {
    final pendingNotifications =
        await _notifications.pendingNotificationRequests();
    return pendingNotifications.length;
  }

  /// Get all pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Clear all scheduled notifications and restart
  static Future<void> refreshAllNotifications(
      List<Reminder> allReminders) async {
    // Cancel all existing notifications
    await cancelAllReminders();

    // Reschedule all active reminders
    for (final reminder in allReminders) {
      if (reminder.isNotificationEnabled) {
        await scheduleReminder(reminder);
      }
    }
  }
}
