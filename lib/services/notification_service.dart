import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    // Android initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
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
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - you can navigate to specific screens here
    // Payload format: "reminderId:timeSlotId" for multi-time or just "reminderId" for single-time
  }

  /// Schedule reminder notifications (handles both single and multi-time)
  static Future<void> scheduleReminder(Reminder reminder) async {
    // Don't schedule if notification is disabled
    if (!reminder.isNotificationEnabled) {
      return;
    }

    if (reminder.hasMultipleTimes) {
      // Schedule notifications for each time slot
      await _scheduleMultiTimeReminder(reminder);
    } else {
      // Schedule single notification (backward compatibility)
      await _scheduleSingleTimeReminder(reminder);
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
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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
    // Don't schedule if time has passed
    if (reminder.scheduledTime.isBefore(DateTime.now())) {
      return;
    }

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
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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
      matchDateTimeComponents: _getMatchDateTimeComponents(reminder.repeatType),
    );
  }

  /// Cancel all notifications for a reminder
  static Future<void> cancelReminder(String reminderId) async {
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
    // Cancel existing notifications
    await cancelReminder(reminder.id);

    // Reschedule with updated information
    await scheduleReminder(reminder);
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
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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
