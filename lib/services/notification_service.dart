import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Action IDs for notification buttons
  static const String completeActionId = 'complete_action';
  static const String snooze10ActionId = 'snooze_10m_action';
  static const String snooze1hActionId = 'snooze_1h_action';

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
      '✓ Complete',
    );

    final DarwinNotificationAction snooze10Action =
        DarwinNotificationAction.plain(
      snooze10ActionId,
      '⏰ 10min',
    );

    final DarwinNotificationAction snooze1hAction =
        DarwinNotificationAction.plain(
      snooze1hActionId,
      '⏰ 1hour',
    );

    final DarwinNotificationCategory reminderCategory =
        DarwinNotificationCategory(
      'reminder_category',
      actions: <DarwinNotificationAction>[
        completeAction,
        snooze10Action,
        snooze1hAction,
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

    debugPrint('🔔 Processing notification action');
    debugPrint('🔔 Action ID: $actionId');
    debugPrint('🔔 Payload: $payload');

    if (payload == null) {
      debugPrint('⚠️ No payload found in notification response');
      return;
    }

    try {
      // Ensure StorageService is properly initialized for background operations
      await _ensureStorageInitialized();

      // Parse payload format: "reminderId:timeSlotId" or just "reminderId"
      final parts = payload.split(':');
      final reminderId = parts[0];
      final timeSlotId = parts.length > 1 ? parts[1] : null;

      debugPrint(
          '🔔 Parsed - ReminderId: $reminderId, TimeSlotId: $timeSlotId');

      switch (actionId) {
        case completeActionId:
          debugPrint('✅ Calling Complete action');
          await _handleCompleteAction(reminderId, timeSlotId);
          break;
        case snooze10ActionId:
          debugPrint('⏰ Calling Snooze 10min action');
          await _handleSnoozeAction(
              reminderId, timeSlotId, const Duration(minutes: 10));
          break;
        case snooze1hActionId:
          debugPrint('⏰ Calling Snooze 1hour action');
          await _handleSnoozeAction(
              reminderId, timeSlotId, const Duration(hours: 1));
          break;
        default:
          debugPrint('👆 Regular notification tap for reminder: $reminderId');
          break;
      }

      // CRITICAL: Mark notification update for main isolate detection
      await StorageService.markNotificationUpdate();

      // Additional step: Force refresh the storage data immediately
      await StorageService.refreshData();

      debugPrint('🔔 Notification action completed successfully');
    } catch (e) {
      debugPrint('❌ Error handling notification action: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
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
      debugPrint('✅ Starting complete action for reminder: $reminderId');

      // Verify reminder exists before proceeding
      final reminder = await StorageService.getReminderById(reminderId);
      if (reminder == null) {
        debugPrint('❌ Cannot complete - reminder not found: $reminderId');
        return;
      }
      debugPrint('✅ Found reminder: ${reminder.title}');

      // Cancel the notification first
      final notificationId = timeSlotId != null
          ? _generateTimeSlotNotificationId(reminderId, timeSlotId)
          : reminderId.hashCode;
      await _notifications.cancel(notificationId);
      debugPrint('✅ Cancelled notification: $notificationId');

      if (timeSlotId != null) {
        // Multi-time reminder - complete specific time slot
        await StorageService.updateTimeSlotStatus(
            reminderId, timeSlotId, ReminderStatus.completed);
        debugPrint('✅ Completed time slot $timeSlotId');
      } else {
        // Single-time reminder - complete entire reminder
        await StorageService.updateReminderStatus(
            reminderId, ReminderStatus.completed);
        debugPrint('✅ Completed reminder $reminderId');
      }

      debugPrint('✅ Complete action finished successfully');
    } catch (e) {
      debugPrint('❌ Error completing reminder: $e');
    }
  }

  /// Handle Snooze action
  @pragma('vm:entry-point')
  static Future<void> _handleSnoozeAction(
      String reminderId, String? timeSlotId, Duration snoozeDuration) async {
    try {
      debugPrint('⏰ Starting snooze action for reminder: $reminderId');
      debugPrint('⏰ Snooze duration: ${snoozeDuration.inMinutes} minutes');

      // Verify reminder exists before proceeding
      final reminder = await StorageService.getReminderById(reminderId);
      if (reminder == null) {
        debugPrint('❌ Cannot snooze - reminder not found: $reminderId');
        return;
      }
      debugPrint('⏰ Found reminder: ${reminder.title}');

      // Cancel current notification first
      final currentNotificationId = timeSlotId != null
          ? _generateTimeSlotNotificationId(reminderId, timeSlotId)
          : reminderId.hashCode;
      await _notifications.cancel(currentNotificationId);
      debugPrint('⏰ Cancelled current notification: $currentNotificationId');

      // Calculate new time
      final snoozeTime = DateTime.now().add(snoozeDuration);
      debugPrint('⏰ New snooze time: $snoozeTime');

      if (timeSlotId != null && reminder.hasMultipleTimes) {
        debugPrint('⏰ Processing multi-time reminder snooze');
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
        debugPrint('⏰ Updated time slot in storage');

        // Schedule new notification for snoozed time
        await _scheduleTimeSlotNotification(
          reminder: reminder.copyWith(
              timeSlots: reminder.timeSlots
                  .map((slot) => slot.id == timeSlotId ? snoozedTimeSlot : slot)
                  .toList()),
          timeSlot: snoozedTimeSlot,
          scheduledTime: snoozeTime,
        );

        debugPrint('⏰ Snoozed time slot for ${snoozeDuration.inMinutes}min');
      } else {
        debugPrint('⏰ Processing single-time reminder snooze');
        // Single-time reminder - snooze entire reminder
        final snoozedReminder = reminder.copyWith(scheduledTime: snoozeTime);
        await StorageService.updateReminder(snoozedReminder);
        debugPrint('⏰ Updated reminder in storage');

        // Schedule new notification for snoozed time
        await _scheduleSingleTimeReminder(snoozedReminder);
        debugPrint('⏰ Scheduled new notification');

        debugPrint('⏰ Snoozed reminder for ${snoozeDuration.inMinutes}min');
      }

      debugPrint('⏰ Snooze action completed successfully');
    } catch (e) {
      debugPrint('❌ Error snoozing reminder: $e');
      debugPrint('❌ Error details: ${e.toString()}');
    }
  }

  /// Schedule reminder notifications (handles both single and multi-time)
  static Future<void> scheduleReminder(Reminder reminder) async {
    try {
      // Don't schedule if notification is disabled
      if (!reminder.isNotificationEnabled) {
        debugPrint(
            '⚠️ Skipping notification scheduling - notifications disabled for ${reminder.id}');
        return;
      }

      if (reminder.hasMultipleTimes) {
        // Schedule notifications for each time slot
        await _scheduleMultiTimeReminder(reminder);
      } else {
        // Schedule single notification (backward compatibility)
        await _scheduleSingleTimeReminder(reminder);
      }
    } catch (e) {
      debugPrint('❌ Error scheduling reminder ${reminder.id}: $e');
      // Don't rethrow - allow reminder saving to continue even if notification scheduling fails
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
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Notifications for scheduled reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          completeActionId,
          '✓ Complete',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          snooze10ActionId,
          '⏰ 10min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          snooze1hActionId,
          '⏰ 1hour',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    // Create iOS notification with category
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'reminder_category',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
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
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'reminder_channel',
        'Reminders',
        channelDescription: 'Notifications for scheduled reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            completeActionId,
            '✓ Complete',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            snooze10ActionId,
            '⏰ 10min',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            snooze1hActionId,
            '⏰ 1hour',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      // Create iOS notification with category
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'reminder_category',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
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

  /// Cancel all notifications for a reminder
  static Future<void> cancelReminder(String reminderId) async {
    try {
      // For single-time reminders, cancel using the reminder ID
      await _notifications.cancel(reminderId.hashCode);

      // For multi-time reminders, we need to cancel each time slot notification
      // Since we don't have access to the reminder object here, we'll use a range approach
      // This is a limitation - ideally we'd pass the reminder object or time slot IDs

      // Cancel potential multi-time notifications (using ID range)
      for (int i = 0; i < 24; i++) {
        // Max 24 time slots per day
        final potentialId =
            _generateTimeSlotNotificationId(reminderId, 'slot_$i');
        await _notifications.cancel(potentialId);
      }
    } catch (e) {
      debugPrint(
          '❌ Error cancelling notifications for reminder $reminderId: $e');
      // Don't rethrow - allow the operation to continue
    }
  }

  /// Cancel specific time slot notification
  static Future<void> cancelTimeSlotNotification(
      String reminderId, String timeSlotId) async {
    final notificationId =
        _generateTimeSlotNotificationId(reminderId, timeSlotId);
    await _notifications.cancel(notificationId);
  }

  /// Update notifications for a reminder (reschedule)
  static Future<void> updateReminderNotifications(Reminder reminder) async {
    try {
      // Cancel existing notifications first
      await cancelReminder(reminder.id);

      // Reschedule with updated information
      await scheduleReminder(reminder);
    } catch (e) {
      debugPrint(
          '❌ Error updating notifications for reminder ${reminder.id}: $e');
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
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'immediate_channel',
      'Immediate Notifications',
      channelDescription: 'Immediate notifications for testing',
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          completeActionId,
          '✓ Complete',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          snooze10ActionId,
          '⏰ 10min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          snooze1hActionId,
          '⏰ 1hour',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'reminder_category',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
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
